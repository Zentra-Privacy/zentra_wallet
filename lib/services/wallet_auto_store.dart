import 'dart:async';

import '../models/wallet_sync_status.dart';

/// Cake-style debounced [store] — periodic persist while synced.
class WalletAutoStore {
  WalletAutoStore();

  Timer? _timer;
  int _lastStoredWalletHeight = -1;
  DateTime? _lastStoreAt;

  void start({required Future<void> Function({required bool force}) onStore}) {
    stop();
    _timer = Timer.periodic(kWalletAutoStoreInterval, (_) {
      unawaited(onStore(force: false));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastStoredWalletHeight = -1;
    _lastStoreAt = null;
  }

  /// Persists wallet when [isSynced], or when [force] (after send / first sync).
  Future<void> maybeStore({
    required bool force,
    required bool isSynced,
    required int walletHeight,
    required Future<void> Function() store,
  }) async {
    if (!force) {
      if (!isSynced) return;
      final lastAt = _lastStoreAt;
      if (lastAt != null &&
          DateTime.now().difference(lastAt) < kWalletAutoStoreInterval) {
        return;
      }
      if (_lastStoredWalletHeight >= 0 &&
          walletHeight > 0 &&
          walletHeight == _lastStoredWalletHeight) {
        return;
      }
    }
    await store();
    _lastStoreAt = DateTime.now();
    if (walletHeight > 0) {
      _lastStoredWalletHeight = walletHeight;
    }
  }
}
