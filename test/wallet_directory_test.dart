import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zentra_wallet/core/wallet_directory.dart';

void main() {
  test('lists wallet base names from .keys files', () async {
    final dir = await Directory.systemTemp.createTemp('zentra_wallets_test_');
    try {
      await File('${dir.path}/alpha.keys').writeAsString('x');
      await File('${dir.path}/beta.keys').writeAsString('x');
      await File('${dir.path}/readme.txt').writeAsString('x');

      final names = await WalletDirectory.listWalletFilenames(dir.path);
      expect(names, ['alpha', 'beta']);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
