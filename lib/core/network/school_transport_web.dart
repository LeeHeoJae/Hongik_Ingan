import 'dart:convert';
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
    headers: const {'Accept': '*/*'},
  );
}

void _addDebugInterceptors(Dio dio) {
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        responseHeader: false,
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
  }) async {
    final uri = Uri.parse(target);
    final targetUri = _mergeQuery(uri, queryParameters);
    final proxyUri = _proxyUri(targetUri);
    final headers = _buildHeaders(targetUri, options);
    final response = await _dio.getUri<T>(
      proxyUri,
      options: _toDioOptions(options, headers),
    );
    _captureResponseMetadata(response);
    return response;
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
    final proxyUri = _proxyUri(targetUri);
    final headers = _buildHeaders(targetUri, options);
    final response = await _dio.postUri<T>(
      proxyUri,
      data: data,
      options: _toDioOptions(options, headers),
    );
    _captureResponseMetadata(response);
    return response;
  }

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
    _cookieStore.clear();
  }

  Options _toDioOptions(SchoolRequestOptions options, headers) {
    return Options(
      headers: headers,
      contentType: options.contentType,
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
    headers['X-Target-Follow-Redirects'] = (options.followRedirects ?? true)
        .toString();

    final cookieHeader = _cookieStore.headerFor(target);
    if (cookieHeader != null) {
      headers['X-Target-Cookie'] = cookieHeader;
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

  final List<_StoredWebCookie> _cookies = [];

  bool get isNotEmpty {
    _removeExpired();
    return _cookies.isNotEmpty;
  }

  /// origin에 cookie를 저장.
  void save(Uri origin, Cookie cookie) {
    _saveParsedCookie(origin, cookie);
  }

  /// rawCookie를 Cookie 객체로 변환하여 origin에 저장.
  void saveSetCookie(Uri origin, String rawCookie) {
    try {
      _saveParsedCookie(origin, Cookie.fromSetCookieValue(rawCookie));
    } catch (error) {
      logMsg('웹 Set-Cookie를 해석하지 못했습니다: $error', level: LogLevel.warning);
    }
  }

  bool hasCookie(Uri target, String name) {
    _removeExpired();
    return _matchingCookies(target).any((cookie) => cookie.name == name);
  }

  /// target에 대해 저장된 Cookie를 문자열로 변환
  String? headerFor(Uri target) {
    _removeExpired();
    if (!_authHosts.contains(target.host) || _cookies.isEmpty) {
      return null;
    }

    final matchingCookies = _matchingCookies(target)
      ..sort((a, b) => b.path.length.compareTo(a.path.length));
    if (matchingCookies.isEmpty) {
      return null;
    }
    return matchingCookies
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  void clear() {
    _cookies.clear();
  }

  /// 파싱된 쿠키를 응답 URL 기준으로 검증하고 웹 쿠키 저장소에 저장.
  ///
  /// domain이 없으면 응답 호스트 전용 쿠키로 처리하고
  /// path가 없으면 응답 URL에서 기본 경로로 계산한다.
  /// domain이 일치하지 않으면 저장하지 않는다.
  void _saveParsedCookie(Uri origin, Cookie cookie) {
    if (cookie.name.isEmpty || !_authHosts.contains(origin.host)) {
      return;
    }

    final rawDomain = cookie.domain?.trim().toLowerCase();
    final hostOnly = rawDomain == null || rawDomain.isEmpty;
    final domain = hostOnly
        ? origin.host.toLowerCase()
        : rawDomain.replaceFirst(RegExp(r'^\.'), '');
    if (!_domainMatches(origin.host.toLowerCase(), domain)) {
      logMsg(
        '웹 쿠키의 도메인이 응답 호스트와 일치하지 않습니다: '
        '${cookie.name} ($domain)',
        level: LogLevel.warning,
      );
      return;
    }

    final path = cookie.path == null || !cookie.path!.startsWith('/')
        ? _defaultPath(origin.path)
        : cookie.path!;
    // 만료시간
    final expiresAt = cookie.maxAge != null
        ? DateTime.now().toUtc().add(Duration(seconds: cookie.maxAge!))
        : cookie.expires?.toUtc();
    final shouldDelete =
        cookie.value.isEmpty ||
        (cookie.maxAge != null && cookie.maxAge! <= 0) ||
        (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc()));

    // 기존 쿠키 제거
    _cookies.removeWhere(
      (stored) =>
          stored.name == cookie.name &&
          stored.domain == domain &&
          stored.path == path,
    );
    if (shouldDelete) {
      return;
    }
    // 새 쿠키 저장
    _cookies.add(
      _StoredWebCookie(
        name: cookie.name,
        value: cookie.value,
        domain: domain,
        path: path,
        hostOnly: hostOnly,
        secure: cookie.secure,
        expiresAt: expiresAt,
      ),
    );
  }

  List<_StoredWebCookie> _matchingCookies(Uri target) {
    if (!_authHosts.contains(target.host)) {
      return [];
    }
    final host = target.host.toLowerCase();
    final path = target.path.isEmpty ? '/' : target.path;
    return _cookies.where((cookie) {
      final domainMatches = cookie.hostOnly
          ? host == cookie.domain
          : _domainMatches(host, cookie.domain);
      return domainMatches &&
          _pathMatches(path, cookie.path) &&
          (!cookie.secure || target.scheme == 'https');
    }).toList();
  }

  void _removeExpired() {
    final now = DateTime.now().toUtc();
    _cookies.removeWhere(
      (cookie) => cookie.expiresAt != null && !cookie.expiresAt!.isAfter(now),
    );
  }

  /// domain와 host가 같은 도메인인지 체크.
  bool _domainMatches(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }

  bool _pathMatches(String requestPath, String cookiePath) {
    if (requestPath == cookiePath) {
      return true;
    }
    if (!requestPath.startsWith(cookiePath)) {
      return false;
    }
    return cookiePath.endsWith('/') ||
        (requestPath.length > cookiePath.length &&
            requestPath[cookiePath.length] == '/');
  }

  String _defaultPath(String requestPath) {
    if (!requestPath.startsWith('/') || requestPath == '/') {
      return '/';
    }
    final lastSlash = requestPath.lastIndexOf('/');
    return lastSlash <= 0 ? '/' : requestPath.substring(0, lastSlash);
  }
}

final class _StoredWebCookie {
  const _StoredWebCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.hostOnly,
    required this.secure,
    required this.expiresAt,
  });

  final String name;
  final String value;
  final String domain;
  final String path;
  final bool hostOnly;
  final bool secure;
  final DateTime? expiresAt;
}
