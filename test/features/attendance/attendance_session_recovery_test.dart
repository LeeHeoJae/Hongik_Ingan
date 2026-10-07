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
import 'package:hongik_ingan/features/attendance/data/attendance_service.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/data/auth_service.dart';
import 'package:hongik_ingan/features/home/domain/session_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _logout = '''<html><body>
장시간 사용이 없어 로그아웃 되었습니다.
[오류]: https://ap.hongik.ac.kr/site/login/logout.php
<script>document.location.replace("http://www.hongik.ac.kr");</script>
</body></html>''';
const _empty = '<table><tbody></tbody></table>';
const _lecture = '''<table><tbody><tr>
<td>1</td><td>2</td><td>Course</td><td>Room</td><td>10:00</td>
<td><form action="stud02.jsp"><input name="lecture" value="1"></form></td>
</tr></tbody></table>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          if (call.method != 'read') return null;
          return (call.arguments as Map)['key'] == 'id'
              ? 'STUDENT'
              : 'test-password';
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  final expiredBodies = [
    _logout,
    '<script>alert("장시간 사용이 없어 로그아웃 되었습니다.")</script>',
    '[오류]: https://ap.hongik.ac.kr/site/login/logout.php',
    "<script>document . location . replace ( 'https://www.hongik.ac.kr/' );</script>",
    '<form><input name = "USER_ID"></form>',
    "<form><input name='PASSWD'></form>",
    '통합 로그인',
  ];
  for (var i = 0; i < expiredBodies.length; i++) {
    test(
      'HTTP 200 expiry variant $i is recognized by fetch and session check',
      () async {
        final transport = _Transport(indexBodies: [expiredBodies[i]]);
        final result = await AttendanceService(transport).getActiveLecture();
        expect(result.status, LectureFetchStatus.failure);
        expect(result.sessionExpired, isTrue);
        expect(result.message, '출결 서버 세션이 만료됐어요.');
        expect(
          await AuthService(transport).checkSessionStatus(),
          SessionStatus.expired,
        );
      },
    );
  }

  test('normal logout links do not invalidate a lecture page', () async {
    final transport = _Transport(
      indexBodies: [
        '<a href="https://ap.hongik.ac.kr/site/login/logout.php">로그아웃</a>$_lecture',
      ],
    );
    final result = await AttendanceService(transport).getActiveLecture();
    expect(result.status, LectureFetchStatus.success);
    expect(result.sessionExpired, isFalse);
  });

  test(
    'unrelated malformed and integration pages remain ordinary failures',
    () async {
      for (final body in ['<p>unexpected response</p>', 'SSO 시스템 연동 오류', '']) {
        final result = await AttendanceService(
          _Transport(indexBodies: [body]),
        ).getActiveLecture();
        expect(result.status, LectureFetchStatus.failure);
        expect(result.sessionExpired, isFalse);
      }
    },
  );

  test(
    'logout HTML during login activation cannot report login success',
    () async {
      final transport = _Transport(indexBodies: [_logout]);
      final result = await AuthService(
        transport,
      ).login('student', 'test-password');
      expect(result, '출결 서버가 로그인 세션을 인식하지 못했어요.');
    },
  );

  test('SSO cookies reactivate attendance without credential login', () async {
    final transport = _Transport();
    expect(
      await AuthService(
        transport,
      ).recoverAttendanceSession(canContinue: () => true),
      isTrue,
    );
    expect(transport.posts, isEmpty);
    expect(transport.loginRequests, 1);
    expect(transport.indexRequests, 1);
  });

  test(
    'failed SSO activation performs LoginExec3 and refreshes cookies',
    () async {
      final transport = _Transport(loginBodies: [_logout, 'activated']);
      expect(
        await AuthService(transport).recoverAttendanceSession(
          studentId: 'student',
          password: 'test-password',
          canContinue: () => true,
        ),
        isTrue,
      );
      expect(
        transport.posts.where((path) => path.endsWith('LoginExec3.php')),
        hasLength(1),
      );
      expect(transport.savedCookies.map((cookie) => cookie.name), ['SSO']);
      expect(transport.loginRequests, 2);
    },
  );

  test('working SSO does not require reading stored credentials', () async {
    final transport = _Transport();
    expect(
      await AuthService(transport).recoverAttendanceSession(
        readPassword: () async => throw StateError('storage unavailable'),
        canContinue: () => true,
      ),
      isTrue,
    );
    expect(transport.posts, isEmpty);
  });

  test(
    'saved credentials for another account cannot be used for recovery',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, (call) async {
            if (call.method != 'read') return null;
            return (call.arguments as Map)['key'] == 'id'
                ? 'OTHER-STUDENT'
                : 'test-password';
          });
      final transport = _Transport(
        indexBodies: [_logout],
        loginBodies: [_logout],
      );
      final container = _container(transport, automaticLogin: true);
      await container.read(attendanceProvider.notifier).fetchLecture();
      expect(container.read(attendanceProvider).sessionExpired, isTrue);
      expect(transport.posts, isEmpty);
    },
  );

  test(
    'logout during LoginExec3 discards embedded authentication cookies',
    () async {
      final transport = _Transport(
        indexBodies: [_logout],
        loginBodies: [_logout],
      );
      transport.loginExecGate = Completer<void>();
      final container = _container(transport, automaticLogin: true);
      final request = container
          .read(attendanceProvider.notifier)
          .fetchLecture();
      await transport.loginExecStarted.future;
      await container.read(homeControllerProvider.notifier).logout();
      transport.loginExecGate!.complete();
      await request;
      expect(container.read(homeControllerProvider).isLoggedIn, isFalse);
      expect(container.read(attendanceProvider).hasCheckedLecture, isFalse);
      expect(transport.savedCookies, isEmpty);
      expect(transport.loginRequests, 1);
      expect(transport.indexRequests, 1);
    },
  );

  test(
    'no credentials or network failure does not trigger credential login',
    () async {
      for (final networkFailure in [false, true]) {
        final transport = _Transport(
          loginBodies: [_logout],
          failActivation: networkFailure,
        );
        expect(
          await AuthService(transport).recoverAttendanceSession(
            studentId: networkFailure ? 'student' : null,
            password: networkFailure ? 'test-password' : null,
            canContinue: () => true,
          ),
          isFalse,
        );
        expect(transport.posts, isEmpty);
      }
    },
  );

  test(
    'lecture request recovers once and concurrent requests share recovery',
    () async {
      final transport = _Transport(indexBodies: [_logout, _empty, _lecture]);
      transport.activationGate = Completer<String>();
      final container = _container(transport);
      final controller = container.read(attendanceProvider.notifier);
      final first = controller.fetchLecture(
        forceRefresh: true,
        isAutomatic: true,
      );
      final second = controller.fetchLecture(forceRefresh: true);
      await transport.activationStarted.future;
      final home = container.read(homeControllerProvider.notifier);
      final recovery1 = home.recoverAttendanceSession();
      final recovery2 = home.recoverAttendanceSession();
      expect(identical(recovery1, recovery2), isTrue);
      final resume = home.revalidateSessionOnResume('student', 'test-password');
      transport.activationGate!.complete('activated');
      await Future.wait([first, second, recovery1, recovery2, resume]);
      expect(container.read(attendanceProvider).currentLecture?.name, 'Course');
      expect(container.read(attendanceProvider).sessionExpired, isFalse);
      expect(transport.loginRequests, 1);
      expect(transport.indexRequests, 3); // initial, activation, one retry
      expect(transport.posts, isEmpty);
      expect(
        transport.lectureOptions.every((options) => !options.allowProxyRetry),
        isTrue,
      );
    },
  );

  test('expiry after the one retry stops automatic polling', () async {
    final transport = _Transport(indexBodies: [_logout, _empty, _logout]);
    final container = _container(transport);
    final controller = container.read(attendanceProvider.notifier);
    await controller.fetchLecture(isAutomatic: true);
    expect(container.read(attendanceProvider).sessionExpired, isTrue);
    await controller.fetchLecture(forceRefresh: true, isAutomatic: true);
    expect(transport.indexRequests, 3);
    expect(transport.loginRequests, 1);
  });

  test(
    'failed recovery retains expiry and suppresses automatic requests',
    () async {
      final transport = _Transport(
        indexBodies: [_logout],
        loginBodies: [_logout],
      );
      final container = _container(transport);
      final controller = container.read(attendanceProvider.notifier);
      await controller.fetchLecture(isAutomatic: true);
      await controller.fetchLecture(isAutomatic: true);
      expect(container.read(attendanceProvider).sessionExpired, isTrue);
      expect(transport.indexRequests, 1);
      expect(transport.posts, isEmpty);
      expect(container.read(homeControllerProvider).isLoading, isFalse);
    },
  );

  test('automatic login uses saved credentials for the same account', () async {
    final transport = _Transport(
      indexBodies: [_logout, _empty, _lecture],
      loginBodies: [_logout, 'activated'],
    );
    final container = _container(transport, automaticLogin: true);
    await container.read(attendanceProvider.notifier).fetchLecture();
    expect(container.read(attendanceProvider).currentLecture?.name, 'Course');
    expect(
      transport.posts.where((path) => path.endsWith('LoginExec3.php')),
      hasLength(1),
    );
    expect(transport.savedCookies.map((cookie) => cookie.name), ['SSO']);
  });

  test(
    'logout during activation prevents further requests and stale state',
    () async {
      final transport = _Transport(indexBodies: [_logout]);
      transport.activationGate = Completer<String>();
      final container = _container(transport);
      final request = container
          .read(attendanceProvider.notifier)
          .fetchLecture();
      await transport.activationStarted.future;
      await container.read(homeControllerProvider.notifier).logout();
      transport.activationGate!.complete('activated');
      await request;
      expect(container.read(homeControllerProvider).isLoggedIn, isFalse);
      expect(container.read(attendanceProvider).hasCheckedLecture, isFalse);
      expect(transport.indexRequests, 1);
      expect(transport.posts, isEmpty);
    },
  );
}

