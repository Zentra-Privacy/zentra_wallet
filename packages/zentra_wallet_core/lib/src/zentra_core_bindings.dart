import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

const int zentraAtomicUnits = 1000000000;
const int zentraDisplayDecimals = 9;

enum ZentraNetwork { mainnet, testnet, stagenet }

class ZentraCore {
  ZentraCore._();
  static final ZentraCore instance = ZentraCore._();

  late final _Lib _lib = _Lib(_openLibrary());

  ffi.DynamicLibrary _openLibrary() {
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libzentra_wallet_core_plugin.so');
    }
    if (Platform.isLinux) {
      return ffi.DynamicLibrary.open('libzentra_wallet_core_plugin.so');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('zentra_wallet_core_plugin.dll');
    }
    if (Platform.isIOS) {
      return ffi.DynamicLibrary.process();
    }
    if (Platform.isMacOS) {
      final exe = Platform.resolvedExecutable;
      final dir = exe.contains('/')
          ? exe.substring(0, exe.lastIndexOf('/'))
          : exe;
      for (final path in <String>[
        '$dir/../Frameworks/libzentra_wallet_core_plugin.dylib',
        '@executable_path/../Frameworks/libzentra_wallet_core_plugin.dylib',
        'libzentra_wallet_core_plugin.dylib',
      ]) {
        try {
          if (path.contains('/') && !path.startsWith('@') && !File(path).existsSync()) {
            continue;
          }
          return ffi.DynamicLibrary.open(path);
        } catch (_) {}
      }
      return ffi.DynamicLibrary.process();
    }
    throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
  }

  bool validateAddress(String address, ZentraNetwork network) {
    final ptr = address.toNativeUtf8();
    try {
      return _lib.validateAddress(ptr, network.index) == 1;
    } finally {
      malloc.free(ptr);
    }
  }

  String atomicToDisplay(int atomic) {
    final result = _lib.atomicToDisplay(atomic);
    try {
      return result.toDartString();
    } finally {
      _lib.freeString(result);
    }
  }

  int displayToAtomic(String display) {
    final ptr = display.toNativeUtf8();
    try {
      return _lib.displayToAtomic(ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  int daemonRpcPort(ZentraNetwork network) => _lib.daemonRpcPort(network.index);

  String addressPrefixChar(ZentraNetwork network) {
    final c = _lib.addressPrefixChar(network.index);
    return String.fromCharCode(c);
  }

  String get coinTicker => _lib.coinTicker().toDartString();
}

class _Lib {
  _Lib(ffi.DynamicLibrary lib)
      : validateAddress = lib.lookupFunction<_ValidateAddressNative, _ValidateAddress>(
          'zentra_validate_address',
        ),
        atomicToDisplay = lib.lookupFunction<_AtomicToDisplayNative, _AtomicToDisplay>(
          'zentra_atomic_to_display',
        ),
        displayToAtomic = lib.lookupFunction<_DisplayToAtomicNative, _DisplayToAtomic>(
          'zentra_display_to_atomic',
        ),
        freeString = lib.lookupFunction<_FreeStringNative, _FreeString>(
          'zentra_free_string',
        ),
        daemonRpcPort = lib.lookupFunction<_DaemonPortNative, _DaemonPort>(
          'zentra_daemon_rpc_port',
        ),
        addressPrefixChar = lib.lookupFunction<_PrefixCharNative, _PrefixChar>(
          'zentra_address_prefix_char',
        ),
        coinTicker = lib.lookupFunction<_CoinTickerNative, _CoinTicker>(
          'zentra_coin_ticker',
        );

  final _ValidateAddress validateAddress;
  final _AtomicToDisplay atomicToDisplay;
  final _DisplayToAtomic displayToAtomic;
  final _FreeString freeString;
  final _DaemonPort daemonRpcPort;
  final _PrefixChar addressPrefixChar;
  final _CoinTicker coinTicker;
}

typedef _ValidateAddressNative = ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Int32);
typedef _ValidateAddress = int Function(ffi.Pointer<Utf8>, int);

typedef _AtomicToDisplayNative = ffi.Pointer<Utf8> Function(ffi.Uint64);
typedef _AtomicToDisplay = ffi.Pointer<Utf8> Function(int);

typedef _DisplayToAtomicNative = ffi.Uint64 Function(ffi.Pointer<Utf8>);
typedef _DisplayToAtomic = int Function(ffi.Pointer<Utf8>);

typedef _FreeStringNative = ffi.Void Function(ffi.Pointer<Utf8>);
typedef _FreeString = void Function(ffi.Pointer<Utf8>);

typedef _DaemonPortNative = ffi.Uint16 Function(ffi.Int32);
typedef _DaemonPort = int Function(int);

typedef _PrefixCharNative = ffi.Int8 Function(ffi.Int32);
typedef _PrefixChar = int Function(int);

typedef _CoinTickerNative = ffi.Pointer<Utf8> Function();
typedef _CoinTicker = ffi.Pointer<Utf8> Function();
