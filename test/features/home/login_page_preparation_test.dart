import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/home/data/auth_service.dart';
import 'package:hongik_ingan/features/home/domain/login_result.dart';

void main() {
  test('a completed preparation is used once', () async {
    final transport = _Transport();
    final auth = AuthService(transport);
    await auth.prepareLoginPage();
    await auth.prepareLoginPage();
    await auth.login('student', 'password', usePreparedLogin: true);
    expect(transport.paths, ['/my/login.do', '/login/LoginCheck_SSO.php']);

    await auth.login('student', 'password', usePreparedLogin: true);
    expect(transport.pageRequests, 2);
  });

  test('login shares the pending request and waits for it', () async {
    final transport = _Transport()..firstPageGate = Completer<void>();
    final auth = AuthService(transport);
    final preparation = auth.prepareLoginPage();
    final login = auth.login('student', 'password', usePreparedLogin: true);
    expect(transport.paths, ['/my/login.do']);
    transport.firstPageGate!.complete();
    await preparation;
    await login;
    expect(transport.paths, ['/my/login.do', '/login/LoginCheck_SSO.php']);
  });

  test('failed preparation is silent and the next login retries', () async {
    final transport = _Transport()..failFirstPage = true;
    final auth = AuthService(transport);
    await auth.prepareLoginPage();
    await auth.login('student', 'password', usePreparedLogin: true);
    expect(transport.pageRequests, 2);
    expect(transport.paths.last, '/login/LoginCheck_SSO.php');
  });

  test(
    'a failure while login waits is returned without a second request',
    () async {
      final transport = _Transport()..firstPageGate = Completer<void>();
      final auth = AuthService(transport);
      final preparation = auth.prepareLoginPage();
      final login = auth.login('student', 'password', usePreparedLogin: true);
      transport.firstPageGate!.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/my/login.do'),
          type: DioExceptionType.connectionError,
        ),
      );
      await preparation;
      expect((await login).failureKind, LoginFailureKind.connection);
      expect(transport.pageRequests, 1);
    },
  );

  test('old preparation and clock rollback require a fresh request', () async {
    var now = DateTime(2026);
    final transport = _Transport();
    final auth = AuthService(transport, now: () => now);
    await auth.prepareLoginPage();
    now = now.add(const Duration(minutes: 1));
    await auth.login('student', 'password', usePreparedLogin: true);
    expect(transport.pageRequests, 2);

    await auth.prepareLoginPage();
    now = now.subtract(const Duration(seconds: 1));
    await auth.login('student', 'password', usePreparedLogin: true);
    expect(transport.pageRequests, 4);
  });

  test('invalidated late completion cannot prepare a later login', () async {
    final transport = _Transport()..firstPageGate = Completer<void>();
    final auth = AuthService(transport);
    final oldPreparation = auth.prepareLoginPage();
    auth.invalidateLoginPagePreparation();
    await auth.login('student', 'password', usePreparedLogin: true);
    transport.firstPageGate!.complete();
    await oldPreparation;
    await auth.login('student', 'password', usePreparedLogin: true);
    expect(transport.pageRequests, 3);
  });

  test('default and security code logins do not reuse a preparation', () async {
    final transport = _Transport();
    final auth = AuthService(transport);
    await auth.prepareLoginPage();
    await auth.login('student', 'password');
    expect(transport.pageRequests, 2);

    await auth.prepareLoginPage();
    await auth.login('student', 'password', securityCode: '123456');
    expect(transport.pageRequests, 4);
  });
}

class _Transport implements SchoolTransport {
  final paths = <String>[];
  Completer<void>? firstPageGate;
  bool failFirstPage = false;
  int pageRequests = 0;

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    paths.add(Uri.parse(target).path);
    pageRequests++;
    if (pageRequests == 1) {
      await firstPageGate?.future;
      if (failFirstPage) {
        throw DioException(
          requestOptions: RequestOptions(path: target),
          type: DioExceptionType.connectionError,
        );
      }
    }
    return Response<T>(requestOptions: RequestOptions(path: target));
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    paths.add(Uri.parse(target).path);
    return Response<T>(
      requestOptions: RequestOptions(path: target),
      data: {'result_code': 'N'} as T,
    );
  }

  @override
  Future<void> clearAuthSession() async {}
  @override
  Future<bool> hasAuthSession() async => false;
  @override
  Future<bool> hasCookie(Uri target, String name) async => false;
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
