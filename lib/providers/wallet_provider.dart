import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zentra_wallet_core/zentra_wallet_core.dart';

import '../core/native_wallet_messages.dart';
import '../core/network/zentra_network.dart';
import '../core/network/zentra_public_nodes.dart';
import '../core/restore_height_utils.dart';
import '../core/seed_utils.dart';
import '../core/wallet_directory.dart';
import '../core/wallet_exception.dart';
import '../models/wallet_backup_info.dart';
import '../models/wallet_models.dart';
import '../models/wallet_sync_status.dart';
import '../services/embedded_wallet_service.dart';
import '../services/settings_store.dart';
import '../services/wallet_auto_store.dart';
import '../services/wallet_blockchain_jobs.dart';
import '../services/wallet_native_worker.dart';

enum WalletConnectionState { disconnected, connecting, connected, error }

class WalletProvider extends ChangeNotifier {
  WalletProvider({SettingsStore? settings})
      : _settings = settings ?? SettingsStore();

  final SettingsStore _settings;
  final WalletBlockchainJobRunner _blockchainJobs = WalletBlockchainJobRunner();
  final WalletBackgroundSync _backgroundSync = WalletBackgroundSync();
  final WalletAutoStore _autoStore = WalletAutoStore();
  Future<void> _storeTail = Future<void>.value();
  bool _pollInFlight = false;
  int _zeroDaemonPolls = 0;

  WalletConnectionState connectionState = WalletConnectionState.disconnected;
  WalletSyncStatus syncStatus = WalletSyncStatus.disconnected;
  String? errorMessage;
  bool nativeAvailable = ZentraNativeWallet.isAvailable;

  ZentraNetType networkType = ZentraNetType.mainnet;
  ZentraNetworkConfig? networkConfig;
  NodeConnectionSettings? nodeSettings;
  EmbeddedWalletService? _wallet;
  String? _walletDir;
  int _connectGeneration = 0;

  WalletBalance? balance;
  WalletAddress? primaryAddress;
  List<WalletTransfer> transfers = [];
  int walletHeight = 0;
  int daemonBlockHeight = 0;
  String? daemonStatus;
  bool isRefreshing = false;

  /// Native wallet2 sync thread is running; UI updates via periodic snapshot polls.
  bool get isBackgroundSyncing => _backgroundSync.isActive;

  String? walletFilename;
  ZentraNetType? walletNetworkType;
  ZentraPublicNode? selectedPublicNode;
  int defaultRestoreHeight = 0;
  /// Last saved scan checkpoint in wallet file (refresh-from-block-height).
  int walletScanHeight = 0;

  Future<void> initialize() async {
    networkType = await _settings.loadNetwork();
    networkConfig = ZentraNetworkConfig.fromType(networkType);
    nodeSettings = await _settings.loadNode();
    walletFilename = await _settings.loadWalletFilename();
    walletNetworkType = await _settings.loadWalletNetwork();
    defaultRestoreHeight = await _settings.loadDefaultRestoreHeight();
    selectedPublicNode = ZentraPublicNode.byId(nodeSettings?.publicNodeId);
    nativeAvailable = ZentraNativeWallet.isAvailable;
    _walletDir = await _resolveWalletDir();
    notifyListeners();
  }

  Future<String> _resolveWalletDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/zentra_wallets');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Wallet base names saved on this device (`*.keys` in the wallet folder).
  Future<List<String>> listLocalWalletFilenames() async {
    _walletDir ??= await _resolveWalletDir();
    return WalletDirectory.listWalletFilenames(_walletDir!);
  }

  /// Returns [desired] or the next free name (`my_wallet` → `my_wallet1`, …).
  Future<String> resolveAvailableWalletFilename(String desired) async {
    final existing = await listLocalWalletFilenames();
    return WalletDirectory.uniqueWalletFilename(desired, existing);
  }

  Future<String> _resolveAvailableFilename(String desired) =>
      resolveAvailableWalletFilename(desired);

