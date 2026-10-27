import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  String? stored;
  var writes = 0;
  var failWrite = false;
  var ignoreWrite = false;
  var unreadable = false;

  setUp(() {
    stored = null;
    writes = 0;
    failWrite = false;
    ignoreWrite = false;
    unreadable = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'read') return unreadable ? null : stored;
          if (call.method == 'containsKey') return stored != null;
          if (call.method == 'write') {
            writes++;
            if (failWrite) throw PlatformException(code: 'storage_unavailable');
            if (!ignoreWrite) {
              stored = (call.arguments as Map)['value'] as String;
            }
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('concurrent reads share a persisted key and separate polls', () async {
    final key = MealVoteKey();
    final tokens = await Future.wait([
      key.tokenFor('poll-a'),
      key.tokenFor('poll-a'),
      key.tokenFor('poll-b'),
    ]);
    expect(writes, 1);
    expect(stored, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(tokens[0], tokens[1]);
    expect(tokens[0], isNot(tokens[2]));
    expect(tokens[0], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(tokens[0], isNot(stored));
    expect(await MealVoteKey().tokenFor('poll-a'), tokens[0]);
    expect(writes, 1);
  });

  test('invalid saved key fails instead of silently replacing votes', () async {
    stored = 'invalid';
    await expectLater(
      MealVoteKey().tokenFor('poll-a'),
      throwsA(isA<MealVoteStorageException>()),
    );
    expect(writes, 0);
  });

  test('read-only access does not create a key', () async {
    expect(await MealVoteKey().tokenFor('poll-a', create: false), isNull);
    expect(writes, 0);
  });

  test('an unreadable existing key is never replaced', () async {
    stored = 'a' * 64;
    unreadable = true;
    final key = MealVoteKey();
    await expectLater(
      key.tokenFor('poll-a', create: false),
      throwsA(isA<MealVoteStorageException>()),
    );
    await expectLater(
      key.tokenFor('poll-a'),
      throwsA(isA<MealVoteStorageException>()),
    );
    expect(stored, 'a' * 64);
    expect(writes, 0);
  });

  test(
    'a failed write does not use an unpersisted key and can retry',
    () async {
      final key = MealVoteKey();
      failWrite = true;
      await expectLater(
        key.tokenFor('poll-a'),
        throwsA(isA<MealVoteStorageException>()),
      );
      expect(stored, isNull);
      failWrite = false;
      expect(await key.tokenFor('poll-a'), matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(writes, 2);
    },
  );

  test('a silently lost write never produces a token', () async {
    ignoreWrite = true;
    await expectLater(
      MealVoteKey().tokenFor('poll-a'),
      throwsA(isA<MealVoteStorageException>()),
    );
    expect(stored, isNull);
  });

  test('cleared storage is not masked by a previously cached key', () async {
    final key = MealVoteKey();
    final old = await key.tokenFor('poll-a');
    stored = null;
    expect(await key.tokenFor('poll-a', create: false), isNull);
    expect(await key.tokenFor('poll-a'), isNot(old));
  });
}
