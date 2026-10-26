import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const date = '2026-10-15';
  const id = 'test-menu';
  late Dio dio;
  late MealVoteService service;
  late List<RequestOptions> requests;
  late DateTime now;
  Map<String, dynamic> total(int version) => {
    'id': id,
    'likes': version,
    'dislikes': 0,
    'version': version,
  };

  setUp(() {
    requests = [];
    now = DateTime(2026, 10, 15);
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final data = switch (options.path) {
            '/api/meals' => {
              'meals': [
                {
                  'id': id,
                  'items': ['밥', '국'],
                },
              ],
            },
            '/api/vote-totals' => {
              'meals': [total(0)],
            },
            '/api/my-votes' => {'votes': <dynamic>[]},
            '/api/vote' => {...total(1), 'choice': options.data['choice']},
            _ => throw StateError('Unexpected request'),
          };
          handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200),
          );
        },
      ),
    );
    service = MealVoteService(dio: dio, clock: () => now, account: 'A123456');
  });
  tearDown(() => service.dispose());

  test('private calls carry only the account, never in the URL', () async {
    final meal = (await service.fetch(date)).single;
    await service.setVote(date, meal, 1);
    await service.setVote(date, meal, 1);
    expect(
      requests.every((request) => request.headers['X-Vote-Session'] == null),
      isTrue,
    );
    expect(
      requests
          .singleWhere((request) => request.path == '/api/my-votes')
          .headers['X-Vote-Account'],
      'A123456',
    );
    final writes = requests.where((request) => request.method == 'PUT');
    expect(writes.map((request) => request.headers['X-Vote-Account']), [
      'A123456',
      'A123456',
    ]);
    expect(
      requests.every(
        (request) =>
            !request.uri.toString().contains('test-attendance-session') &&
            !request.uri.toString().contains('A123456'),
      ),
      isTrue,
    );
    expect(
      requests
          .where(
            (request) =>
                ['/api/meals', '/api/vote-totals'].contains(request.path),
          )
          .every(
            (request) =>
                request.headers['X-Vote-Session'] == null &&
                request.headers['X-Vote-Account'] == null,
          ),
      isTrue,
    );
  });

  test(
    'date cache coalesces requests, expires after 15 seconds and preserves a newer vote',
    () async {
      final both = await Future.wait([
        service.fetch(date),
        service.fetch(date),
      ]);
      expect(requests.length, 3);
      await service.setVote(date, both.first.single, 1);
      requests.clear();
      expect((await service.fetch(date)).single.likes, 1);
      expect(requests, isEmpty);
      now = now.add(const Duration(seconds: 16));
      final refreshed = (await service.fetch(date)).single;
      expect(refreshed.likes, 1);
      // Private selection is fresh even while public totals are cached.
      expect(refreshed.choice, 0);
      expect(requests.map((request) => request.path), [
        '/api/meals',
        '/api/vote-totals',
        '/api/my-votes',
      ]);
    },
  );

  test('a query started before saving cannot undo the saved result', () async {
    final meal = (await service.fetch(date)).single;
    final started = Completer<void>();
    RequestInterceptorHandler? pending;
    RequestOptions? held;
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/vote-totals') {
            pending = handler;
            held = options;
            started.complete();
            return;
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: options.path == '/api/meals'
                  ? {
                      'meals': [
                        {
                          'id': id,
                          'items': ['밥', '국'],
                        },
                      ],
                    }
                  : options.path == '/api/my-votes'
                  ? {'votes': <dynamic>[]}
                  : {...total(1), 'choice': 1},
            ),
          );
        },
      ),
    );
    final loading = service.fetch(date, force: true);
    await started.future;
    await service.setVote(date, meal, 1);
    pending!.resolve(
      Response(
        requestOptions: held!,
        statusCode: 200,
        data: {
          'meals': [total(0)],
        },
      ),
    );
    final result = (await loading).single;
    expect(result.likes, 1);
    expect(result.choice, 1);
  });

  test(
    'anonymous viewers only read public endpoints and cannot submit',
    () async {
      service = MealVoteService(dio: dio, clock: () => now);
      final meal = (await service.fetch(date)).single;
      expect(requests.map((request) => request.path), [
        '/api/meals',
        '/api/vote-totals',
      ]);
      await expectLater(
        service.setVote(date, meal, 1),
        throwsA(isA<MealVoteAuthenticationException>()),
      );
      expect(requests.length, 2);
    },
  );

  test(
    'a logged-in account can read and vote without a school session',
    () async {
      final meal = (await service.fetch(date)).single;
      expect(service.authenticationFailed, isFalse);
      expect(requests.length, 3);
      final saved = await service.setVote(date, meal, 1);
      expect(saved.choice, 1);
      expect(requests.last.headers['X-Vote-Account'], 'A123456');
      expect(requests.last.headers['X-Vote-Session'], isNull);
    },
  );

  for (final status in [401, 503, null]) {
    test(
      'private failure $status preserves totals and recovers on retry',
      () async {
        final meal = (await service.fetch(date)).single;
        await service.setVote(date, meal, 1);
        var failing = true;
        dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (failing && options.path == '/api/my-votes') {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: status == null
                        ? DioExceptionType.connectionTimeout
                        : DioExceptionType.badResponse,
                    response: status == null
                        ? null
                        : Response(requestOptions: options, statusCode: status),
                  ),
                );
              } else {
                handler.next(options);
              }
            },
          ),
        );
        final result = (await service.fetch(date, force: true)).single;
        expect(result.likes, 1);
        expect(result.choice, 0);
        expect(service.authenticationFailed, status == 401);
        expect(service.personalVotesUnavailable, status != 401);
        failing = false;
        await service.fetch(date, force: true);
        expect(service.authenticationFailed, isFalse);
        expect(service.personalVotesUnavailable, isFalse);
      },
    );
  }
}
