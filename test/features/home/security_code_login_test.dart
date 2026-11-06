import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/home/data/auth_service.dart';
import 'package:hongik_ingan/features/home/domain/login_result.dart';
import 'package:hongik_ingan/features/home/domain/session_recovery_result.dart';

void main() {
  test('security code is requested before establishing a session', () async {
    final transport = _SecurityCodeTransport();
    final result = await AuthService(transport).login('student', 'password');

    expect(result.needsSecurityCode, isTrue);
    expect(transport.paths, ['/my/login.do', '/login/LoginCheck_SSO.php']);
  });

  test(
    'portal verification submits the code and activates attendance',
    () async {
      final transport = _SecurityCodeTransport();
      final result = await AuthService(
        transport,
      ).login('student', 'password', securityCode: '001234');

      expect(result.isSuccess, isTrue);
      expect(transport.submittedCode, '001234');
      expect(transport.paths, [
        '/my/login.do',
        '/login/LoginCheck_SSO.php',
        '/app/login/LoginCheck.jsp',
        '/app/login/LoginExec.jsp',
        '/sso/loginCheckAll.jsp',
        '/kr',
        '/kr/index.do',
        '/kr/index.do',
        '/login.jsp',
        '/index.jsp',
      ]);
    },
  );

  test('unexpected portal redirect does not authenticate the user', () async {
    final transport = _SecurityCodeTransport()..rejectCode = true;
    final result = await AuthService(
      transport,
    ).login('student', 'password', securityCode: '654321');

    expect(result.failureKind, LoginFailureKind.securityCode);
    expect(transport.paths, isNot(contains('/sso/loginCheckAll.jsp')));
    expect(transport.paths, isNot(contains('/login.jsp')));
  });

  test('handoff does not follow redirects to another host', () async {
    final transport = _SecurityCodeTransport()..maliciousHandoff = true;
    final result = await AuthService(
      transport,
    ).login('student', 'password', securityCode: '001234');

    expect(result.isFailure, isTrue);
    expect(transport.paths, isNot(contains('/outside')));
    expect(transport.paths, isNot(contains('/login.jsp')));
  });

  for (final code in ['', '12345', '1234567', '12345a', '123456\n']) {
    test(
      'invalid security code is rejected without a request: $code',
      () async {
        final transport = _SecurityCodeTransport();
        final result = await AuthService(
          transport,
        ).login('student', 'password', securityCode: code);
        expect(result.failureKind, LoginFailureKind.invalidInput);
        expect(transport.paths, isEmpty);
      },
    );
  }

  test(
    'session recovery reports a code challenge without submitting one',
    () async {
      final transport = _SecurityCodeTransport();
      final result = await AuthService(transport).recoverAttendanceSession(
        studentId: 'student',
        readPassword: () async => 'password',
        canContinue: () => true,
      );

      expect(result, SessionRecoveryResult.securityCodeRequired);
      expect(transport.submittedCode, isNull);
      expect(transport.paths, isNot(contains('/app/login/LoginExec.jsp')));
    },
  );
}

class _SecurityCodeTransport implements SchoolTransport {
  final paths = <String>[];
  bool rejectCode = false;
  bool maliciousHandoff = false;
  bool authenticated = false;
  String? submittedCode;

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    final path = Uri.parse(target).path;
    final host = Uri.parse(target).host;
    paths.add(path);
    String? location;
    if (path == '/sso/loginCheckAll.jsp') {
      location = maliciousHandoff ? 'https://example.com/outside' : '/kr';
    } else if (host == 'my.hongik.ac.kr' && path == '/kr') {
      location = '/kr/index.do';
    } else if (host == 'my.hongik.ac.kr' && path == '/kr/index.do') {
      location = 'https://www.hongik.ac.kr/kr/index.do';
    } else if (host == 'www.hongik.ac.kr') {
      authenticated = true;
    }
    final body = path == '/login.jsp' && !authenticated ? '통합 로그인' : 'ready';
    return Response<T>(
      requestOptions: RequestOptions(path: target),
      statusCode: location == null ? 200 : 302,
      headers: location == null
          ? null
          : Headers.fromMap({
              'location': [location],
            }),
      data: body as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    final path = Uri.parse(target).path;
    paths.add(path);
    if (path.startsWith('/app/login/')) {
      expect(options.headers['Origin'], 'https://my.hongik.ac.kr');
      expect(options.headers['Referer'], 'https://my.hongik.ac.kr/');
      expect(options.allowProxyRetry, isFalse);
    }
    Object body = {'result_code': 'Y', 'pin_use': '1'};
    if (path == '/app/login/LoginExec.jsp') {
      submittedCode = (data as Map)['SEC_CODE'] as String;
      body = rejectCode
          ? '<script>document.location.href="https://my.hongik.ac.kr/my/login.do";</script>'
          : '<script>document.location.href="https://my.hongik.ac.kr/sso/loginCheckAll.jsp?refer2=%2Fkr";</script>';
    }
    return Response<T>(
      requestOptions: RequestOptions(path: target),
      statusCode: 200,
      data: body as T,
    );
  }

  @override
  Future<void> clearAuthSession() async => authenticated = false;
  @override
  Future<bool> hasAuthSession() async => authenticated;
  @override
  Future<bool> hasCookie(Uri target, String name) async => authenticated;
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
