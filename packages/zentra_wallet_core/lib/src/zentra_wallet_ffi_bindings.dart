import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

class NativeWalletUnavailable implements Exception {
  NativeWalletUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

class ZentraNativeWallet {
  ZentraNativeWallet._(this._lib);
  static ZentraNativeWallet? _instance;

  static ZentraNativeWallet get instance {
    if (_instance != null) return _instance!;
    throw NativeWalletUnavailable(
      'Native wallet not loaded. Run: ./scripts/build_native_wallet.sh',
    );
  }

  static bool get isAvailable {
    try {
      _instance ??= ZentraNativeWallet._(_NativeLib(_openLib()));
      return true;
    } catch (_) {
      return false;
    }
  }

  static ffi.DynamicLibrary _openLib() {
    if (Platform.isLinux) {
      for (final name in ['libzentra_wallet_ffi.so', 'zentra_wallet_ffi.so']) {
        try {
          return ffi.DynamicLibrary.open(name);
        } catch (_) {}
      }
    }
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libzentra_wallet_ffi.so');
    }
    throw NativeWalletUnavailable('Platform ${Platform.operatingSystem}');
  }

  final _NativeLib _lib;

  void init(String walletDir) {
    final dir = walletDir.toNativeUtf8();
    try {
      final ok = _lib.init(dir);
      if (ok != 1) throw NativeWalletUnavailable(_lastError());
    } finally {
      malloc.free(dir);
    }
  }

  void shutdown() => _lib.shutdown();

  void setDaemon(String address, {bool trusted = true}) {
    final a = address.toNativeUtf8();
    try {
      _lib.setDaemon(a, trusted ? 1 : 0);
    } finally {
      malloc.free(a);
    }
  }

  ffi.Pointer<ffi.Void> createWallet(String path, String password, int nettype) =>
      _open(path, password, nettype, isRestore: false, seed: null, restoreHeight: 0);

  ffi.Pointer<ffi.Void> openWallet(String path, String password, int nettype) {
    final p = path.toNativeUtf8();
    final pw = password.toNativeUtf8();
    try {
      final h = _lib.openWallet(p, pw, nettype);
      if (h == ffi.nullptr) throw NativeWalletUnavailable(_lastError());
      return h;
    } finally {
      malloc.free(p);
      malloc.free(pw);
    }
  }

  ffi.Pointer<ffi.Void> restoreWallet(
    String path,
    String password,
    String seed,
    int nettype, {
    int restoreHeight = 0,
  }) =>
      _open(path, password, nettype, isRestore: true, seed: seed, restoreHeight: restoreHeight);

  ffi.Pointer<ffi.Void> _open(
    String path,
    String password,
    int nettype, {
    required bool isRestore,
    required String? seed,
    required int restoreHeight,
  }) {
    final p = path.toNativeUtf8();
    final pw = password.toNativeUtf8();
    try {
      final ffi.Pointer<ffi.Void> h;
      if (isRestore) {
        final s = (seed ?? '').toNativeUtf8();
        try {
          h = _lib.restoreWallet(p, pw, s, nettype, restoreHeight);
        } finally {
          malloc.free(s);
        }
      } else {
        h = _lib.createWallet(p, pw, nettype);
      }
      if (h == ffi.nullptr) throw NativeWalletUnavailable(_lastError());
      return h;
    } finally {
      malloc.free(p);
      malloc.free(pw);
    }
  }

  void closeWallet(ffi.Pointer<ffi.Void> handle) => _lib.closeWallet(handle);

  void refresh(ffi.Pointer<ffi.Void> handle) {
    if (_lib.refresh(handle) != 1) throw NativeWalletUnavailable(_lastError());
  }

  void startBackgroundRefresh(ffi.Pointer<ffi.Void> handle) => _lib.startBgRefresh(handle);

  int balance(ffi.Pointer<ffi.Void> handle) => _lib.balance(handle);

  int unlockedBalance(ffi.Pointer<ffi.Void> handle) => _lib.unlockedBalance(handle);

  int walletHeight(ffi.Pointer<ffi.Void> handle) => _lib.walletHeight(handle);

  int daemonHeight(ffi.Pointer<ffi.Void> handle) => _lib.daemonHeight(handle);

  String address(ffi.Pointer<ffi.Void> handle) => _takeString(_lib.address(handle));

  String seed(ffi.Pointer<ffi.Void> handle) => _takeString(_lib.seed(handle));

  String send(ffi.Pointer<ffi.Void> handle, String to, int amountAtomic) {
    final addr = to.toNativeUtf8();
    try {
      final ptr = _lib.send(handle, addr, amountAtomic);
      if (ptr == ffi.nullptr) throw NativeWalletUnavailable(_lastError());
      return _takeString(ptr);
    } finally {
      malloc.free(addr);
    }
  }

  void store(ffi.Pointer<ffi.Void> handle) {
    if (_lib.store(handle) != 1) throw NativeWalletUnavailable(_lastError());
  }

  bool addressValid(String address, int nettype) {
    final a = address.toNativeUtf8();
    try {
      return _lib.addressValid(a, nettype) == 1;
    } finally {
      malloc.free(a);
    }
  }

