import 'dart:typed_data';

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
}

class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200});
  final int status;
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
        if (status >= 400) 'retry-after': ['20'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
