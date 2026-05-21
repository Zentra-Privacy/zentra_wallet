import 'package:zentra_wallet_core/zentra_wallet_core.dart';

import '../core/network/zentra_network.dart';
import '../core/rpc/wallet_rpc_client.dart';
import '../models/wallet_models.dart';

class WalletService {
  WalletService({
    required ZentraNetworkConfig network,
    required RpcConnectionSettings rpc,
  })  : network = network,
        _rpc = WalletRpcClient(
          host: rpc.host,
          port: rpc.port,
          username: rpc.username,
          password: rpc.password,
        );

  final ZentraNetworkConfig network;
  final WalletRpcClient _rpc;
  final ZentraCore _core = ZentraCore.instance;

  WalletRpcClient get client => _rpc;

  bool validateAddress(String address) =>
      _core.validateAddress(address, network.ffiNetwork);

  String formatAtomic(int atomic) => _core.atomicToDisplay(atomic);

  int parseDisplay(String amount) => _core.displayToAtomic(amount);

  Future<WalletBalance> fetchBalance() async {
    final res = await _rpc.getBalance();
    return WalletBalance(
      balanceAtomic: (res['balance'] as num?)?.toInt() ?? 0,
      unlockedAtomic: (res['unlocked_balance'] as num?)?.toInt() ?? 0,
      blocksToUnlock: (res['blocks_to_unlock'] as num?)?.toInt() ?? 0,
    );
  }

  Future<WalletAddress> fetchPrimaryAddress() async {
    final res = await _rpc.getAddress();
    final list = res['addresses'] as List<dynamic>? ?? [];
    if (list.isNotEmpty) {
      final first = list.first as Map<String, dynamic>;
      return WalletAddress(
        address: first['address'] as String? ?? '',
        label: first['label'] as String?,
      );
    }
    // Legacy RPC field when addresses[] is empty
    final legacy = res['address'] as String?;
    if (legacy != null && legacy.isNotEmpty) {
      return WalletAddress(address: legacy);
    }
    throw WalletRpcException('No address returned from wallet RPC');
  }

  Future<int> fetchWalletHeight() async {
    final res = await _rpc.getHeight();
    return (res['height'] as num?)?.toInt() ?? 0;
  }

  Future<List<WalletTransfer>> fetchTransfers() async {
    final res = await _rpc.getTransfers();
    final incoming = (res['in'] as List<dynamic>? ?? [])
        .map((e) => WalletTransfer.fromRpc(e as Map<String, dynamic>, incoming: true));
    final outgoing = (res['out'] as List<dynamic>? ?? [])
        .map((e) => WalletTransfer.fromRpc(e as Map<String, dynamic>, incoming: false));
    // RPC pending list is outgoing unconfirmed only (get_unconfirmed_payments_out)
    final pending = (res['pending'] as List<dynamic>? ?? [])
        .map((e) => WalletTransfer.fromRpc(e as Map<String, dynamic>, incoming: false));
    final pool = (res['pool'] as List<dynamic>? ?? [])
        .map((e) => WalletTransfer.fromRpc(e as Map<String, dynamic>, incoming: true));
    final failed = (res['failed'] as List<dynamic>? ?? [])
        .map((e) => WalletTransfer.fromRpc(e as Map<String, dynamic>, incoming: false));
    final all = [...incoming, ...outgoing, ...pending, ...pool, ...failed];
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  Future<String> send({
    required String address,
    required String amountDisplay,
    int priority = 1,
  }) async {
    if (!validateAddress(address)) {
      throw WalletRpcException('Invalid Zentra address for ${network.label}');
    }
    final atomic = parseDisplay(amountDisplay);
    if (atomic <= 0) {
      throw WalletRpcException('Amount must be greater than zero');
    }
    final bal = await fetchBalance();
    if (atomic > bal.unlockedAtomic) {
      throw WalletRpcException(
        'Insufficient unlocked balance (${formatAtomic(bal.unlockedAtomic)} ZTR available)',
      );
    }
    final res = await _rpc.transfer(
      address: address,
      amountAtomic: atomic,
      priority: priority,
    );
    final txHash = res['tx_hash'] as String?;
    if (txHash == null || txHash.isEmpty) {
      throw WalletRpcException('Transfer succeeded but no tx_hash in response');
    }
    await _rpc.store();
    return txHash;
  }

  Future<void> createWallet({
    required String filename,
    required String password,
  }) async {
    await _rpc.createWallet(filename: filename, password: password);
  }

  Future<String> restoreWallet({
    required String filename,
    required String seed,
    required String password,
    int restoreHeight = 0,
  }) async {
    final res = await _rpc.restoreDeterministicWallet(
      filename: filename,
      seed: seed.trim(),
      password: password,
      restoreHeight: restoreHeight,
    );
    return res['address'] as String? ?? '';
  }

  Future<void> openWallet({
    required String filename,
    required String password,
  }) async {
    await _rpc.openWallet(filename: filename, password: password);
  }

  void dispose() => _rpc.dispose();
}
