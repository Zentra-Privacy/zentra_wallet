import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zentra_wallet/models/wallet_models.dart';
import 'package:zentra_wallet_core/zentra_wallet_core.dart';

bool _nativeAvailable() {
  try {
    if (Platform.isLinux) {
      ffi.DynamicLibrary.open('libzentra_wallet_core_plugin.so');
      return true;
    }
  } catch (_) {}
  return false;
}

void main() {
  test('C++ core amount round-trip', () {
    if (!_nativeAvailable()) {
      // `flutter test` does not bundle the FFI .so; run after `flutter build linux`.
      return;
    }
    final core = ZentraCore.instance;
    expect(core.displayToAtomic('1.5'), 1500000000);
    expect(core.atomicToDisplay(1500000000), '1.5');
    expect(core.coinTicker, 'ZTR');
  });

  test('transfer direction from RPC type field', () {
    final pending = WalletTransfer.fromRpc({
      'txid': 'abc',
      'amount': 1000,
      'type': 'pending',
      'timestamp': 1,
      'height': 0,
    });
    expect(pending.isIncoming, isFalse);
    expect(pending.pending, isTrue);

    final pool = WalletTransfer.fromRpc({
      'txid': 'def',
      'amount': 2000,
      'type': 'pool',
      'timestamp': 2,
      'height': 0,
    });
    expect(pool.isIncoming, isTrue);

    final failed = WalletTransfer.fromRpc({
      'txid': 'fail',
      'amount': 500,
      'type': 'failed',
      'timestamp': 3,
      'height': 0,
    });
    expect(failed.isIncoming, isFalse);
    expect(failed.failed, isTrue);
  });

  test('address prefix validation mainnet', () {
    if (!_nativeAvailable()) {
      return;
    }
    final core = ZentraCore.instance;
    expect(
      core.validateAddress(
        'Z7i2zfb8jc9PmBBodytkH5YaSW47CK3X2JhMxdPLvqxHjmuRQMwJLVgDtFkU3h5jgFVSS5evJfmVWbNUeAdHspG82MaXVnZmS',
        ZentraNetwork.mainnet,
      ),
      isTrue,
    );
    expect(core.validateAddress('4invalid', ZentraNetwork.mainnet), isFalse);
  });
}
