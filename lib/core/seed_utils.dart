/// Normalize and validate Monero-style mnemonic seeds.
class SeedUtils {
  static String normalize(String seed) =>
      seed.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

  /// English Monero mnemonics are typically 25 words (24 + checksum word).
  static bool isValidWordCount(String seed) {
    final n = normalize(seed).split(' ').length;
    return n == 12 || n == 13 || n == 24 || n == 25;
  }
}
