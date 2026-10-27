import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';

List<String>? mealChoiceOptions(List<MealMenu> meals, LunchPoll? poll) {
  if (poll == null || meals.length != 2) return null;
  final remaining = [0, 1];
  final result = List<String>.filled(2, '');
  for (final option in ['A', 'B']) {
    final items = poll.options[option];
    if (items == null) return null;
    final index = remaining.indexWhere(
      (i) =>
          (meals[i].option == null || meals[i].option == option) &&
          normalizedVoteItems(meals[i].items) == normalizedVoteItems(items),
    );
    if (index < 0) return null;
    result[remaining.removeAt(index)] = option;
  }
  return result;
}

int? leadingMealIndex(List<MealMenu> meals, LunchPoll? poll) {
  final options = mealChoiceOptions(meals, poll);
  if (options == null || poll!.aVotes == poll.bVotes) return null;
  return options.indexOf(poll.aVotes > poll.bVotes ? 'A' : 'B');
}

final mealChoiceServiceProvider = Provider<MealChoiceService>((ref) {
  final service = MealChoiceService(
    account: ref.watch(mealVoteAccountProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

class LunchPoll {
  const LunchPoll({
    required this.id,
    required this.options,
    this.aVotes = 0,
    this.bVotes = 0,
    this.version = 0,
    this.choice,
  });

  final String id;
  final Map<String, List<String>> options;
  final int aVotes;
  final int bVotes;
  final int version;
  final String? choice;

  factory LunchPoll.fromJson(Map<String, dynamic> json) => LunchPoll(
    id: json['id'] as String,
    options: {
      for (final row in json['options'] as List)
        row['option'] as String: List<String>.from(row['items'] as List),
    },
    aVotes: json['aVotes'] as int,
    bVotes: json['bVotes'] as int,
    version: json['version'] as int,
  );

  LunchPoll withChoice(String? next, {bool optimistic = false}) => LunchPoll(
    id: id,
    options: options,
    version: version,
    choice: next,
    aVotes:
        aVotes +
        (optimistic ? (next == 'A' ? 1 : 0) - (choice == 'A' ? 1 : 0) : 0),
    bVotes:
        bVotes +
        (optimistic ? (next == 'B' ? 1 : 0) - (choice == 'B' ? 1 : 0) : 0),
  );

  LunchPoll withResult(Map<String, dynamic> json) => LunchPoll(
    id: id,
    options: options,
    aVotes: json['aVotes'] as int,
    bVotes: json['bVotes'] as int,
    version: json['version'] as int,
    choice: json['choice'] as String?,
  );
}

class MealChoiceService {
  MealChoiceService({Dio? dio, this.account, DateTime Function()? clock})
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

  final Dio _dio;
  final String? account;
  final DateTime Function() _clock;
  final _authenticationFailed = <String, bool>{};
  final _personalUnavailable = <String, bool>{};
  bool authenticationFailedFor(String date) =>
      _authenticationFailed[date] ?? false;
  bool personalUnavailableFor(String date) =>
      _personalUnavailable[date] ?? false;
  final _cache = <String, LunchPoll?>{};
  final _fetchedAt = <String, DateTime>{};
  final _inflight = <String, Future<LunchPoll?>>{};
  final _generation = <String, int>{};
  final _updates =
      StreamController<({String date, LunchPoll? poll})>.broadcast();
  final _published = <String, LunchPoll?>{};
  final _revisions = <String, int>{};
  final _pendingChoices = <String>{};

  Stream<({String date, LunchPoll? poll})> get updates => _updates.stream;
  LunchPoll? published(String date) => _published[date];
  int revision(String date) => _revisions[date] ?? 0;
  bool choicePending(String date) => _pendingChoices.contains(date);

  void publish(String date, LunchPoll? poll) {
    _published[date] = poll;
    _revisions[date] = revision(date) + 1;
    if (!_updates.isClosed) _updates.add((date: date, poll: poll));
  }

  void setChoicePending(String date, bool pending) {
    if (pending) {
      _pendingChoices.add(date);
    } else {
      _pendingChoices.remove(date);
    }
  }

  Options get _auth => Options(headers: {'X-Vote-Account': account});

  Future<LunchPoll?> fetch(String date, {bool force = false}) {
    final fetched = _fetchedAt[date];
    if (!force &&
        fetched != null &&
        _clock().difference(fetched) < const Duration(seconds: 15)) {
      return Future.value(_cache[date]);
    }
    return _inflight[date] ??= _fetch(date).whenComplete(() {
      _inflight.remove(date);
    });
  }

  Future<LunchPoll?> _fetch(String date) async {
    final generation = _generation[date] ?? 0;
    final data = (await _dio.get<Map<String, dynamic>>(
      '/api/meal-choice',
      queryParameters: {'date': date},
    )).data!;
    var poll = data['poll'] == null
        ? null
        : LunchPoll.fromJson(Map<String, dynamic>.from(data['poll'] as Map));
    var authFailed = false;
    var ownUnavailable = false;
    if (poll != null && account != null) {
      try {
        final own = (await _dio.get<Map<String, dynamic>>(
          '/api/meal-choice',
          queryParameters: {'date': date, 'mine': '1'},
          options: _auth,
        )).data!;
        if (own['id'] != poll.id) throw StateError('Menu changed');
        poll = poll.withChoice(own['choice'] as String?);
      } on DioException catch (error) {
        authFailed = error.response?.statusCode == 401;
        ownUnavailable = !authFailed;
      } catch (_) {
        ownUnavailable = true;
      }
    }
    final old = _cache[date];
    if (generation != (_generation[date] ?? 0)) return old;
    _authenticationFailed[date] = authFailed;
    _personalUnavailable[date] = ownUnavailable;
    if (old != null &&
        poll != null &&
        old.id == poll.id &&
        old.version > poll.version) {
      poll = old.withChoice(poll.choice);
    }
    _cache[date] = poll;
    _fetchedAt[date] = _clock();
    if (_cache.length > 14) {
      final oldest = _fetchedAt.keys.reduce(
        (a, b) => _fetchedAt[a]!.isBefore(_fetchedAt[b]!) ? a : b,
      );
      _cache.remove(oldest);
      _fetchedAt.remove(oldest);
      _authenticationFailed.remove(oldest);
      _personalUnavailable.remove(oldest);
    }
    return poll;
  }

  Future<LunchPoll> setChoice(
    String date,
    LunchPoll poll,
    String? choice,
  ) async {
    if (account == null) throw const MealVoteAuthenticationException();
    _generation[date] = (_generation[date] ?? 0) + 1;
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/meal-choice',
      data: {'date': date, 'id': poll.id, 'choice': choice},
      options: _auth,
    );
    final updated = poll.withResult(response.data!);
    _generation[date] = (_generation[date] ?? 0) + 1;
    _cache[date] = updated;
    _fetchedAt[date] = _clock();
    return updated;
  }

  void dispose() {
    _updates.close();
    _dio.close(force: true);
  }
}
