import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/logging/log_diagnostics.dart';
import 'package:hongik_ingan/core/network/school_log_interceptor.dart';

void main() {
  test('web cookie inventory is excluded from request logs', () async {
    final logs = <String>[];
    final dio = Dio()
      ..httpClientAdapter = _Adapter(200)
      ..interceptors.add(
        SchoolLogInterceptor(write: (message, level) => logs.add(message)),
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
          SchoolLogInterceptor(write: (message, level) => logs.add(message)),
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
      expect(logs.join('\n'), contains('status=$statusCode'));
      expect(logs.join('\n'), isNot(contains('Response Text:')));
      expect(logs.join('\n'), isNot(contains('[60, 104')));
    });
  }

  test('plain text bodies are buffered until a semantic failure', () async {
    final logs = <String>[];
    final buffer = DiagnosticLogBuffer(
      emit: (event) => logs.add(event.message),
    );
    final dio = Dio()
      ..httpClientAdapter = _Adapter(200)
      ..interceptors.add(SchoolLogInterceptor(write: buffer.add));
    addTearDown(() => dio.close(force: true));

    final response = await dio.get<String>(
      'https://example.test/text',
      options: Options(responseType: ResponseType.plain),
    );

    expect(response.data, '<html>');
    expect(logs, hasLength(1));
    expect(logs.single, contains('status=200'));
    expect(logs.single, isNot(contains('<html>')));
    buffer.add('parse failed', LogLevel.error);
    expect(logs.join('\n'), contains('<html>'));
    expect(logs.last, 'parse failed');
  });

  test(
    'timeout retains request id, stage, and failure type without payloads',
    () async {
      final logs = <String>[];
      final buffer = DiagnosticLogBuffer(
        emit: (event) => logs.add(event.message),
      );
      final dio = Dio()
        ..httpClientAdapter = _TimeoutAdapter()
        ..interceptors.add(SchoolLogInterceptor(write: buffer.add));
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.post<String>(
          'https://example.test/submit?authCode=private-query',
          data: {'PASSWD': 'private-password'},
          options: Options(extra: {logStageKey: 'attendanceSubmit'}),
        ),
        throwsA(isA<DioException>()),
      );
      final text = logs.join('\n');
      expect(text, contains('stage=attendanceSubmit'));
      expect(text, contains('error=receiveTimeout'));
      expect(text, contains('http start id='));
      expect(text, isNot(contains('private-query')));
      expect(text, isNot(contains('private-password')));
    },
  );

  test('failure clues beyond a long HTML header are preserved and bounded', () {
    final logs = <String>[];
    logResponseDiagnostics(
      Response<String>(
        requestOptions: RequestOptions(path: '/submit'),
        statusCode: 200,
        data:
            '${'x' * 10000}<script>alert("session expired");</script>${'y' * 10000}',
      ),
      write: (message, level) => logs.add(message),
    );
    expect(logs.single, contains('session expired'));
    expect(logs.single, contains('truncated'));
    expect(logs.single.length, lessThan(4500));
  });
}

class _TimeoutAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
    );
  }

  @override
  void close({bool force = false}) {}
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
