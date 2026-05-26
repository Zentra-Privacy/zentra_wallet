/// Parse and validate blockchain restore / scan-from heights.
class RestoreHeightUtils {
  /// Matches native `kScanHeightMargin` in zentra_wallet_ffi.cpp.
  static const int daemonTipMargin = 12;

  /// Scan start for a brand-new wallet (near chain tip, not genesis).
  static int scanHeightFromDaemonTip(int daemonHeight) {
    if (daemonHeight <= 0) return 0;
    return daemonHeight > daemonTipMargin ? daemonHeight - daemonTipMargin : 0;
  }

  static int? parse(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    final n = int.tryParse(t);
    if (n == null || n < 0) return null;
    return n;
  }

  static String format(int height) => height <= 0 ? '' : height.toString();
}
