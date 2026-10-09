import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/app_config.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/user_dao.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'forgetting during a save removes both credentials after the save',
    () async {
      final config = _MemoryConfig(rememberMe: true, autoLogin: true);
      final dao = _ControlledUserDao()..saveGate = Completer<void>();
      final container = _container(config, dao);
      final controller = container.read(homeControllerProvider.notifier);

      final login = controller.login('student', 'password');
      await dao.saveStarted.future;
      final forgotten = controller.onRememberMeChanged(false);
      expect(container.read(homeControllerProvider).rememberMe, isFalse);
      expect(container.read(homeControllerProvider).autoLogin, isFalse);
      expect(config.savedId, isNull);
      expect(dao.deletes, 0);
      dao.saveGate!.complete();
      expect(await login, 'Success');
      await forgotten;

      expect(await dao.load(), (null, null));
      expect(dao.events, ['save-id:STUDENT', 'save-password', 'delete']);
      expect(config.rememberMe, isFalse);
      expect(config.autoLogin, isFalse);
      expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
    },
  );

  test('rapid setting changes persist the last selection in order', () async {
    final config = _MemoryConfig()..settingsGate = Completer<void>();
    final dao = _ControlledUserDao();
    final container = _container(config, dao);
    final controller = container.read(homeControllerProvider.notifier);

    final first = controller.onAutoLoginChanged(true);
    await config.settingsStarted.future;
    final second = controller.onRememberMeChanged(false);
    final third = controller.onAutoLoginChanged(true);
    config.settingsGate!.complete();
    await Future.wait([first, second, third]);

    expect(config.events, [
      'remember:true',
      'auto:true',
      'auto:false',
      'remember:false',
      'remember:true',
      'auto:true',
    ]);
    expect(config.rememberMe, isTrue);
    expect(config.autoLogin, isTrue);
    expect(container.read(homeControllerProvider).rememberMe, isTrue);
    expect(container.read(homeControllerProvider).autoLogin, isTrue);
    expect(dao.deletes, 1);
  });

  test('a queued login save checks the latest remember choice', () async {
    final config = _MemoryConfig()..settingsGate = Completer<void>();
    final dao = _ControlledUserDao();
    final transport = _LoginTransport();
    final container = _container(config, dao, transport: transport);
    final controller = container.read(homeControllerProvider.notifier);

    final remembered = controller.onRememberMeChanged(true);
    await config.settingsStarted.future;
    final login = controller.login('student', 'password');
    await transport.loginFinished.future;
    final forgotten = controller.onRememberMeChanged(false);
    config.settingsGate!.complete();
    await Future.wait([remembered, forgotten]);
    expect(await login, 'Success');

    expect(dao.saves, 0);
    expect(await dao.load(), (null, null));
  });

  test(
    'save failure clears partial credentials and does not block later login',
    () async {
      final config = _MemoryConfig(rememberMe: true);
      final dao = _ControlledUserDao()..failSaveOnce = true;
      final container = _container(config, dao);
      final controller = container.read(homeControllerProvider.notifier);

      expect(await controller.login('first', 'first-password'), 'Success');
      expect(container.read(homeControllerProvider).isLoading, isFalse);
      expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
      expect(
        container.read(homeControllerProvider).statusMessage,
        contains('저장에 실패'),
      );
      expect(await dao.load(), (null, null));
      expect(config.savedId, isNull);
      expect(config.savedPw, isNull);

      expect(await controller.login('second', 'second-password'), 'Success');
      expect(await dao.load(), ('SECOND', 'second-password'));
    },
  );

  test('preference failure still attempts credential deletion', () async {
    final config = _MemoryConfig(rememberMe: true, autoLogin: true)
      ..failAutoOnce = true;
    final dao = _ControlledUserDao()
      ..id = 'STUDENT'
      ..password = 'password';
    final container = _container(config, dao);
    final controller = container.read(homeControllerProvider.notifier);

    await controller.onRememberMeChanged(false);
    expect(dao.deletes, 1);
    expect(await dao.load(), (null, null));
    expect(
      container.read(homeControllerProvider).statusMessage,
      contains('저장하지 못'),
    );

    await controller.onRememberMeChanged(false);
    expect(config.rememberMe, isFalse);
    expect(config.autoLogin, isFalse);
  });

  test(
    'deletion failure does not poison the next settings operation',
    () async {
      final config = _MemoryConfig(rememberMe: true);
      final dao = _ControlledUserDao()..failDeleteOnce = true;
      final container = _container(config, dao);
      final controller = container.read(homeControllerProvider.notifier);

      await controller.onRememberMeChanged(false);
      expect(
        container.read(homeControllerProvider).statusMessage,
        contains('저장하지 못'),
      );
      await controller.onAutoLoginChanged(true);
      expect(config.rememberMe, isTrue);
      expect(config.autoLogin, isTrue);
    },
  );

  test(
    'an old settings failure does not roll back a newer selection',
    () async {
      final config = _MemoryConfig()
        ..settingsGate = Completer<void>()
        ..failRememberOnce = true;
      final dao = _ControlledUserDao();
      final container = _container(config, dao);
      final controller = container.read(homeControllerProvider.notifier);

      final first = controller.onRememberMeChanged(true);
      await config.settingsStarted.future;
      final latest = controller.onAutoLoginChanged(true);
      config.settingsGate!.complete();
      await Future.wait([first, latest]);

      expect(config.rememberMe, isTrue);
      expect(config.autoLogin, isTrue);
      expect(container.read(homeControllerProvider).rememberMe, isTrue);
      expect(container.read(homeControllerProvider).autoLogin, isTrue);
      expect(
        container.read(homeControllerProvider).statusMessage,
        isNot(contains('저장하지 못')),
      );
    },
  );

  test(
    'logout and a new account cannot be overwritten by an older save',
    () async {
      final config = _MemoryConfig(rememberMe: true, autoLogin: true);
      final dao = _ControlledUserDao()..saveGate = Completer<void>();
      final container = _container(config, dao);
      final controller = container.read(homeControllerProvider.notifier);

      final oldLogin = controller.login('old', 'old-password');
      await dao.saveStarted.future;
      final logout = controller.logout();
      final newLogin = controller.login('new', 'new-password');
      dao.saveGate!.complete();
      expect(await oldLogin, 'Cancelled');
      await logout;
      expect(await newLogin, 'Success');

      expect(await dao.load(), ('NEW', 'new-password'));
      expect(config.autoLogin, isFalse);
      expect(container.read(homeControllerProvider).userId, 'new');
      expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
    },
  );
}

