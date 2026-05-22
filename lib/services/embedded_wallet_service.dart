import 'dart:ffi' as ffi;

import 'package:zentra_wallet_core/zentra_wallet_core.dart';

import '../core/network/zentra_network.dart';
import '../core/wallet_exception.dart';
import '../models/wallet_models.dart';

/// Embedded wallet2 (Cake/Monero-style) — keys and sync on device; remote zentrad only.
class EmbeddedWalletService {
  EmbeddedWalletService({
    required this.network,
    required this.walletDir,
    required this.daemonAddress,
  }) {
    if (!ZentraNativeWallet.isAvailable) {
      throw NativeWalletUnavailable(
        'Native wallet library missing. Run: ./wallet.sh build-docker',
      );
    }
    _native = ZentraNativeWallet.instance;
    _native.init(walletDir);
    _native.setDaemon(daemonAddress, trusted: _isLocalDaemon(daemonAddress));
  }

  /// Remote public nodes must not be trusted (Monero wallet2 threat model).
  static bool _isLocalDaemon(String address) {
    final host = address.split(':').first.trim().toLowerCase();
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  final ZentraNetworkConfig network;
  final String walletDir;
  final String daemonAddress;
  late final ZentraNativeWallet _native;
  ffi.Pointer<ffi.Void>? _handle;

  int get nettypeIndex => network.type.index;

  bool get isOpen => _handle != null && _handle != ffi.nullptr;

  void createWallet({
    required String filename,
    required String password,
    int restoreHeight = 0,
  }) {
    _close();
    _handle = _native.createWallet(
      filename,
      password,
      nettypeIndex,
      restoreHeight: restoreHeight,
    );
    if (!_native.startBackgroundRefresh(_handle!)) {
      throw WalletException('Background refresh failed to start');
    }
  }

  int fetchRestoreHeight() {
    _requireOpen();
    return _native.restoreHeight(_handle!);
  }

  void setRestoreHeight(int height) {
    _requireOpen();
    _native.setRestoreHeight(_handle!, height);
  }

  void openWallet({required String filename, required String password}) {
    _close();
    _handle = _native.openWallet(filename, password, nettypeIndex);
    if (!_native.startBackgroundRefresh(_handle!)) {
      throw WalletException('Background refresh failed to start');
    }
  }

  String restoreWallet({
    required String filename,
    required String password,
    required String seed,
    int restoreHeight = 0,
  }) {
    _close();
    _handle = _native.restoreWallet(
      filename,
      password,
      seed,
      nettypeIndex,
      restoreHeight: restoreHeight,
    );
    if (!_native.startBackgroundRefresh(_handle!)) {
      throw WalletException('Background refresh failed to start');
    }
    return _native.address(_handle!);
  }

  void _close() {
    if (_handle != null && _handle != ffi.nullptr) {
      _native.closeWallet(_handle!);
      _handle = null;
    }
  }

  Future<void> refresh() async {
    _requireOpen();
    _native.refresh(_handle!);
  }

  Future<WalletBalance> fetchBalance() async {
    _requireOpen();
    return WalletBalance(
      balanceAtomic: _native.balance(_handle!),
      unlockedAtomic: _native.unlockedBalance(_handle!),
    );
  }

  Future<WalletAddress> fetchPrimaryAddress() async {
    _requireOpen();
    return WalletAddress(address: _native.address(_handle!));
  }

  Future<int> fetchWalletHeight() async {
    _requireOpen();
    return _native.walletHeight(_handle!);
  }

  Future<int> fetchDaemonHeight() async {
    _requireOpen();
    return _native.daemonHeight(_handle!);
  }

  Future<List<WalletTransfer>> fetchTransfers() async {
    _requireOpen();
    final rows = _native.transfers(_handle!);
    return rows.map(WalletTransfer.fromNative).toList();
  }

  String? fetchSeed() {
    _requireOpen();
    return _native.seed(_handle!);
  }

  bool validateAddress(String address) =>
      _native.addressValid(address.trim(), nettypeIndex);

  String formatAtomic(int atomic) => ZentraCore.instance.atomicToDisplay(atomic);

  int parseDisplay(String display) => ZentraCore.instance.displayToAtomic(display.trim());

  int estimateFee({required String address, required String amountDisplay, int priority = 0}) {
    _requireOpen();
    final dest = address.trim();
    if (!validateAddress(dest)) {
      throw WalletException('Invalid address for ${network.label}');
    }
    final atomic = parseDisplay(amountDisplay);
    if (atomic <= 0) throw WalletException('Invalid amount');
    final fee = _native.estimateFee(_handle!, dest, atomic, priority: priority);
    if (fee <= 0) {
      throw WalletException(_native.lastErrorMessage());
    }
    return fee;
  }

  /// Sends [amountDisplay] ZTR. Network fee is extra (see [estimateFee]).
  Future<String> send({
    required String address,
    required String amountDisplay,
    int priority = 0,
  }) async {
    _requireOpen();
    final dest = address.trim();
    if (!validateAddress(dest)) {
      throw WalletException('Invalid address for ${network.label}');
    }
    final atomic = parseDisplay(amountDisplay);
    if (atomic <= 0) throw WalletException('Invalid amount');
    final txid = _native.send(_handle!, dest, atomic, priority: priority);
    store();
    return txid;
  }

  void store() {
    _requireOpen();
    _native.store(_handle!);
  }

  void dispose() {
    _close();
    _native.shutdown();
  }

  void _requireOpen() {
    if (!isOpen) throw WalletException('No wallet open');
  }
}
