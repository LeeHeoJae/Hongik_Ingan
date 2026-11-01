import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/network/school_log_interceptor.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';

import '../logging/logger.dart';
import 'web_auth_cookie_store.dart';

export 'web_auth_cookie_store.dart';

Future<SchoolTransport> createSchoolTransport() async {
  Dio dio = _buildDio();
  WebAuthCookieStore cookieStore = WebAuthCookieStore();

  logMsg('CookieJar 시작', level: LogLevel.info);
  return SchoolTransportWeb(dio, cookieStore);
}

Dio _buildDio() {
  final dio = Dio(_createBaseOptions());
  return dio;
}

BaseOptions _createBaseOptions() {
  return BaseOptions(
    // 프록시의 전체 처리 Timeout이 9초이므로 그보다 긴 receiveTimeout을 10초로 설정
    connectTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
    headers: const {'Accept': '*/*'},
  );
}

final class SchoolTransportWeb implements SchoolTransport {
  SchoolTransportWeb(this._dio, this._cookieStore);

  final Dio _dio;
  final WebAuthCookieStore _cookieStore;
  Future<void> _authRequests = Future.value();
  int _authGeneration = 0;

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    final uri = Uri.parse(target);
    final targetUri = _mergeQuery(uri, queryParameters);
    final proxyUri = _proxyUri(targetUri, options);
    return _request<T>(
      targetUri,
      options,
      'GET',
      () => _dio.getUri<T>(
        proxyUri,
        options: _toDioOptions(options, _buildHeaders(targetUri, options)),
      ),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    final uri = Uri.parse(target);
    final targetUri = _mergeQuery(uri, queryParameters);
    final proxyUri = _proxyUri(targetUri, options);
    return _request<T>(
      targetUri,
      options,
      'POST',
      () => _dio.postUri<T>(
        proxyUri,
        data: data,
        options: _toDioOptions(options, _buildHeaders(targetUri, options)),
      ),
    );
  }

  Future<Response<T>> _request<T>(
    Uri target,
    SchoolRequestOptions options,
    String method,
    Future<Response<T>> Function() send,
  ) {
    if (!_cookieStore.isAuthHost(target)) {
      return _send(target, options, method, send, _authGeneration);
    }
    final generation = _authGeneration;
    // Authentication responses can rotate cookies. Preserve their request order.
    final request = _authRequests.then((_) {
      if (generation != _authGeneration) {
        throw DioException(
          requestOptions: RequestOptions(path: target.toString()),
          type: DioExceptionType.cancel,
        );
      }
      return _send(target, options, method, send, generation);
    });
    _authRequests = request.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return request;
  }

  Future<Response<T>> _send<T>(
    Uri target,
    SchoolRequestOptions options,
    String method,
    Future<Response<T>> Function() send,
    int generation,
  ) async {
    final requestLog = SchoolRequestLog(
      target,
      method,
      stage: options.timeoutProfile.name,
    );
    final hadCookies = _cookieStore.headerFor(target) != null;
    try {
      final response = await send();
      if (generation == _authGeneration) _captureResponseMetadata(response);
      requestLog.finish(
        response,
        context: _requestLogContext(hadCookies, response),
      );
      return response;
    } on DioException catch (error) {
      error.requestOptions.extra[logRequestIdKey] = requestLog.id;
      final response = error.response;
      if (response != null && generation == _authGeneration) {
        _captureResponseMetadata(response);
      }
      requestLog.finish(
        response,
        errorType: error.type,
        context: _requestLogContext(hadCookies, response),
      );
      rethrow;
    }
  }

  Map<String, Object?> _requestLogContext(
    bool hadCookies,
    Response<dynamic>? response,
  ) => {
    'sentAuthCookies': hadCookies,
    'receivedCookieMetadata':
        response?.headers.value('x-target-set-cookies') != null,
    'hasAttendanceSession': _cookieStore.hasCookie(
      Uri.parse('https://at.hongik.ac.kr/'),
      'JSESSIONID',
    ),
  };

  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {
    for (final cookie in cookies) {
      if (cookie.name.isEmpty || cookie.value.isEmpty) {
        continue;
      }
      _cookieStore.save(Uri.parse('https://hongik.ac.kr/'), cookie);
    }
  }

