import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ssoError = '''<script>
alert('SSO 시스템 연동 중 오류가 발생했습니다.');
document.location.replace("http://www.hongik.ac.kr");
</script>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  for (final (page, expectedStatus, expectedClears) in [
    ('ok', LoginStatus.required, 0),
    ('통합 로그인', LoginStatus.expired, 1),
    (_ssoError, LoginStatus.verificationFailed, 0),
  ]) {
    test(
      'initial session check clears only expired cookies: $expectedStatus',
      () async {
        final transport = _RecoveryTransport(initialPage: page);
        final container = ProviderContainer.test(
          overrides: [
            schoolTransportProvider.overrideWithValue(transport),
            homeControllerProvider.overrideWith(
              () => _LoggedInHomeController(automaticLogin: false),
            ),
            attendanceProvider.overrideWith(_QuietAttendanceController.new),
          ],
        );
        await container
            .read(homeControllerProvider.notifier)
            .restoreSessionOrLogin('', '');
        expect(
          container.read(homeControllerProvider).loginStatus,
          expectedStatus,
        );
        expect(transport.clearCalls, expectedClears);
      },
    );
  }

  for (final automaticLogin in [false, true]) {
    for (final page in ['통합 로그인', 'SSO 시스템 연동 오류']) {
      test(
        'resume restores SSO before clearing cookies ($automaticLogin, $page)',
        () async {
          final transport = _RecoveryTransport(
            ssoCanReactivate: true,
            initialPage: page,
          );
          final attendance = _QuietAttendanceController();
          final container = ProviderContainer.test(
            overrides: [
              schoolTransportProvider.overrideWithValue(transport),
              homeControllerProvider.overrideWith(
                () => _LoggedInHomeController(automaticLogin: automaticLogin),
              ),
              attendanceProvider.overrideWith(() => attendance),
            ],
          );
          final controller = container.read(homeControllerProvider.notifier);
          final first = controller.revalidateSessionOnResume(
            'student',
            'test-password',
          );
          final second = controller.revalidateSessionOnResume(
            'student',
            'test-password',
          );
          await Future.wait([first, second]);
          expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
          expect(transport.clearCalls, 0);
          expect(transport.loginStarted.isCompleted, isFalse);
          expect(transport.loginRequests, 1);
          expect(attendance.fetchCalls, 1);
        },
      );
    }
  }

  for (final succeeds in [true, false]) {
    test('SSO failure on resume reauthenticates once ($succeeds)', () async {
      final transport = _RecoveryTransport(
        initialPage: _ssoError,
        activationPage: _ssoError,
      );
      final attendance = _QuietAttendanceController();
      final container = ProviderContainer.test(
        overrides: [
          schoolTransportProvider.overrideWithValue(transport),
          homeControllerProvider.overrideWith(_LoggedInHomeController.new),
          attendanceProvider.overrideWith(() => attendance),
        ],
      );
      final controller = container.read(homeControllerProvider.notifier);
      final request = controller.revalidateSessionOnResume(
        'student',
        'test-password',
      );
      final concurrent = controller.revalidateSessionOnResume(
        'student',
        'test-password',
      );
      await transport.loginStarted.future;
      expect(container.read(homeControllerProvider).isLoading, isTrue);
      expect(
        container.read(homeControllerProvider).loginStatus,
        LoginStatus.recoveringSession,
      );
      transport.validation.complete({'result_code': succeeds ? 'Y' : 'N'});
      await Future.wait([request, concurrent]);
      final result = container.read(homeControllerProvider);
      expect(result.isLoading, isFalse);
      expect(result.isLoggedIn, succeeds ? isTrue : isFalse);
      expect(
        result.loginStatus,
        succeeds ? LoginStatus.required : LoginStatus.expired,
      );
      expect(transport.credentialLogins, 1);
      expect(transport.clearCalls, succeeds ? 0 : 1);
      expect(attendance.fetchCalls, succeeds ? 1 : 0);
    });
  }

  for (final accountMatches in [true, false]) {
    test(
      'resume respects automatic login and account ($accountMatches)',
      () async {
        final transport = _RecoveryTransport(
          initialPage: _ssoError,
          activationPage: _ssoError,
        );
        final container = ProviderContainer.test(
          overrides: [
            schoolTransportProvider.overrideWithValue(transport),
            homeControllerProvider.overrideWith(
              () => _LoggedInHomeController(automaticLogin: !accountMatches),
            ),
            attendanceProvider.overrideWith(_QuietAttendanceController.new),
          ],
        );
        await container
            .read(homeControllerProvider.notifier)
            .revalidateSessionOnResume(
              accountMatches ? 'student' : 'different-account',
              'test-password',
            );
        expect(transport.credentialLogins, 0);
        expect(
          container.read(homeControllerProvider).loginStatus,
          LoginStatus.required,
        );
        expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
        expect(container.read(homeControllerProvider).isLoading, isFalse);
        expect(transport.clearCalls, 0);
      },
    );
  }

  for (final outage in [
    'activation',
    'reauthentication',
    'validation',
    'unknownValidation',
  ]) {
    test('resume $outage outage retains account and cookies', () async {
      final transport = _RecoveryTransport(
        initialPage: _ssoError,
        activationPage: _ssoError,
        activationNetworkFailure: outage == 'activation',
        postAuthenticationPage: _ssoError,
      );
      final container = ProviderContainer.test(
        overrides: [
          schoolTransportProvider.overrideWithValue(transport),
          homeControllerProvider.overrideWith(_LoggedInHomeController.new),
        ],
      );
      final home = container.read(homeControllerProvider.notifier);
      final request = home.revalidateSessionOnResume(
        'student',
        'test-password',
      );
      if (outage != 'activation') {
        await transport.loginStarted.future;
        transport.validation.complete(switch (outage) {
          'validation' => {'result_code': 'N', 'result_msg': 'SSO 시스템 연동 오류'},
          'unknownValidation' => {'result_msg': 'Server unavailable'},
          _ => {'result_code': 'Y'},
        });
      }
      await request;
      expect(container.read(homeControllerProvider).isLoggedIn, isTrue);
      expect(container.read(homeControllerProvider).isLoading, isFalse);
      expect(
        container.read(homeControllerProvider).statusMessage,
        isNot(contains('SSO')),
      );
      expect(transport.clearCalls, 0);
      expect(container.read(attendanceProvider).isLectureStale, isTrue);
      expect(container.read(attendanceProvider).error, isNull);
      final requests = transport.loginRequests;
      await home.revalidateSessionOnResume('student', 'test-password');
      expect(transport.loginRequests, requests);
    });
  }

  test('logout cancels SSO reauthentication on resume', () async {
    final transport = _RecoveryTransport(
      initialPage: _ssoError,
      activationPage: _ssoError,
    );
    final container = ProviderContainer.test(
      overrides: [
        schoolTransportProvider.overrideWithValue(transport),
        homeControllerProvider.overrideWith(_LoggedInHomeController.new),
        attendanceProvider.overrideWith(_QuietAttendanceController.new),
      ],
    );
    final controller = container.read(homeControllerProvider.notifier);
    final request = controller.revalidateSessionOnResume(
      'student',
      'test-password',
    );
    await transport.loginStarted.future;
    await controller.logout();
    transport.validation.complete({'result_code': 'Y'});
    await request;
    expect(container.read(homeControllerProvider).isLoggedIn, isFalse);
    expect(container.read(homeControllerProvider).isLoading, isFalse);
    expect(transport.loginRequests, 1);
  });

  for (final succeeds in [true, false]) {
    test(
      'expired session stays in recovery until authentication finishes ($succeeds)',
      () async {
        final transport = _RecoveryTransport();
        final container = ProviderContainer.test(
          overrides: [
            schoolTransportProvider.overrideWithValue(transport),
            homeControllerProvider.overrideWith(_LoggedInHomeController.new),
            attendanceProvider.overrideWith(_QuietAttendanceController.new),
          ],
        );
        final states = <HomeState>[];
        container.listen(homeControllerProvider, (_, next) => states.add(next));
        final controller = container.read(homeControllerProvider.notifier);
        final request = controller.revalidateSessionOnResume(
          'student',
          'test-password',
        );
        await transport.loginStarted.future;
        final recovering = container.read(homeControllerProvider);
        expect(recovering.isLoading, isTrue);
        expect(recovering.isLoggedIn, isTrue);
        expect(recovering.loginStatus, LoginStatus.recoveringSession);
        expect(
          states.every(
            (state) => state.loginStatus == LoginStatus.recoveringSession,
          ),
          isTrue,
        );
        transport.validation.complete({
          'result_code': succeeds ? 'Y' : 'N',
          'result_msg': '인증 실패',
        });
        await request;
        final result = container.read(homeControllerProvider);
        expect(result.isLoading, isFalse);
        expect(result.isLoggedIn, succeeds);
        expect(
          result.loginStatus,
          succeeds ? LoginStatus.required : LoginStatus.expired,
        );
        if (!succeeds) expect(result.statusMessage, '다시 로그인해 주세요.');
      },
    );
  }

  test(
    'logout during recovery prevents a late login result from restoring the session',
    () async {
      final transport = _RecoveryTransport();
      final container = ProviderContainer.test(
        overrides: [
          schoolTransportProvider.overrideWithValue(transport),
          homeControllerProvider.overrideWith(_LoggedInHomeController.new),
          attendanceProvider.overrideWith(_QuietAttendanceController.new),
        ],
      );
      final controller = container.read(homeControllerProvider.notifier);
      final request = controller.revalidateSessionOnResume(
        'student',
        'test-password',
      );
      await transport.loginStarted.future;
      await controller.logout();
      transport.validation.complete({'result_code': 'Y'});
      await request;
      final result = container.read(homeControllerProvider);
      expect(result.isLoggedIn, isFalse);
      expect(result.isLoading, isFalse);
      expect(result.loginStatus, LoginStatus.required);
      expect(result.autoLogin, isFalse);
    },
  );
}

class _LoggedInHomeController extends HomeController {
  _LoggedInHomeController({this.automaticLogin = true});
  final bool automaticLogin;
  @override
  HomeState build() {
    super.build();
    return HomeState(
      isLoggedIn: true,
      userId: 'student',
      rememberMe: automaticLogin,
      autoLogin: automaticLogin,
    );
  }
}

class _QuietAttendanceController extends AttendanceController {
  var fetchCalls = 0;

  @override
  Future<void> fetchLecture({
    bool forceRefresh = false,
    bool isAutomatic = false,
  }) async {
    fetchCalls++;
  }
}

class _RecoveryTransport implements SchoolTransport {
  _RecoveryTransport({
    this.ssoCanReactivate = false,
    this.initialPage = '통합 로그인',
    this.activationPage = '통합 로그인',
    this.activationNetworkFailure = false,
    this.postAuthenticationPage = 'ok',
  });
  final bool ssoCanReactivate;
  final String initialPage;
  final String activationPage;
  final bool activationNetworkFailure;
  final String postAuthenticationPage;
  final loginStarted = Completer<void>();
  final validation = Completer<Map<String, dynamic>>();
  var _indexRequests = 0;
  var clearCalls = 0;
  var loginRequests = 0;
  var credentialLogins = 0;

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    final initial = target.endsWith('index.jsp') && _indexRequests++ == 0;
    if (target.endsWith('login.jsp')) loginRequests++;
    if (target.endsWith('login.jsp') && activationNetworkFailure) {
      throw DioException(
        requestOptions: RequestOptions(path: target),
        type: DioExceptionType.connectionError,
      );
    }
    final expired =
        target.endsWith('login.jsp') &&
        !ssoCanReactivate &&
        !validation.isCompleted;
    return Response<T>(
      requestOptions: RequestOptions(path: target),
      statusCode: 200,
      data:
          (initial
                  ? initialPage
                  : expired
                  ? activationPage
                  : validation.isCompleted
                  ? postAuthenticationPage
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
    Object payload = 'ok';
    if (target.endsWith('LoginCheck_SSO.php')) {
      credentialLogins++;
      loginStarted.complete();
      payload = await validation.future;
    }
    return Response<T>(
      requestOptions: RequestOptions(path: target),
      statusCode: 200,
      data: payload as T,
    );
  }

  @override
  Future<void> clearAuthSession() async {
    clearCalls++;
  }

  @override
  Future<bool> hasAuthSession() async => true;
  @override
  Future<bool> hasCookie(Uri target, String name) async => true;
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
