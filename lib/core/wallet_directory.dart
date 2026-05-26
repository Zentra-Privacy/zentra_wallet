import 'dart:io';

/// Discovers wallet files under the app wallet directory (Monero-style `*.keys`).
class WalletDirectory {
  const WalletDirectory._();

  static Future<List<String>> listWalletFilenames(String walletDir) async {
    final dir = Directory(walletDir);
    if (!await dir.exists()) return [];

    final names = <String>{};
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final base = _basename(entity.path);
      if (base.endsWith('.keys') && base.length > 5) {
        names.add(base.substring(0, base.length - 5));
      }
    }

    final list = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static String _basename(String path) {
    final sep = Platform.pathSeparator;
    final i = path.lastIndexOf(sep);
    return i < 0 ? path : path.substring(i + 1);
  }
}
