import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zentra_wallet_core/zentra_wallet_core.dart';

import '../core/network/zentra_network.dart';
import '../core/network/zentra_public_nodes.dart';
import '../core/seed_utils.dart';
import '../core/wallet_exception.dart';
import '../models/wallet_models.dart';
import '../services/embedded_wallet_service.dart';
import '../services/settings_store.dart';

enum WalletConnectionState { disconnected, connecting, connected, error }

class WalletProvider extends ChangeNotifier {
  WalletProvider({SettingsStore? settings})
      : _settings = settings ?? SettingsStore();

  final SettingsStore _settings;

  WalletConnectionState connectionState = WalletConnectionState.disconnected;
  String? errorMessage;
  bool nativeAvailable = ZentraNativeWallet.isAvailable;

  ZentraNetType networkType = ZentraNetType.mainnet;
  ZentraNetworkConfig? networkConfig;
  NodeConnectionSettings? nodeSettings;
  EmbeddedWalletService? _wallet;
  String? _walletDir;

  WalletBalance? balance;
  WalletAddress? primaryAddress;
  List<WalletTransfer> transfers = [];
  int walletHeight = 0;
  int daemonBlockHeight = 0;
  String? daemonStatus;
  bool isRefreshing = false;

  String? walletFilename;
  ZentraPublicNode? selectedPublicNode;
  int defaultRestoreHeight = 0;

  Future<void> initialize() async {
    networkType = await _settings.loadNetwork();
    networkConfig = ZentraNetworkConfig.fromType(networkType);
    nodeSettings = await _settings.loadNode();
    walletFilename = await _settings.loadWalletFilename();
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
  }

  Future<bool> connect({String? passwordOverride}) async {
    _refreshNativeFlag();
    if (!nativeAvailable) {
      connectionState = WalletConnectionState.error;
      errorMessage =
          'Embedded wallet not built. Run: ./scripts/build_native_wallet.sh';
      notifyListeners();
      return false;
    }
    if (walletFilename == null || walletFilename!.isEmpty) {
      connectionState = WalletConnectionState.disconnected;
      return false;
    }

    connectionState = WalletConnectionState.connecting;
    errorMessage = null;
    notifyListeners();

    try {
      await _ensureWallet();
      final password = passwordOverride ?? await _settings.loadWalletPassword() ?? '';
      _wallet!.openWallet(
        filename: walletFilename!,
        password: password,
      );
      await _wallet!.refresh();
      await _applyWalletSnapshot();
      connectionState = WalletConnectionState.connected;
      return true;
    } catch (e) {
      connectionState = WalletConnectionState.error;
      errorMessage = _userMessage(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_wallet == null || !_wallet!.isOpen) return;
    isRefreshing = true;
    notifyListeners();
    try {
      await _wallet!.refresh();
      await _applyWalletSnapshot();
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
    try {
      _wallet!.setRestoreHeight(height);
      await updateDefaultRestoreHeight(height);
      await refresh();
      return true;
    } catch (e) {
      errorMessage = _userMessage(e);
      notifyListeners();
      return false;
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
          'Embedded wallet not built. Run: ./scripts/build_native_wallet.sh';
      notifyListeners();
      return false;
    }
    if (!isValidWalletFilename(filename)) {
      errorMessage = 'Wallet name must be a simple filename (no path separators)';
      notifyListeners();
      return false;
    }
    await _ensureWallet();
    try {
      _wallet!.createWallet(
        filename: filename.trim(),
        password: password,
        restoreHeight: restoreHeight ?? defaultRestoreHeight,
      );
      final ok = await _syncAfterOpen();
      if (ok) {
        await _persistWalletSession(filename, password);
        if (restoreHeight != null) await updateDefaultRestoreHeight(restoreHeight);
      }
      return ok;
    } catch (e) {
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
          'Embedded wallet not built. Run: ./scripts/build_native_wallet.sh';
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
    await _ensureWallet();
    try {
      _wallet!.restoreWallet(
        filename: filename.trim(),
        password: password,
        seed: normalized,
        restoreHeight: restoreHeight ?? defaultRestoreHeight,
      );
      final ok = await _syncAfterOpen();
      if (ok) {
        await _persistWalletSession(filename, password);
        if (restoreHeight != null) await updateDefaultRestoreHeight(restoreHeight);
      }
      return ok;
    } catch (e) {
      errorMessage = _userMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> _syncAfterOpen() async {
    connectionState = WalletConnectionState.connecting;
    notifyListeners();
    try {
      await _wallet!.refresh();
      await _applyWalletSnapshot();
      connectionState = WalletConnectionState.connected;
      return true;
    } catch (e) {
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
    await _settings.setOnboarded(true);
    walletFilename = filename;
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

  Future<String?> sendTransfer({
    required String address,
    required String amount,
  }) async {
    if (_wallet == null || !_wallet!.isOpen) {
      errorMessage = 'Wallet not open';
      notifyListeners();
      return null;
    }
    if (connectionState != WalletConnectionState.connected) {
      errorMessage = 'Wallet not connected';
      notifyListeners();
      return null;
    }
    try {
      final tx = await _wallet!.send(address: address, amountDisplay: amount);
      await refresh();
      return tx;
    } catch (e) {
      errorMessage = _userMessage(e);
      notifyListeners();
      return null;
    }
  }

  String formatAmount(int atomic) =>
      _wallet?.formatAtomic(atomic) ?? ZentraCore.instance.atomicToDisplay(atomic);

  int parseAmount(String display) =>
      _wallet?.parseDisplay(display) ?? ZentraCore.instance.displayToAtomic(display);

  bool validateAddress(String addr) {
    final trimmed = addr.trim();
    if (trimmed.isEmpty) return false;
    if (_wallet != null) return _wallet!.validateAddress(trimmed);
    if (!nativeAvailable || networkConfig == null) return false;
    return ZentraNativeWallet.instance.addressValid(trimmed, networkConfig!.type.index);
  }

  bool get isWalletBehindDaemon {
    if (daemonBlockHeight <= 0 || walletHeight <= 0) return false;
    return daemonBlockHeight - walletHeight > 3;
  }

  Future<void> updateNetwork(ZentraNetType type) async {
    final reconnect = walletFilename != null && walletFilename!.isNotEmpty;
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
    _wallet?.dispose();
    _wallet = null;
    balance = null;
    primaryAddress = null;
    transfers = [];
    walletHeight = 0;
    daemonBlockHeight = 0;
    daemonStatus = null;
    connectionState = WalletConnectionState.disconnected;
    errorMessage = null;
  }

  @override
  void dispose() {
    _wallet?.dispose();
    super.dispose();
  }
}
