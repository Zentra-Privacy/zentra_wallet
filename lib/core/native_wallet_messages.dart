/// User-facing copy when the embedded wallet engine (.so) is missing.
/// No shell scripts or developer commands — those belong in README / wallet.sh only.
abstract final class NativeWalletMessages {
  static const String title = 'Wallet engine unavailable';

  static const String subtitle =
      'This installation is missing the secure wallet module. '
      'Use the official desktop app package for your system.';

  static const String detail =
      'The wallet engine is not available on this device.';

  static const String shortHint = 'Wallet engine not installed';
}
