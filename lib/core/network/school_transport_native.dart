import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:path_provider/path_provider.dart';

import '../logging/logger.dart';

Future<SchoolTransport> createSchoolTransport() async {
  final directory = await getApplicationSupportDirectory();
  final persistentCookieJar = PersistCookieJar(
    ignoreExpires: false,
    storage: FileStorage('${directory.path}/.cookies'),
  );
  Dio dio = _buildDio(persistentCookieJar);
  logMsg('CookieJar 시작', level: LogLevel.info);
  return SchoolTransportNative(dio, persistentCookieJar);
}

Dio _buildDio(CookieJar jar) {
  final dio = Dio(_createBaseOptions());
  dio.interceptors.add(CookieManager(jar));
  _addDebugInterceptors(dio);
  return dio;
}

BaseOptions _createBaseOptions() {
  return BaseOptions(
    headers: const {
      'Accept': '*/*',
      'Connection': 'keep-alive',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'Origin': 'https://my.hongik.ac.kr',
      'Referer': 'https://my.hongik.ac.kr/',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
    },
  );
}

void _addDebugInterceptors(Dio dio) {
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        responseHeader: true,
        logPrint: (obj) => logMsg(obj.toString()),
      ),
    );
  }
}

final class SchoolTransportNative implements SchoolTransport {
  SchoolTransportNative(this._dio, this._cookieJar);

  final Dio _dio;
  final CookieJar _cookieJar;
  static final List<Uri> _authCookieUris = [
    Uri.parse('https://hongik.ac.kr/'),
    Uri.parse('https://my.hongik.ac.kr/'),
    Uri.parse('https://ap.hongik.ac.kr/'),
    Uri.parse('https://at.hongik.ac.kr/'),
  ];

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    return _dio.get<T>(
      target,
      queryParameters: queryParameters,
      options: _toDioOptions(options),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    return _dio.post(
      target,
      data: data,
      queryParameters: queryParameters,
      options: _toDioOptions(options),
    );
  }

  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {
    await Future.wait([
      _cookieJar.saveFromResponse(Uri.parse('https://hongik.ac.kr'), cookies),
      _cookieJar.saveFromResponse(
        Uri.parse('https://my.hongik.ac.kr'),
        cookies,
      ),
      _cookieJar.saveFromResponse(
        Uri.parse('https://ap.hongik.ac.kr'),
        cookies,
      ),
      _cookieJar.saveFromResponse(
        Uri.parse('https://at.hongik.ac.kr'),
        cookies,
      ),
    ]);
  }

  @override
  Future<bool> hasAuthSession() async {
    for (final uri in _authCookieUris) {
      final cookies = await _cookieJar.loadForRequest(uri);
      if (cookies.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> clearAuthSession() async {
    await _cookieJar.deleteAll();
  }

  Options _toDioOptions(SchoolRequestOptions options) {
    final timeouts = _timeoutFor(options.timeoutProfile);

    return Options(
      headers: options.headers,
      responseType: options.responseType,
      followRedirects: options.followRedirects,
      validateStatus: options.validateStatus,
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: timeouts,
    );
  }

  /// 네이티브 요청의 서버 응답 대기 시간을 반환.
  ///
  /// 요청 실패의 영향에 따라 분류
  Duration _timeoutFor(NetworkTimeoutProfile profile) {
    return switch (profile) {
      NetworkTimeoutProfile.standard => const Duration(seconds: 8),
      // UI와 연결되어 있어 매우 짧은 Timeout
      NetworkTimeoutProfile.sessionCheck => const Duration(seconds: 4),
      NetworkTimeoutProfile.loginPage => const Duration(seconds: 7),
      NetworkTimeoutProfile.loginPost => const Duration(seconds: 9),
      // redirect 가능성이 있어 긴 Timeout
      NetworkTimeoutProfile.attendanceSession => const Duration(seconds: 8),
      // 사용자가 재시도할 수 있어 짧은 Timeout
      NetworkTimeoutProfile.lectureFetch => const Duration(seconds: 7),
      // 출석을 완료했지만 응답이 늦게 오는 경우가 있어 긴 Timeout
      NetworkTimeoutProfile.attendanceSubmit => const Duration(seconds: 10),
    };
  }
}
