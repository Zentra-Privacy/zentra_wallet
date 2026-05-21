/// Sensitive wallet backup material shown once after create (or from Settings).
class WalletBackupInfo {
  const WalletBackupInfo({
    required this.address,
    this.seedPhrase,
    required this.walletName,
  });

  final String address;
  final String? seedPhrase;
  final String walletName;

  bool get hasSeed => seedPhrase != null && seedPhrase!.trim().isNotEmpty;
}
