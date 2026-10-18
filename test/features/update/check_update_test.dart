import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/update/check_update.dart';
import 'package:hongik_ingan/features/update/domain/update_check_result.dart';

void main() {
  for (final (current, latest, expected) in [
    ('1.4.0', '1.3.0', UpdateCheckStatus.upToDate),
    ('1.4.0', '1.4.0', UpdateCheckStatus.upToDate),
    ('1.4', '1.4.0', UpdateCheckStatus.upToDate),
    ('1.4.0', '1.4', UpdateCheckStatus.upToDate),
    ('1.9.0', '1.10.0', UpdateCheckStatus.available),
    ('1.4.0', '1.4.1', UpdateCheckStatus.available),
    ('1.4.0', '2.0.0', UpdateCheckStatus.available),
    ('1.4.0-beta.2', '1.4.0-beta.10', UpdateCheckStatus.available),
    ('1.4.0-beta.10', '1.4.0-beta.2', UpdateCheckStatus.upToDate),
    ('1.4.0-beta.2', '1.4.0', UpdateCheckStatus.available),
    ('1.4.0', '1.4.0-beta.2', UpdateCheckStatus.upToDate),
    ('1.4.0+1', '1.4.0+2', UpdateCheckStatus.upToDate),
    ('1.4.0', '1.4.0+2', UpdateCheckStatus.upToDate),
    (' 1.4.0 ', '1.4.1 ', UpdateCheckStatus.available),
    ('invalid', '1.4.0', UpdateCheckStatus.failed),
    ('1.4.0', 'invalid', UpdateCheckStatus.failed),
    ('1.4.0', '1.4.0+', UpdateCheckStatus.failed),
    ('1.4.0', '1.4.0.1', UpdateCheckStatus.failed),
  ]) {
    test('version precedence: $current -> $latest', () async {
      final client = Dio();
      addTearDown(client.close);
      client.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'latest_version': latest,
                  'update_url': 'https://example.invalid/release',
                },
              ),
            );
          },
        ),
      );
      final result = await checkUpdate(
        client: client,
        readCurrentVersion: () async => current,
      );
      expect(result.status, expected);
    });
  }

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
