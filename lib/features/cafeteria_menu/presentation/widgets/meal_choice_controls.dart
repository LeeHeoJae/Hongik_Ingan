import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_choice_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';

class MealChoiceControls extends ConsumerStatefulWidget {
  const MealChoiceControls({
    super.key,
    required this.date,
    required this.meals,
    required this.itemBuilder,
    required this.headerBuilder,
  });

  final DateTime date;
  final List<MealMenu> meals;
  final Widget Function(MealMenu meal) itemBuilder;
  final Widget Function(bool closed) headerBuilder;

  @override
  ConsumerState<MealChoiceControls> createState() => _MealChoiceControlsState();
}

class _MealChoiceControlsState extends ConsumerState<MealChoiceControls>
    with WidgetsBindingObserver {
  LunchPoll? _poll;
  String? _error;
  bool _readFailed = true;
  bool _authRequired = false;
  bool _personalUnavailable = false;
  bool _saving = false;
  int _request = 0;
  Timer? _timer;
  Timer? _tooltipTimer;
  final _tooltipKeys = List.generate(2, (_) => GlobalKey<TooltipState>());

  void _showLoginHint(int index) {
    _tooltipKeys[index].currentState?.ensureTooltipVisible();
    _tooltipTimer?.cancel();
    _tooltipTimer = Timer(
      const Duration(seconds: 3),
      Tooltip.dismissAllToolTips,
    );
  }

  String get _date => campusDateKey(widget.date);
  bool get _today => _date == campusDateKey(ref.read(campusClockProvider)());
  bool get _closed =>
      _date.compareTo(campusDateKey(ref.read(campusClockProvider)())) < 0;
  bool get _enabled =>
      _today &&
      !_readFailed &&
      !_authRequired &&
      !_personalUnavailable &&
      ref.read(mealVoteAccountProvider) != null;
  String get _menuKey => widget.meals
      .map((m) => '${m.option}:${normalizedVoteItems(m.items)}')
      .join('|');

  // Weekday HTML has no slot IDs. Resolve against the server's canonical
  // PRICELEVEL options, never by display order. Remove matched entries so
  // identical menus still require a complete pair and retain A/B identities.
  List<MealMenu>? _resolveMeals(LunchPoll? poll) {
    if (poll == null) return null;
    final remaining = [...widget.meals];
    final resolved = <MealMenu>[];
    for (final option in ['A', 'B']) {
      final items = poll.options[option];
      if (items == null) return null;
      final index = remaining.indexWhere(
        (meal) =>
            (meal.option == null || meal.option == option) &&
            normalizedVoteItems(meal.items) == normalizedVoteItems(items),
      );
      if (index < 0) return null;
      final meal = remaining.removeAt(index);
      resolved.add(
        MealMenu(
          type: meal.type,
          time: meal.time,
          items: meal.items,
          option: option,
        ),
      );
    }
    return remaining.isEmpty ? resolved : null;
  }

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
  void didUpdateWidget(covariant MealChoiceControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = oldWidget.meals
        .map((m) => '${m.option}:${normalizedVoteItems(m.items)}')
        .join('|');
    if (oldWidget.date != widget.date || oldKey != _menuKey) {
      _request++;
      _saving = false;
      _poll = null;
      _readFailed = true;
      _error = null;
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
      final service = ref.read(mealChoiceServiceProvider);
      var poll = await service.fetch(_date, force: force);
      if (!mounted || request != _request) return;
      final matches = _resolveMeals(poll) != null;
      if (ref.read(mealVoteAccountProvider) == null) {
        poll = poll?.withChoice(null);
      }
      setState(() {
        _poll = matches ? poll : null;
        _readFailed = !matches;
        _authRequired = service.authenticationFailed;
        _personalUnavailable = service.personalUnavailable;
        _error = matches ? null : '식단 정보가 달라요. 메뉴를 새로고침해 주세요.';
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _readFailed = true;
          _error = '투표를 불러오지 못했어요.';
        });
      }
    }
  }

  Future<void> _choose(String option) async {
    final poll = _poll;
    if (!_enabled || poll == null) return;
    setState(() {
      _poll = poll.withChoice(
        poll.choice == option ? null : option,
        optimistic: true,
      );
      _error = null;
    });
    if (_saving) return;
    _saving = true;
    final request = ++_request;
    final service = ref.read(mealChoiceServiceProvider);
    final date = _date;
    var confirmed = poll;
    try {
      while (mounted && request == _request) {
        final desired = _poll!.choice;
        final updated = await service.setChoice(date, confirmed, desired);
        if (!mounted || request != _request) return;
        confirmed = updated;
        final latest = _poll!.choice;
        setState(() => _poll = updated.withChoice(latest, optimistic: true));
        if (latest == desired) break;
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _poll = confirmed;
          _authRequired =
              error is MealVoteAuthenticationException ||
              (error is DioException && error.response?.statusCode == 401);
          final conflict =
              error is DioException && error.response?.statusCode == 409;
          if (conflict) _readFailed = true;
          _error = _authRequired
              ? '로그인을 다시 확인해 주세요.'
              : conflict
              ? '식단이 변경되었거나 투표가 마감됐어요. 메뉴를 새로고침해 주세요.'
              : '선택을 저장하지 못했어요. 다시 눌러 주세요.';
        });
      }
    } finally {
      if (mounted && request == _request) _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(mealVoteAccountProvider);
    ref.listen(mealVoteAccountProvider, (previous, next) {
      _request++;
      setState(() {
        _poll = _poll?.withChoice(null);
        _saving = false;
        _readFailed = true;
        _authRequired = false;
        _personalUnavailable = false;
        _error = null;
      });
      unawaited(_load(force: true));
    });
    final notice =
        _error ??
        (_authRequired
            ? '로그인을 다시 확인해 주세요.'
            : _personalUnavailable
            ? '내 선택을 확인하지 못했어요. 다시 시도해 주세요.'
            : !_today && !_closed
            ? '당일에 선택할 수 있어요.'
            : null);
    final meals = _resolveMeals(_poll) ?? widget.meals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.headerBuilder(_closed),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final wide =
                meals.length == 2 && constraints.maxWidth >= 600 * scale;
            return MealOptionsLayout(
              children: [
                for (var i = 0; i < meals.length; i++)
                  _option(
                    meals[i],
                    i,
                    wide: wide,
                    account: account,
                    notice: notice,
                  ),
              ],
            );
          },
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(notice, style: Theme.of(context).textTheme.bodySmall),
          ),
        if (_error != null || _personalUnavailable || _authRequired)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _load(force: true),
              child: const Text('다시 시도'),
            ),
          ),
      ],
    );
  }

  Widget _option(
    MealMenu meal,
    int index, {
    required bool wide,
    required String? account,
    required String? notice,
  }) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final label = meal.option == null ? '식단 ${index + 1}' : '${meal.option}안';
    final selected = meal.option != null && _poll?.choice == meal.option;
    final count = _poll == null || meal.option == null
        ? null
        : meal.option == 'A'
        ? _poll!.aVotes
        : _poll!.bVotes;
    final color = selected ? theme.colorScheme.primary : palette.textSecondary;
    final action = _enabled && meal.option != null
        ? () => _choose(meal.option!)
        : null;
    final locked =
        account == null &&
        _today &&
        !_readFailed &&
        !_authRequired &&
        !_personalUnavailable &&
        meal.option != null;
    const loginHint = '로그인 후 학번으로 투표할 수 있어요.';
    final tooltipKey = _tooltipKeys[index];
    final option = Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: action != null,
      label: '$label, ${count == null ? '집계 확인 전' : '$count표'}',
      hint: locked
          ? loginHint
          : action == null
          ? notice
          : selected
          ? '다시 누르면 선택 취소'
          : '이 식단 선택',
      onTap: action,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('meal-choice-${meal.option ?? index}'),
          onTap: locked ? () => _showLoginHint(index) : action,
          onFocusChange: locked
              ? (focused) {
                  if (focused) _showLoginHint(index);
                }
              : null,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectionContainer.disabled(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 24),
                        child: Wrap(
                          alignment: wide && index == 0
                              ? WrapAlignment.end
                              : WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Icon(
                              locked
                                  ? Icons.lock_outline_rounded
                                  : selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: color,
                            ),
                            Text(
                              label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              count == null ? '—' : '$count표',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                widget.itemBuilder(meal),
              ],
            ),
          ),
        ),
      ),
    );
    if (!locked) return option;
    return Tooltip(
      key: tooltipKey,
      message: loginHint,
      excludeFromSemantics: true,
      triggerMode: TooltipTriggerMode.manual,
      child: option,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tooltipTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Shared layout keeps voting and read-only menus at the same breakpoints.
class MealOptionsLayout extends StatelessWidget {
  const MealOptionsLayout({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (children.length == 2 && constraints.maxWidth >= 600 * scale) {
          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 25),
                  Expanded(child: children[1]),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(width: 1, color: palette.cardOutline),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: palette.cardOutline),
                ),
              children[i],
            ],
          ],
        );
      },
    );
  }
}
