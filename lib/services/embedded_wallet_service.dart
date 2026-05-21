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
        'Native wallet library missing. Run: ./scripts/build_native_wallet.sh',
      );
    }
    _native = ZentraNativeWallet.instance;
    _native.init(walletDir);
    _native.setDaemon(daemonAddress, trusted: true);
  }

  final ZentraNetworkConfig network;
  final String walletDir;
  final String daemonAddress;
  late final ZentraNativeWallet _native;
  ffi.Pointer<ffi.Void>? _handle;

  int get nettypeIndex => network.type.index;

  bool get isOpen => _handle != null && _handle != ffi.nullptr;

  void createWallet({required String filename, required String password}) {
    _close();
    _handle = _native.createWallet(filename, password, nettypeIndex);
    _native.startBackgroundRefresh(_handle!);
  }

  void openWallet({required String filename, required String password}) {
    _close();
    _handle = _native.openWallet(filename, password, nettypeIndex);
    _native.startBackgroundRefresh(_handle!);
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
    _native.startBackgroundRefresh(_handle!);
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

  /// Sends [amountDisplay] ZTR. Fees are deducted by wallet2 — do not pre-check
  /// unlocked balance here (amount + fee is validated natively).
  Future<String> send({required String address, required String amountDisplay}) async {
    _requireOpen();
    final dest = address.trim();
    if (!validateAddress(dest)) {
      throw WalletException('Invalid address for ${network.label}');
    }
    final atomic = parseDisplay(amountDisplay);
    if (atomic <= 0) throw WalletException('Invalid amount');
    final txid = _native.send(_handle!, dest, atomic);
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
