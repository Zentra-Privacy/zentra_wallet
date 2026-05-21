/// Parse and validate blockchain restore / scan-from heights.
class RestoreHeightUtils {
  static int? parse(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    final n = int.tryParse(t);
    if (n == null || n < 0) return null;
    return n;
  }

  static String format(int height) => height <= 0 ? '' : height.toString();
}
