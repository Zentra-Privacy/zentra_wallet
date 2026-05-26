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

  group('uniqueWalletFilename', () {
    test('returns desired when free', () {
      expect(
        WalletDirectory.uniqueWalletFilename('my_wallet', ['other']),
        'my_wallet',
      );
    });

    test('appends increment when taken', () {
      expect(
        WalletDirectory.uniqueWalletFilename('my_wallet', ['my_wallet']),
        'my_wallet1',
      );
      expect(
        WalletDirectory.uniqueWalletFilename('my_wallet', ['my_wallet', 'my_wallet1']),
        'my_wallet2',
      );
    });

    test('case-insensitive collision', () {
      expect(
        WalletDirectory.uniqueWalletFilename('my_wallet', ['My_Wallet']),
        'my_wallet1',
      );
    });
  });
}
