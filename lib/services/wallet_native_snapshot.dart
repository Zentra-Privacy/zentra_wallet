/// Serializable wallet state from a worker isolate (Cake Wallet pattern).
class WalletNativeSnapshot {
  const WalletNativeSnapshot({
    required this.balanceAtomic,
    required this.unlockedAtomic,
    required this.walletHeight,
    required this.daemonHeight,
    required this.address,
    required this.restoreHeight,
    this.transfers = const [],
  });

  final int balanceAtomic;
  final int unlockedAtomic;
  final int walletHeight;
  final int daemonHeight;
  final String address;
  final int restoreHeight;
  final List<Map<String, dynamic>> transfers;
}
