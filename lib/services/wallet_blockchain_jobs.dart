import 'dart:async';

import '../models/wallet_sync_status.dart';

/// Serializes blocking wallet2 FFI work so calls do not overlap (refresh races, mutex).
class WalletBlockchainJobRunner {
  Future<void> _tail = Future<void>.value();
  int _generation = 0;
  int _inFlight = 0;

  /// Runs [job] after earlier queued jobs complete.
  Future<T> run<T>(Future<T> Function() job) {
    final gen = _generation;
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      if (gen != _generation) {
        if (!completer.isCompleted) {
          completer.completeError(StateError('Blockchain job cancelled'));
        }
        return;
      }
      _inFlight++;
      try {
        final result = await job();
        if (gen != _generation) {
          if (!completer.isCompleted) {
            completer.completeError(StateError('Blockchain job cancelled'));
          }
          return;
        }
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      } finally {
        _inFlight--;
      }
    });
    return completer.future;
  }

  /// Drops queued jobs (e.g. wallet closed). In-flight work is not interrupted.
  void reset() {
    _generation++;
    _tail = Future<void>.value();
  }

  /// Waits until native jobs started before [reset] finish (safe before closing wallet).
  Future<void> awaitIdle() async {
    while (_inFlight > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    await _tail;
  }
}

/// Native wallet2 background refresh plus periodic UI snapshot updates.
class WalletBackgroundSync {
  WalletBackgroundSync({
    this.pollInterval = kWalletSyncPollInterval,
  });

  final Duration pollInterval;
  Timer? _pollTimer;
  bool _active = false;

  bool get isActive => _active;

  /// Starts periodic [onPoll] (native refresh must already be running).
  void start({
    required Future<void> Function() onPoll,
  }) {
    stop();
    _active = true;
    unawaited(onPoll());
    _pollTimer = Timer.periodic(pollInterval, (_) => unawaited(onPoll()));
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _active = false;
  }
}
