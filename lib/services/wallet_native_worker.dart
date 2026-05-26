import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:zentra_wallet_core/zentra_wallet_core.dart';

/// Heavy wallet2 FFI on a worker isolate (Cake Wallet pattern).
class WalletNativeWorker {
  static Future<int> openWallet({
    required String walletDir,
    required String daemonAddress,
    required bool trustedDaemon,
    required String filename,
    required String password,
    required int nettype,
  }) async {
    return Isolate.run(() => _openWallet(
          walletDir: walletDir,
          daemonAddress: daemonAddress,
          trustedDaemon: trustedDaemon,
          filename: filename,
          password: password,
          nettype: nettype,
        ));
  }

  static Future<int> createWallet({
    required String walletDir,
    required String daemonAddress,
    required bool trustedDaemon,
    required String filename,
    required String password,
    required int nettype,
    required int restoreHeight,
  }) async {
    return Isolate.run(() => _createWallet(
          walletDir: walletDir,
          daemonAddress: daemonAddress,
          trustedDaemon: trustedDaemon,
          filename: filename,
          password: password,
          nettype: nettype,
          restoreHeight: restoreHeight,
        ));
  }

  static Future<int> restoreWallet({
    required String walletDir,
    required String daemonAddress,
    required bool trustedDaemon,
    required String filename,
    required String password,
    required String seed,
    required int nettype,
    required int restoreHeight,
  }) async {
    return Isolate.run(() => _restoreWallet(
          walletDir: walletDir,
          daemonAddress: daemonAddress,
          trustedDaemon: trustedDaemon,
          filename: filename,
          password: password,
          seed: seed,
          nettype: nettype,
          restoreHeight: restoreHeight,
        ));
  }

  static int _openWallet({
    required String walletDir,
    required String daemonAddress,
    required bool trustedDaemon,
    required String filename,
    required String password,
    required int nettype,
  }) {
    final native = _loadNative(walletDir, daemonAddress, trustedDaemon);
    final handle = native.openWallet(filename, password, nettype);
    return handle.address;
  }

  static int _createWallet({
    required String walletDir,
    required String daemonAddress,
    required bool trustedDaemon,
    required String filename,
    required String password,
    required int nettype,
    required int restoreHeight,
  }) {
    final native = _loadNative(walletDir, daemonAddress, trustedDaemon);
    final handle = native.createWallet(
      filename,
      password,
      nettype,
      restoreHeight: restoreHeight,
    );
    return handle.address;
  }

  static int _restoreWallet({
    required String walletDir,
    required String daemonAddress,
    required bool trustedDaemon,
    required String filename,
    required String password,
    required String seed,
    required int nettype,
    required int restoreHeight,
  }) {
    final native = _loadNative(walletDir, daemonAddress, trustedDaemon);
    final handle = native.restoreWallet(
      filename,
      password,
      seed,
      nettype,
      restoreHeight: restoreHeight,
    );
    return handle.address;
  }

  static ZentraNativeWallet _loadNative(
    String walletDir,
    String daemonAddress,
    bool trustedDaemon,
  ) {
    if (!ZentraNativeWallet.isAvailable) {
      throw NativeWalletUnavailable(
        ZentraNativeWallet.loadError ?? 'Wallet engine unavailable',
      );
    }
    final native = ZentraNativeWallet.instance;
    native.init(walletDir);
    native.setDaemon(daemonAddress, trusted: trustedDaemon);
    return native;
  }

  static ffi.Pointer<ffi.Void> pointerFromAddress(int address) =>
      ffi.Pointer<ffi.Void>.fromAddress(address);
}