  @override
  Future<bool> hasAuthSession() async {
    return _cookieStore.isNotEmpty;
  }

  @override
  Future<bool> hasCookie(Uri target, String name) async {
    return _cookieStore.hasCookie(target, name);
  }

  @override
  Future<void> clearAuthSession() async {
    _authGeneration++;
    _cookieStore.clear();
  }

  Options _toDioOptions(SchoolRequestOptions options, headers) {
    final isSeatStatus =
        options.timeoutProfile == NetworkTimeoutProfile.seatStatus;

    return Options(
      headers: headers,
      contentType: options.contentType,
      responseType: options.responseType,
      followRedirects: options.followRedirects,
      validateStatus: options.validateStatus,
      connectTimeout: isSeatStatus ? const Duration(seconds: 3) : null,
      sendTimeout: isSeatStatus ? const Duration(seconds: 3) : null,
      receiveTimeout: isSeatStatus ? const Duration(seconds: 5) : null,
    );
  }

  Uri _mergeQuery(Uri target, Map<String, dynamic>? queryParameters) {
    return target.replace(
      queryParameters: {...target.queryParameters, ...?queryParameters},
    );
  }

  Uri _proxyUri(Uri target, SchoolRequestOptions options) {
    return Uri(
      path: '/api/proxy',
      queryParameters: {
        'url': target.toString(),
        if (options.cacheDay != null) 'cache-day': options.cacheDay!,
        if (options.cacheMode == NetworkCacheMode.revalidate)
          'cache-bust': DateTime.now().microsecondsSinceEpoch.toString(),
      },
    );
  }

  Map<String, dynamic> _buildHeaders(Uri target, SchoolRequestOptions options) {
    final headers = {...options.headers};
    final targetOrigin = _headerValue(headers, 'origin');
    final targetReferer = _headerValue(headers, 'referer');

    _removeBrowserForbiddenHeaders(headers);

    if (targetOrigin != null) {
      headers['X-Target-Origin'] = targetOrigin;
    }
    if (targetReferer != null) {
      headers['X-Target-Referer'] = targetReferer;
    }
    if (options.cacheMode == NetworkCacheMode.revalidate) {
      headers['Pragma'] = 'no-cache';
    }
    headers['X-Target-Follow-Redirects'] = (options.followRedirects ?? true)
        .toString();
    if (!options.allowProxyRetry) {
      headers['X-Target-Retry'] = 'false';
    }

    if (_cookieStore.isAuthHost(target)) {
      headers['X-Target-Cookie-Store'] = _cookieStore.encodedForProxy();
    }

    return headers;
  }

  String? _headerValue(Map<String, dynamic> headers, String targetName) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == targetName) {
        return entry.value?.toString();
      }
    }
    return null;
  }

  /// 프록시 응답에서 원본 서버의 쿠키, 리다이렉트 정보를 복원, 저장.
  void _captureResponseMetadata(Response<dynamic> response) {
    final encodedCookies = response.headers.value('x-target-set-cookies');
    if (encodedCookies != null && encodedCookies.isNotEmpty) {
      try {
        final decoded = utf8.decode(
          base64Url.decode(base64Url.normalize(encodedCookies)),
        );
        final records = jsonDecode(decoded);
        if (records is List) {
          for (final record in records) {
            if (record is! Map) {
              continue;
            }
            final rawUrl = record['url'];
            final rawCookies = record['cookies'];
            if (rawUrl is! String || rawCookies is! List) {
              continue;
            }
            final origin = Uri.tryParse(rawUrl);
            if (origin == null || !origin.hasAuthority) {
              continue;
            }
            for (final rawCookie in rawCookies.whereType<String>()) {
              _cookieStore.saveSetCookie(origin, rawCookie);
            }
          }
        }
      } catch (error) {
        logMsg('웹 응답 쿠키를 해석하지 못했습니다: $error', level: LogLevel.warning);
      }
    }

    // 리다이렉트 정보
    final targetLocation = response.headers.value('x-target-location');
    if (targetLocation != null && targetLocation.isNotEmpty) {
      response.headers.set('location', targetLocation);
    }
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
