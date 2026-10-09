import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import '../domain/attendance_overview.dart';
import '../domain/attendance_week_target.dart';

/// A read-only matrix with a fixed schedule header and week column.
class SchoolAttendanceTable extends ConsumerStatefulWidget {
  const SchoolAttendanceTable({super.key, required this.detail});

  final SchoolAttendanceDetail detail;

  @override
  ConsumerState<SchoolAttendanceTable> createState() =>
      _SchoolAttendanceTableState();
}

class _SchoolAttendanceTableState extends ConsumerState<SchoolAttendanceTable> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _heading = ScrollController(keepScrollOffset: false);
  final _detailScroll = ScrollController();
  SchoolAttendanceEntry? _selected;
  ModalRoute<void>? _detailRoute;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _horizontal.addListener(() => _sync(_horizontal, _heading));
    _heading.addListener(() => _sync(_heading, _horizontal));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(_horizontal, _heading);
    });
  }

  void _sync(ScrollController source, ScrollController target) {
    if (_syncing || !source.hasClients || !target.hasClients) return;
    _syncing = true;
    target.jumpTo(source.offset.clamp(0, target.position.maxScrollExtent));
    _syncing = false;
  }

  @override
  void didUpdateWidget(SchoolAttendanceTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail != widget.detail) _selected = null;
  }

  @override
  void dispose() {
    // The records route can be removed beneath this dialog on account changes.
    final detailRoute = _detailRoute;
    if (detailRoute != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (detailRoute.isActive) {
          detailRoute.navigator?.removeRoute(detailRoute);
        }
      });
    }
    _vertical.dispose();
    _horizontal.dispose();
    _heading.dispose();
    _detailScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final statusStyle = theme.textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
    final secondaryStyle = theme.textTheme.bodySmall!.copyWith(
      color: palette.textSecondary,
      height: 1.4,
    );
    final headingStyle = theme.textTheme.bodySmall!.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
    final grid = _AttendanceGrid(widget.detail.entries);
    final now = ref.watch(campusClockProvider)();
    final target = attendanceWeekTarget(widget.detail, now);
    final currentWeek = target?.isCurrentWeek == true ? target!.week : null;
    final jumpLabel = target?.isCurrentWeek == false ? '최근 수업' : '이번 주';
    final jumpTooltip = target == null
        ? '이동할 강의 날짜가 없어요.'
        : '$jumpLabel(${target.week}주차)로 이동';
    void jump() {
      final latestTarget = attendanceWeekTarget(
        widget.detail,
        ref.read(campusClockProvider)(),
      );
      setState(() => _selected = null);
      if (latestTarget != null) _jumpToWeek(latestTarget.week);
    }

    double textHeight(String value, TextStyle style, double width) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout(maxWidth: width);
      final height = painter.height;
      painter.dispose();
      return height.ceilToDouble();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${widget.detail.course.key.termLabel} · ${widget.detail.course.codeLabel}',
                style: secondaryStyle,
              ),
            ),
            Tooltip(
              message: jumpTooltip,
              child: scaler.scale(14) > 19
                  ? IconButton(
                      key: const ValueKey('attendance-week-jump'),
                      onPressed: target == null ? null : jump,
                      icon: const Icon(Icons.my_location_rounded, size: 20),
                    )
                  : TextButton.icon(
                      key: const ValueKey('attendance-week-jump'),
                      onPressed: target == null ? null : jump,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(jumpLabel),
                    ),
            ),
          ],
        ),
        Text('미입력은 결석을 뜻하지 않아요.', style: secondaryStyle),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final weekWidth = math.max(48.0, scaler.scale(32) + 16);
              final viewportWidth = math.max(
                1.0,
                constraints.maxWidth - weekWidth,
              );
              final columnWidth = math.max(
                scaler.scale(96),
                viewportWidth / grid.slots.length,
              );
              final contentWidth = columnWidth * grid.slots.length;
              final headerHeight = grid.slots.fold<double>(44, (height, slot) {
                return math.max(
                  height,
                  textHeight(
                        _scheduleLabel(slot.$1),
                        headingStyle,
                        columnWidth - 16,
                      ) +
                      16,
                );
              });
              final rowHeights = [
                for (final week in grid.weeks)
                  grid.slots.fold<double>(52, (height, slot) {
                    final entry = grid.rows[week]?[slot];
                    return math.max(
                      height,
                      entry == null
                          ? textHeight(
                                  '정보 없음',
                                  secondaryStyle,
                                  columnWidth - 16,
                                ) +
                                20
                          : textHeight(
                                  entry.status,
                                  statusStyle,
                                  columnWidth - 16,
                                ) +
                                textHeight(
                                  _dateLabel(entry.lectureLabel),
                                  secondaryStyle,
                                  columnWidth - 16,
                                ) +
                                26,
                    );
                  }),
              ];
              _weekOffsets = {
                for (var index = 0; index < grid.weeks.length; index++)
                  grid.weeks[index]: rowHeights
                      .take(index)
                      .fold<double>(0, (a, b) => a + b),
              };

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Scrollbar(
                      controller: _horizontal,
                      thumbVisibility: contentWidth > viewportWidth,
                      trackVisibility: contentWidth > viewportWidth,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      notificationPredicate: (notification) =>
                          notification.metrics.axis == Axis.horizontal,
                      child: Column(
                        children: [
                          ColoredBox(
                            color: palette.cardSurfaceMuted,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: weekWidth,
                                  height: headerHeight,
                                  child: Center(
                                    child: Semantics(
                                      header: true,
                                      child: Text('주차', style: headingStyle),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    key: const ValueKey(
                                      'attendance-table-heading',
                                    ),
                                    controller: _heading,
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final slot in grid.slots)
                                          SizedBox(
                                            width: columnWidth,
                                            height: headerHeight,
                                            child: Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                child: Semantics(
                                                  header: true,
                                                  child: Text(
                                                    _scheduleLabel(slot.$1),
                                                    style: headingStyle,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Scrollbar(
                              controller: _vertical,
                              thumbVisibility: true,
                              notificationPredicate: (notification) =>
                                  notification.metrics.axis == Axis.vertical,
                              child: SingleChildScrollView(
                                key: PageStorageKey(
                                  'attendance-detail-${widget.detail.course.key.id}',
                                ),
                                controller: _vertical,
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ColoredBox(
                                      color: palette.cardSurfaceMuted,
                                      child: Column(
                                        children: [
                                          for (
                                            var index = 0;
                                            index < grid.weeks.length;
                                            index++
                                          )
                                            Container(
                                              key: ValueKey(
                                                'attendance-week-${grid.weeks[index]}',
                                              ),
                                              width: weekWidth,
                                              height: rowHeights[index],
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color:
                                                    grid.weeks[index] ==
                                                        currentWeek
                                                    ? theme
                                                          .colorScheme
                                                          .primaryContainer
                                                    : null,
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: palette.cardOutline,
                                                  ),
                                                ),
                                              ),
                                              child: Semantics(
                                                label:
                                                    '${grid.weeks[index]}주차${grid.weeks[index] == currentWeek ? ', 이번 주' : ''}',
                                                excludeSemantics: true,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '${grid.weeks[index]}주',
                                                      style: headingStyle,
                                                    ),
                                                    if (grid.weeks[index] ==
                                                        currentWeek)
                                                      Text(
                                                        '이번 주',
                                                        style: secondaryStyle,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        key: const PageStorageKey(
                                          'attendance-table-horizontal',
                                        ),
                                        controller: _horizontal,
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: contentWidth,
                                          child: Column(
                                            children: [
                                              for (
                                                var index = 0;
                                                index < grid.weeks.length;
                                                index++
                                              )
                                                Row(
                                                  children: [
                                                    for (final slot
                                                        in grid.slots)
                                                      _cell(
                                                        grid.rows[grid
                                                            .weeks[index]]?[slot],
                                                        week: grid.weeks[index],
                                                        slot: slot,
                                                        width: columnWidth,
                                                        height:
                                                            rowHeights[index],
                                                        statusStyle:
                                                            statusStyle,
                                                        secondaryStyle:
                                                            secondaryStyle,
                                                        palette: palette,
                                                        inlineDetail:
                                                            constraints
                                                                .maxHeight >=
                                                            headerHeight +
                                                                rowHeights[index] +
                                                                scaler.scale(
                                                                  96,
                                                                ),
                                                      ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selected case final entry?)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.45,
                      ),
                      child: Scrollbar(
                        controller: _detailScroll,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          key: const ValueKey('attendance-entry-detail'),
                          controller: _detailScroll,
                          primary: false,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${entry.week}주차 · ${_scheduleLabel(entry.schedule)}',
                                        style: headingStyle,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '선택 해제',
                                      onPressed: () =>
                                          setState(() => _selected = null),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    '${entry.lectureLabel}\n출결: ${entry.status}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Map<int, double> _weekOffsets = {};

  void _jumpToWeek(int week) {
    if (!_vertical.hasClients) return;
    _vertical.jumpTo(
      (_weekOffsets[week] ?? 0).clamp(0, _vertical.position.maxScrollExtent),
    );
  }

  Widget _cell(
    SchoolAttendanceEntry? entry, {
    required int week,
    required (String, int) slot,
    required double width,
    required double height,
    required TextStyle statusStyle,
    required TextStyle secondaryStyle,
    required HongikPalette palette,
    required bool inlineDetail,
  }) {
    final theme = Theme.of(context);
    final selected = entry != null && identical(_selected, entry);
    final color = switch (entry?.status) {
      '출석' => palette.success,
      '지각' => palette.warning,
      '결석' => theme.colorScheme.error,
      _ => theme.colorScheme.onSurface,
    };
    void select() {
      if (entry == null) return;
      if (inlineDetail) {
        if (_detailScroll.hasClients) _detailScroll.jumpTo(0);
        setState(() => _selected = selected ? null : entry);
      } else {
        showDialog<void>(
          context: context,
          builder: (context) {
            _detailRoute = ModalRoute.of<void>(context);
            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.week}주차 · ${_scheduleLabel(entry.schedule)}',
                    ),
                  ),
                  IconButton(
                    tooltip: '상세 닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                key: const ValueKey('attendance-entry-detail'),
                child: Text('${entry.lectureLabel}\n출결: ${entry.status}'),
              ),
            );
          },
        ).whenComplete(() => _detailRoute = null);
      }
    }

    return Semantics(
      label: entry == null
          ? '$week주차, ${_scheduleLabel(slot.$1)}, 정보 없음'
          : '$week주차, ${_scheduleLabel(entry.schedule)}, ${entry.lectureLabel}, 출결 ${entry.status}',
      button: entry != null,
      selected: selected,
      onTap: entry == null ? null : select,
      excludeSemantics: true,
      child: SizedBox(
        key: ValueKey('attendance-cell-$week-${slot.$1}-${slot.$2}'),
        width: width,
        height: height,
        child: Material(
          color: selected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          child: InkWell(
            onTap: entry == null ? null : select,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.cardOutline)),
              ),
              child: entry == null
                  ? Text(
                      '정보 없음',
                      style: secondaryStyle,
                      textAlign: TextAlign.center,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.status,
                          style: statusStyle.copyWith(color: color),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateLabel(entry.lectureLabel),
                          style: secondaryStyle,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _scheduleLabel(String value) {
  final match = RegExp(r'^([월화수목금토일])(\d+)$').firstMatch(value);
  return match == null ? value : '${match[1]} ${match[2]}교시';
}

String _dateLabel(String value) =>
    RegExp(r'^\d{2}/\d{2}\([월화수목금토일]\)').stringMatch(value) ?? value;

class _AttendanceGrid {
  _AttendanceGrid(List<SchoolAttendanceEntry> entries) {
    final seen = <(String, int)>{};
    final occurrences = <int, Map<String, int>>{};
    for (final entry in entries) {
      final counts = occurrences.putIfAbsent(entry.week, () => {});
      final occurrence = counts.update(
        entry.schedule,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      final slot = (entry.schedule, occurrence);
      if (seen.add(slot)) slots.add(slot);
      (rows[entry.week] ??= {})[slot] = entry;
    }
    weeks.addAll(rows.keys.toList()..sort());
  }

  final slots = <(String, int)>[];
  final weeks = <int>[];
  final rows = <int, Map<(String, int), SchoolAttendanceEntry>>{};
}
