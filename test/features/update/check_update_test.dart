import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/update/check_update.dart';
import 'package:hongik_ingan/features/update/domain/update_check_result.dart';

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
      final result = await checkUpdate(
        client: client,
        readCurrentVersion: () async => '1.0',
      );
      expect(result.status, UpdateCheckStatus.available);
      final info = result.info!;
      expect(info.currentVersion, '1.0');
      expect(info.latestVersion, '2.0');
      expect(info.updateUrl, 'https://example.com');
      expect(info.notice, '');
    });
  }

  for (final data in [
    {'latest_version': 2},
    'invalid JSON',
    {'latest_version': '', 'update_url': 'https://example.com'},
    {'latest_version': '2.0', 'update_url': 'invalid'},
  ]) {
    test('invalid update response is a failed check: $data', () async {
      final client = Dio();
      addTearDown(client.close);
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(Response(requestOptions: options, data: data));
          },
        ),
      );
      final result = await checkUpdate(
        client: client,
        readCurrentVersion: () async => '1.0',
      );
      expect(result.status, UpdateCheckStatus.failed);
    });
  }

  test(
    'network failure is distinct from up to date and leaves the client open',
    () async {
      final adapter = _FailingAdapter();
      final client = Dio()..httpClientAdapter = adapter;
      addTearDown(client.close);
      final result = await checkUpdate(
        client: client,
        readCurrentVersion: () async => '1.0',
      );
      expect(result.status, UpdateCheckStatus.failed);
      expect(adapter.closed, isFalse);
    },
  );

  test('matching version is explicitly up to date', () async {
    final client = Dio();
    addTearDown(client.close);
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'latest_version': '1.0',
                'update_url': 'https://example.com',
              },
            ),
          );
        },
      ),
    );
    final result = await checkUpdate(
      client: client,
      readCurrentVersion: () async => '1.0',
    );
    expect(result.status, UpdateCheckStatus.upToDate);
    expect(result.info, isNull);
  });
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
