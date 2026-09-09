import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'attendance_code_form.dart';
import 'attendance_result_dialog.dart';

/// 홈 전자출결 영역
///
/// 출결 화면과 사용자 동작을 담당한다.
class AttendanceSection extends ConsumerStatefulWidget {
  const AttendanceSection({super.key});
  @override
  ConsumerState<AttendanceSection> createState() => _AttendanceSectionState();
}

class _AttendanceSectionState extends ConsumerState<AttendanceSection> {
  Completer<String?>? _codeRequest;
  DialogRoute<String>? _codeRoute;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          attendance.error ??
              (lecture == null
                  ? attendance.isBusy
                        ? '수업 정보를 확인하고 있어요.'
                        : '현재 출석 가능한 수업이 없어요.'
                  : lecture.name),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: attendance.error == null
                ? colorScheme.onSurface
                : colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (lecture != null && attendance.error == null) ...[
          const SizedBox(height: 6),
          Text(lecture.time, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            '제출 후 출석 확인을 위해 현재 위치를 확인합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: attendance.isBusy
              ? null
              : lecture == null || attendance.error != null
              ? () => ref
                    .read(attendanceProvider.notifier)
                    .fetchLecture(forceRefresh: true)
              : () => _handleAttendance(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 58),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: isDark ? 0 : 1,
            shadowColor: isDark
                ? Colors.transparent
                : Colors.black.withValues(alpha: 0.12),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: Text(switch (attendance.phase) {
            AttendancePhase.fetchingLecture => '수업 확인 중',
            AttendancePhase.enteringCode => '번호 입력 중',
            AttendancePhase.locating => '위치 확인 중',
            AttendancePhase.submitting => '출석 제출 중',
            AttendancePhase.idle =>
              attendance.error != null
                  ? '다시 시도'
                  : lecture == null
                  ? '새로고침'
                  : '출결 번호 입력',
          }, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          ExpansionTile(
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
                        const AttendanceSubmissionResult.notice('출석이 완료됐어요.'),
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
  }

  /// 인증번호 입력창 중복 열기 방지
  bool _openingAttendance = false;

  Future<void> _handleAttendance(BuildContext context) async {
    if (_openingAttendance) return;
    _openingAttendance = true;
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
        _showSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
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
