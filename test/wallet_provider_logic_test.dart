import 'package:flutter_test/flutter_test.dart';
import 'package:zentra_wallet/models/wallet_sync_status.dart';

/// Mirrors [WalletProvider.isSynced] / [WalletProvider.blocksBehindDaemon].
bool providerIsSynced({
  required bool connected,
  required int walletHeight,
  required int daemonBlockHeight,
}) {
  if (!connected || daemonBlockHeight <= 0) return false;
  final behind = walletHeight <= 0
      ? daemonBlockHeight
      : (daemonBlockHeight - walletHeight).clamp(0, daemonBlockHeight);
  return behind < kWalletSyncedBlocksThreshold;
}

void main() {
  group('sync gating (Cake-style)', () {
    test('not synced when wallet height is 0 but daemon has blocks', () {
      expect(
        providerIsSynced(connected: true, walletHeight: 0, daemonBlockHeight: 500),
        isFalse,
      );
    });

    test('synced when 99 blocks behind', () {
      expect(
        providerIsSynced(connected: true, walletHeight: 901, daemonBlockHeight: 1000),
        isTrue,
      );
    });

    test('not synced when exactly 100 blocks behind', () {
      expect(
        providerIsSynced(connected: true, walletHeight: 900, daemonBlockHeight: 1000),
        isFalse,
      );
    });

    test('not synced when disconnected', () {
      expect(
        providerIsSynced(connected: false, walletHeight: 1000, daemonBlockHeight: 1000),
        isFalse,
      );
    });
  });
}
