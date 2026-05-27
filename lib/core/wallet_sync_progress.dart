/// Cake Wallet–style sync progress and ETA (cw_core SyncingSyncStatus).
class WalletSyncProgress {
  WalletSyncProgress({
    required this.walletHeight,
    required this.daemonHeight,
    required this.blocksLeft,
    required this.progressFraction,
  });

  final int walletHeight;
  final int daemonHeight;
  final int blocksLeft;
  final double progressFraction;

  static final Map<DateTime, int> _blockHistory = {};
  static Duration? _lastEtaDuration;
  static DateTime? _globalSyncStartTime;
  static const int _minDataPoints = 3;

  static void reset() {
    _blockHistory.clear();
    _lastEtaDuration = null;
    _globalSyncStartTime = null;
  }

  static void recordBlocksLeft(int blocksLeft) {
    _blockHistory[DateTime.now()] = blocksLeft;
    _globalSyncStartTime ??= DateTime.now();
  }

  /// Progress from heights (Cake SyncListener formula).
  static WalletSyncProgress? fromHeights({
    required int initialSyncHeight,
    required int walletHeight,
    required int daemonHeight,
  }) {
    if (daemonHeight <= 0) return null;
    var syncHeight = walletHeight;
    if (syncHeight <= 0) syncHeight = walletHeight;
    if (initialSyncHeight <= 0 && syncHeight > 0) {
      // Caller should persist initial height externally.
    }
    final bchHeight = daemonHeight > syncHeight ? daemonHeight : syncHeight;
    if (syncHeight < 0) return null;
    final left = bchHeight - syncHeight;
    if (left < 0) return null;

    final initial = initialSyncHeight > 0 ? initialSyncHeight : syncHeight;
    final track = bchHeight - initial;
    final diff = track - (bchHeight - syncHeight);
    final ptc = diff <= 0 || track <= 0 ? 0.0 : diff / track;

    recordBlocksLeft(left + 1);
    return WalletSyncProgress(
      walletHeight: syncHeight,
      daemonHeight: bchHeight,
      blocksLeft: left,
      progressFraction: ptc.clamp(0.0, 1.0),
    );
  }

  bool get shouldShowBlocksRemaining {
    if (_globalSyncStartTime == null) return true;
    return DateTime.now().difference(_globalSyncStartTime!).inSeconds < 15;
  }

  String? get formattedEta {
    if (_blockHistory.length < _minDataPoints) return null;
    final duration = _etaDuration();
    if (duration.inDays > 0 || blocksLeft < 100) return null;
    final smoothed = _applySmoothing(duration);
    _lastEtaDuration = smoothed;
    return _formatDuration(smoothed);
  }

  Duration _etaDuration() {
    if (_blockHistory.length < 2) return Duration.zero;
    final entries = _blockHistory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final first = entries.first;
    final last = entries.last;
    final blockDelta = first.value - last.value;
    if (blockDelta <= 0) return Duration.zero;
    final timeDelta = last.key.difference(first.key);
    if (timeDelta.inMilliseconds <= 0) return Duration.zero;
    final msPerBlock = timeDelta.inMilliseconds / blockDelta;
    return Duration(milliseconds: (msPerBlock * blocksLeft).round());
  }

  Duration _applySmoothing(Duration newDuration) {
    final last = _lastEtaDuration;
    if (last == null) return newDuration;
    final currentMs = last.inMilliseconds;
    final newMs = newDuration.inMilliseconds;
    final diffSec = ((newMs - currentMs) / 1000).abs();
    int adjustedMs;
    if (diffSec > 3600) {
      adjustedMs = currentMs + (newMs > currentMs ? 1 : -1) * 30 * 60 * 1000;
    } else if (diffSec > 300) {
      adjustedMs = currentMs + (newMs > currentMs ? 1 : -1) * 2 * 60 * 1000;
    } else {
      adjustedMs = newMs;
    }
    return Duration(milliseconds: adjustedMs);
  }

  static String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      return '~${d.inHours}h ${d.inMinutes.remainder(60)}m left';
    }
    if (d.inMinutes >= 1) {
      return '~${d.inMinutes}m left';
    }
    return '~${d.inSeconds}s left';
  }
}
