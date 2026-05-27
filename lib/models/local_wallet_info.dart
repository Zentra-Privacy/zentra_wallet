/// A wallet file on this device (MetaMask-style account list entry).
class LocalWalletInfo {
  const LocalWalletInfo({
    required this.filename,
    required this.isActive,
    required this.hasStoredPassword,
    this.networkLabel,
    this.addressPreview,
  });

  final String filename;
  final bool isActive;
  final bool hasStoredPassword;
  final String? networkLabel;
  /// Truncated primary address when this wallet is connected.
  final String? addressPreview;
}
