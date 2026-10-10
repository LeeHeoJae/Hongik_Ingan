import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/app_config.dart';
import 'package:hongik_ingan/core/user_dao.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, Object> stored;
  late bool failWrite;
  late bool throwWrite;

  setUp(() {
    SharedPreferences.resetStatic();
    stored = {};
    failWrite = false;
    throwWrite = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll' || call.method == 'getAllWithParameters') {
        return stored;
      }
      if (call.method == 'setBool') {
        if (throwWrite) throw PlatformException(code: 'unavailable');
        if (failWrite) return false;
        final arguments = call.arguments as Map;
        stored[arguments['key'] as String] = arguments['value'] as bool;
        return true;
      }
      throw StateError('Unexpected storage method: ${call.method}');
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
  });

  for (final key in ['remember_me', 'auto_login']) {
    for (final throws in [false, true]) {
      test(
        '$key keeps its confirmed value after a failed write (throws: $throws)',
        () async {
          final config = AppConfig(userDao: _UserDao());
          await config.init();
          failWrite = !throws;
          throwWrite = throws;
          final write = key == 'remember_me'
              ? config.setRememberMe(true)
              : config.setAutoLogin(true);
          await expectLater(
            write,
            throws ? throwsA(isA<PlatformException>()) : throwsStateError,
          );
          // The plugin cache has changed, but the confirmed setting has not.
          expect((await SharedPreferences.getInstance()).getBool(key), isTrue);
          expect(
            key == 'remember_me' ? config.rememberMe : config.autoLogin,
            isFalse,
          );
          expect(stored['flutter.$key'], isNull);

          failWrite = false;
          throwWrite = false;
          if (key == 'remember_me') {
            await config.setRememberMe(true);
            expect(config.rememberMe, isTrue);
          } else {
            await config.setAutoLogin(true);
            expect(config.autoLogin, isTrue);
          }
          expect(stored['flutter.$key'], isTrue);
        },
      );
    }
  }

  test(
    'concurrent initialization shares a request and retries after failure',
    () async {
      final pending = Completer<SharedPreferences>();
      var loads = 0;
      final config = AppConfig(
        loadPreferences: () {
          loads++;
          return loads == 1 ? pending.future : SharedPreferences.getInstance();
        },
      );
      final first = config.init();
      final second = config.init();
      expect(identical(first, second), isTrue);
      final failure = expectLater(first, throwsStateError);
      pending.completeError(StateError('Unavailable'));
      await failure;
      expect(config.isInitialized, isFalse);
      await config.init();
      expect(loads, 2);
      expect(config.isInitialized, isTrue);
    },
  );

  test(
    'credentials must finish loading before initialization succeeds',
    () async {
      stored = {'flutter.remember_me': true, 'flutter.auto_login': true};
      final dao = _UserDao()..failLoad = true;
      final config = AppConfig(userDao: dao);
      await expectLater(config.init(), throwsStateError);
      expect(config.isInitialized, isFalse);
      expect(config.rememberMe, isFalse);
      expect(config.savedId, isNull);
      dao.failLoad = false;
      await config.init();
      expect(config.isInitialized, isTrue);
      expect(config.rememberMe, isTrue);
      expect(config.autoLogin, isTrue);
      expect((config.savedId, config.savedPw), ('STUDENT', 'password'));
      expect(dao.loads, 2);
    },
  );

  test('credentials are not loaded when remembering is disabled', () async {
    final dao = _UserDao()..failLoad = true;
    final config = AppConfig(userDao: dao);
    await config.init();
    expect(dao.loads, 0);
    expect(config.isInitialized, isTrue);
    expect((config.savedId, config.savedPw), (null, null));
  });
}

class _UserDao extends UserDao {
  bool failLoad = false;
  int loads = 0;

  @override
  Future<(String?, String?)> load() async {
    loads++;
    if (failLoad) throw StateError('Unavailable');
    return ('STUDENT', 'password');
  }
}
