import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zentra_wallet_core/zentra_wallet_core.dart';

import '../core/network/zentra_network.dart';
import '../core/network/zentra_public_nodes.dart';
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

  Future<void> initialize() async {
    networkType = await _settings.loadNetwork();
    networkConfig = ZentraNetworkConfig.fromType(networkType);
    nodeSettings = await _settings.loadNode();
    walletFilename = await _settings.loadWalletFilename();
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

  Future<bool> connect() async {
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
      _wallet!.openWallet(
        filename: walletFilename!,
        password: await _settings.loadWalletPassword() ?? '',
      );
      await _wallet!.refresh();
      balance = await _wallet!.fetchBalance();
      primaryAddress = await _wallet!.fetchPrimaryAddress();
      walletHeight = await _wallet!.fetchWalletHeight();
      daemonBlockHeight = await _wallet!.fetchDaemonHeight();
      daemonStatus = 'Daemon height $daemonBlockHeight';
      transfers = await _wallet!.fetchTransfers();
      connectionState = WalletConnectionState.connected;
      return true;
    } catch (e) {
      connectionState = WalletConnectionState.error;
      errorMessage = e.toString();
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_wallet == null || !(_wallet!.isOpen)) return;
    isRefreshing = true;
    notifyListeners();
    try {
      await _wallet!.refresh();
      balance = await _wallet!.fetchBalance();
      primaryAddress = await _wallet!.fetchPrimaryAddress();
      walletHeight = await _wallet!.fetchWalletHeight();
      daemonBlockHeight = await _wallet!.fetchDaemonHeight();
      transfers = await _wallet!.fetchTransfers();
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<bool> createNewWallet({
    required String filename,
    required String password,
  }) async {
    _refreshNativeFlag();
    if (!nativeAvailable) {
      errorMessage =
          'Embedded wallet not built. Run: ./scripts/build_native_wallet.sh';
      notifyListeners();
      return false;
    }
    await _ensureWallet();
    try {
      _wallet!.createWallet(filename: filename, password: password);
      await _settings.saveWalletFilename(filename);
      await _settings.saveWalletPassword(password);
      await _settings.setOnboarded(true);
      walletFilename = filename;
      return await _syncAfterOpen();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreFromSeed({
    required String filename,
    required String seed,
    required String password,
    int restoreHeight = 0,
  }) async {
    _refreshNativeFlag();
    if (!nativeAvailable) {
      errorMessage =
          'Embedded wallet not built. Run: ./scripts/build_native_wallet.sh';
      notifyListeners();
      return false;
    }
    await _ensureWallet();
    try {
      _wallet!.restoreWallet(
        filename: filename,
        password: password,
        seed: seed,
        restoreHeight: restoreHeight,
      );
      await _settings.saveWalletFilename(filename);
      await _settings.saveWalletPassword(password);
      await _settings.setOnboarded(true);
      walletFilename = filename;
      return await _syncAfterOpen();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> _syncAfterOpen() async {
    connectionState = WalletConnectionState.connecting;
    notifyListeners();
    try {
      await _wallet!.refresh();
      balance = await _wallet!.fetchBalance();
      primaryAddress = await _wallet!.fetchPrimaryAddress();
      walletHeight = await _wallet!.fetchWalletHeight();
      daemonBlockHeight = await _wallet!.fetchDaemonHeight();
      daemonStatus = 'Daemon height $daemonBlockHeight';
      transfers = await _wallet!.fetchTransfers();
      connectionState = WalletConnectionState.connected;
      return true;
    } catch (e) {
      connectionState = WalletConnectionState.error;
      errorMessage = e.toString();
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> openExistingWallet({
    required String filename,
    required String password,
  }) async {
    await _settings.saveWalletFilename(filename);
    await _settings.saveWalletPassword(password);
    await _settings.setOnboarded(true);
    walletFilename = filename;
    return connect();
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
      errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  String formatAmount(int atomic) =>
      _wallet?.formatAtomic(atomic) ?? ZentraCore.instance.atomicToDisplay(atomic);

  int parseAmount(String display) =>
      _wallet?.parseDisplay(display) ?? ZentraCore.instance.displayToAtomic(display);

  bool validateAddress(String addr) {
    if (addr.trim().isEmpty) return false;
    if (_wallet != null) return _wallet!.validateAddress(addr);
    if (!nativeAvailable || networkConfig == null) return false;
    return ZentraNativeWallet.instance.addressValid(addr, networkConfig!.type.index);
  }

  bool get isWalletBehindDaemon {
    if (daemonBlockHeight <= 0 || walletHeight <= 0) return false;
    return daemonBlockHeight - walletHeight > 3;
  }

  Future<void> updateNetwork(ZentraNetType type) async {
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
