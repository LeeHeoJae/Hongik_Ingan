import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import '../application/attendance_history_provider.dart';

/// A short preview with a direct link to the full request history.
class AttendanceHistorySummary extends ConsumerWidget {
  const AttendanceHistorySummary({
    super.key,
    required this.userId,
    this.onRecordPressed,
    this.extraSpace = 0,
    this.headingGap = 8,
    this.recordGap = 12,
  });

  final String userId;
  final VoidCallback? onRecordPressed;
  final double extraSpace;
  final double headingGap;
  final double recordGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: palette.textSecondary,
      height: 1.4,
    );
    Widget historyAction() => TextButton.icon(
      key: const ValueKey('attendance-history-summary-action'),
      onPressed: onRecordPressed,
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
    final history = ref.watch(attendanceHistoryProvider(userId));
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
        SizedBox(height: headingGap),
        Padding(
          key: const ValueKey('attendance-history-summary-body'),
          padding: EdgeInsets.symmetric(vertical: extraSpace / 2),
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
                    if (index > 0) SizedBox(height: recordGap),
                    Builder(
                      builder: (context) {
                        final record = records[index];
                        final time = toCampusTime(record.requestedAt);
                        String two(int value) =>
                            value.toString().padLeft(2, '0');
                        final timestamp =
                            '${time.year}.${two(time.month)}.${two(time.day)} '
                            '${two(time.hour)}:${two(time.minute)}';
                        return InkWell(
                          onTap: onRecordPressed,
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
