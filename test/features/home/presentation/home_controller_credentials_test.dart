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
import 'package:hongik_ingan/features/attendance/application/attendance_data_source.dart';
import 'package:hongik_ingan/features/attendance/debug/attendance_test_environment.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/domain/login_result.dart';
import 'package:hongik_ingan/features/update/domain/update_check_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'login preparation is skipped if the form is hidden during clearing',
    () async {
      final transport = _LoginTransport()..clearGate = Completer<void>();
      final container = _container(
        _MemoryConfig(),
        _ControlledUserDao(),
        transport: transport,
      );
      final home = container.read(homeControllerProvider.notifier);
      final logout = home.logout();
      var formVisible = true;
      final preparation = home.prepareLoginPage(canContinue: () => formVisible);
      formVisible = false;
      transport.clearGate!.complete();
      await logout;
      await preparation;
      expect(transport.getRequests, isEmpty);
    },
  );

  test(
    'login page preparation waits until session clearing completes',
    () async {
      final transport = _LoginTransport()..clearGate = Completer<void>();
      final container = _container(
        _MemoryConfig(),
        _ControlledUserDao(),
        transport: transport,
      );
      final home = container.read(homeControllerProvider.notifier);
      final logout = home.logout();
      final preparation = home.prepareLoginPage();
      expect(transport.getRequests, isEmpty);
      transport.clearGate!.complete();
      await logout;
      await preparation;
      expect(transport.getRequests.single, endsWith('/my/login.do'));
      await home.login('STUDENT', 'password');
      expect(
        transport.getRequests.where((url) => url.endsWith('/my/login.do')),
        hasLength(1),
      );
    },
  );

  test(
    'reserved sample waits for real login and survives credential failure',
    () async {
      final transport = _LoginTransport()..acceptLogin = false;
      final container = _container(
        _MemoryConfig(),
        _ControlledUserDao(),
        transport: transport,
        useRealAttendance: true,
      );
      final testMode = container.read(
        attendanceTestControllerProvider.notifier,
      );
      await testMode.enable();
      final source = container.read(attendanceDataSourceOverrideProvider)!;
      final sample = source.transport as AttendanceTestTransport;
      expect(sample.lectureRequests, 0);
      expect(transport.getRequests, isEmpty);
      expect(container.read(homeControllerProvider).isLoggedIn, isFalse);
      expect(container.read(attendanceProvider).currentLecture, isNull);

      final home = container.read(homeControllerProvider.notifier);
      final failure = await home.login('NEW', 'password');
      expect(failure.isFailure, isTrue);
      expect(container.read(homeControllerProvider).isLoggedIn, isFalse);
      expect(
        container.read(attendanceDataSourceOverrideProvider),
        same(source),
      );
      expect(sample.lectureRequests, 0);

      transport.acceptLogin = true;
      final result = await home.login('NEW', 'password');
      await container.read(attendanceProvider.notifier).fetchLecture();
      expect(result.isSuccess, isTrue);
      expect(container.read(homeControllerProvider).userId, 'NEW');
      expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
      expect(
        container.read(attendanceDataSourceOverrideProvider),
        same(source),
      );
      expect(sample.lectureRequests, 1);
      expect(
        container.read(attendanceProvider).currentLecture?.name,
        '모바일 앱 프로그래밍',
      );
      // Real authentication still activates the attendance session once. The
      // automatic lecture lookup after it must use the reserved fixture source.
      expect(
        transport.getRequests.where((target) => target.endsWith('index.jsp')),
        hasLength(1),
      );
    },
  );

  test(
    'initialization returns saved input and ignores completion after disposal',
    () async {
      final config = _MemoryConfig(rememberMe: true)
        ..initGate = Completer<void>();
      final container = _container(config, _ControlledUserDao());
      final controller = container.read(homeControllerProvider.notifier);
      final initialized = controller.initializeApp();
      config.initGate!.complete();
      expect(await initialized, ('STUDENT', 'password'));
      expect(container.read(homeControllerProvider).rememberMe, isTrue);

      final lateConfig = _MemoryConfig()..initGate = Completer<void>();
      final lateContainer = _container(lateConfig, _ControlledUserDao());
      final pending = lateContainer
          .read(homeControllerProvider.notifier)
          .initializeApp();
      lateContainer.dispose();
      lateConfig.initGate!.complete();
      expect(await pending, (null, null));
    },
  );

  test(
    'update completion after disposal does not access provider state',
    () async {
      final result = Completer<UpdateCheckResult>();
      final container = ProviderContainer(
        overrides: [
          schoolTransportProvider.overrideWithValue(_LoginTransport()),
          homeControllerProvider.overrideWith(
            () => HomeController(
              appConfig: _MemoryConfig(),
              userDao: _ControlledUserDao(),
              updateChecker: () => result.future,
            ),
          ),
        ],
      );
      final pending = container
          .read(homeControllerProvider.notifier)
          .fetchUpdateInfo();
      container.dispose();
      result.complete(const UpdateCheckResult.upToDate());
      await pending;
    },
  );

  test(
    'update requests are shared while checking and failure can retry',
    () async {
      final first = Completer<UpdateCheckResult>();
      var calls = 0;
      final container = _container(
        _MemoryConfig(),
        _ControlledUserDao(),
        updateChecker: () {
          calls++;
          return calls == 1
              ? first.future
              : Future.value(const UpdateCheckResult.upToDate());
        },
      );
      final controller = container.read(homeControllerProvider.notifier);
      expect(
        container.read(homeControllerProvider).updateCheck.status,
        UpdateCheckStatus.idle,
      );
      controller.scheduleUpdateCheck(delay: Duration.zero);
      final pending = controller.fetchUpdateInfo(userInitiated: true);
      await controller.fetchUpdateInfo(userInitiated: true);
      expect(calls, 1);
      expect(
        container.read(homeControllerProvider).updateCheck.status,
        UpdateCheckStatus.checking,
      );
      first.complete(const UpdateCheckResult.failed());
      await pending;
      expect(
        container.read(homeControllerProvider).updateCheck.status,
        UpdateCheckStatus.failed,
      );
      await controller.fetchUpdateInfo(userInitiated: true);
      expect(calls, 2);
      expect(
        container.read(homeControllerProvider).updateCheck.status,
        UpdateCheckStatus.upToDate,
      );
    },
  );

  test('a thrown update check becomes a retryable failure', () async {
    final container = _container(
      _MemoryConfig(),
      _ControlledUserDao(),
      updateChecker: () async => throw StateError('connection failed'),
    );
    await container
        .read(homeControllerProvider.notifier)
        .fetchUpdateInfo(userInitiated: true);
    expect(
      container.read(homeControllerProvider).updateCheck.status,
      UpdateCheckStatus.failed,
    );
  });

  test(
    'missing input returns a typed failure without storing credentials',
    () async {
      final dao = _ControlledUserDao();
      final container = _container(_MemoryConfig(), dao);
      final result = await container
          .read(homeControllerProvider.notifier)
          .login('', '');
      expect(result.failureKind, LoginFailureKind.invalidInput);
      expect(result.displayMessage, '학번과 비밀번호를 모두 입력해 주세요.');
      expect(dao.saves, 0);
      expect(container.read(homeControllerProvider).isLoading, isFalse);
    },
  );

  test('security code challenge is not treated as a failed login', () async {
    final dao = _ControlledUserDao();
    final transport = _LoginTransport()..securityCodeRequired = true;
    final container = _container(_MemoryConfig(), dao, transport: transport);
    final result = await container
        .read(homeControllerProvider.notifier)
        .login('student', 'password');

    expect(result.needsSecurityCode, isTrue);
    expect(
      container.read(homeControllerProvider).loginStatus,
      LoginStatus.securityCodeRequired,
    );
    expect(container.read(homeControllerProvider).isLoggedIn, isFalse);
    expect(container.read(homeControllerProvider).isLoading, isFalse);
    expect(dao.saves, 0);
  });

  test(
    'security code remains a separate stage while a request is in flight',
    () async {
      final transport = _LoginTransport()..securityCodeRequired = true;
      final container = _container(
        _MemoryConfig(),
        _ControlledUserDao(),
        transport: transport,
      );
      final controller = container.read(homeControllerProvider.notifier);
      await controller.login('student', 'password');
      transport.loginPageGate = Completer<void>();
      transport.portalFailure = true;
      final pending = controller.login(
        'student',
        'password',
        securityCode: '001234',
      );

      expect(
        container.read(homeControllerProvider).loginStatus,
        LoginStatus.verifyingSecurityCode,
      );
      expect(
        container.read(homeControllerProvider).isSecurityCodeStage,
        isTrue,
      );
      expect(container.read(homeControllerProvider).isLoading, isTrue);
      transport.loginPageGate!.complete();
      final result = await pending;
      expect(result.failureKind, LoginFailureKind.connection);
      expect(
        container.read(homeControllerProvider).loginStatus,
        LoginStatus.securityCodeRequired,
      );
      expect(
        container.read(homeControllerProvider).isSecurityCodeStage,
        isTrue,
      );
    },
  );

  test(
    'changing credentials invalidates the security code challenge',
    () async {
      final transport = _LoginTransport()..securityCodeRequired = true;
      final container = _container(
        _MemoryConfig(),
        _ControlledUserDao(),
        transport: transport,
      );
      final controller = container.read(homeControllerProvider.notifier);
      await controller.login('student', 'password');
      controller.invalidateSecurityCodeChallenge();
      expect(
        container.read(homeControllerProvider).loginStatus,
        LoginStatus.required,
      );
      expect(
        container.read(homeControllerProvider).isSecurityCodeStage,
        isFalse,
      );
    },
  );

  test('logout cancels a pending security code verification', () async {
    final transport = _LoginTransport()..securityCodeRequired = true;
    final container = _container(
      _MemoryConfig(),
      _ControlledUserDao(),
      transport: transport,
    );
    final controller = container.read(homeControllerProvider.notifier);
    await controller.login('student', 'password');
    transport.loginPageGate = Completer<void>();
    final pending = controller.login(
      'student',
      'password',
      securityCode: '001234',
    );
    await controller.logout();
    transport.loginPageGate!.complete();

    expect((await pending).isCancelled, isTrue);
    expect(container.read(homeControllerProvider).isLoggedIn, isFalse);
    expect(container.read(homeControllerProvider).isSecurityCodeStage, isFalse);
    expect(
      transport.postRequests.where(
        (path) => path.endsWith('/app/login/LoginExec.jsp'),
      ),
      isEmpty,
    );
  });

  test('expired startup session prompts for a security code', () async {
    final dao = _ControlledUserDao();
    final transport = _LoginTransport()
      ..securityCodeRequired = true
      ..expireAttendance = true;
    final container = _container(
      _MemoryConfig(rememberMe: true, autoLogin: true),
      dao,
      transport: transport,
    );
    final controller = container.read(homeControllerProvider.notifier);
    await controller.initializeApp();
    await controller.restoreInitialSession('STUDENT', 'password');

    final state = container.read(homeControllerProvider);
    expect(state.loginStatus, LoginStatus.securityCodeRequired);
    expect(state.isLoggedIn, isFalse);
    expect(state.isLoading, isFalse);
    expect(dao.saves, 0);
  });

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
      expect((await login).isSuccess, isTrue);
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
    expect((await login).isSuccess, isTrue);

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

      expect(
        (await controller.login('first', 'first-password')).isSuccess,
        isTrue,
      );
      expect(container.read(homeControllerProvider).isLoading, isFalse);
      expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
      expect(
        container.read(homeControllerProvider).statusMessage,
        contains('저장에 실패'),
      );
      expect(await dao.load(), (null, null));
      expect(config.savedId, isNull);
      expect(config.savedPw, isNull);

      expect(
        (await controller.login('second', 'second-password')).isSuccess,
        isTrue,
      );
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
      expect((await oldLogin).isCancelled, isTrue);
      await logout;
      expect((await newLogin).isSuccess, isTrue);

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
  Future<UpdateCheckResult> Function()? updateChecker,
  bool useRealAttendance = false,
}) {
  return ProviderContainer.test(
    overrides: [
      schoolTransportProvider.overrideWithValue(transport ?? _LoginTransport()),
      homeControllerProvider.overrideWith(
        () => HomeController(
          appConfig: config,
          userDao: dao,
          updateChecker: updateChecker,
        ),
      ),
      if (!useRealAttendance)
        attendanceProvider.overrideWith(_QuietAttendanceController.new),
      if (useRealAttendance)
        attendanceTestLatencyProvider.overrideWithValue(Duration.zero),
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
  Completer<void>? initGate;

  @override
  Future<void> init() async => await initGate?.future;

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
  final getRequests = <String>[];
  final postRequests = <String>[];
  bool acceptLogin = true;
  bool securityCodeRequired = false;
  bool expireAttendance = false;
  bool portalFailure = false;
  Completer<void>? loginPageGate;
  Completer<void>? clearGate;

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    getRequests.add(target);
    if (target.endsWith('/my/login.do')) await loginPageGate?.future;
    if (target.endsWith('index.jsp') && !loginFinished.isCompleted) {
      loginFinished.complete();
    }
    return Response<T>(
      requestOptions: RequestOptions(path: target),
      statusCode: 200,
      data:
          (expireAttendance && Uri.parse(target).host == 'at.hongik.ac.kr'
                  ? '통합 로그인'
                  : 'ok')
              as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    postRequests.add(target);
    if (portalFailure && target.endsWith('/app/login/LoginCheck.jsp')) {
      throw DioException(
        requestOptions: RequestOptions(path: target),
        type: DioExceptionType.connectionError,
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: target),
      statusCode: 200,
      data:
          (target.endsWith('LoginCheck_SSO.php')
                  ? {
                      'result_code': acceptLogin ? 'Y' : 'N',
                      'pin_use': securityCodeRequired ? '1' : '0',
                    }
                  : 'ok')
              as T,
    );
  }

  @override
  Future<void> clearAuthSession() async => await clearGate?.future;
  @override
  Future<bool> hasAuthSession() async => true;
  @override
  Future<bool> hasCookie(Uri target, String name) async => true;
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
