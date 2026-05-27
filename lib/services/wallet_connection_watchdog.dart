import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Cake [check_connection.dart] — reconnect when network returns after failure.
class WalletConnectionWatchdog {
  WalletConnectionWatchdog({
    this.interval = const Duration(seconds: 5),
  });

  final Duration interval;
  Timer? _timer;
  bool _reconnectInFlight = false;

  void start({
    required Future<bool> Function() isConnectionFailed,
    required Future<void> Function() onReconnect,
  }) {
    stop();
    _timer = Timer.periodic(interval, (_) async {
      if (_reconnectInFlight) return;
      try {
        final results = await Connectivity().checkConnectivity();
        if (results.contains(ConnectivityResult.none)) return;
        if (!await isConnectionFailed()) return;
        _reconnectInFlight = true;
        try {
          await onReconnect();
        } finally {
          _reconnectInFlight = false;
        }
      } catch (_) {
        _reconnectInFlight = false;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _reconnectInFlight = false;
  }
}