  Future<void> _ensureWallet() async {
    if (_wallet != null) return;
    if (networkConfig == null || nodeSettings == null) await initialize();
    _walletDir ??= await _resolveWalletDir();
    _wallet = EmbeddedWalletService(
      network: networkConfig!,
      walletDir: _walletDir!,
      daemonAddress: nodeSettings!.daemonAddress,
    );
  }

  void _refreshNativeFlag() => nativeAvailable = ZentraNativeWallet.isAvailable;

  static String _userMessage(Object e) {
    final s = e.toString();
    if (e is NativeWalletUnavailable || e is WalletException) {
      return s;
    }
    return s.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<void> _applyWalletSnapshot() async {
    balance = await _wallet!.fetchBalance();
    primaryAddress = await _wallet!.fetchPrimaryAddress();
    walletHeight = await _wallet!.fetchWalletHeight();
    daemonBlockHeight = await _wallet!.fetchDaemonHeight();
    daemonStatus = 'Daemon height $daemonBlockHeight';
    final list = await _wallet!.fetchTransfers();
    list.sort((a, b) {
      final ta = a.timestamp;
      final tb = b.timestamp;
      if (ta != tb) return tb.compareTo(ta);
      return b.height.compareTo(a.height);
    });
    transfers = list;
    walletScanHeight = _wallet!.fetchRestoreHeight();
  }

  void _clearWalletSnapshot() {
    balance = null;
    primaryAddress = null;
    transfers = [];
    walletHeight = 0;
    daemonBlockHeight = 0;
    daemonStatus = null;
    walletScanHeight = 0;
  }

  void _beginWalletOperation() {
    _connectGeneration++;
    _stopBlockchainSync();
    errorMessage = null;
  }

  void _disposeWalletOnFailure() {
    _stopBlockchainSync();
    _wallet?.dispose();
    _wallet = null;
    connectionState = WalletConnectionState.disconnected;
    syncStatus = WalletSyncStatus.disconnected;
    _clearWalletSnapshot();
  }

  void _stopBlockchainSync() {
    _backgroundSync.stop();
    _autoStore.stop();
    _blockchainJobs.reset();
    _storeTail = Future<void>.value();
    _pollInFlight = false;
    _zeroDaemonPolls = 0;
    syncStatus = WalletSyncStatus.disconnected;
  }

  void _startBlockchainSync() {
    if (_wallet == null || !_wallet!.isOpen) return;
    syncStatus = WalletSyncStatus.syncing;
    _backgroundSync.start(
      onNativeStart: () => _wallet!.startBackgroundRefresh(),
      onPoll: _pollSnapshotFromBackground,
    );
    _autoStore.start(
      onStore: ({required bool force}) => _persistWalletFile(force: force),
    );
  }

  /// Blocking refresh + snapshot before native background sync (daemon height is 0 until then).
  Future<void> _runInitialWalletRefresh() async {
    await _blockchainJobs.run(() async {
      await _wallet!.refresh();
      await _applyWalletSnapshot();
    });
    _updateSyncStatusFromHeights();
  }

  Future<void> _pollSnapshotFromBackground() async {
    if (_wallet == null || !_wallet!.isOpen || _pollInFlight) return;
    final gen = _connectGeneration;
    _pollInFlight = true;
    try {
      await _blockchainJobs.run(() async {
        if (gen != _connectGeneration || _wallet == null || !_wallet!.isOpen) return;
        final wasSynced = isSynced;
        if (daemonBlockHeight <= 0) {
          _zeroDaemonPolls++;
          // Background refresh alone may not update heights on Android; retry refresh periodically.
          if (_zeroDaemonPolls == 1 || _zeroDaemonPolls % 5 == 0) {
            await _wallet!.refresh();
          }
        } else {
          _zeroDaemonPolls = 0;
        }
        await _applyWalletSnapshot();
        if (gen != _connectGeneration) return;
        _updateSyncStatusFromHeights();
        if (!wasSynced && isSynced) {
          await _persistWalletFile(force: true);
        } else {
          await _persistWalletFile(force: false);
        }
      });
      if (gen == _connectGeneration) {
        if (daemonBlockHeight > 0) {
          errorMessage = null;
        }
        notifyListeners();
      }
    } catch (e) {
      if (gen == _connectGeneration) {
        if (daemonBlockHeight <= 0) {
          errorMessage = _userMessage(e);
          notifyListeners();
        }
        assert(() {
          debugPrint('Wallet background poll failed: $e');
          return true;
        }());
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _updateSyncStatusFromHeights() {
    if (connectionState != WalletConnectionState.connected) return;
    if (isSynced) {
      syncStatus = WalletSyncStatus.synced;
    } else {
      syncStatus = WalletSyncStatus.syncing;
    }
  }

  /// Serializes wallet [store] without the blockchain job queue (avoids deadlock with send).
  Future<void> _persistWalletFile({required bool force}) async {
    if (_wallet == null || !_wallet!.isOpen) return;
    final op = _storeTail.then((_) async {
      if (_wallet == null || !_wallet!.isOpen) return;
      await _autoStore.maybeStore(
        force: force,
        isSynced: isSynced,
        walletHeight: walletHeight,
        store: () async => _wallet!.store(),
      );
    });
    _storeTail = op.catchError((Object e) {
      if (force) {
        assert(() {
          debugPrint('Wallet store failed: $e');
          return true;
        }());
      }
    });
    await op;
  }

  /// Called when [connect] is aborted externally (e.g. splash screen timeout).
  void markConnectFailed(String message) {
    _connectGeneration++;
    _stopBlockchainSync();
    connectionState = WalletConnectionState.error;
    errorMessage = message;
    _wallet?.dispose();
    _wallet = null;
    _clearWalletSnapshot();
    notifyListeners();
  }

  /// Resets session before onboarding create/open/restore (Settings → different wallet).
  void prepareForNewWalletFlow() {
    _resetWalletSession();
    notifyListeners();
  }

  /// True when a newer connect/reset superseded [gen]; cleans up stale native wallet.
  bool _connectStale(int gen) {
    if (gen == _connectGeneration) return false;
    _disposeWalletOnFailure();
    return true;
  }

  Future<bool> connect({
    String? passwordOverride,
    /// When false, opens the wallet and starts background sync without blocking on [refresh].
    /// Use on splash so Home can show while the node syncs (mobile networks are slower).
    bool waitForInitialSync = true,
  }) async {
    final gen = ++_connectGeneration;
    _stopBlockchainSync();
    _refreshNativeFlag();
    if (!nativeAvailable) {
      connectionState = WalletConnectionState.error;
      errorMessage =
          NativeWalletMessages.detail;
      notifyListeners();
      return false;
    }
    if (walletFilename == null || walletFilename!.isEmpty) {
      connectionState = WalletConnectionState.disconnected;
      notifyListeners();
      return false;
    }

    _walletDir ??= await _resolveWalletDir();
    if (!await WalletDirectory.walletKeysExist(_walletDir!, walletFilename!)) {
      await _settings.clearWalletFilename();
      walletFilename = null;
      connectionState = WalletConnectionState.disconnected;
      notifyListeners();
      return false;
    }

    connectionState = WalletConnectionState.connecting;
    syncStatus = WalletSyncStatus.disconnected;
    errorMessage = null;
    notifyListeners();

    if (walletNetworkType != null && walletNetworkType != networkType) {
      connectionState = WalletConnectionState.error;
      errorMessage =
          'Wallet "${walletFilename!}" is for ${ZentraNetworkConfig.fromType(walletNetworkType!).label}. '
          'Switch network in Settings or use another wallet file.';
      notifyListeners();
      return false;
    }

    try {
      await _ensureWallet();
      if (_connectStale(gen)) return false;
      final password = passwordOverride ?? await _settings.loadWalletPassword() ?? '';
      syncStatus = WalletSyncStatus.connecting;
      await _blockchainJobs.run(() async {
        _wallet!.openWallet(filename: walletFilename!, password: password);
      });
      if (_connectStale(gen)) return false;
      if (waitForInitialSync) {
        await _runInitialWalletRefresh();
        if (_connectStale(gen)) return false;
      }
      connectionState = WalletConnectionState.connected;
      _startBlockchainSync();
      if (!waitForInitialSync) {
        syncStatus = WalletSyncStatus.syncing;
        unawaited(_runInitialWalletRefresh().catchError((Object e) {
          if (gen == _connectGeneration) {
            errorMessage = _userMessage(e);
            notifyListeners();
          }
        }));
      }
      if (_connectStale(gen)) return false;
      errorMessage = null;
      return true;
    } catch (e) {
      if (_connectStale(gen)) return false;
      _stopBlockchainSync();
      connectionState = WalletConnectionState.error;
      errorMessage = _userMessage(e);
      _wallet?.dispose();
      _wallet = null;
      return false;
    } finally {
      if (gen == _connectGeneration) {
        if (connectionState == WalletConnectionState.connecting) {
          _stopBlockchainSync();
          connectionState = WalletConnectionState.error;
          errorMessage ??= 'Connection interrupted';
          _wallet?.dispose();
          _wallet = null;
        }
        notifyListeners();
      }
    }
  }

  /// Pull-to-refresh / manual update. Uses a light snapshot poll while background sync runs.
  Future<void> refresh({bool forceBlocking = false}) async {
    if (_wallet == null || !_wallet!.isOpen) return;
    isRefreshing = true;
    notifyListeners();
    try {
      if (_backgroundSync.isActive && !forceBlocking) {
        await _pollSnapshotFromBackground();
      } else {
        await _blockchainJobs.run(() async {
          await _wallet!.refresh();
          await _applyWalletSnapshot();
        });
      }
      errorMessage = null;
    } catch (e) {
      errorMessage = _userMessage(e);
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> updateDefaultRestoreHeight(int height) async {
    defaultRestoreHeight = height.clamp(0, 0x7FFFFFFF);
    await _settings.saveDefaultRestoreHeight(defaultRestoreHeight);
    notifyListeners();
  }

  /// Applies restore height to the open wallet and saves as default.
  Future<bool> applyRestoreHeightToOpenWallet(int height) async {
    if (_wallet == null || !_wallet!.isOpen) {
      errorMessage = 'Open a wallet first';
      notifyListeners();
      return false;
    }
    _stopBlockchainSync();
    try {
      _wallet!.setRestoreHeight(height);
      await updateDefaultRestoreHeight(height);
      await _blockchainJobs.run(() async {
        await _wallet!.refresh();
        await _applyWalletSnapshot();
      });
      _updateSyncStatusFromHeights();
      return true;
    } catch (e) {
      errorMessage = _userMessage(e);
      return false;
    } finally {
      if (_wallet != null && _wallet!.isOpen) {
        _startBlockchainSync();
      }
      notifyListeners();
    }
  }

  Future<bool> createNewWallet({
    required String filename,
    required String password,
    int? restoreHeight,
  }) async {
    _refreshNativeFlag();
    if (!nativeAvailable) {
      errorMessage =
          NativeWalletMessages.detail;
      notifyListeners();
      return false;
    }
    if (!isValidWalletFilename(filename)) {
      errorMessage = 'Wallet name must be a simple filename (no path separators)';
      notifyListeners();
      return false;
    }
    final resolved = await _resolveAvailableFilename(filename);
    await _ensureWallet();
    _beginWalletOperation();
    try {
      final trusted = EmbeddedWalletService.isTrustedDaemon(nodeSettings!.daemonAddress);
      final handleAddr = await WalletNativeWorker.createWallet(
        walletDir: _walletDir!,
        daemonAddress: nodeSettings!.daemonAddress,
        trustedDaemon: trusted,
        filename: resolved,
        password: password,
        nettype: networkConfig!.type.index,
        restoreHeight: restoreHeight ?? 0,
      );
      _wallet!.adoptHandle(WalletNativeWorker.pointerFromAddress(handleAddr));
      if (restoreHeight == null) {
        await _setScanHeightFromDaemonTip();
      }
      final ok = await _syncAfterOpen();
      if (ok) {
        await _persistWalletSession(resolved, password);
        if (restoreHeight != null) await updateDefaultRestoreHeight(restoreHeight);
      }
      return ok;
    } catch (e) {
      _disposeWalletOnFailure();
      connectionState = WalletConnectionState.error;
      errorMessage = _userMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreFromSeed({
    required String filename,
    required String seed,
    required String password,
    int? restoreHeight,
  }) async {
    _refreshNativeFlag();
    if (!nativeAvailable) {
      errorMessage =
          NativeWalletMessages.detail;
      notifyListeners();
      return false;
    }
    final normalized = SeedUtils.normalize(seed);
    if (!SeedUtils.isValidWordCount(normalized)) {
      errorMessage = 'Seed must be 12, 13, 24, or 25 words';
      notifyListeners();
      return false;
    }
    if (!isValidWalletFilename(filename)) {
      errorMessage = 'Wallet name must be a simple filename (no path separators)';
      notifyListeners();
      return false;
    }
    final resolved = await _resolveAvailableFilename(filename);
    await _ensureWallet();
    _beginWalletOperation();
    try {
      final trusted = EmbeddedWalletService.isTrustedDaemon(nodeSettings!.daemonAddress);
      final handleAddr = await WalletNativeWorker.restoreWallet(
        walletDir: _walletDir!,
        daemonAddress: nodeSettings!.daemonAddress,
        trustedDaemon: trusted,
        filename: resolved,
        password: password,
        seed: normalized,
        nettype: networkConfig!.type.index,
        restoreHeight: restoreHeight ?? defaultRestoreHeight,
      );
      _wallet!.adoptHandle(WalletNativeWorker.pointerFromAddress(handleAddr));
      final ok = await _syncAfterOpen();
      if (ok) {
        await _persistWalletSession(resolved, password);
        if (restoreHeight != null) await updateDefaultRestoreHeight(restoreHeight);
      }
      return ok;
    } catch (e) {
      _disposeWalletOnFailure();
      connectionState = WalletConnectionState.error;
      errorMessage = _userMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// New wallets: start scan near daemon tip (fast). Restore still uses user height.
  Future<void> _setScanHeightFromDaemonTip() async {
    if (_wallet == null || !_wallet!.isOpen) return;
    try {
      final daemonH = await _wallet!.fetchDaemonHeight();
      final tip = RestoreHeightUtils.scanHeightFromDaemonTip(daemonH);
      if (tip > 0) {
        _wallet!.setRestoreHeight(tip);
      }
    } catch (_) {
      // First refresh may still proceed from height 0.
    }
  }

  Future<bool> _syncAfterOpen() async {
    connectionState = WalletConnectionState.connected;
    syncStatus = WalletSyncStatus.syncing;
    errorMessage = null;
    notifyListeners();
    try {
      await _runInitialWalletRefresh();
      _startBlockchainSync();
      return true;
    } catch (e) {
      _disposeWalletOnFailure();
      connectionState = WalletConnectionState.error;
      errorMessage = _userMessage(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _persistWalletSession(String filename, String password) async {
    await _settings.saveWalletFilename(filename);
    await _settings.saveWalletPassword(password);
    await _settings.saveWalletNetwork(networkType);
    await _settings.setOnboarded(true);
    walletFilename = filename;
    walletNetworkType = networkType;
  }

  Future<bool> openExistingWallet({
    required String filename,
    required String password,
  }) async {
    final previousFilename = walletFilename;
    walletFilename = filename;
    final ok = await connect(passwordOverride: password);
    if (ok) {
      await _persistWalletSession(filename, password);
    } else {
      walletFilename = previousFilename;
    }
    return ok;
  }

  static bool isValidWalletFilename(String name) {
    final t = name.trim();
    return t.isNotEmpty && !t.contains('/') && !t.contains('\\');
  }

  int sendPriority = 0;

  Future<int?> estimateTransferFee({
    required String address,
    required String amount,
    int? priority,
  }) async {
    if (_wallet == null || !_wallet!.isOpen) return null;
    return _blockchainJobs.run(
      () async => _wallet!.estimateFee(
        address: address,
        amountDisplay: amount,
        priority: priority ?? sendPriority,
      ),
    );
  }

  Future<String?> sendTransfer({
    required String address,
    required String amount,
    int? priority,
  }) async {
    if (_wallet == null || !_wallet!.isOpen) {
      errorMessage = 'Wallet not open';
      notifyListeners();
      return null;
    }
    if (!canTransact) {
      errorMessage = !isSynced
          ? 'Wait for sync to finish before sending'
          : 'Wallet not ready';
      notifyListeners();
      return null;
    }
    try {
      final tx = await _blockchainJobs.run(
        () => _wallet!.send(
          address: address,
          amountDisplay: amount,
          priority: priority ?? sendPriority,
        ),
      );
      await _persistWalletFile(force: true);
      try {
        await refresh();
      } catch (_) {
        // Send may have succeeded; background sync will catch up on Home.
      }
      return tx;
    } catch (e) {
      errorMessage = _userMessage(e);
      notifyListeners();
      return null;
    }
  }

  int get lockedBalanceAtomic {
    final b = balance;
    if (b == null) return 0;
    final locked = b.balanceAtomic - b.unlockedAtomic;
    return locked > 0 ? locked : 0;
  }

  String formatAmount(int atomic) =>
      _wallet?.formatAtomic(atomic) ?? ZentraCore.instance.atomicToDisplay(atomic);

  int parseAmount(String display) =>
      _wallet?.parseDisplay(display) ?? ZentraCore.instance.displayToAtomic(display);

  /// Seed + address from the open wallet (for backup screen).
  Future<WalletBackupInfo?> fetchBackupInfo() async {
    if (_wallet == null || !_wallet!.isOpen) return null;
    try {
      final addr = primaryAddress ?? await _wallet!.fetchPrimaryAddress();
      final seed = _wallet!.fetchSeed();
      return WalletBackupInfo(
        address: addr.address,
        seedPhrase: seed?.trim().isNotEmpty == true ? seed!.trim() : null,
        walletName: walletFilename ?? 'wallet',
      );
    } catch (_) {
      return null;
    }
  }

  bool validateAddress(String addr) {
    final trimmed = addr.trim();
    if (trimmed.isEmpty) return false;
    if (_wallet != null) return _wallet!.validateAddress(trimmed);
    if (!nativeAvailable || networkConfig == null) return false;
    return ZentraNativeWallet.instance.addressValid(trimmed, networkConfig!.type.index);
  }

  int get blocksBehindDaemon {
    if (daemonBlockHeight <= 0) return 0;
    if (walletHeight <= 0) return daemonBlockHeight;
    final behind = daemonBlockHeight - walletHeight;
    return behind > 0 ? behind : 0;
  }

  /// Cake Wallet: synced when within [kWalletSyncedBlocksThreshold] of daemon tip.
  bool get isSynced =>
      connectionState == WalletConnectionState.connected &&
      daemonBlockHeight > 0 &&
      blocksBehindDaemon < kWalletSyncedBlocksThreshold;

  bool get isWalletBehindDaemon => !isSynced && daemonBlockHeight > 0;

  /// True only while the wallet file is being opened (not blockchain catch-up sync).
  bool get isOpeningWallet =>
      syncStatus == WalletSyncStatus.connecting ||
      (connectionState == WalletConnectionState.connecting && !_backgroundSync.isActive);

  /// Connected but daemon height not available yet (node RPC / first refresh pending).
  bool get isWaitingForDaemon =>
      connectionState == WalletConnectionState.connected && daemonBlockHeight <= 0;

  bool get showSyncBanner =>
      isWalletBehindDaemon || isWaitingForDaemon || (connectionState == WalletConnectionState.connected && !isSynced);

  /// Subtitle under the sync banner on Home / History / Settings.
  String? get syncBannerSubtitle {
    if (isWaitingForDaemon) {
      return isBackgroundSyncing ? 'Fetching node status…' : 'Connecting to node…';
    }
    return syncProgressLabel;
  }

  bool get canTransact =>
      connectionState == WalletConnectionState.connected && isSynced;

  String get connectionStatusLabel {
    if (connectionState == WalletConnectionState.error) return 'Error';
    if (connectionState == WalletConnectionState.disconnected) return 'Offline';
    if (connectionState == WalletConnectionState.connecting) return 'Connecting';
    switch (syncStatus) {
      case WalletSyncStatus.synced:
        return 'Synced';
      case WalletSyncStatus.syncing:
        return 'Syncing';
      case WalletSyncStatus.attempting:
        return 'Syncing';
      case WalletSyncStatus.connected:
        return 'Connected';
      case WalletSyncStatus.connecting:
        return 'Opening';
      case WalletSyncStatus.disconnected:
        return 'Offline';
    }
  }

  /// e.g. "Block 650 of 668 · 18 blocks behind" while catching up.
  String? get syncProgressLabel {
    if (!isWalletBehindDaemon || daemonBlockHeight <= 0) return null;
    final behind = blocksBehindDaemon;
    if (behind > 0 && behind < daemonBlockHeight) {
      return 'Block $walletHeight of $daemonBlockHeight · $behind behind';
    }
    return 'Block $walletHeight of $daemonBlockHeight';
  }

  double? get syncProgressFraction {
    if (!isWalletBehindDaemon || daemonBlockHeight <= 0) return null;
    return (walletHeight / daemonBlockHeight).clamp(0.0, 1.0);
  }

  Future<void> updateNetwork(ZentraNetType type) async {
    final reconnect = walletFilename != null && walletFilename!.isNotEmpty;
    if (reconnect &&
        walletNetworkType != null &&
        walletNetworkType != type) {
      errorMessage =
          'This wallet belongs to ${ZentraNetworkConfig.fromType(walletNetworkType!).label}. '
          'Use a different wallet file for ${ZentraNetworkConfig.fromType(type).label}.';
      notifyListeners();
      return;
    }
    networkType = type;
    networkConfig = ZentraNetworkConfig.fromType(type);
    await _settings.saveNetwork(type);
    if (type == ZentraNetType.mainnet) {
      final node = ZentraPublicNode.seedPrimary;
      nodeSettings = node.toNodeSettings();
      selectedPublicNode = node;
    } else {
      final cfg = networkConfig!;
      nodeSettings = NodeConnectionSettings(
        daemonAddress: '127.0.0.1:${cfg.daemonRpcPort}',
      );
      selectedPublicNode = null;
    }
    await _settings.saveNode(nodeSettings!);
    _resetWalletSession();
    notifyListeners();
    if (reconnect) await connect();
  }

  Future<void> updateNode(NodeConnectionSettings settings) async {
    final reconnect = connectionState == WalletConnectionState.connected &&
        walletFilename != null &&
        walletFilename!.isNotEmpty;
    nodeSettings = settings;
    selectedPublicNode = ZentraPublicNode.byId(settings.publicNodeId);
    await _settings.saveNode(settings);
    _resetWalletSession();
    notifyListeners();
    if (reconnect) await connect();
  }

  void _resetWalletSession() {
    _connectGeneration++;
    _stopBlockchainSync();
    _wallet?.dispose();
    _wallet = null;
    balance = null;
    primaryAddress = null;
    transfers = [];
    walletHeight = 0;
    daemonBlockHeight = 0;
    daemonStatus = null;
    walletScanHeight = 0;
    connectionState = WalletConnectionState.disconnected;
    errorMessage = null;
  }

  @override
  void dispose() {
    _connectGeneration++;
    _stopBlockchainSync();
    _wallet?.dispose();
    _wallet = null;
    ZentraNativeWallet.release();
    super.dispose();
  }
}
