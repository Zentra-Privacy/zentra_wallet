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

  /// Parsed from embedded wallet2 [TransactionHistory] JSON (native FFI).
  factory WalletTransfer.fromNative(Map<String, dynamic> json) {
    final paymentId = json['payment_id'] as String?;
    return WalletTransfer(
      txid: json['txid'] as String? ?? '',
      amountAtomic: ((json['amount'] as num?)?.toInt() ?? 0).abs(),
      isIncoming: json['incoming'] == true,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
      paymentId: paymentId != null && paymentId.isNotEmpty ? paymentId : null,
      pending: json['pending'] == true,
      failed: json['failed'] == true,
    );
  }
}

/// Remote zentrad node (daemon) — wallet runs inside the app.
class NodeConnectionSettings {
  const NodeConnectionSettings({
    required this.daemonAddress,
    this.publicNodeId,
  });

  final String daemonAddress;
  final String? publicNodeId;

  NodeConnectionSettings copyWith({
    String? daemonAddress,
    String? publicNodeId,
  }) =>
      NodeConnectionSettings(
        daemonAddress: daemonAddress ?? this.daemonAddress,
        publicNodeId: publicNodeId ?? this.publicNodeId,
      );
}
