import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_key.dart';
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

final _mealVoteKeyProvider = Provider<MealVoteKey>((ref) => MealVoteKey());

final mealChoiceServiceProvider = Provider<MealChoiceService>((ref) {
  final service = MealChoiceService(
    tokenFor: ref.read(_mealVoteKeyProvider).tokenFor,
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
    this.menuStale = false,
  });

  final String id;
  final Map<String, List<String>> options;
  final int aVotes;
  final int bVotes;
  final int version;
  final String? choice;
  final bool menuStale;

  factory LunchPoll.fromJson(Map<String, dynamic> json) => LunchPoll(
    id: json['id'] as String,
    options: {
      for (final row in json['options'] as List)
        row['option'] as String: List<String>.from(row['items'] as List),
    },
    aVotes: json['aVotes'] as int,
    bVotes: json['bVotes'] as int,
    version: json['version'] as int,
    menuStale: json['menuStale'] == true,
  );

  LunchPoll withChoice(String? next, {bool optimistic = false}) => LunchPoll(
    id: id,
    options: options,
    version: version,
    choice: next,
    menuStale: menuStale,
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
    menuStale: menuStale,
  );

  LunchPoll withMenuStale(bool value) => LunchPoll(
    id: id,
    options: options,
    aVotes: aVotes,
    bVotes: bVotes,
    version: version,
    choice: choice,
    menuStale: value,
  );
}

class MealChoiceSaveException implements Exception {
  const MealChoiceSaveException(this.cause, this.confirmed);
  final Object cause;
  final LunchPoll confirmed;
}

class _PendingChoice {
  _PendingChoice(this.confirmed, this.desired);
  LunchPoll confirmed;
  String? desired;
  final completion = Completer<LunchPoll>();
}

class MealChoiceService {
  MealChoiceService({
    Dio? dio,
    Future<String?> Function(String, {bool create})? tokenFor,
    DateTime Function()? clock,
  }) : _dio =
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
       _clock = clock ?? DateTime.now,
       _tokenFor = tokenFor ?? MealVoteKey().tokenFor;

  final Dio _dio;
  final Future<String?> Function(String, {bool create}) _tokenFor;
  final DateTime Function() _clock;
  final _personalUnavailable = <String, bool>{};
  final _storageUnavailable = <String, bool>{};
  bool personalUnavailableFor(String date) =>
      _personalUnavailable[date] ?? false;
  bool storageUnavailableFor(String date) => _storageUnavailable[date] ?? false;
  final _cache = <String, LunchPoll?>{};
  final _fetchedAt = <String, DateTime>{};
  final _inflight = <String, Future<LunchPoll?>>{};
  final _generation = <String, int>{};
  final _updates =
      StreamController<({String date, LunchPoll? poll})>.broadcast();
  final _published = <String, LunchPoll?>{};
  final _revisions = <String, int>{};
  final _pendingChoices = <String>{};
  final _writes = <String, _PendingChoice>{};

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

  // The queue belongs to the service so navigation cannot discard the last tap.
  Future<LunchPoll> queueChoice(String date, LunchPoll poll, String? choice) {
    final existing = _writes[date];
    if (existing != null) {
      existing.desired = choice;
      publish(date, existing.confirmed.withChoice(choice, optimistic: true));
      return existing.completion.future;
    }
    final pending = _PendingChoice(poll, choice);
    _writes[date] = pending;
    setChoicePending(date, true);
    publish(date, poll.withChoice(choice, optimistic: true));
    unawaited(_saveChoices(date, pending));
    return pending.completion.future;
  }

  Future<void> waitForChoice(String date) async {
    final pending = _writes[date];
    if (pending == null) return;
    try {
      await pending.completion.future;
    } catch (_) {
      // The caller reloads the server snapshot after a failed save as well.
    }
  }

