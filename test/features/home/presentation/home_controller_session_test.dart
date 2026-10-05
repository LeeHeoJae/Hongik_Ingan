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
        expect(recovering.isLoggedIn, isFalse);
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
          succeeds ? LoginStatus.required : LoginStatus.failed,
        );
        if (!succeeds) expect(result.statusMessage, '인증 실패');
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
  @override
  HomeState build() {
    super.build();
    return const HomeState(
      isLoggedIn: true,
      userId: 'student',
      rememberMe: true,
      autoLogin: true,
    );
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

class _RecoveryTransport implements SchoolTransport {
  final loginStarted = Completer<void>();
  final validation = Completer<Map<String, dynamic>>();
  var _indexRequests = 0;

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    final expired = target.endsWith('index.jsp') && _indexRequests++ == 0;
    return Response<T>(
      requestOptions: RequestOptions(path: target),
      statusCode: 200,
      data: (expired ? '통합 로그인' : 'ok') as T,
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
  Future<void> clearAuthSession() async {}
  @override
  Future<bool> hasAuthSession() async => true;
  @override
  Future<bool> hasCookie(Uri target, String name) async => true;
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
