import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/presentation/widgets/content_loading_skeleton.dart';
import 'package:hongik_ingan/core/presentation/widgets/content_state_message.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

class AttendanceHistoryButton extends ConsumerWidget {
  const AttendanceHistoryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(homeControllerProvider);
    final userId = session.userId;
    if (!session.isLoggedIn || userId == null || userId.isEmpty) {
      return const SizedBox.shrink();
    }
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    void open() {
      ref.invalidate(attendanceHistoryProvider(userId));
      unawaited(showAttendanceHistory(context, userId));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabel =
            MediaQuery.sizeOf(context).width >= 960 &&
            MediaQuery.textScalerOf(context).scale(14) <= 19;
        if (!showLabel) {
          return IconButton(
            key: const ValueKey('attendance-history-button'),
            onPressed: open,
            tooltip: '요청 기록',
            color: palette.textSecondary,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.history_rounded, size: 20),
          );
        }
        return TextButton.icon(
          key: const ValueKey('attendance-history-button'),
          onPressed: open,
          style: TextButton.styleFrom(
            foregroundColor: palette.textSecondary,
            minimumSize: const Size(44, 44),
            textStyle: Theme.of(context).textTheme.bodySmall,
          ),
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('요청 기록'),
        );
      },
    );
  }
}

Future<void> showAttendanceHistory(BuildContext context, String userId) async {
  final media = MediaQuery.of(context);
  final view = AttendanceHistoryView(userId: userId);
  if (media.size.width < 960) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
        child: SafeArea(top: false, child: view),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 560,
          height: (media.size.height * 0.8).clamp(0, 600).toDouble(),
          child: view,
        ),
      ),
    );
  }
}

class AttendanceHistoryView extends ConsumerStatefulWidget {
  const AttendanceHistoryView({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<AttendanceHistoryView> createState() =>
      _AttendanceHistoryViewState();
}

class _AttendanceHistoryViewState extends ConsumerState<AttendanceHistoryView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(homeControllerProvider);
    if (!session.isLoggedIn || session.userId != widget.userId) {
      // Hide the old account immediately, even while its storage read is pending.
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || route == null || !route.isActive) return;
        if (route.isCurrent) {
          route.navigator?.pop();
        } else {
          route.navigator?.removeRoute(route);
        }
      });
      return const SizedBox.shrink();
    }
    final history = ref.watch(attendanceHistoryProvider(widget.userId));
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '최근 출결 요청',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '닫기',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: history.when(
              skipLoadingOnRefresh: false,
              loading: () => const ContentLoadingSkeleton(itemCount: 2),
              error: (_, _) => ContentStateMessage(
                icon: Icons.error_outline_rounded,
                title: '요청 기록을 불러오지 못했어요.',
                message: '잠시 후 다시 시도해 주세요.',
                tone: ContentStateTone.error,
                actionLabel: '다시 시도',
                onAction: () =>
                    ref.invalidate(attendanceHistoryProvider(widget.userId)),
              ),
              data: (records) {
                if (records.isEmpty) {
                  return const ContentStateMessage(
                    icon: Icons.history_rounded,
                    title: '아직 출결 요청 기록이 없어요.',
                    message: '이 기기에서 보낸 최근 20건을 보여줘요.',
                  );
                }
                return Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    itemCount: records.length + 1,
                    separatorBuilder: (context, index) => index == 0
                        ? const SizedBox(height: 16)
                        : Divider(height: 28, color: palette.cardOutline),
                    itemBuilder: (context, index) => index == 0
                        ? Text(
                            '이 기기에서 보낸 최근 20건이에요.\n요청 시각은 한국 시간 기준이에요.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondary,
                              height: 1.5,
                            ),
                          )
                        : _HistoryRecord(record: records[index - 1]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRecord extends StatelessWidget {
  const _HistoryRecord({required this.record});

  final AttendanceRequestRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<HongikPalette>() ?? HongikPalette.light;
    final time = toCampusTime(record.requestedAt);
    String two(int value) => value.toString().padLeft(2, '0');
    final timestamp =
        '${time.year}.${two(time.month)}.${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          record.lectureName,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '요청 시각  $timestamp',
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text('출결 번호  ${record.authCode}', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(
          record.hasServerResponse ? '서버 응답' : '서버 결과 확인 불가',
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          record.message,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
