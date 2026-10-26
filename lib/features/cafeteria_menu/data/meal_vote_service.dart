import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

final mealVoteAccountProvider = Provider<String?>((ref) {
  final account = ref.watch(
    homeControllerProvider.select(
      (state) => state.isLoggedIn ? state.userId?.trim().toUpperCase() : null,
    ),
  );
  return account == null || account.isEmpty ? null : account;
});

final mealVoteServiceProvider = Provider<MealVoteService>((ref) {
  final account = ref.watch(mealVoteAccountProvider);
  final service = MealVoteService(account: account);
  ref.onDispose(service.dispose);
  return service;
});

String normalizedVoteItems(List<String> items) => items
    .map((item) => item.replaceAll(RegExp(r'\s+'), ' ').trim())
    .where((item) => item.isNotEmpty)
    .join('\n');

class MealVote {
  const MealVote({
    required this.id,
    required this.items,
    this.likes = 0,
    this.dislikes = 0,
    this.version = 0,
    this.choice = 0,
  });

  final String id;
  final List<String> items;
  final int likes;
  final int dislikes;
  final int version;
  final int choice;

  MealVote withChoice(int choice) => MealVote(
    id: id,
    items: items,
    likes: likes,
    dislikes: dislikes,
    version: version,
    choice: choice,
  );

  MealVote withResult(Map<String, dynamic> result, {int? choice}) => MealVote(
    id: id,
    items: items,
    likes: result['likes'] as int,
    dislikes: result['dislikes'] as int,
    version: result['version'] as int,
    choice: choice ?? result['choice'] as int? ?? this.choice,
  );
}

class MealVoteService {
  MealVoteService({Dio? dio, this.account, DateTime Function()? clock})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: kIsWeb
                  ? ''
                  : const String.fromEnvironment(
                      'VOTE_API_BASE_URL',
                      defaultValue: 'https://hongik-ingan.vercel.app',
                    ),
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ),
      _clock = clock ?? DateTime.now;

  final String? account;
  bool authenticationFailed = false;
  bool personalVotesUnavailable = false;
  final Dio _dio;
  final DateTime Function() _clock;
  final _cache = <String, List<MealVote>>{};
  final _fetchedAt = <String, DateTime>{};
  final _inflight = <String, Future<List<MealVote>>>{};
  final _generation = <String, int>{};

  Future<Options> _authOptions() async {
    if (account == null || account!.isEmpty) {
      authenticationFailed = true;
      throw const MealVoteAuthenticationException();
    }
    return Options(headers: {'X-Vote-Account': account});
  }

  Future<List<MealVote>> fetch(String date, {bool force = false}) {
    final fetched = _fetchedAt[date];
    if (!force &&
        fetched != null &&
        _clock().difference(fetched) < const Duration(seconds: 15)) {
      return Future.value(_cache[date]!);
    }
    return _inflight[date] ??= _fetch(date).whenComplete(() {
      _inflight.remove(date);
    });
  }

  Future<List<MealVote>> _fetch(String date) async {
    final generation = _generation[date] ?? 0;
    final menus = (await _dio.get<Map<String, dynamic>>(
      '/api/meals',
      queryParameters: {'date': date},
    )).data!;
    // Resolve the trusted menu before querying totals to avoid caching an empty day.
    final totals = (await _dio.get<Map<String, dynamic>>(
      '/api/vote-totals',
      queryParameters: {'date': date},
    )).data!;
    var choices = <dynamic>[];
    authenticationFailed = false;
    personalVotesUnavailable = false;
    if (account != null) {
      try {
        choices =
            (await _dio.get<Map<String, dynamic>>(
                  '/api/my-votes',
                  queryParameters: {'date': date},
                  options: await _authOptions(),
                )).data!['votes']
                as List;
      } on MealVoteAuthenticationException {
        authenticationFailed = true;
      } on DioException catch (error) {
        authenticationFailed = error.response?.statusCode == 401;
        personalVotesUnavailable = !authenticationFailed;
      }
    }
    final totalMap = {
      for (final row in totals['meals'] as List) row['id']: row,
    };
    final choiceMap = {for (final row in choices) row['id']: row['choice']};
    final previous = {
      for (final meal in _cache[date] ?? <MealVote>[]) meal.id: meal,
    };
    final result = <MealVote>[];
    for (final row in menus['meals'] as List) {
      final id = row['id'] as String;
      final total = totalMap[id];
      if (total == null) throw StateError('Vote totals not ready');
      final old = previous[id];
      if (old != null &&
          (old.version > (total['version'] as int) ||
              generation != (_generation[date] ?? 0))) {
        result.add(
          authenticationFailed || personalVotesUnavailable
              ? old.withChoice(0)
              : generation != (_generation[date] ?? 0)
              ? old
              : old.withChoice(choiceMap[id] as int? ?? 0),
        );
      } else {
        result.add(
          MealVote(
            id: id,
            items: List<String>.from(row['items'] as List),
          ).withResult(
            Map<String, dynamic>.from(total as Map),
            choice: choiceMap[id] as int? ?? 0,
          ),
        );
      }
    }
    _cache[date] = result;
    _fetchedAt[date] = _clock();
    // Keep only the small date window displayed by the menu feature.
    if (_cache.length > 14) {
      final oldest = _fetchedAt.keys.reduce(
        (a, b) => _fetchedAt[a]!.isBefore(_fetchedAt[b]!) ? a : b,
      );
      _cache.remove(oldest);
      _fetchedAt.remove(oldest);
    }
    return result;
  }

  Future<MealVote> setVote(String date, MealVote meal, int choice) async {
    final options = await _authOptions();
    _generation[date] = (_generation[date] ?? 0) + 1;
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/vote',
      data: {'date': date, 'id': meal.id, 'choice': choice},
      options: options,
    );
    final updated = meal.withResult(response.data!);
    _generation[date] = (_generation[date] ?? 0) + 1;
    _cache[date] = [
      for (final existing in _cache[date] ?? [meal])
        existing.id == meal.id ? updated : existing,
    ];
    _fetchedAt[date] = _clock();
    return updated;
  }

  void dispose() => _dio.close(force: true);
}

class MealVoteAuthenticationException implements Exception {
  const MealVoteAuthenticationException();
}