  Future<void> _saveChoices(String date, _PendingChoice pending) async {
    try {
      while (true) {
        final desired = pending.desired;
        pending.confirmed = await setChoice(date, pending.confirmed, desired);
        publish(
          date,
          pending.confirmed.withChoice(pending.desired, optimistic: true),
        );
        if (pending.desired == desired) break;
      }
      pending.completion.complete(pending.confirmed);
    } catch (error) {
      _fetchedAt.remove(date);
      final uncertain =
          error is DioException &&
          (error.response == null ||
              error.response?.statusCode == null ||
              error.response!.statusCode! >= 500 ||
              error.response!.statusCode == 409);
      publish(date, uncertain ? null : pending.confirmed);
      pending.completion.completeError(
        MealChoiceSaveException(error, pending.confirmed),
      );
    } finally {
      _writes.remove(date);
      setChoicePending(date, false);
    }
  }

  Future<LunchPoll?> fetch(
    String date, {
    bool force = false,
    bool fresh = false,
  }) {
    final pending = _inflight[date];
    if (fresh && pending != null) {
      return pending
          .then<void>((_) {}, onError: (Object _) {})
          .then((_) => fetch(date, force: true, fresh: true));
    }
    final fetched = _fetchedAt[date];
    if (!force &&
        !fresh &&
        fetched != null &&
        _clock().difference(fetched) < const Duration(seconds: 15)) {
      return Future.value(_cache[date]);
    }
    return _inflight[date] ??= _fetch(date, fresh: fresh).whenComplete(() {
      _inflight.remove(date);
    });
  }

  Future<LunchPoll?> _fetch(String date, {required bool fresh}) async {
    final generation = _generation[date] ?? 0;
    final data = (await _dio.get<Map<String, dynamic>>(
      '/api/meal-choice',
      queryParameters: {'date': date, if (fresh) 'fresh': '1'},
    )).data!;
    var poll = data['poll'] == null
        ? null
        : LunchPoll.fromJson(Map<String, dynamic>.from(data['poll'] as Map));
    var ownUnavailable = false;
    var storageUnavailable = false;
    var personalLoaded = false;
    if (poll != null) {
      try {
        final token = await _tokenFor(poll.id, create: false);
        if (token != null) {
          final own = (await _dio.get<Map<String, dynamic>>(
            '/api/meal-choice',
            queryParameters: {'date': date, 'mine': '1', 'id': poll.id},
            options: Options(headers: {'X-Vote-Token': token}),
          )).data!;
          if (own['id'] != poll.id) throw StateError('Menu changed');
          poll = poll.withResult(own);
          personalLoaded = true;
        }
      } catch (error) {
        ownUnavailable = true;
        storageUnavailable = error is MealVoteStorageException;
      }
    }
    final old = _cache[date];
    if (generation != (_generation[date] ?? 0)) return old;
    _personalUnavailable[date] = ownUnavailable;
    _storageUnavailable[date] = storageUnavailable;
    if (old != null &&
        poll != null &&
        old.id == poll.id &&
        old.version > poll.version) {
      poll = (personalLoaded ? old : old.withChoice(null)).withMenuStale(
        poll.menuStale,
      );
    }
    _cache[date] = poll;
    _fetchedAt[date] = _clock();
    if (_cache.length > 14) {
      final oldest = _fetchedAt.keys.reduce(
        (a, b) => _fetchedAt[a]!.isBefore(_fetchedAt[b]!) ? a : b,
      );
      _cache.remove(oldest);
      _fetchedAt.remove(oldest);
      _personalUnavailable.remove(oldest);
      _storageUnavailable.remove(oldest);
    }
    return poll;
  }

  Future<LunchPoll> setChoice(
    String date,
    LunchPoll poll,
    String? choice,
  ) async {
    _generation[date] = (_generation[date] ?? 0) + 1;
    final token = await _tokenFor(poll.id, create: true);
    if (token == null) throw StateError('Vote key unavailable');
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/meal-choice',
      data: {'date': date, 'id': poll.id, 'choice': choice},
      options: Options(headers: {'X-Vote-Token': token}),
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
