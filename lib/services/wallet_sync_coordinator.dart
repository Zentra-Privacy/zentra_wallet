import '../core/wallet_sync_progress.dart';
import 'wallet_native_snapshot.dart';

/// Cake [SyncListener] logic: skip duplicate heights, cache daemon tip, compute progress.
class WalletSyncCoordinator {
  int _lastKnownWalletHeight = -1;
  int _initialSyncHeight = 0;
  int _cachedDaemonHeight = 0;

  void reset() {
    _lastKnownWalletHeight = -1;
    _initialSyncHeight = 0;
    _cachedDaemonHeight = 0;
    WalletSyncProgress.reset();
  }

  int get initialSyncHeight => _initialSyncHeight;

  /// Updates cached daemon height (Cake getNodeHeightOrUpdate).
  int resolveDaemonHeight(WalletNativeSnapshot snap) {
    final base = snap.walletHeight;
    if (_cachedDaemonHeight < base || _cachedDaemonHeight == 0) {
      _cachedDaemonHeight = snap.daemonHeight;
    } else if (snap.daemonHeight > _cachedDaemonHeight) {
      _cachedDaemonHeight = snap.daemonHeight;
    }
    return _cachedDaemonHeight;
  }

  /// Returns progress when wallet height advanced; null if poll should skip progress tick.
  WalletSyncProgress? progressForSnapshot(WalletNativeSnapshot snap) {
    final daemonH = resolveDaemonHeight(snap);
    if (daemonH <= 0) return null;

    var syncHeight = snap.walletHeight;
    if (syncHeight <= 0) syncHeight = 0;

    if (_initialSyncHeight <= 0 && syncHeight > 0) {
      _initialSyncHeight = syncHeight;
    }

    if (_lastKnownWalletHeight == syncHeight && daemonH == _cachedDaemonHeight) {
      return null;
    }

    _lastKnownWalletHeight = syncHeight;
    return WalletSyncProgress.fromHeights(
      initialSyncHeight: _initialSyncHeight,
      walletHeight: syncHeight,
      daemonHeight: daemonH,
    );
  }
}
