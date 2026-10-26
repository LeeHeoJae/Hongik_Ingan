import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';

/// 학교 서비스의 HTTP 요청과 인증 세션 관리를 함께 제공하는 전송 계층.
abstract interface class SchoolTransport
    implements SchoolHttpTransport, SchoolSessionStore {}

/// 학교 서비스의 HTTP 요청.
abstract interface class SchoolHttpTransport {
  /// HTTP GET 메시지.
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  });

  /// HTTP POST 메시지.
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  });
}

/// 인증 쿠키와 세션 상태를 관리.
abstract interface class SchoolSessionStore {
  /// cookies 저장.
  Future<void> saveAuthCookies(List<Cookie> cookies);

  /// 세션이 유효한지 확인.
  Future<bool> hasAuthSession();

  /// target 요청에 사용할 name 쿠키가 저장되어 있는지 확인.
  Future<bool> hasCookie(Uri target, String name);

  /// 세션 초기화.
  Future<void> clearAuthSession();
}
