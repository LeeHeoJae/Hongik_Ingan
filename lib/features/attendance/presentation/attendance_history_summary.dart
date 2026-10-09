import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import '../application/attendance_history_provider.dart';

/// A short preview; the panel heading provides access to the full history.
class AttendanceHistorySummary extends ConsumerWidget {
  const AttendanceHistorySummary({
    super.key,
    required this.userId,
    this.trailing,
    this.onRecordPressed,
    this.extraSpace = 0,
  });

  final String userId;
  final Widget? trailing;
  final VoidCallback? onRecordPressed;
  final double extraSpace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: palette.textSecondary,
      height: 1.4,
    );
    final history = ref.watch(attendanceHistoryProvider(userId));
    if (history.asData?.value.isEmpty == true &&
        MediaQuery.sizeOf(context).width >= 960 &&
        MediaQuery.textScalerOf(context).scale(14) <= 19) {
      return Row(
        key: const ValueKey('attendance-history-summary'),
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('최근 출결 요청', style: theme.textTheme.bodySmall),
                Text(
                  '아직 출결 요청 기록이 없어요.',
                  key: const ValueKey('attendance-history-summary-body'),
                  style: secondary,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      );
    }
    return Column(
      key: const ValueKey('attendance-history-summary'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('최근 출결 요청', style: theme.textTheme.titleSmall),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
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
                    if (index > 0) const SizedBox(height: 12),
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
