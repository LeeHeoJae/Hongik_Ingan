import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/home/data/auth_service.dart';
import 'package:hongik_ingan/features/home/domain/session_status.dart';

const _legacy = bool.fromEnvironment('SSO_LEGACY');

void main() {
  final checks = [
    ('normal page', '<table><tbody></tbody></table>', SessionStatus.valid),
    ('SSO error', 'SSO 시스템 연동 오류', SessionStatus.integrationError),
    ('login page', '통합 로그인', SessionStatus.expired),
    (
      'logout page',
      '장시간 사용이 없어 로그아웃 되었습니다.',
      _legacy ? SessionStatus.valid : SessionStatus.expired,
    ),
    ('unrecognized nonempty 200', '<p>Maintenance</p>', SessionStatus.valid),
    ('empty 200', '', SessionStatus.unknown),
  ];
  for (final check in checks) {
    test('legacy=$_legacy session classification: ${check.$1}', () async {
      final transport = _Transport(check.$2);
      expect(await AuthService(transport).checkSessionStatus(), check.$3);
      expect(transport.gets, check.$3 == SessionStatus.unknown ? 2 : 1);
      expect(transport.clears, 0);
    });
  }

  for (final stage in ['login', 'index']) {
    test('legacy=$_legacy empty activation response at $stage', () async {
      final transport = _Transport(
        stage == 'index' ? '' : '<table><tbody></tbody></table>',
        emptyLogin: stage == 'login',
      );
      final result = await AuthService(
        transport,
      ).login('student', 'test-password');
      expect(result.isSuccess, _legacy);
    });
  }
}

class _Transport implements SchoolTransport {
  _Transport(this.indexBody, {this.emptyLogin = false});
  final String indexBody;
  final bool emptyLogin;
  int gets = 0, clears = 0;
  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    gets++;
    final body = target.endsWith('index.jsp')
        ? indexBody
        : target.endsWith('login.jsp') && emptyLogin
        ? ''
        : 'ok';
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
    final Object body = target.endsWith('LoginCheck_SSO.php')
        ? {'result_code': 'Y'}
        : "<script>SetCookie('SSO', 'test-sso');</script>";
    return Response<T>(
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: target),
    );
  }

  @override
  Future<void> clearAuthSession() async {
    clears++;
  }

  @override
  Future<bool> hasAuthSession() async => true;
  @override
  Future<bool> hasCookie(Uri target, String name) async => true;
  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
