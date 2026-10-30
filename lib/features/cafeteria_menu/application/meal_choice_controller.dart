import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_choice_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_key.dart';

const _unchanged = Object();

class MealChoiceState {
  const MealChoiceState({
    this.poll,
    this.error,
    this.readFailed = true,
    this.personalUnavailable = false,
    this.storageUnavailable = false,
    this.serverClosed = false,
    this.menuMismatch = false,
    this.saving = false,
  });

  final LunchPoll? poll;
  final String? error;
  final bool readFailed;
  final bool personalUnavailable;
  final bool storageUnavailable;
  final bool serverClosed;
  final bool menuMismatch;
  final bool saving;

  MealChoiceState copyWith({
    Object? poll = _unchanged,
    Object? error = _unchanged,
    bool? readFailed,
    bool? personalUnavailable,
    bool? storageUnavailable,
    bool? serverClosed,
    bool? menuMismatch,
    bool? saving,
  }) => MealChoiceState(
    poll: identical(poll, _unchanged) ? this.poll : poll as LunchPoll?,
    error: identical(error, _unchanged) ? this.error : error as String?,
    readFailed: readFailed ?? this.readFailed,
    personalUnavailable: personalUnavailable ?? this.personalUnavailable,
    storageUnavailable: storageUnavailable ?? this.storageUnavailable,
    serverClosed: serverClosed ?? this.serverClosed,
    menuMismatch: menuMismatch ?? this.menuMismatch,
    saving: saving ?? this.saving,
  );
}

final mealChoiceProvider = NotifierProvider.autoDispose
    .family<MealChoiceController, MealChoiceState, String>(
      MealChoiceController.new,
    );

// A passive listener can display retained state without scheduling requests.
final activeMealChoiceProvider = Provider.autoDispose.family<void, String>((
  ref,
  date,
) {
  final controller = ref.watch(mealChoiceProvider(date).notifier);
  controller.activate();
  ref.onDispose(controller.deactivate);
});

class MealChoiceController extends Notifier<MealChoiceState>
    with WidgetsBindingObserver {
  MealChoiceController(this.date);

  final String date;
  late MealChoiceService _service;
  Timer? _timer;
  Timer? _closeTimer;
  StreamSubscription<({String date, LunchPoll? poll})>? _updates;
  bool _active = false;
  bool _foreground = false;
  int _request = 0;

  @override
  MealChoiceState build() {
    _service = ref.watch(mealChoiceServiceProvider);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _updates = _service.updates.listen((update) {
      if (update.date != date || !ref.mounted) return;
      state = state.copyWith(poll: update.poll);
    });
    ref.onDispose(() {
      _request++;
      _timer?.cancel();
      _closeTimer?.cancel();
      _updates?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    return MealChoiceState(poll: _service.published(date));
  }

  bool get closed {
    final now = ref.read(campusClockProvider)();
    final comparison = date.compareTo(campusDateKey(now));
    return state.serverClosed ||
        comparison < 0 ||
        (comparison == 0 && now.hour >= 14);
  }

  void activate() {
    _active = true;
    scheduleMicrotask(() {
      if (ref.mounted && _active && _foreground) _start();
    });
  }

  void deactivate() {
    _active = false;
    _stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final wasForeground = _foreground;
    _foreground = lifecycle == AppLifecycleState.resumed;
    if (!_foreground) {
      _stop();
    } else if (!wasForeground && _active) {
      _start();
    }
  }

  void _start() {
    _stop();
    if (!_active || !_foreground) return;
    unawaited(load());
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!closed) unawaited(load());
    });
    final now = ref.read(campusClockProvider)();
    final day = DateTime.tryParse(date);
    if (day == null) return;
    final current = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    final deadline = DateTime.utc(day.year, day.month, day.day, 14);
    if (deadline.isAfter(current)) {
      _closeTimer = Timer(deadline.difference(current), () {
        if (!ref.mounted || !_active || !_foreground) return;
        state = state.copyWith();
        unawaited(load(force: true, fresh: true));
      });
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  Future<void> load({bool force = false, bool fresh = false}) async {
    if (state.saving) return;
    final request = ++_request;
    try {
      final pending = _service.choicePending(date);
      if (pending) await _service.waitForChoice(date);
      if (!ref.mounted || request != _request) return;
      final revision = _service.revision(date);
      final poll = await _service.fetch(
        date,
        force: force,
        fresh: fresh || pending,
      );
      if (!ref.mounted ||
          request != _request ||
          _service.choicePending(date) ||
          _service.revision(date) != revision) {
        return;
      }
      state = state.copyWith(
        poll: poll,
        readFailed: poll == null,
        menuMismatch: poll == null,
        personalUnavailable: _service.personalUnavailableFor(date),
        storageUnavailable: _service.storageUnavailableFor(date),
        error: poll == null ? '식단 정보가 달라요. 메뉴를 새로고침해 주세요.' : null,
      );
      _service.publish(date, poll);
    } catch (_) {
      if (!ref.mounted || request != _request) return;
      state = state.copyWith(readFailed: true, error: '투표를 불러오지 못했어요.');
      _service.publish(date, null);
    }
  }

  Future<void> choose(String option) async {
    final poll = state.poll;
    if (poll == null ||
        state.readFailed ||
        state.personalUnavailable ||
        poll.menuStale ||
        closed) {
      return;
    }
    final choice = poll.choice == option ? null : option;
    state = state.copyWith(error: null);
    final saving = _service.queueChoice(date, poll, choice);
    if (state.saving) return;
    state = state.copyWith(saving: true);
    final request = ++_request;
    var reconcile = false;
    try {
      final updated = await saving;
      if (ref.mounted && request == _request) {
        state = state.copyWith(poll: updated);
      }
    } catch (failure) {
      if (!ref.mounted || request != _request) return;
      final error = failure is MealChoiceSaveException
          ? failure.cause
          : failure;
      final confirmed = failure is MealChoiceSaveException
          ? failure.confirmed
          : poll;
      final conflict =
          error is DioException && error.response?.statusCode == 409;
      final code = error is DioException && error.response?.data is Map
          ? (error.response!.data as Map)['error']
          : null;
      final serverClosed = conflict && code == 'VOTING_CLOSED';
      reconcile =
          error is DioException &&
          (error.response == null ||
              error.response!.statusCode == null ||
              error.response!.statusCode! >= 500);
      final readFailed = conflict || reconcile;
      state = state.copyWith(
        poll: confirmed,
        readFailed: readFailed,
        serverClosed: state.serverClosed || serverClosed,
        menuMismatch: conflict && code == 'MENU_UNAVAILABLE',
        error: error is UnsupportedError
            ? '이 브라우저에서는 투표를 저장할 수 없어요. 다른 브라우저에서 시도해 주세요.'
            : error is MealVoteStorageException
            ? '기기의 투표 저장소에 접근할 수 없어요. 저장소 설정을 확인해 주세요.'
            : serverClosed
            ? null
            : conflict && code == 'MENU_UNAVAILABLE'
            ? '식단이 변경됐어요. 메뉴를 새로고침해 주세요.'
            : conflict
            ? '투표 상태가 변경됐어요. 다시 확인해 주세요.'
            : reconcile
            ? '선택 결과를 확인하고 있어요.'
            : '선택을 저장하지 못했어요. 다시 눌러 주세요.',
      );
      _service.publish(date, readFailed ? null : confirmed);
    } finally {
      if (ref.mounted && request == _request) {
        state = state.copyWith(saving: false);
        if (reconcile || closed) unawaited(load(force: true, fresh: true));
      }
    }
  }
}
