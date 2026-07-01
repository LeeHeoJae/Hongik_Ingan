import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';

import '../logging/logger.dart';

Future<SchoolTransport> createSchoolTransport() async {
  Dio dio = _buildDio();
  WebAuthCookieStore cookieStore = WebAuthCookieStore();

  logMsg('CookieJar 시작', level: LogLevel.info);
  return SchoolTransportWeb(dio, cookieStore);
}

Dio _buildDio() {
  final dio = Dio(_createBaseOptions());
  _addDebugInterceptors(dio);
  return dio;
}

BaseOptions _createBaseOptions() {
  return BaseOptions(
    // 프록시의 전체 처리 Timeout 이 9초이므로 그보다 긴 receiveTimeout을 10초로 설정
    connectTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
    headers: const {
      'Accept': '*/*',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
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

final class SchoolTransportWeb implements SchoolTransport {
  SchoolTransportWeb(this._dio, this._cookieStore);

  final Dio _dio;
  final WebAuthCookieStore _cookieStore;

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    final uri = Uri.parse(target);
    final targetUri = _mergeQuery(uri, queryParameters);
    final proxyUri = _proxyUri(targetUri);
    final headers = _buildHeaders(targetUri, options.headers);
    return _dio.getUri<T>(proxyUri, options: _toDioOptions(options, headers));
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    final uri = Uri.parse(target);
    final targetUri = _mergeQuery(uri, queryParameters);
    final proxyUri = _proxyUri(targetUri);
    final headers = _buildHeaders(targetUri, options.headers);
    return _dio.postUri<T>(
      proxyUri,
      data: data,
      options: _toDioOptions(options, headers),
    );
  }

  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {
    for (final cookie in cookies) {
      if (cookie.name.isEmpty || cookie.value.isEmpty) {
        continue;
      }
      _cookieStore.save(cookie);
    }
  }

  @override
  Future<bool> hasAuthSession() async {
    return _cookieStore.isNotEmpty;
  }

  @override
  Future<void> clearAuthSession() async {
    _cookieStore.clear();
  }

  Options _toDioOptions(SchoolRequestOptions options, headers) {
    return Options(
      headers: headers,
      responseType: options.responseType,
      followRedirects: options.followRedirects,
      validateStatus: options.validateStatus,
    );
  }

  Uri _mergeQuery(Uri target, Map<String, dynamic>? queryParameters) {
    return target.replace(
      queryParameters: {
        ...target.queryParameters,
        if (queryParameters != null) ...queryParameters,
      },
    );
  }

  Uri _proxyUri(Uri target) {
    return Uri(path: '/api/proxy', queryParameters: {'url': target.toString()});
  }

  Map<String, dynamic> _buildHeaders(
    Uri target,
    Map<String, dynamic> requestHeaders,
  ) {
    final headers = {...requestHeaders};

    _removeBrowserForbiddenHeaders(headers);

    final cookieHeader = _cookieStore.headerFor(target);
    if (cookieHeader != null) {
      headers['X-Target-Cookie'] = cookieHeader;
    }

    return headers;
  }

  /// 웹 요청에서 브라우저가 직접 설정할 수 없는 헤더를 제거.
  ///
  /// 보안 정책상 특정 헤더들을 임의로 설정하면 브라우저가 무시하거나 요청이 실패할 수 있어 제거한다.
  /// 이러한 헤더들을 프록시 서버에서 직접 설정한다.
  void _removeBrowserForbiddenHeaders(Map<String, dynamic> headers) {
    const forbiddenHeaders = {
      'connection',
      'content-length',
      'cookie',
      'host',
      'origin',
      'referer',
      'user-agent',
    };

    headers.removeWhere(
      (name, _) =>
          forbiddenHeaders.contains(name.toLowerCase()) ||
          name.toLowerCase().startsWith('proxy-') ||
          name.toLowerCase().startsWith('sec-'),
    );
  }
}

/// 웹에서의 쿠키 저장소.
///
/// 네이티브와 달리 웹은 프록시를 사용하기에 기존의 CookieJar을 사용할 수 없다.
/// 따라서 X-Target-Cookie를 사용하여 쿠키를 프록시에게 전송한다.
final class WebAuthCookieStore {
  final _authHosts = {
    'hongik.ac.kr',
    'my.hongik.ac.kr',
    'ap.hongik.ac.kr',
    'at.hongik.ac.kr',
  };

  final Map<String, String> _cookies = {};

  bool get isNotEmpty => _cookies.isNotEmpty;

  void save(Cookie cookie) {
    _cookies[cookie.name] = cookie.value;
  }

  /// target에 대해 저장된 Cookie를 문자열로 변환
  String? headerFor(Uri target) {
    if (!_authHosts.contains(target.host) || _cookies.isEmpty) {
      return null;
    }

    return _cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  void clear() {
    _cookies.clear();
  }
}
