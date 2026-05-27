import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zentra_wallet/services/wallet_blockchain_jobs.dart';

void main() {
  test('WalletBlockchainJobRunner runs jobs in order', () async {
    final runner = WalletBlockchainJobRunner();
    final order = <int>[];

    final first = runner.run(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      order.add(1);
      return 'a';
    });
    final second = runner.run(() async {
      order.add(2);
      return 'b';
    });

    expect(await first, 'a');
    expect(await second, 'b');
    expect(order, [1, 2]);
  });

  test('WalletBlockchainJobRunner awaitIdle waits for in-flight jobs', () async {
    final runner = WalletBlockchainJobRunner();
    var finished = false;

    unawaited(runner.run(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      finished = true;
    }));

    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(finished, isFalse);
    await runner.awaitIdle();
    expect(finished, isTrue);
  });

  test('WalletBlockchainJobRunner reset cancels queued jobs', () async {
    final runner = WalletBlockchainJobRunner();
    var ran = false;

    final pending = runner.run(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      ran = true;
      return 1;
    });
    runner.reset();
    await expectLater(pending, throwsA(isA<StateError>()));

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(ran, isFalse);
  });
}
