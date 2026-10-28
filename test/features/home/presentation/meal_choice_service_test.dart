import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_choice_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_key.dart';

void main() {
  const date = '2026-10-26';
  late Dio dio;
  late MealChoiceService service;
  late List<RequestOptions> requests;
  late DateTime now;
  var privateStatus = 200;
  var changed = false;
  Map<String, dynamic> poll(int version) => {
    'id': 'poll',
    'options': [
      {
        'option': 'A',
        'items': ['밥'],
      },
      {
        'option': 'B',
        'items': ['면'],
      },
    ],
    'aVotes': 12 + version,
    'bVotes': 8,
    'version': version,
  };
  setUp(() {
    now = DateTime(2026, 10, 26);
    privateStatus = 200;
    changed = false;
    requests = [];
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final mine = options.queryParameters['mine'] == '1';
          if (mine && privateStatus != 200) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: privateStatus,
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: options.method == 'PUT'
                  ? {...poll(1), 'choice': options.data['choice']}
                  : mine
                  ? {
                      ...poll(0),
                      'id': changed ? 'new-poll' : 'poll',
                      'choice': null,
                    }
                  : {'date': date, 'poll': poll(0)},
            ),
          );
        },
      ),
    );
    service = MealChoiceService(
      dio: dio,
      tokenFor: (id, {create = true}) async => 'token-$id',
      clock: () => now,
    );
  });
  tearDown(() => service.dispose());

  test(
    'public and personal requests keep the vote token out of URLs',
    () async {
      final polls = await Future.wait([
        service.fetch(date),
        service.fetch(date),
      ]);
      expect(requests.length, 2);
      expect(requests.first.headers['X-Vote-Token'], isNull);
      expect(requests.last.headers['X-Vote-Token'], 'token-poll');
      expect(requests.last.queryParameters['id'], 'poll');
      expect(requests.last.headers['X-Vote-Account'], isNull);
      expect(requests.last.headers['X-Target-Cookie-Store'], isNull);
      final saved = await service.setChoice(date, polls.first!, 'A');
      expect(saved.choice, 'A');
      expect(requests.last.data, {'date': date, 'id': 'poll', 'choice': 'A'});
      expect(requests.last.headers['X-Vote-Token'], 'token-poll');
      expect((await service.fetch(date))!.aVotes, 13);
      expect(requests.length, 3);
      now = now.add(const Duration(seconds: 16));
      final refreshed = (await service.fetch(date))!;
      expect(refreshed.aVotes, 13);
      expect(refreshed.choice, 'A');
      expect(requests.length, 5);
      expect(
        requests.every((r) => !r.uri.toString().contains('token-poll')),
        isTrue,
      );
    },
  );

  for (final status in [401, 503]) {
    test(
      'private error $status clears selection, preserves counts and retries',
      () async {
        final initial = (await service.fetch(date))!;
        await service.setChoice(date, initial, 'A');
        privateStatus = status;
        final failed = (await service.fetch(date, force: true))!;
        expect(failed.aVotes, 13);
        expect(failed.choice, isNull);
        expect(service.personalUnavailableFor(date), isTrue);
        privateStatus = 200;
        await service.fetch(date, force: true);
        expect(service.personalUnavailableFor(date), isFalse);
      },
    );
  }

  test(
    'different private poll disables action rather than selecting wrong menus',
    () async {
      changed = true;
      final result = await service.fetch(date);
      expect(result!.choice, isNull);
      expect(service.personalUnavailableFor(date), isTrue);
    },
  );

  test('personal snapshot replaces stale cached public totals', () async {
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.queryParameters['mine'] == '1') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 'poll',
                  'choice': 'B',
                  'aVotes': 1,
                  'bVotes': 1,
                  'version': 2,
                },
              ),
            );
          } else {
            handler.next(options);
          }
        },
      ),
    );
    final result = (await service.fetch(date))!;
    expect(result.choice, 'B');
    expect(result.aVotes, 1);
    expect(result.bVotes, 1);
    expect(result.version, 2);
  });

  test('personal errors stay associated with their cached date', () async {
    privateStatus = 503;
    await service.fetch(date);
    privateStatus = 200;
    await service.fetch('2026-10-27');
    await service.fetch(date);
    expect(service.personalUnavailableFor(date), isTrue);
    expect(service.personalUnavailableFor('2026-10-27'), isFalse);
  });

  test(
    'fresh fetch bypasses local cache and requests an uncached poll',
    () async {
      await service.fetch(date);
      await service.fetch(date, fresh: true);
      expect(requests.length, 4);
      expect(requests[2].queryParameters['fresh'], '1');
      expect(requests[3].queryParameters['mine'], '1');
    },
  );

  test('fresh fetch waits for an older in-flight request', () async {
    final started = Completer<void>();
    RequestInterceptorHandler? pending;
    RequestOptions? held;
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.queryParameters['mine'] == null && pending == null) {
            pending = handler;
            held = options;
            started.complete();
          } else {
            handler.next(options);
          }
        },
      ),
    );
    final older = service.fetch(date);
    await started.future;
    final fresh = service.fetch(date, fresh: true);
    pending!.resolve(
      Response(
        requestOptions: held!,
        statusCode: 200,
        data: {'date': date, 'poll': poll(0)},
      ),
    );
    await older;
    await fresh;
    expect(
      requests.where((r) => r.queryParameters['fresh'] == '1'),
      hasLength(1),
    );
  });

  test('late public response cannot overwrite a confirmed write', () async {
    final initial = (await service.fetch(date))!;
    final started = Completer<void>();
    RequestInterceptorHandler? pending;
    RequestOptions? held;
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'GET' &&
              options.queryParameters['mine'] == null) {
            pending = handler;
            held = options;
            started.complete();
          } else {
            handler.next(options);
          }
        },
      ),
    );
    final loading = service.fetch(date, force: true);
    await started.future;
    await service.setChoice(date, initial, 'A');
    pending!.resolve(
      Response(
        requestOptions: held!,
        statusCode: 200,
        data: {'date': date, 'poll': poll(0)},
      ),
    );
    final result = (await loading)!;
    expect(result.aVotes, 13);
    expect(result.choice, 'A');
  });

  test('first visit creates a key only when voting', () async {
    var created = false;
    service = MealChoiceService(
      dio: dio,
      clock: () => now,
      tokenFor: (id, {create = true}) async {
        if (create) created = true;
        return created ? 'token-$id' : null;
      },
    );
    final result = (await service.fetch(date))!;
    expect(requests.length, 1);
    expect(created, isFalse);
    expect((await service.setChoice(date, result, 'A')).choice, 'A');
    expect(created, isTrue);
    expect(requests.length, 2);
  });

  test(
    'storage read failure preserves totals and does not send a personal request',
    () async {
      service = MealChoiceService(
        dio: dio,
        clock: () => now,
        tokenFor: (id, {create = true}) async =>
            throw const MealVoteStorageException(),
      );
      final result = await service.fetch(date);
      expect(result!.aVotes, 12);
      expect(service.personalUnavailableFor(date), isTrue);
      expect(service.storageUnavailableFor(date), isTrue);
      expect(requests.length, 1);
    },
  );
}