ProviderContainer _container(
  _Transport transport, {
  bool automaticLogin = false,
}) {
  final container = ProviderContainer.test(
    overrides: [
      schoolTransportProvider.overrideWithValue(transport),
      homeControllerProvider.overrideWith(() => _Home(automaticLogin)),
    ],
  );
  container.read(homeControllerProvider);
  return container;
}

class _Home extends HomeController {
  _Home(this.automaticLogin);
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

class _Transport implements SchoolTransport {
  _Transport({
    List<String>? indexBodies,
    List<String>? loginBodies,
    this.failActivation = false,
  }) : indexBodies = indexBodies ?? [_empty],
       loginBodies = loginBodies ?? ['activated'];
  final List<String> indexBodies;
  final List<String> loginBodies;
  final bool failActivation;
  final posts = <String>[];
  final savedCookies = <Cookie>[];
  final lectureOptions = <SchoolRequestOptions>[];
  final activationStarted = Completer<void>();
  Completer<String>? activationGate;
  final loginExecStarted = Completer<void>();
  Completer<void>? loginExecGate;
  var indexRequests = 0;
  var loginRequests = 0;

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    Object body = 'ok';
    if (target.endsWith('index.jsp')) {
      indexRequests++;
      body = indexBodies.length > 1
          ? indexBodies.removeAt(0)
          : indexBodies.single;
      if (options.timeoutProfile == NetworkTimeoutProfile.lectureFetch) {
        lectureOptions.add(options);
      }
    } else if (target.endsWith('login.jsp')) {
      loginRequests++;
      if (!activationStarted.isCompleted) activationStarted.complete();
      if (failActivation) {
        throw DioException(
          requestOptions: RequestOptions(path: target),
          type: DioExceptionType.connectionError,
        );
      }
      body = activationGate != null
          ? await activationGate!.future
          : loginBodies.length > 1
          ? loginBodies.removeAt(0)
          : loginBodies.single;
    }
    return Response<T>(
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: target),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    posts.add(target);
    if (target.endsWith('LoginExec3.php')) {
      if (!loginExecStarted.isCompleted) loginExecStarted.complete();
      if (loginExecGate != null) await loginExecGate!.future;
    }
    final Object body = target.endsWith('LoginCheck_SSO.php')
        ? {'result_code': 'Y'}
        : "<script>SetCookie('SSO', 'test-cookie');</script>";
    return Response<T>(
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: target),
    );
  }

  @override
  Future<void> clearAuthSession() async {}
  @override
  Future<bool> hasAuthSession() async => true;
  @override
  Future<bool> hasCookie(Uri target, String name) async => true;
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async =>
      savedCookies.addAll(cookies);
}
