import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_service.dart';

class MealVoteControls extends ConsumerStatefulWidget {
  const MealVoteControls({super.key, required this.date, required this.items});

  final DateTime date;
  final List<String> items;

  @override
  ConsumerState<MealVoteControls> createState() => _MealVoteControlsState();
}

class _MealVoteControlsState extends ConsumerState<MealVoteControls>
    with WidgetsBindingObserver {
  MealVote? _meal;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _readFailed = false;
  bool _authRequired = false;
  bool _personalUnavailable = false;
  int _request = 0;
  Timer? _timer;

  String get _date => campusDateKey(widget.date);
  bool get _today => _date == campusDateKey(ref.read(campusClockProvider)());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted &&
          TickerMode.valuesOf(context).enabled &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        if (_today) {
          unawaited(_load());
        } else {
          setState(() {});
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant MealVoteControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date ||
        normalizedVoteItems(oldWidget.items) !=
            normalizedVoteItems(widget.items)) {
      _request++;
      _saving = false;
      _meal = null;
      _error = null;
      _loading = true;
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        TickerMode.valuesOf(context).enabled) {
      unawaited(_load());
    }
  }

  Future<void> _load({bool force = false}) async {
    if (_saving) return;
    final request = ++_request;
    try {
      final service = ref.read(mealVoteServiceProvider);
      final meals = await service.fetch(_date, force: force);
      if (!mounted || request != _request) return;
      final match = meals.where(
        (meal) =>
            normalizedVoteItems(meal.items) ==
            normalizedVoteItems(widget.items),
      );
      setState(() {
        final loaded = match.firstOrNull;
        _meal = ref.read(mealVoteAccountProvider) == null
            ? loaded?.withChoice(0)
            : loaded;
        _authRequired = service.authenticationFailed;
        _personalUnavailable = service.personalVotesUnavailable;
        _readFailed = _meal == null;
        _loading = false;
        _error = _meal == null ? '식단 정보가 달라요. 메뉴를 새로고침해 주세요.' : null;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = '평가를 불러오지 못했어요.';
          _readFailed = true;
        });
      }
    }
  }

  Future<void> _vote(int choice) async {
    final meal = _meal;
    if (meal == null ||
        !_today ||
        _readFailed ||
        _authRequired ||
        _personalUnavailable ||
        ref.read(mealVoteAccountProvider) == null) {
      return;
    }
    final nextChoice = meal.choice == choice ? 0 : choice;
    setState(() {
      _meal = meal.withOptimisticChoice(nextChoice);
      _error = null;
    });
    if (_saving) return;
    _saving = true;
    final request = ++_request;
    final service = ref.read(mealVoteServiceProvider);
    final date = _date;
    var confirmed = meal;
    try {
      while (mounted && request == _request) {
        final desired = _meal!.choice;
        final updated = await service.setVote(date, confirmed, desired);
        if (!mounted || request != _request) return;
        confirmed = updated;
        final latest = _meal!.choice;
        setState(() => _meal = updated.withOptimisticChoice(latest));
        if (latest == desired) break;
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _meal = confirmed;
          _authRequired =
              error is MealVoteAuthenticationException ||
              (error is DioException && error.response?.statusCode == 401);
          _error = _authRequired
              ? '로그인을 다시 확인해 주세요.'
              : error is DioException && error.response?.statusCode == 409
              ? '투표할 수 없는 식단이에요. 메뉴를 새로고침해 주세요.'
              : '평가를 저장하지 못했어요. 다시 눌러 주세요.';
        });
      }
    } finally {
      if (mounted && request == _request) _saving = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(mealVoteAccountProvider);
    ref.listen(mealVoteAccountProvider, (previous, next) {
      _request++;
      setState(() {
        _meal = _meal?.withChoice(0);
        _error = null;
        _loading = _meal == null;
        _saving = false;
        _authRequired = false;
        _personalUnavailable = false;
        _readFailed = false;
      });
      unawaited(_load(force: true));
    });
    final meal = _meal;
    final style = Theme.of(context).textTheme.bodySmall;
    return SelectionContainer.disabled(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meal != null)
            Align(alignment: Alignment.center, child: _voteButton(meal)),
          if (_error != null) Text(_error!, style: style),
          if (meal != null && _today && account == null)
            Text('로그인 후 평가할 수 있어요.', style: style),
          if (meal != null &&
              _today &&
              account != null &&
              _authRequired &&
              _error == null)
            Text('로그인을 다시 확인해 주세요.', style: style),
          if (meal != null && account != null && _personalUnavailable)
            Text('내 평가를 확인하지 못했어요. 다시 시도해 주세요.', style: style),
          if (!_loading && (_readFailed || _personalUnavailable))
            TextButton(
              onPressed: () => _load(force: true),
              child: const Text('다시 시도'),
            ),
          if (meal != null && !_today)
            Text(
              _date.compareTo(campusDateKey(ref.read(campusClockProvider)())) <
                      0
                  ? '마감된 평가예요.'
                  : '당일에 평가할 수 있어요.',
              style: style,
            ),
        ],
      ),
    );
  }

  Widget _voteButton(MealVote meal) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    return Material(
      color: palette.cardSurfaceMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _button(1, meal.likes, '추천')),
          SizedBox(
            width: 1,
            height: MediaQuery.textScalerOf(
              context,
            ).scale(theme.textTheme.bodyMedium?.fontSize ?? 14),
            child: ColoredBox(color: palette.cardOutline),
          ),
          Flexible(child: _button(-1, meal.dislikes, '비추천')),
        ],
      ),
    );
  }

  Widget _button(int choice, int count, String label) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final selected = _meal!.choice == choice;
    return Semantics(
      selected: selected,
      child: TextButton(
        key: ValueKey('meal-vote-$choice'),
        onPressed:
            !_today ||
                _readFailed ||
                _authRequired ||
                _personalUnavailable ||
                ref.read(mealVoteAccountProvider) == null
            ? null
            : () => _vote(choice),
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(),
          textStyle: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          foregroundColor: selected
              ? theme.colorScheme.primary
              : palette.textSecondary,
          disabledForegroundColor: selected
              ? theme.colorScheme.primary
              : palette.textSecondary,
        ),
        child: Semantics(
          label: '$label $count',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                choice == 1
                    ? (selected ? Icons.thumb_up : Icons.thumb_up_outlined)
                    : (selected ? Icons.thumb_down : Icons.thumb_down_outlined),
                size: 16,
              ),
              const SizedBox(width: 4),
              Flexible(child: Text('$count', textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }
}
