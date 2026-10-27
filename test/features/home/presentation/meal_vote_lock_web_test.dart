@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_lock_web.dart';

void main() {
  test('key creation waits for an earlier browser lock', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final order = <int>[];
    final first = withVoteKeyLock(() async {
      order.add(1);
      started.complete();
      await release.future;
      return 'first';
    });
    await started.future;
    final second = withVoteKeyLock(() async {
      order.add(2);
      return 'second';
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(order, [1]);
    release.complete();
    expect(await first, 'first');
    expect(await second, 'second');
    expect(order, [1, 2]);
  });
}
