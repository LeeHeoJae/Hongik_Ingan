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
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return LayoutBuilder(
      builder: (context, constraints) {
        final statusContent = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.cardSurfaceMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  _interactionError != null
                      ? '출결 진행 실패'
                      : _statusTitle(attendance),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: displayError == null
                        ? colorScheme.onSurface
                        : colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (hasConfirmedLecture && displayError == null) ...[
                Text(
                  lecture.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(lecture.time),
              ] else
                Text(
                  displayError ?? _statusDescription(attendance),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: displayError == null
                        ? palette.textSecondary
                        : colorScheme.error,
                  ),
                ),
            ],
          ),
        );
        final action = ElevatedButton(
          onPressed: attendance.isBusy
              ? null
              : !hasConfirmedLecture
              ? _refreshLecture
              : () => _handleAttendance(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
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
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            statusContent,
            if (hasConfirmedLecture) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: attendance.isBusy ? null : _refreshLecture,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('수업 정보 새로고침'),
              ),
              const SizedBox(height: 6),
              Text(
                '번호를 입력한 뒤 현재 위치를 확인하고 제출해요.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
              ),
            ],
          ],
        );
        final layout =
            widget.layoutBuilder?.call(content, action) ??
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content, const SizedBox(height: 12), action],
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
            ? '수업 확인 완료'
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
