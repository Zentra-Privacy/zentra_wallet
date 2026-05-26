import 'package:flutter_test/flutter_test.dart';
import 'package:zentra_wallet/models/wallet_sync_status.dart';

void main() {
  test('Cake-style synced threshold is 100 blocks', () {
    expect(kWalletSyncedBlocksThreshold, 100);
  });

  bool isSynced(int walletHeight, int daemonHeight) {
    if (daemonHeight <= 0) return false;
    final behind = walletHeight <= 0
        ? daemonHeight
        : (daemonHeight - walletHeight).clamp(0, daemonHeight);
    return behind < kWalletSyncedBlocksThreshold;
  }

  test('synced when within threshold of tip', () {
    expect(isSynced(901, 1000), isTrue); // 99 blocks behind
    expect(isSynced(900, 1000), isFalse); // exactly 100 — still syncing
    expect(isSynced(850, 1000), isFalse);
    expect(isSynced(0, 500), isFalse);
  });
}
