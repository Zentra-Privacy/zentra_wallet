import 'package:flutter_test/flutter_test.dart';
import 'package:zentra_wallet/services/wallet_native_snapshot.dart';
import 'package:zentra_wallet/services/wallet_sync_coordinator.dart';

void main() {
  test('skips progress when wallet height unchanged', () {
    final c = WalletSyncCoordinator();
    final snap = WalletNativeSnapshot(
      balanceAtomic: 1,
      unlockedAtomic: 1,
      walletHeight: 100,
      daemonHeight: 200,
      address: 'ztr',
      restoreHeight: 0,
    );
    expect(c.progressForSnapshot(snap), isNotNull);
    expect(c.progressForSnapshot(snap), isNull);
  });

  test('updates progress when wallet height advances', () {
    final c = WalletSyncCoordinator();
    c.progressForSnapshot(const WalletNativeSnapshot(
      balanceAtomic: 1,
      unlockedAtomic: 1,
      walletHeight: 100,
      daemonHeight: 200,
      address: 'a',
      restoreHeight: 0,
    ));
    final p = c.progressForSnapshot(const WalletNativeSnapshot(
      balanceAtomic: 1,
      unlockedAtomic: 1,
      walletHeight: 101,
      daemonHeight: 200,
      address: 'a',
      restoreHeight: 0,
    ));
    expect(p, isNotNull);
    expect(p!.blocksLeft, 99);
  });
}
