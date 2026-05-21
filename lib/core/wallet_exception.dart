/// Wallet-layer errors (validation, state) — distinct from missing native lib.
class WalletException implements Exception {
  WalletException(this.message);
  final String message;
  @override
  String toString() => message;
}
