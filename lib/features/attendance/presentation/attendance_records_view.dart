import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_segmented_selector.dart';
import 'package:hongik_ingan/core/presentation/widgets/content_loading_skeleton.dart';
import 'package:hongik_ingan/core/presentation/widgets/content_state_message.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import '../application/attendance_controller.dart';
import '../application/attendance_history_provider.dart';
import '../application/attendance_overview_provider.dart';
import '../data/attendance_overview_service.dart';
import '../domain/attendance_overview.dart';
import 'attendance_history_view.dart';
import 'school_attendance_table.dart';

enum AttendanceRecordsTab { school, requests }

class AttendanceRecordsButton extends ConsumerWidget {
  const AttendanceRecordsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy =
        ref.watch(attendanceProvider.select((state) => state.isBusy)) ||
        ref.watch(homeControllerProvider.select((state) => state.isLoading));
    final userId = ref.watch(
      homeControllerProvider.select(
        (state) => state.isLoggedIn ? state.userId : null,
      ),
    );
    if (userId == null) return const SizedBox.shrink();
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;
    void open() => unawaited(showAttendanceRecords(context, userId));
    if (MediaQuery.textScalerOf(context).scale(14) > 19 ||
        MediaQuery.sizeOf(context).width < 360) {
      return IconButton(
        key: const ValueKey('attendance-history-button'),
        tooltip: '출결 내역',
        onPressed: busy ? null : open,
        color: palette.textSecondary,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        icon: const Icon(Icons.history_rounded, size: 20),
      );
    }
    return TextButton.icon(
      key: const ValueKey('attendance-history-button'),
      onPressed: busy ? null : open,
      style: TextButton.styleFrom(
        foregroundColor: palette.textSecondary,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: Theme.of(context).textTheme.bodySmall,
      ),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.chevron_right_rounded, size: 16),
      label: const Text('출결 내역'),
    );
  }
}

Future<void> showAttendanceRecords(
  BuildContext context,
  String userId, {
  AttendanceRecordsTab initialTab = AttendanceRecordsTab.school,
}) async {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).invalidate(attendanceHistoryProvider(userId));
  final media = MediaQuery.of(context);
  final view = AttendanceRecordsView(userId: userId, initialTab: initialTab);
  if (media.size.width < 960) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: media.size.height < 600 ? 1 : 0.85,
        child: SafeArea(top: false, child: view),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 560,
          height: (media.size.height * 0.85).clamp(0, 700).toDouble(),
          child: view,
        ),
      ),
    );
  }
}

class AttendanceRecordsView extends ConsumerStatefulWidget {
  const AttendanceRecordsView({
    super.key,
    required this.userId,
    this.initialTab = AttendanceRecordsTab.school,
  });
  final String userId;
  final AttendanceRecordsTab initialTab;
  @override
  ConsumerState<AttendanceRecordsView> createState() =>
      _AttendanceRecordsViewState();
}

class _AttendanceRecordsViewState extends ConsumerState<AttendanceRecordsView> {
  late AttendanceRecordsTab _tab = widget.initialTab;
  late bool _schoolOpened = _tab == AttendanceRecordsTab.school;
  AttendanceCourse? _selectedCourse;
  AttendanceCourse? _requestFilter;

