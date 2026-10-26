import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:hongik_ingan/core/network/school_log_interceptor.dart';
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
  Dio dio = _buildDio();
  logMsg('CookieJar 시작', level: LogLevel.info);
  return SchoolTransportNative(dio, persistentCookieJar);
}

Dio _buildDio() {
  final dio = Dio(_createBaseOptions());
  dio.interceptors.add(SchoolLogInterceptor());
  return dio;
}

BaseOptions _createBaseOptions() {
  return BaseOptions(
    headers: const {
      'Accept': '*/*',
      'Connection': 'keep-alive',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
    },
  );
}

final class SchoolTransportNative implements SchoolTransport {
  SchoolTransportNative(this._dio, this._cookieJar) {
    _dio.interceptors.insert(0, _SessionCookieManager(this));
  }

  final Dio _dio;
  final CookieJar _cookieJar;
  Future<void> _authRequests = Future.value();
  Future<void> _cookieWrites = Future.value();
  int _authGeneration = 0;
  static const _generationKey = 'schoolAuthGeneration';
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
    return _request<T>(
      target,
      (generation) => _dio.get<T>(
        target,
        queryParameters: queryParameters,
        options: _toDioOptions(options, generation),
      ),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    return _request<T>(
      target,
      (generation) => _dio.post<T>(
        target,
        data: data,
        queryParameters: queryParameters,
        options: _toDioOptions(options, generation),
      ),
    );
  }

  Future<Response<T>> _request<T>(
    String target,
    Future<Response<T>> Function(int generation) send,
  ) {
    final generation = _authGeneration;
    final host = Uri.parse(target).host;
    if (!_authCookieUris.any((uri) => uri.host == host)) {
      return send(generation);
    }
    // Session cookies may rotate; authenticated requests must keep their order.
    final request = _authRequests.then((_) async {
      await _cookieWrites;
      if (generation != _authGeneration) {
        throw DioException(
          requestOptions: RequestOptions(path: target),
          type: DioExceptionType.cancel,
        );
      }
      return send(generation);
    });
    _authRequests = request.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return request;
  }

  Future<void> _writeCookies(Future<void> Function() write) {
    final operation = _cookieWrites.then((_) => write());
    _cookieWrites = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) {
    final generation = _authGeneration;
    return _writeCookies(() async {
      if (generation != _authGeneration) return;
      for (final uri in _authCookieUris) {
        await _cookieJar.saveFromResponse(uri, cookies);
      }
    });
  }

  @override
  Future<bool> hasAuthSession() async {
    await _cookieWrites;
    for (final uri in _authCookieUris) {
      final cookies = await _cookieJar.loadForRequest(uri);
      if (cookies.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> hasCookie(Uri target, String name) async {
    await _cookieWrites;
    final cookies = await _cookieJar.loadForRequest(target);
    return cookies.any((cookie) => cookie.name == name);
  }

  @override
  Future<void> clearAuthSession() {
    _authGeneration++;
    return _writeCookies(_cookieJar.deleteAll);
  }

  Options _toDioOptions(SchoolRequestOptions options, int generation) {
    final timeoutProfile = options.timeoutProfile;
    final isSeatStatus = timeoutProfile == NetworkTimeoutProfile.seatStatus;
    final headers = {...options.headers};
    if (options.cacheMode == NetworkCacheMode.revalidate) {
      headers['Pragma'] = 'no-cache';
    }

    return Options(
      extra: {logStageKey: timeoutProfile.name, _generationKey: generation},
      headers: headers,
      contentType: options.contentType,
      responseType: options.responseType,
      followRedirects: options.followRedirects,
      validateStatus: options.validateStatus,
      connectTimeout: Duration(seconds: isSeatStatus ? 3 : 5),
      sendTimeout: Duration(seconds: isSeatStatus ? 3 : 5),
      receiveTimeout: _timeoutFor(timeoutProfile),
    );
  }

  /// 네이티브 요청의 서버 응답 대기 시간을 반환.
  ///
  /// 요청 실패의 영향에 따라 분류
  Duration _timeoutFor(NetworkTimeoutProfile profile) {
    return switch (profile) {
      NetworkTimeoutProfile.standard => const Duration(seconds: 8),
      NetworkTimeoutProfile.seatStatus => const Duration(seconds: 5),
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

final class _SessionCookieManager extends CookieManager {
  _SessionCookieManager(this._transport) : super(_transport._cookieJar);

  final SchoolTransportNative _transport;

  @override
  Future<void> saveCookies(Response response) {
    return _transport._writeCookies(() async {
      if (response.requestOptions.extra[SchoolTransportNative._generationKey] !=
          _transport._authGeneration) {
        return;
      }
      // Deletion waits for any save already running, including persistent I/O.
      await super.saveCookies(response);
    });
  }
}
