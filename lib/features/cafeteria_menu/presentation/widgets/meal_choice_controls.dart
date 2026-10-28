import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_choice_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_key.dart';
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
  bool _personalUnavailable = false;
  bool _storageUnavailable = false;
  bool _serverClosed = false;
  bool _saving = false;
  int _request = 0;
  Timer? _timer;
  Timer? _closeTimer;

  String get _date => campusDateKey(widget.date);
  bool get _closed {
    final now = ref.read(campusClockProvider)();
    final comparison = _date.compareTo(campusDateKey(now));
    return _serverClosed ||
        comparison < 0 ||
        (comparison == 0 && now.hour >= 14);
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    final now = ref.read(campusClockProvider)();
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
    final deadline = DateTime.utc(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      14,
    );
    if (!deadline.isAfter(current)) return;
    _closeTimer = Timer(deadline.difference(current), () {
      if (!mounted) return;
      setState(() {});
      unawaited(_load(force: true, fresh: true));
    });
  }

  bool get _enabled => !_closed && !_readFailed && !_personalUnavailable;
  String get _menuKey => widget.meals
      .map((m) => '${m.option}:${normalizedVoteItems(m.items)}')
      .join('|');

  // Weekday HTML has no slot IDs. Resolve against the server's canonical
  // PRICELEVEL options, never by display order. Remove matched entries so
  // identical menus still require a complete pair and retain A/B identities.
  List<MealMenu>? _resolveMeals(LunchPoll? poll) {
    final options = mealChoiceOptions(widget.meals, poll);
    if (options == null) return null;
    return [
      for (var i = 0; i < widget.meals.length; i++)
        MealMenu(
          type: widget.meals[i].type,
          time: widget.meals[i].time,
          items: widget.meals[i].items,
          option: options[i],
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleClose();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted &&
          TickerMode.valuesOf(context).enabled &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        if (!_closed) {
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
      if (oldWidget.date != widget.date) _serverClosed = false;
      _scheduleClose();
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
      _scheduleClose();
      unawaited(_load());
    }
  }

  Future<void> _load({bool force = false, bool fresh = false}) async {
    if (_saving) return;
    final request = ++_request;
    final date = _date;
    try {
      final service = ref.read(mealChoiceServiceProvider);
      final pending = service.choicePending(date);
      if (pending) await service.waitForChoice(date);
      if (!mounted || request != _request) return;
      final poll = await service.fetch(
        date,
        force: force,
        fresh: fresh || pending,
      );
      if (!mounted || request != _request) return;
      final matches = _resolveMeals(poll) != null;
      setState(() {
        _poll = matches ? poll : null;
        _readFailed = !matches;
        _personalUnavailable = service.personalUnavailableFor(_date);
        _storageUnavailable = service.storageUnavailableFor(_date);
        _error = matches ? null : '식단 정보가 달라요. 메뉴를 새로고침해 주세요.';
      });
      service.publish(_date, matches ? poll : null);
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _readFailed = true;
          _error = '투표를 불러오지 못했어요.';
        });
        ref.read(mealChoiceServiceProvider).publish(_date, null);
      }
    }
  }

  Future<void> _choose(String option) async {
    final poll = _poll;
    if (!_enabled || poll == null) return;
    final service = ref.read(mealChoiceServiceProvider);
    final date = _date;
    setState(() {
      _poll = poll.withChoice(
        poll.choice == option ? null : option,
        optimistic: true,
      );
      _error = null;
    });
    final saving = service.queueChoice(date, poll, _poll!.choice);
    if (_saving) return;
    _saving = true;
    final request = ++_request;
    var reconcile = false;
    try {
      final updated = await saving;
      if (!mounted || request != _request) return;
      setState(() => _poll = updated);
    } catch (failure) {
      final error = failure is MealChoiceSaveException
          ? failure.cause
          : failure;
      final confirmed = failure is MealChoiceSaveException
          ? failure.confirmed
          : poll;
      if (mounted && request == _request) {
        setState(() {
          _poll = confirmed;
          final conflict =
              error is DioException && error.response?.statusCode == 409;
          final code = error is DioException && error.response?.data is Map
              ? (error.response!.data as Map)['error']
              : null;
          final closed = conflict && code == 'VOTING_CLOSED';
          if (closed) _serverClosed = true;
          reconcile =
              error is DioException &&
              (error.response == null ||
                  error.response!.statusCode == null ||
                  error.response!.statusCode! >= 500);
          if (conflict || reconcile) _readFailed = true;
          _error = error is UnsupportedError
              ? '이 브라우저에서는 투표를 저장할 수 없어요. 다른 브라우저에서 시도해 주세요.'
              : error is MealVoteStorageException
              ? '기기의 투표 저장소에 접근할 수 없어요. 저장소 설정을 확인해 주세요.'
              : closed
              ? null
              : conflict && code == 'MENU_UNAVAILABLE'
              ? '식단이 변경됐어요. 메뉴를 새로고침해 주세요.'
              : conflict
              ? '투표 상태가 변경됐어요. 다시 확인해 주세요.'
              : reconcile
              ? '선택 결과를 확인하고 있어요.'
              : '선택을 저장하지 못했어요. 다시 눌러 주세요.';
        });
        service.publish(date, _readFailed ? null : _poll);
      }
    } finally {
      if (mounted && request == _request) {
        _saving = false;
        if (reconcile || _closed) {
          unawaited(_load(force: true, fresh: true));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice =
        _error ??
        (_storageUnavailable
            ? '기기의 투표 저장소에 접근할 수 없어요. 저장소 설정을 확인해 주세요.'
            : _personalUnavailable
            ? '내 선택을 확인하지 못했어요. 다시 시도해 주세요.'
            : null);
    final meals = _resolveMeals(_poll) ?? widget.meals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.headerBuilder(_closed),
        if (!_closed) ...[
          const SizedBox(height: 4),
          Text(
            '메뉴를 눌러 투표 · 오후 2시 마감',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color:
                  (Theme.of(context).extension<HongikPalette>() ??
                          HongikPalette.light)
                      .textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final wide =
                meals.length == 2 && constraints.maxWidth >= 600 * scale;
            return MealOptionsLayout(
              children: [
                for (var i = 0; i < meals.length; i++)
                  _option(meals[i], i, wide: wide, notice: notice),
              ],
            );
          },
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(notice, style: Theme.of(context).textTheme.bodySmall),
          ),
        if (_error != null || _personalUnavailable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _load(force: true, fresh: true),
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
    required String? notice,
  }) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final label = index == 0 ? 'A안' : 'B안';
    final selected = meal.option != null && _poll?.choice == meal.option;
    final leading =
        !_readFailed && leadingMealIndex(widget.meals, _poll) == index;
    final count = _poll == null || meal.option == null
        ? null
        : meal.option == 'A'
        ? _poll!.aVotes
        : _poll!.bVotes;
    final countLabel = count != null
        ? '$count표'
        : _error == null
        ? '집계 확인 중'
        : '—';
    final loading = count == null && _error == null;
    final color = selected ? palette.brandRed : palette.textSecondary;
    final resultColor = leading
        ? theme.colorScheme.primary
        : palette.textSecondary;
    final action = _enabled && meal.option != null
        ? () => _choose(meal.option!)
        : null;
    final headerItems = <Widget>[
      Icon(
        action == null &&
                !(_closed && selected && !_personalUnavailable && !_readFailed)
            ? Icons.lock_outline_rounded
            : selected
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        size: 18,
        color: color,
      ),
      Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: resultColor,
          fontWeight: leading ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      if (loading)
        _LoadingVoteCount(
          key: ValueKey('meal-vote-loading-$index'),
          color: color,
        )
      else
        Text(
          countLabel,
          style: theme.textTheme.bodyMedium?.copyWith(color: resultColor),
        ),
    ];
    final option = Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: action != null,
      label:
          '$label, ${countLabel == '—' ? '집계 확인 불가' : countLabel}${leading ? ', 투표 수 우세' : ''}',
      hint: action == null
          ? notice ?? (_closed ? '마감된 투표예요.' : null)
          : selected
          ? '다시 누르면 선택 취소'
          : '이 식단 선택',
      onTap: action,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('meal-choice-${meal.option ?? index}'),
          onTap: action,
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
                          children: wide && index == 0
                              ? headerItems.reversed.toList()
                              : headerItems,
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
    return option;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _closeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _LoadingVoteCount extends StatefulWidget {
  const _LoadingVoteCount({super.key, required this.color});

  final Color color;

  @override
  State<_LoadingVoteCount> createState() => _LoadingVoteCountState();
}

class _LoadingVoteCountState extends State<_LoadingVoteCount>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: widget.color);
    final size = MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: const ValueKey('meal-vote-wave'),
          child: CustomPaint(
            size: Size(size, size),
            painter: _VoteWavePainter(color: widget.color, phase: _animation),
          ),
        ),
        Text('표', style: style),
      ],
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }
}

class _VoteWavePainter extends CustomPainter {
  _VoteWavePainter({required this.color, required this.phase})
    : super(repaint: phase);

  final Color color;
  final Animation<double> phase;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i <= 32; i++) {
      final x = size.width * i / 32;
      final y =
          size.height *
          (0.5 + 0.12 * math.sin(2 * math.pi * (i / 32 - phase.value)));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.09,
    );
  }

  @override
  bool shouldRepaint(covariant _VoteWavePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.phase != phase;
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
