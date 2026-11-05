import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import '../application/attendance_history_provider.dart';
import '../domain/attendance_request_record.dart';

/// A short preview with a direct link to the full request history.
class AttendanceHistorySummary extends ConsumerStatefulWidget {
  const AttendanceHistorySummary({
    super.key,
    required this.userId,
    this.onRecordPressed,
    this.extraSpace = 0,
    this.headingGap = 8,
    this.recordGap = 12,
    this.historySnapshot,
  });

  final String userId;
  final VoidCallback? onRecordPressed;
  final double extraSpace;
  final double headingGap;
  final double recordGap;
  final AsyncValue<List<AttendanceRequestRecord>>? historySnapshot;

  @override
  ConsumerState<AttendanceHistorySummary> createState() =>
      _AttendanceHistorySummaryState();
}

class _AttendanceHistorySummaryState
    extends ConsumerState<AttendanceHistorySummary> {
  bool _observedEmpty = false;
  bool _fadeFirstRecord = false;

  @override
  void didUpdateWidget(covariant AttendanceHistorySummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _observedEmpty = false;
      _fadeFirstRecord = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: palette.textSecondary,
      height: 1.4,
    );
    Widget historyAction() => TextButton.icon(
      key: const ValueKey('attendance-history-summary-action'),
      onPressed: widget.onRecordPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(32, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        textStyle: theme.textTheme.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
      ),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.chevron_right_rounded, size: 14),
      label: const Text('최근 출결 요청'),
    );
    final history =
        widget.historySnapshot ??
        ref.watch<AsyncValue<List<AttendanceRequestRecord>>>(
          attendanceHistoryProvider(widget.userId),
        );
    final records = history.asData?.value;
    if (records != null) {
      if (records.isEmpty) {
        _observedEmpty = true;
        _fadeFirstRecord = false;
      } else if (_observedEmpty) {
        _observedEmpty = false;
        _fadeFirstRecord = true;
      }
    }
    if (history.asData?.value.isEmpty == true &&
        MediaQuery.sizeOf(context).width >= 960 &&
        MediaQuery.textScalerOf(context).scale(14) <= 19) {
      return Row(
        key: const ValueKey('attendance-history-summary'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          historyAction(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '아직 출결 요청 기록이 없어요.',
              key: const ValueKey('attendance-history-summary-body'),
              style: secondary,
            ),
          ),
        ],
      );
    }
    return Column(
      key: const ValueKey('attendance-history-summary'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [Flexible(child: historyAction())]),
        SizedBox(height: widget.headingGap),
        Padding(
          key: const ValueKey('attendance-history-summary-body'),
          padding: EdgeInsets.symmetric(vertical: widget.extraSpace / 2),
          child: history.when(
            loading: () => Text('요청 기록 확인 중', style: secondary),
            error: (_, _) => Text('요청 기록을 불러오지 못했어요.', style: secondary),
            data: (records) {
              if (records.isEmpty) {
                return Text('아직 출결 요청 기록이 없어요.', style: secondary);
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    var index = 0;
                    index < records.length && index < 2;
                    index++
                  ) ...[
                    if (index > 0) SizedBox(height: widget.recordGap),
                    Builder(
                      builder: (context) {
                        final record = records[index];
                        final time = toCampusTime(record.requestedAt);
                        String two(int value) =>
                            value.toString().padLeft(2, '0');
                        final timestamp =
                            '${time.year}.${two(time.month)}.${two(time.day)} '
                            '${two(time.hour)}:${two(time.minute)}';
                        final recordContent = InkWell(
                          onTap: widget.onRecordPressed,
                          child: Column(
                            key: ValueKey(
                              'attendance-summary-record-${record.id}',
                            ),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                record.lectureName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(timestamp, style: secondary),
                              if (!record.hasKnownResult)
                                Text(
                                  '서버 결과 확인 불가',
                                  style: secondary?.copyWith(
                                    color: palette.warning,
                                  ),
                                ),
                              Text(
                                record.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                        if (index != 0 ||
                            !_fadeFirstRecord ||
                            MediaQuery.disableAnimationsOf(context)) {
                          return recordContent;
                        }
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 120),
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            alwaysIncludeSemantics: true,
                            child: child,
                          ),
                          child: recordContent,
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