ProviderContainer _container(
  _MemoryConfig config,
  _ControlledUserDao dao, {
  _LoginTransport? transport,
}) {
  return ProviderContainer.test(
    overrides: [
      schoolTransportProvider.overrideWithValue(transport ?? _LoginTransport()),
      homeControllerProvider.overrideWith(
        () => HomeController(appConfig: config, userDao: dao),
      ),
      attendanceProvider.overrideWith(_QuietAttendanceController.new),
    ],
  );
}

class _MemoryConfig implements AppConfig {
  _MemoryConfig({this.rememberMe = false, this.autoLogin = false});

  @override
  bool rememberMe;
  @override
  bool autoLogin;
  @override
  bool autoAttendance = false;
  @override
  String? savedId = 'STUDENT';
  @override
  String? savedPw = 'password';
  @override
  bool get isInitialized => true;

  final events = <String>[];
  final settingsStarted = Completer<void>();
  Completer<void>? settingsGate;
  bool failRememberOnce = false;
  bool failAutoOnce = false;

  @override
  Future<void> init() async {}

  @override
  void clearSavedCredentials() {
    savedId = null;
    savedPw = null;
  }

  @override
  Future<void> setRememberMe(bool value) async {
    if (!settingsStarted.isCompleted) settingsStarted.complete();
    await settingsGate?.future;
    if (failRememberOnce) {
      failRememberOnce = false;
      throw StateError('preference write failed');
    }
    events.add('remember:$value');
    rememberMe = value;
  }

  @override
  Future<void> setAutoLogin(bool value) async {
    if (failAutoOnce) {
      failAutoOnce = false;
      throw StateError('preference write failed');
    }
    events.add('auto:$value');
    autoLogin = value;
  }

  @override
  Future<void> setAutoAttendance(bool value) async => autoAttendance = value;
}

class _ControlledUserDao extends UserDao {
  String? id;
  String? password;
  int saves = 0;
  int deletes = 0;
  bool failSaveOnce = false;
  bool failDeleteOnce = false;
  Completer<void>? saveGate;
  final saveStarted = Completer<void>();
  final events = <String>[];

  @override
  Future<void> save(String id, String pw) async {
    saves++;
    this.id = id.toUpperCase();
    events.add('save-id:${this.id}');
    if (!saveStarted.isCompleted) saveStarted.complete();
    await saveGate?.future;
    if (failSaveOnce) {
      failSaveOnce = false;
      throw StateError('password write failed');
    }
    password = pw;
    events.add('save-password');
  }

  @override
  Future<(String?, String?)> load() async => (id, password);

  @override
  Future<void> delete() async {
    deletes++;
    if (failDeleteOnce) {
      failDeleteOnce = false;
      throw StateError('delete failed');
    }
    events.add('delete');
    id = null;
    password = null;
  }
}

class _QuietAttendanceController extends AttendanceController {
  @override
  AttendanceState build() => const AttendanceState();

  @override
  Future<void> fetchLecture({
    bool forceRefresh = false,
    bool isAutomatic = false,
  }) async {}
}

class _LoginTransport implements SchoolTransport {
  final loginFinished = Completer<void>();

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    if (target.endsWith('index.jsp') && !loginFinished.isCompleted) {
      loginFinished.complete();
    }
    return Response<T>(
      requestOptions: RequestOptions(path: target),
      statusCode: 200,
      data: 'ok' as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async => Response<T>(
    requestOptions: RequestOptions(path: target),
    statusCode: 200,
    data:
        (target.endsWith('LoginCheck_SSO.php') ? {'result_code': 'Y'} : 'ok')
            as T,
  );

  @override
  Future<void> clearAuthSession() async {}
  @override
  Future<bool> hasAuthSession() async => true;
  @override
  Future<bool> hasCookie(Uri target, String name) async => true;
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