  List<Map<String, dynamic>> transfers(ffi.Pointer<ffi.Void> handle) {
    final ptr = _lib.transfersJson(handle);
    if (ptr == ffi.nullptr) throw NativeWalletUnavailable(_lastError());
    final json = _takeString(ptr);
    final decoded = jsonDecode(json);
    if (decoded is! List) return [];
    return [
      for (final item in decoded)
        if (item is Map)
          Map<String, dynamic>.from(
            item.map((k, v) => MapEntry(k.toString(), v)),
          ),
    ];
  }

  String _lastError() {
    final p = _lib.lastError();
    try {
      return p == ffi.nullptr ? 'Unknown native error' : p.toDartString();
    } finally {
      if (p != ffi.nullptr) _lib.freeString(p);
    }
  }

  String _takeString(ffi.Pointer<Utf8> ptr) {
    if (ptr == ffi.nullptr) return '';
    try {
      return ptr.toDartString();
    } finally {
      _lib.freeString(ptr);
    }
  }
}

class _NativeLib {
  _NativeLib(ffi.DynamicLibrary lib)
      : init = lib.lookupFunction<_InitNative, _Init>('zentra_wm_init'),
        shutdown = lib.lookupFunction<_VoidNative, _Void>('zentra_wm_shutdown'),
        setDaemon = lib.lookupFunction<_SetDaemonNative, _SetDaemon>('zentra_wm_set_daemon'),
        createWallet = lib.lookupFunction<_OpenNative, _Open>('zentra_wm_create_wallet'),
        openWallet = lib.lookupFunction<_OpenNative, _Open>('zentra_wm_open_wallet'),
        restoreWallet = lib.lookupFunction<_RestoreNative, _Restore>('zentra_wm_restore_wallet'),
        closeWallet = lib.lookupFunction<_CloseNative, _Close>('zentra_wm_close_wallet'),
        refresh = lib.lookupFunction<_RefreshNative, _Refresh>('zentra_wm_refresh'),
        startBgRefresh = lib.lookupFunction<_RefreshNative, _Refresh>('zentra_wm_start_background_refresh'),
        balance = lib.lookupFunction<_BalNative, _Bal>('zentra_wm_balance'),
        unlockedBalance = lib.lookupFunction<_BalNative, _Bal>('zentra_wm_unlocked_balance'),
        walletHeight = lib.lookupFunction<_BalNative, _Bal>('zentra_wm_wallet_height'),
        daemonHeight = lib.lookupFunction<_BalNative, _Bal>('zentra_wm_daemon_height'),
        address = lib.lookupFunction<_StrNative, _Str>('zentra_wm_address'),
        seed = lib.lookupFunction<_StrNative, _Str>('zentra_wm_seed'),
        send = lib.lookupFunction<_SendNative, _Send>('zentra_wm_send'),
        store = lib.lookupFunction<_RefreshNative, _Refresh>('zentra_wm_store'),
        lastError = lib.lookupFunction<_LastErrorNative, _LastError>('zentra_wm_last_error'),
        freeString = lib.lookupFunction<_FreeNative, _Free>('zentra_wm_free_string'),
        addressValid = lib.lookupFunction<_AddrValidNative, _AddrValid>('zentra_wm_address_valid'),
        transfersJson = lib.lookupFunction<_StrNative, _Str>('zentra_wm_transfers_json');

  final _Init init;
  final _Void shutdown;
  final _SetDaemon setDaemon;
  final _Open createWallet;
  final _Open openWallet;
  final _Restore restoreWallet;
  final _Close closeWallet;
  final _Refresh refresh;
  final _Refresh startBgRefresh;
  final _Bal balance;
  final _Bal unlockedBalance;
  final _Bal walletHeight;
  final _Bal daemonHeight;
  final _Str address;
  final _Str seed;
  final _Send send;
  final _Refresh store;
  final _LastError lastError;
  final _Free freeString;
  final _AddrValid addressValid;
  final _Str transfersJson;
}

typedef _InitNative = ffi.Int32 Function(ffi.Pointer<Utf8>);
typedef _Init = int Function(ffi.Pointer<Utf8>);
typedef _VoidNative = ffi.Void Function();
typedef _Void = void Function();
typedef _SetDaemonNative = ffi.Void Function(ffi.Pointer<Utf8>, ffi.Int32);
typedef _SetDaemon = void Function(ffi.Pointer<Utf8>, int);
typedef _OpenNative = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Int32);
typedef _Open = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, int);
typedef _RestoreNative = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Int32, ffi.Uint64);
typedef _Restore = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, int, int);
typedef _CloseNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _Close = void Function(ffi.Pointer<ffi.Void>);
typedef _RefreshNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>);
typedef _Refresh = int Function(ffi.Pointer<ffi.Void>);
typedef _BalNative = ffi.Uint64 Function(ffi.Pointer<ffi.Void>);
typedef _Bal = int Function(ffi.Pointer<ffi.Void>);
typedef _StrNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>);
typedef _Str = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>);
typedef _LastErrorNative = ffi.Pointer<Utf8> Function();
typedef _LastError = ffi.Pointer<Utf8> Function();
typedef _SendNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>, ffi.Uint64);
typedef _Send = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>, int);
typedef _FreeNative = ffi.Void Function(ffi.Pointer<Utf8>);
typedef _Free = void Function(ffi.Pointer<Utf8>);
typedef _AddrValidNative = ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Int32);
typedef _AddrValid = int Function(ffi.Pointer<Utf8>, int);
