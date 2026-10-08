import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_log_interceptor.dart';

void main() {
  test('web cookie inventory is excluded from request logs', () async {
    final logs = <String>[];
    final dio = Dio()
      ..httpClientAdapter = _Adapter(200)
      ..interceptors.add(
        SchoolLogInterceptor(
          requestHeader: false,
          responseHeader: false,
          logPrint: (message) => logs.add(message.toString()),
        ),
      );
    addTearDown(() => dio.close(force: true));
    await dio.get<String>(
      'https://example.test/text',
      options: Options(
        responseType: ResponseType.plain,
        headers: {'X-Target-Cookie-Store': 'private-cookie-inventory'},
      ),
    );
    expect(logs.join('\n'), isNot(contains('private-cookie-inventory')));
  });
  for (final statusCode in [200, 500]) {
    test('binary HTTP $statusCode keeps bytes and omits body logs', () async {
      final logs = <String>[];
      final dio = Dio()
        ..httpClientAdapter = _Adapter(statusCode)
        ..interceptors.add(
          SchoolLogInterceptor(
            responseHeader: true,
            logPrint: (message) => logs.add(message.toString()),
          ),
        );
      addTearDown(() => dio.close(force: true));

      Response<dynamic> response;
      try {
        response = await dio.get<List<int>>(
          'https://example.test/seats',
          options: Options(responseType: ResponseType.bytes),
        );
        expect(statusCode, 200);
      } on DioException catch (error) {
        expect(statusCode, 500);
        response = error.response!;
      }

      expect(response.data, [60, 104, 116, 109, 108, 62]);
      expect(logs, contains('statusCode: $statusCode'));
      expect(logs.join('\n'), isNot(contains('Response Text:')));
      expect(logs.join('\n'), isNot(contains('[60, 104')));
    });
  }

  test('plain text responses retain readable body logs', () async {
    final logs = <String>[];
    final dio = Dio()
      ..httpClientAdapter = _Adapter(200)
      ..interceptors.add(
        SchoolLogInterceptor(
          responseHeader: false,
          logPrint: (message) => logs.add(message.toString()),
        ),
      );
    addTearDown(() => dio.close(force: true));

    final response = await dio.get<String>(
      'https://example.test/text',
      options: Options(responseType: ResponseType.plain),
    );

    expect(response.data, '<html>');
    expect(logs, contains('Response Text:'));
    expect(logs, contains('<html>'));
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.statusCode);

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      [60, 104, 116, 109, 108, 62],
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
