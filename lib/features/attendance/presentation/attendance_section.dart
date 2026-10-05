import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'attendance_code_form.dart';
import 'attendance_result_dialog.dart';

/// 홈 전자출결 영역
///
/// 출결 화면과 사용자 동작을 담당한다.
class AttendanceSection extends ConsumerStatefulWidget {
  const AttendanceSection({super.key, this.layoutBuilder});

  final Widget Function(Widget content, Widget action)? layoutBuilder;
  @override
  ConsumerState<AttendanceSection> createState() => _AttendanceSectionState();
}

class _AttendanceSectionState extends ConsumerState<AttendanceSection> {
  Completer<String?>? _codeRequest;
  DialogRoute<String>? _codeRoute;
  String? _interactionError;

  @override
  void dispose() {
    _codeRequest?.complete(null);
    _codeRequest = null;
    final route = _codeRoute;
    _codeRoute = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.navigator?.mounted == true && route!.isActive) {
        route.navigator!.removeRoute(route);
      }
    });
    super.dispose();
  }

  void _finishCodeEntry(String? code) {
    final request = _codeRequest;
    if (request == null) return;
    _codeRequest = null;
    final route = _codeRoute;
    _codeRoute = null;
    if (route?.navigator?.mounted == true && route!.isActive) {
      route.navigator!.removeRoute(route);
    }
    request.complete(code);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(attendanceProvider.notifier).fetchLecture();
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(attendanceProvider);
    final lecture = attendance.currentLecture;
    final colorScheme = Theme.of(context).colorScheme;
    final isFetching = attendance.phase == AttendancePhase.fetchingLecture;
    final displayError = _interactionError ?? attendance.error;
    final hasConfirmedLecture =
        lecture != null && attendance.error == null && !isFetching;
    final hasDisplayLecture =
        lecture != null && (hasConfirmedLecture || isFetching);
    final canEnterCode = hasConfirmedLecture && !attendance.isBusy;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return LayoutBuilder(
      builder: (context, constraints) {
        final statusColor = displayError != null
            ? colorScheme.error
            : canEnterCode
            ? palette.brandBlue
            : palette.textSecondary;
        final statusContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      displayError != null
                          ? Icons.error_outline_rounded
                          : canEnterCode
                          ? Icons.check_circle_outline_rounded
                          : switch (attendance.phase) {
                              AttendancePhase.fetchingLecture =>
                                Icons.refresh_rounded,
                              AttendancePhase.enteringCode =>
                                Icons.keyboard_rounded,
                              AttendancePhase.locating =>
                                Icons.location_searching_rounded,
                              AttendancePhase.submitting =>
                                Icons.cloud_upload_outlined,
                              AttendancePhase.idle => Icons.schedule_rounded,
                            },
                      size: 16,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _interactionError != null
                          ? '출결 진행 실패'
                          : _statusTitle(attendance),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (hasDisplayLecture) ...[
              if (isFetching) ...[
                Text(
                  '이전 조회 정보',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                lecture.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    lecture.time,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: attendance.isBusy ? null : _refreshLecture,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.textSecondary,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: Theme.of(context).textTheme.bodySmall,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('수업 정보 새로고침'),
                  ),
                ],
              ),
            ],
            if (!hasConfirmedLecture ||
                attendance.isBusy ||
                displayError != null)
              Padding(
                padding: EdgeInsets.only(top: hasDisplayLecture ? 8 : 0),
                child: Text(
                  displayError ?? _statusDescription(attendance),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: displayError == null
                        ? palette.textSecondary
                        : colorScheme.error,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        );
        final action = ElevatedButton(
          onPressed: attendance.isBusy
              ? null
              : !hasConfirmedLecture
              ? _refreshLecture
              : () => _handleAttendance(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: EdgeInsets.symmetric(horizontal: canEnterCode ? 14 : 18),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: canEnterCode
                ? BorderSide(
                    color: colorScheme.onPrimary.withValues(alpha: 0.24),
                    width: 1.5,
                  )
                : BorderSide.none,
            backgroundColor: canEnterCode
                ? palette.brandBlue
                : colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (canEnterCode) ...[
                const Icon(Icons.edit_note_rounded, size: 18),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  switch (attendance.phase) {
                    AttendancePhase.fetchingLecture => '수업 조회 중',
                    AttendancePhase.enteringCode => '번호 입력 중',
                    AttendancePhase.locating => '위치 확인 중',
                    AttendancePhase.submitting => '출석 제출 중',
                    AttendancePhase.idle =>
                      attendance.error != null
                          ? '다시 시도'
                          : !hasConfirmedLecture
                          ? '수업 새로고침'
                          : '출결 번호 입력',
                  },
                  style: TextStyle(
                    fontSize: canEnterCode ? 16 : 15,
                    fontWeight: canEnterCode
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
        final layout =
            widget.layoutBuilder?.call(statusContent, action) ??
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [statusContent, const SizedBox(height: 16), action],
            );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            layout,
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                // Keep the boolean expansion state separate from scroll offsets.
                key: const PageStorageKey('home-attendance-debug-expansion'),
                tilePadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: const Text('출결 화면 테스트'),
                children: [
                  TextButton.icon(
                    onPressed: attendance.isBusy || lecture != null
                        ? null
                        : () => ref
                              .read(attendanceProvider.notifier)
                              .showDebugSampleLecture(),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('샘플 수업 보기'),
                  ),
                  TextButton.icon(
                    onPressed: attendance.isBusy
                        ? null
                        : () => _showResultDialog(
                            context,
                            const AttendanceSubmissionResult.notice(
                              '출석이 완료됐어요.',
                            ),
                          ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('성공 결과 보기'),
                  ),
                  TextButton.icon(
                    onPressed: attendance.isBusy
                        ? null
                        : () => _showResultDialog(
                            context,
                            const AttendanceSubmissionResult.notice(
                              '인증번호가 올바르지 않아요. 수업에서 안내한 네 자리 번호를 '
                              '확인한 뒤 다시 시도해 주세요.',
                            ),
                          ),
                    icon: const Icon(Icons.error_outline, size: 18),
                    label: const Text('실패 결과 보기'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  String _statusTitle(AttendanceState attendance) {
    if (attendance.error != null) return '수업 조회 실패';
    return switch (attendance.phase) {
      AttendancePhase.fetchingLecture => '수업 조회 중',
      AttendancePhase.enteringCode => '출결 번호 입력 중',
      AttendancePhase.locating => '위치 확인 중',
      AttendancePhase.submitting => '출석 제출 중',
      AttendancePhase.idle =>
        attendance.currentLecture != null
            ? '번호 입력 가능'
            : attendance.hasCheckedLecture
            ? '출결 가능한 수업이 없어요'
            : '수업 확인 전',
    };
  }

  String _statusDescription(AttendanceState attendance) {
    return switch (attendance.phase) {
      AttendancePhase.fetchingLecture => '현재 출결 가능한 수업을 확인하고 있어요.',
      AttendancePhase.enteringCode => '수업에서 안내한 출결 번호를 입력해 주세요.',
      AttendancePhase.locating => '출결을 위해 현재 위치를 확인하고 있어요.',
      AttendancePhase.submitting => '출석 결과를 기다리고 있어요.',
      AttendancePhase.idle =>
        attendance.hasCheckedLecture
            ? '잠시 후 새로고침으로 다시 확인할 수 있어요.'
            : '수업 정보는 조회 결과가 도착한 뒤에 표시돼요.',
    };
  }

  /// 인증번호 입력창 중복 열기 방지
  bool _openingAttendance = false;

  void _refreshLecture() {
    setState(() => _interactionError = null);
    unawaited(
      ref.read(attendanceProvider.notifier).fetchLecture(forceRefresh: true),
    );
  }

  Future<void> _handleAttendance(BuildContext context) async {
    if (_openingAttendance) return;
    _openingAttendance = true;
    setState(() => _interactionError = null);
    final controller = ref.read(attendanceProvider.notifier);
    final session = ref.read(homeControllerProvider);
    var sessionChanged = false;
    final subscription = ref.listenManual(homeControllerProvider, (_, next) {
      if (!next.isLoggedIn || next.userId != session.userId) {
        sessionChanged = true;
        if (mounted) _finishCodeEntry(null);
      }
    });
    try {
      await controller.fetchLecture();
      if (!context.mounted || sessionChanged || !session.isLoggedIn) return;
      final attendance = ref.read(attendanceProvider);
      final lecture = attendance.currentLecture;
      if (lecture == null || attendance.error != null) return;
      final result = await controller.performAttendance(
        userId: session.userId,
        requestAuthCode: () {
          final request = Completer<String?>();
          _codeRequest = request;
          final route = DialogRoute<String>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              constraints: const BoxConstraints(maxWidth: 360),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: AttendanceCodeForm(
                  lecture: lecture,
                  onSubmit: (code) => Navigator.of(dialogContext).pop(code),
                  onCancel: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          );
          _codeRoute = route;
          unawaited(
            Navigator.of(context, rootNavigator: true).push(route).then((code) {
              if (identical(_codeRequest, request)) _finishCodeEntry(code);
            }),
          );
          return request.future;
        },
        canContinue: () =>
            context.mounted && session.isLoggedIn && !sessionChanged,
      );
      if (context.mounted && !sessionChanged && result != null) {
        _showResultDialog(context, result);
      }
    } catch (e) {
      if (context.mounted && !sessionChanged) {
        final message = e.toString().replaceFirst('Exception: ', '');
        if (MediaQuery.sizeOf(context).width >= 960) {
          setState(() => _interactionError = message);
        } else {
          _showSnackBar(context, message);
        }
      }
    } finally {
      _openingAttendance = false;
      subscription.close();
    }
  }

  void _showResultDialog(
    BuildContext context,
    AttendanceSubmissionResult result,
  ) {
    if (!kIsWeb) {
      unawaited(HapticFeedback.lightImpact());
    }
    showDialog(
      context: context,
      builder: (context) => AttendanceResultDialog(result: result),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
