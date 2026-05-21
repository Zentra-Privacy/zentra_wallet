import 'package:flutter/foundation.dart';
import 'package:zentra_wallet_core/zentra_wallet_core.dart';

import '../core/network/rpc_address.dart';
import '../core/network/zentra_network.dart';
import '../core/network/zentra_public_nodes.dart';
import '../core/rpc/daemon_rpc_client.dart';
import '../models/wallet_models.dart';
import '../services/settings_store.dart';
import '../services/wallet_service.dart';

enum WalletConnectionState { disconnected, connecting, connected, error }

class WalletProvider extends ChangeNotifier {
  WalletProvider({SettingsStore? settings})
      : _settings = settings ?? SettingsStore();

  final SettingsStore _settings;

  WalletConnectionState connectionState = WalletConnectionState.disconnected;
  String? errorMessage;

  ZentraNetType networkType = ZentraNetType.mainnet;
  ZentraNetworkConfig? networkConfig;
  RpcConnectionSettings? rpcSettings;
  WalletService? _service;

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
    rpcSettings = await _settings.loadRpc();
    walletFilename = await _settings.loadWalletFilename();
    selectedPublicNode = ZentraPublicNode.byId(rpcSettings?.publicNodeId);
    notifyListeners();
  }

  Future<void> pingDaemon() async {
    final daemon = rpcSettings?.daemonAddress;
    if (daemon == null || !daemon.contains(':')) {
      daemonStatus = null;
      return;
    }
    final parsed = RpcAddress.parse(daemon);
    if (parsed == null) {
      daemonStatus = 'Invalid daemon address';
      notifyListeners();
      return;
    }
    final client = DaemonRpcClient(host: parsed.host, port: parsed.port);
    try {
      final info = await client.getInfo();
      daemonBlockHeight = (info['height'] as num?)?.toInt() ?? 0;
      daemonStatus = 'Daemon OK · height $daemonBlockHeight';
    } catch (e) {
      daemonBlockHeight = 0;
      daemonStatus = 'Daemon unreachable: $e';
    } finally {
      client.dispose();
      notifyListeners();
    }
  }

  Future<bool> connect() async {
    if (rpcSettings == null) await initialize();
    connectionState = WalletConnectionState.connecting;
    errorMessage = null;
    notifyListeners();

    try {
      await pingDaemon();
      _service?.dispose();
      _service = WalletService(
        network: networkConfig!,
        rpc: rpcSettings!,
      );
      balance = await _service!.fetchBalance();
      primaryAddress = await _service!.fetchPrimaryAddress();
      walletHeight = await _service!.fetchWalletHeight();
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
    if (_service == null) return;
    isRefreshing = true;
    notifyListeners();
    try {
      balance = await _service!.fetchBalance();
      primaryAddress = await _service!.fetchPrimaryAddress();
      walletHeight = await _service!.fetchWalletHeight();
      transfers = await _service!.fetchTransfers();
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
    await _ensureService();
    try {
      await _service!.createWallet(filename: filename, password: password);
      await _settings.saveWalletFilename(filename);
      await _settings.setOnboarded(true);
      walletFilename = filename;
      return await connect();
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
    await _ensureService();
    try {
      await _service!.restoreWallet(
        filename: filename,
        seed: seed,
        password: password,
        restoreHeight: restoreHeight,
      );
      await _settings.saveWalletFilename(filename);
      await _settings.setOnboarded(true);
      walletFilename = filename;
      return await connect();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> openExistingWallet({
    required String filename,
    required String password,
  }) async {
    await _ensureService();
    try {
      await _service!.openWallet(filename: filename, password: password);
      await _settings.saveWalletFilename(filename);
      await _settings.setOnboarded(true);
      walletFilename = filename;
      return await connect();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String?> sendTransfer({
    required String address,
    required String amount,
  }) async {
    if (_service == null) return null;
    try {
      final tx = await _service!.send(address: address, amountDisplay: amount);
      await refresh();
      return tx;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  String formatAmount(int atomic) =>
      _service?.formatAtomic(atomic) ?? ZentraCore.instance.atomicToDisplay(atomic);

  int parseAmount(String display) =>
      _service?.parseDisplay(display) ?? ZentraCore.instance.displayToAtomic(display);

  bool validateAddress(String addr) {
    if (_service != null) return _service!.validateAddress(addr);
    final net = networkConfig?.ffiNetwork ?? ZentraNetwork.mainnet;
    return ZentraCore.instance.validateAddress(addr, net);
  }

  /// True when wallet is behind daemon by more than 3 blocks.
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
      rpcSettings = node.toRpcSettings(
        username: rpcSettings?.username,
        password: rpcSettings?.password,
      );
      selectedPublicNode = node;
    } else {
      final cfg = networkConfig!;
      rpcSettings = RpcConnectionSettings(
        host: '127.0.0.1',
        port: cfg.defaultWalletRpcPort,
        username: rpcSettings?.username,
        password: rpcSettings?.password,
        daemonAddress: '127.0.0.1:${cfg.daemonRpcPort}',
        publicNodeId: null,
      );
      selectedPublicNode = null;
    }
    await _settings.saveRpc(rpcSettings!);
    connectionState = WalletConnectionState.disconnected;
    _service?.dispose();
    _service = null;
    notifyListeners();
  }

  Future<void> updateRpc(RpcConnectionSettings settings) async {
    rpcSettings = settings;
    selectedPublicNode = ZentraPublicNode.byId(settings.publicNodeId);
    await _settings.saveRpc(settings);
    notifyListeners();
  }

  Future<void> applyPublicNode(ZentraPublicNode node) async {
    rpcSettings = node.toRpcSettings(
      username: rpcSettings?.username,
      password: rpcSettings?.password,
    );
    selectedPublicNode = node;
    await _settings.saveRpc(rpcSettings!);
    notifyListeners();
  }

  Future<void> _ensureService() async {
    if (_service != null) return;
    if (networkConfig == null || rpcSettings == null) await initialize();
    _service = WalletService(network: networkConfig!, rpc: rpcSettings!);
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }
}
