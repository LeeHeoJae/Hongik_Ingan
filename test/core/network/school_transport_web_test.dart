import 'dart:typed_data';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport_web.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_service.dart';

void main() {
  test('only automatic lecture requests disable proxy retries', () async {
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final service = AttendanceService(
      SchoolTransportWeb(dio, WebAuthCookieStore()),
    );

    await service.getActiveLecture(isAutomatic: true);
    final automatic = adapter.requests.single;
    expect(automatic.uri.path, '/api/proxy');
    final target = Uri.parse(automatic.uri.queryParameters['url']!);
    expect(target.scheme, 'https');
    expect(target.host, 'at.hongik.ac.kr');
    expect(target.path, '/index.jsp');
    expect(target.queryParameters, isEmpty);
    expect(automatic.headers['X-Target-Retry'], 'false');
    expect(
      automatic.headers['X-Target-Referer'],
      'https://at.hongik.ac.kr/login.jsp',
    );
    expect(automatic.responseType, ResponseType.plain);

    await service.getActiveLecture();
    expect(
      adapter.requests.last.headers.containsKey('X-Target-Retry'),
      isFalse,
    );
    expect(const SchoolRequestOptions().allowProxyRetry, isTrue);
  });

  for (final status in [429, 503]) {
    test('preserves Retry-After when Dio rejects HTTP $status', () async {
      final adapter = _Adapter(status: status);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final service = AttendanceService(
        SchoolTransportWeb(dio, WebAuthCookieStore()),
      );
      final result = await service.getActiveLecture(isAutomatic: true);
      expect(result.status, LectureFetchStatus.failure);
      expect(result.retryAfter, '20');
      expect(result.sessionExpired, isFalse);
    });
  }

  for (final method in ['GET', 'POST']) {
    test(
      'captures cookie invalidation on a rejected $method response',
      () async {
        final store = WebAuthCookieStore();
        final target = Uri.parse('https://at.hongik.ac.kr/');
        store.saveSetCookie(target, 'JSESSIONID=old-session; Path=/; Secure');
        final adapter = _Adapter(
          status: 401,
          cookieMetadata: base64Url.encode(
            utf8.encode(
              jsonEncode([
                {
                  'url': '${target}index.jsp',
                  'cookies': ['JSESSIONID=; Path=/; Max-Age=0; Secure'],
                },
              ]),
            ),
          ),
        );
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final transport = SchoolTransportWeb(dio, store);
        await expectLater(
          method == 'GET'
              ? transport.get<String>('${target}index.jsp')
              : transport.post<String>('${target}index.jsp'),
          throwsA(isA<DioException>()),
        );
        expect(await transport.hasCookie(target, 'JSESSIONID'), isFalse);
      },
    );
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200, this.cookieMetadata});
  final int status;
  final String? cookieMetadata;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '<table><tbody></tbody></table>',
      status,
      headers: {
        'content-type': ['text/html; charset=utf-8'],
        if (cookieMetadata != null) 'x-target-set-cookies': [cookieMetadata!],
        if (status >= 400) 'retry-after': ['20'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
