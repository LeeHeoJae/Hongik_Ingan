import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/update/check_update.dart';

void main() {
  for (final asString in [true, false]) {
    test('typed update from ${asString ? 'text' : 'decoded JSON'}', () async {
      final client = Dio();
      addTearDown(client.close);
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final data = {
              'latest_version': '2.0',
              'update_url': 'https://example.com',
            };
            handler.resolve(
              Response(
                requestOptions: options,
                data: asString ? jsonEncode(data) : data,
              ),
            );
          },
        ),
      );
      final info = await checkUpdate(
        client: client,
        readCurrentVersion: () async => '1.0',
      );
      expect(info!.currentVersion, '1.0');
      expect(info.latestVersion, '2.0');
      expect(info.updateUrl, 'https://example.com');
      expect(info.notice, '');
    });
  }

  for (final data in [
    {'latest_version': '1.0', 'update_url': 'https://example.com'},
    {'latest_version': 2},
    'invalid JSON',
  ]) {
    test('matching or invalid update response returns null: $data', () async {
      final client = Dio();
      addTearDown(client.close);
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(Response(requestOptions: options, data: data));
          },
        ),
      );
      expect(
        await checkUpdate(
          client: client,
          readCurrentVersion: () async => '1.0',
        ),
        isNull,
      );
    });
  }

  test(
    'network failure returns null and leaves the injected client open',
    () async {
      final adapter = _FailingAdapter();
      final client = Dio()..httpClientAdapter = adapter;
      addTearDown(client.close);
      expect(
        await checkUpdate(
          client: client,
          readCurrentVersion: () async => '1.0',
        ),
        isNull,
      );
      expect(adapter.closed, isFalse);
    },
  );
}

class _FailingAdapter implements HttpClientAdapter {
  bool closed = false;
  @override
  void close({bool force = false}) => closed = true;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException(
    requestOptions: options,
    type: DioExceptionType.connectionTimeout,
  );
}
