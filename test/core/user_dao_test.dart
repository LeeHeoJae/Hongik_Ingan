import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/user_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final failedKeys in <Set<String>>[
    {},
    {'id'},
    {'pw'},
    {'id', 'pw'},
  ]) {
    test(
      'deletion tries both keys and reports the first failure: $failedKeys',
      () async {
        final stored = {'id': 'STUDENT', 'pw': 'password'};
        final attempts = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'delete');
          final key = (call.arguments as Map)['key'] as String;
          attempts.add(key);
          if (failedKeys.contains(key)) throw PlatformException(code: key);
          stored.remove(key);
          return null;
        });
        final dao = UserDao();
        if (failedKeys.isEmpty) {
          await dao.delete();
        } else {
          await expectLater(
            dao.delete(),
            throwsA(
              isA<PlatformException>().having(
                (error) => error.code,
                'code',
                failedKeys.contains('id') ? 'id' : 'pw',
              ),
            ),
          );
        }
        expect(attempts, ['id', 'pw']);
        expect(stored.keys.toSet(), failedKeys);

        failedKeys.clear();
        await dao.delete();
        expect(stored, isEmpty);
      },
    );
  }
}
