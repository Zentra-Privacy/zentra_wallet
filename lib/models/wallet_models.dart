class WalletBalance {
  const WalletBalance({
    required this.balanceAtomic,
    required this.unlockedAtomic,
    this.blocksToUnlock = 0,
  });

  final int balanceAtomic;
  final int unlockedAtomic;
  final int blocksToUnlock;
}

class WalletAddress {
  const WalletAddress({required this.address, this.label});

  final String address;
  final String? label;
}

class WalletTransfer {
  const WalletTransfer({
    required this.txid,
    required this.amountAtomic,
    required this.isIncoming,
    required this.timestamp,
    required this.height,
    required this.confirmations,
    this.paymentId,
    this.pending = false,
    this.failed = false,
  });

  final String txid;
  final int amountAtomic;
  final bool isIncoming;
  final int timestamp;
  final int height;
  final int confirmations;
  final String? paymentId;
  final bool pending;
  final bool failed;

  bool get isFailed => failed;

  factory WalletTransfer.fromRpc(Map<String, dynamic> json, {bool? incoming}) {
    final type = json['type'] as String?;
    final isIncoming = incoming ?? _incomingFromRpcType(type);
    return WalletTransfer(
      txid: json['txid'] as String? ?? '',
      amountAtomic: (json['amount'] as num?)?.toInt() ?? 0,
      isIncoming: isIncoming,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
      paymentId: json['payment_id'] as String?,
      pending: type == 'pending' || json['pending'] == true,
      failed: type == 'failed',
    );
  }

  /// Matches zentra `wallet_rpc_server::fill_transfer_entry` type strings.
  static bool _incomingFromRpcType(String? type) {
    switch (type) {
      case 'in':
      case 'pool':
      case 'block':
        return true;
      case 'out':
      case 'pending':
      case 'failed':
        return false;
      default:
        return true;
    }
  }
}

class RpcConnectionSettings {
  const RpcConnectionSettings({
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.daemonAddress,
    this.publicNodeId,
  });

  final String host;
  final int port;
  final String? username;
  final String? password;
  final String? daemonAddress;
  /// `seed1` / `seed2` when using a built-in mainnet VPS node.
  final String? publicNodeId;

  RpcConnectionSettings copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    String? daemonAddress,
    String? publicNodeId,
  }) =>
      RpcConnectionSettings(
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
        daemonAddress: daemonAddress ?? this.daemonAddress,
        publicNodeId: publicNodeId ?? this.publicNodeId,
      );
}
