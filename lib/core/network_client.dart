import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

import 'logger.dart';
import 'web_proxy.dart';

class NetworkClient {
  static final NetworkClient instance = NetworkClient._internal();

  factory NetworkClient() => instance;

  late Dio dio;
  late CookieJar cookieJar;
  final Map<String, String> _webTargetCookies = {};

  NetworkClient._internal() {
    cookieJar = CookieJar();
    dio = Dio(
      BaseOptions(
        connectTimeout: kIsWeb ? _webConnectTimeout : _nativeConnectTimeout,
        sendTimeout: kIsWeb ? _webSendTimeout : _nativeSendTimeout,
        receiveTimeout: kIsWeb ? _webReceiveTimeout : _nativeReceiveTimeout,
        headers: kIsWeb ? _webHeaders : _nativeHeaders,
      ),
    );
    if (kIsWeb) {
      dio.interceptors.add(_WebProxyCookieInterceptor(cookieJar));
    } else {
      dio.interceptors.add(CookieManager(cookieJar));
    }
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

  void setWebTargetCookies(Iterable<Cookie> cookies) {
    if (!kIsWeb) {
      return;
    }

    var addedCount = 0;
    for (final cookie in cookies) {
      if (cookie.name.isEmpty || cookie.value.isEmpty) {
        continue;
      }
      _webTargetCookies[cookie.name] = cookie.value;
      addedCount++;
    }

    logMsg(
      'Web target cookies updated: added=$addedCount total=${_webTargetCookies.length}',
      level: LogLevel.info,
    );
  }

  String webTargetCookieHeader(Iterable<Cookie> jarCookies) {
    final mergedCookies = <String, String>{};
    for (final cookie in jarCookies) {
      if (cookie.name.isEmpty || cookie.value.isEmpty) {
        continue;
      }
      mergedCookies[cookie.name] = cookie.value;
    }
    mergedCookies.addAll(_webTargetCookies);
    return mergedCookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }
}

enum NetworkTimeoutProfile {
  sessionCheck,
  loginPage,
  loginPost,
  attendanceSession,
  lectureFetch,
  attendanceSubmit,
}

class _NativeTimeouts {
  const _NativeTimeouts({
    required this.connectTimeout,
    required this.sendTimeout,
    required this.receiveTimeout,
  });

  final Duration connectTimeout;
  final Duration sendTimeout;
  final Duration receiveTimeout;
}

Options schoolRequestOptions({
  required NetworkTimeoutProfile timeoutProfile,
  Map<String, dynamic>? headers,
  ResponseType? responseType,
  String? contentType,
  bool? followRedirects,
  ValidateStatus? validateStatus,
}) {
  final timeouts = _nativeTimeoutFor(timeoutProfile);
  return Options(
    headers: headers,
    responseType: responseType,
    contentType: contentType,
    followRedirects: followRedirects,
    validateStatus: validateStatus,
    connectTimeout: kIsWeb ? null : timeouts.connectTimeout,
    sendTimeout: kIsWeb ? null : timeouts.sendTimeout,
    receiveTimeout: kIsWeb ? null : timeouts.receiveTimeout,
  );
}

_NativeTimeouts _nativeTimeoutFor(NetworkTimeoutProfile profile) {
  switch (profile) {
    case NetworkTimeoutProfile.sessionCheck:
      return const _NativeTimeouts(
        connectTimeout: Duration(seconds: 3),
        sendTimeout: Duration(seconds: 3),
        receiveTimeout: Duration(seconds: 4),
      );
    case NetworkTimeoutProfile.loginPage:
      return const _NativeTimeouts(
        connectTimeout: Duration(seconds: 4),
        sendTimeout: Duration(seconds: 4),
        receiveTimeout: Duration(seconds: 7),
      );
    case NetworkTimeoutProfile.loginPost:
      return const _NativeTimeouts(
        connectTimeout: Duration(seconds: 5),
        sendTimeout: Duration(seconds: 5),
        receiveTimeout: Duration(seconds: 9),
      );
    case NetworkTimeoutProfile.attendanceSession:
      return const _NativeTimeouts(
        connectTimeout: Duration(seconds: 4),
        sendTimeout: Duration(seconds: 4),
        receiveTimeout: Duration(seconds: 8),
      );
    case NetworkTimeoutProfile.lectureFetch:
      return const _NativeTimeouts(
        connectTimeout: Duration(seconds: 4),
        sendTimeout: Duration(seconds: 4),
        receiveTimeout: Duration(seconds: 7),
      );
    case NetworkTimeoutProfile.attendanceSubmit:
      return const _NativeTimeouts(
        connectTimeout: Duration(seconds: 5),
        sendTimeout: Duration(seconds: 5),
        receiveTimeout: Duration(seconds: 10),
      );
  }
}

const _webConnectTimeout = Duration(seconds: 4);
const _webSendTimeout = Duration(seconds: 4);
const _webReceiveTimeout = Duration(milliseconds: 9500);
const _nativeConnectTimeout = Duration(seconds: 5);
const _nativeSendTimeout = Duration(seconds: 5);
const _nativeReceiveTimeout = Duration(milliseconds: 8500);

const Map<String, String> _webHeaders = {
  'Accept': '*/*',
  'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
};

const Map<String, String> _nativeHeaders = {
  'Accept': '*/*',
  'Connection': 'keep-alive',
  'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
  'Origin': 'https://my.hongik.ac.kr',
  'Referer': 'https://my.hongik.ac.kr/',
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
};

class _WebProxyCookieInterceptor extends Interceptor {
  _WebProxyCookieInterceptor(this.cookieJar);

  final CookieJar cookieJar;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final originalUri = options.uri;
    if (originalUri.scheme == 'http' || originalUri.scheme == 'https') {
      _removeBrowserForbiddenHeaders(options.headers);
      final cookies = await cookieJar.loadForRequest(originalUri);
      final cookieHeader = NetworkClient().webTargetCookieHeader(cookies);
      if (cookieHeader.isNotEmpty) {
        options.headers['X-Target-Cookie'] = cookieHeader;
      }
      final proxiedPath = webProxyUrl(originalUri.toString());
      logMsg(
        'Web proxy request: ${options.method} ${_safeUri(originalUri)} -> $proxiedPath '
        '(jarCookies: ${cookies.length}, headerCookie: ${cookieHeader.isNotEmpty})',
        level: LogLevel.info,
      );
      options.baseUrl = '';
      options.path = proxiedPath;
      options.queryParameters = {};
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logMsg(
      'Web proxy error: ${err.requestOptions.method} ${err.requestOptions.uri} '
      'type=${err.type} message=${err.message} status=${err.response?.statusCode}',
      level: LogLevel.error,
    );
    handler.next(err);
  }

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

  String _safeUri(Uri uri) {
    final redactedQuery = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      final key = entry.key.toLowerCase();
      redactedQuery[entry.key] =
          key.contains('pass') ||
              key.contains('pwd') ||
              key.contains('token') ||
              key.contains('key')
          ? '***'
          : entry.value;
    }
    return uri.replace(queryParameters: redactedQuery).toString();
  }
}