  void _showRequests(AttendanceCourse course) {
    ref.invalidate(attendanceHistoryProvider(widget.userId));
    setState(() {
      _tab = AttendanceRecordsTab.requests;
      _requestFilter = course;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(homeControllerProvider);
    if (!session.isLoggedIn || session.userId != widget.userId) {
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
    final detailOpen =
        _tab == AttendanceRecordsTab.school && _selectedCourse != null;
    return PopScope(
      canPop: !detailOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && detailOpen) setState(() => _selectedCourse = null);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '출결 내역',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, semanticLabel: '닫기'),
                ),
              ],
            ),
            AppSegmentedSelector<AttendanceRecordsTab>(
              items: AttendanceRecordsTab.values,
              selectedItem: _tab,
              labelOf: (tab) =>
                  tab == AttendanceRecordsTab.school ? '학교 출결' : '요청 기록',
              onSelected: (tab) => setState(() {
                _tab = tab;
                if (tab == AttendanceRecordsTab.school) _schoolOpened = true;
              }),
            ),
            const SizedBox(height: 12),
            if (_tab == AttendanceRecordsTab.requests && _requestFilter != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _requestFilter = null),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('전체 요청 기록'),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                children: [
                  if (_schoolOpened)
                    _SchoolAttendanceView(
                      selectedCourse: _selectedCourse,
                      onSelected: (course) {
                        setState(() => _selectedCourse = course);
                        if (course != null) {
                          unawaited(
                            ref
                                .read(attendanceOverviewProvider.notifier)
                                .loadDetail(course),
                          );
                        }
                      },
                      onShowRequests: _showRequests,
                    )
                  else
                    const SizedBox.shrink(),
                  AttendanceHistoryView(
                    userId: widget.userId,
                    embedded: true,
                    courseFilter: _requestFilter,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolAttendanceView extends ConsumerWidget {
  const _SchoolAttendanceView({
    required this.selectedCourse,
    required this.onSelected,
    required this.onShowRequests,
  });
  final AttendanceCourse? selectedCourse;
  final ValueChanged<AttendanceCourse?> onSelected;
  final ValueChanged<AttendanceCourse> onShowRequests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(attendanceOverviewProvider);
    final controller = ref.read(attendanceOverviewProvider.notifier);
    final course = selectedCourse;
    final busy =
        ref.watch(attendanceProvider.select((state) => state.isBusy)) ||
        ref.watch(homeControllerProvider.select((state) => state.isLoading));
    final value = course == null
        ? overview.courses
        : overview.details[course.key.id];
    final refreshing = course == null
        ? overview.refreshingCourses
        : overview.refreshingDetails.contains(course.key.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (course != null)
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  semanticLabel: '과목 목록',
                ),
                onPressed: () => onSelected(null),
              ),
            Expanded(
              child: Text(
                course?.name ?? '수강과목',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Semantics(
              container: true,
              label: '학교 출결 새로고침',
              child: IconButton(
                onPressed: busy || refreshing || value?.isLoading == true
                    ? null
                    : () {
                        if (course == null) {
                          unawaited(controller.loadCourses(refresh: true));
                        } else {
                          unawaited(
                            controller.loadDetail(course, refresh: true),
                          );
                        }
                      },
                icon: refreshing && value?.hasValue == true
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        ),
        Expanded(
          child: course == null
              ? overview.courses.when(
                  skipLoadingOnRefresh: false,
                  loading: () => const ContentLoadingSkeleton(itemCount: 3),
                  error: (error, _) => _OverviewError(
                    error: error,
                    onRetry: () => controller.loadCourses(refresh: true),
                  ),
                  data: (courses) {
                    if (courses.isEmpty) {
                      return const ContentStateMessage(
                        icon: Icons.school_outlined,
                        title: '수강과목이 없어요.',
                        message: '',
                      );
                    }
                    return ListView.separated(
                      key: const PageStorageKey('attendance-courses'),
                      itemCount: courses.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final item = courses[index];
                        final detail =
                            overview.details[item.key.id]?.asData?.value;
                        return ListTile(
                          key: ValueKey('attendance-course-${item.key.id}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.key.termLabel} · ${item.codeLabel}'
                            '${detail == null
                                ? ''
                                : detail.isPublished
                                ? ' · 출결표 공개'
                                : ' · 출석부 비공개'}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: busy ? null : () => onSelected(item),
                        );
                      },
                    );
                  },
                )
              : (overview.details[course.key.id] ??
                        const AsyncLoading<SchoolAttendanceDetail>())
                    .when(
                      skipLoadingOnRefresh: false,
                      loading: () => const ContentLoadingSkeleton(itemCount: 3),
                      error: (error, _) => _OverviewError(
                        error: error,
                        onRetry: () =>
                            controller.loadDetail(course, refresh: true),
                      ),
                      data: (detail) => _SchoolAttendanceDetailView(
                        detail: detail,
                        onShowRequests: () => onShowRequests(course),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _OverviewError extends StatelessWidget {
  const _OverviewError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ContentStateMessage(
    icon: Icons.error_outline_rounded,
    title: '학교 출결을 확인하지 못했어요.',
    message: error is AttendanceOverviewException
        ? (error as AttendanceOverviewException).message
        : '잠시 후 다시 시도해 주세요.',
    tone: ContentStateTone.error,
    actionLabel: '다시 시도',
    onAction: onRetry,
  );
}

class _SchoolAttendanceDetailView extends StatelessWidget {
  const _SchoolAttendanceDetailView({
    required this.detail,
    required this.onShowRequests,
  });
  final SchoolAttendanceDetail detail;
  final VoidCallback onShowRequests;
  @override
  Widget build(BuildContext context) {
    if (!detail.isPublished) {
      return ContentStateMessage(
        icon: Icons.lock_outline_rounded,
        title: '출석부가 공개되지 않았어요.',
        message: '학교에서 이 과목의 출결표를 공개하지 않았어요.',
        actionLabel: '이 과목의 요청 기록 보기',
        actionIcon: Icons.history_rounded,
        onAction: onShowRequests,
      );
    }
    if (detail.entries.isEmpty) {
      return const ContentStateMessage(
        icon: Icons.event_note_outlined,
        title: '아직 학교 출결 내역이 없어요.',
        message: '',
      );
    }
    return SchoolAttendanceTable(
      key: ValueKey(detail.course.key.id),
      detail: detail,
    );
  }
}
