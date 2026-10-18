import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_animated_switcher.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'attendance_code_form.dart';
import 'attendance_result_dialog.dart';
import 'attendance_status_message.dart';

class AttendancePresentation {
  const AttendancePresentation({
    required this.lecture,
    required this.lectureKey,
    required this.status,
    required this.action,
  });

  final Widget? lecture;
  final Object? lectureKey;
  final AttendanceStatusMessage status;
  final Widget action;

  Object get statusKey => (
    status.title,
    status.description,
    status.icon,
    status.isError,
    status.isReady,
  );
}

/// 홈 전자출결 영역
///
/// 출결 화면과 사용자 동작을 담당한다.
class AttendanceSection extends ConsumerStatefulWidget {
  const AttendanceSection({
    super.key,
    this.layoutBuilder,
    this.presentationBuilder,
    this.informationExtraSpace = 0,
    this.informationGap = 12,
    this.lectureGap = 8,
    this.onInteractionChanged,
  });

  final Widget Function(Widget content, Widget action)? layoutBuilder;
  final Widget Function(AttendancePresentation presentation)?
  presentationBuilder;
  final double informationExtraSpace;
  final double informationGap;
  final double lectureGap;
  final ValueChanged<bool>? onInteractionChanged;
  @override
  ConsumerState<AttendanceSection> createState() => _AttendanceSectionState();
}

class _AttendanceSectionState extends ConsumerState<AttendanceSection> {
  Completer<String?>? _codeRequest;
  DialogRoute<String>? _codeRoute;
  DialogRoute<void>? _resultRoute;
  String? _interactionError;
  int _backdropHolds = 0;
  Future<void>? _codeExit;

  void _holdBackdrop() {
    if (_backdropHolds++ == 0) widget.onInteractionChanged?.call(true);
  }

  void _releaseBackdrop() {
    if (_backdropHolds > 0 && --_backdropHolds == 0) {
      widget.onInteractionChanged?.call(false);
    }
  }

  @override
  void dispose() {
    _codeRequest?.complete(null);
    _codeRequest = null;
    final route = _codeRoute;
    final resultRoute = _resultRoute;
    final releaseBackdrop = _backdropHolds > 0
        ? widget.onInteractionChanged
        : null;
    _codeRoute = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      releaseBackdrop?.call(false);
      if (route?.navigator?.mounted == true && route!.isActive) {
        route.navigator!.removeRoute(route);
      }
      if (resultRoute?.navigator?.mounted == true && resultRoute!.isActive) {
        resultRoute.navigator!.removeRoute(resultRoute);
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

  Future<String?> _requestAttendanceDialog(
    BuildContext context,
    WidgetBuilder builder, {
    bool codeEntry = false,
  }) {
    if (!context.mounted) return Future.value(null);
    final request = Completer<String?>();
    _codeRequest = request;
    final route = codeEntry
        ? AttendanceCodeRoute<String>(context: context, builder: builder)
        : DialogRoute<String>(
            context: context,
            builder: builder,
            barrierDismissible: false,
          );
    _codeRoute = route;
    _holdBackdrop();
    _codeExit = route.completed.then((_) {
      if (mounted) _releaseBackdrop();
    });
    unawaited(
      Navigator.of(context, rootNavigator: true).push(route).then((code) {
        if (identical(_codeRequest, request)) _finishCodeEntry(code);
      }),
    );
    // Processing may start as soon as pop returns. The caller keeps the
    // backdrop held until the route has also finished painting its exit.
    return codeEntry
        ? request.future
        : request.future.then((value) async {
            await route.completed;
            return value;
          });
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
    ref.listen(attendanceProvider, (previous, next) {
      if (next.phase == AttendancePhase.fetchingLecture) {
        _interactionError = null;
      }
    });
    final attendance = ref.watch(attendanceProvider);
    final lecture = attendance.currentLecture;
    final colorScheme = Theme.of(context).colorScheme;
    final isFetching = attendance.phase == AttendancePhase.fetchingLecture;
    final submissionResult = attendance.submissionResult;
    final displayError =
        _interactionError ??
        (submissionResult == null ? attendance.error : null);
    final description =
        submissionResult?.message ??
        (displayError != null && attendance.isLectureStale && lecture != null
            ? '$displayError 이전 조회 정보'
            : displayError) ??
        ((isFetching || attendance.isLectureStale) && lecture != null
            ? '이전 조회 정보'
            : _statusDescription(attendance));
    final hasConfirmedLecture =
        submissionResult == null &&
        lecture != null &&
        attendance.error == null &&
        !attendance.sessionExpired &&
        !attendance.isLectureStale &&
        !isFetching;
    final hasDisplayLecture = attendance.hasDisplayLecture;
    final canEnterCode = hasConfirmedLecture && !attendance.isBusy;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = MediaQuery.sizeOf(context).width < 600;
        final statusMessage = AttendanceStatusMessage(
          key: const ValueKey('attendance-status-message'),
          title: _interactionError != null
              ? '출결 진행 실패'
              : _statusTitle(attendance),
          description: description,
          reserveDescriptionSpace: MediaQuery.sizeOf(context).width >= 600,
          isError: displayError != null || (submissionResult?.isError ?? false),
          isReady: canEnterCode,
          icon: submissionResult != null
              ? submissionResult.isError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded
              : displayError != null
              ? Icons.error_outline_rounded
              : canEnterCode
              ? Icons.check_circle_outline_rounded
              : switch (attendance.phase) {
                  AttendancePhase.fetchingLecture => Icons.refresh_rounded,
                  AttendancePhase.enteringCode => Icons.keyboard_rounded,
                  AttendancePhase.locating => Icons.location_searching_rounded,
                  AttendancePhase.submitting => Icons.cloud_upload_outlined,
                  AttendancePhase.idle => Icons.schedule_rounded,
                },
        );
        final lectureContent = hasDisplayLecture && lecture != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lecture.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: widget.lectureGap),
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
                          tapTargetSize: mobile
                              ? MaterialTapTargetSize.shrinkWrap
                              : null,
                          visualDensity: mobile ? VisualDensity.standard : null,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: Theme.of(context).textTheme.bodySmall,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('수업 정보 새로고침'),
                      ),
                    ],
                  ),
                ],
              )
            : null;
        final lectureInformation = lectureContent == null
            ? null
            : Padding(
                key: const ValueKey('attendance-lecture-information'),
                padding: EdgeInsets.symmetric(
                  vertical: mobile ? widget.informationExtraSpace / 2 : 0,
                ),
                child: lectureContent,
              );
        final statusContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mobile || lectureContent == null) statusMessage,
            if (lectureContent != null) ...[
              if (!mobile) SizedBox(height: widget.informationGap),
              lectureInformation!,
              if (mobile) ...[
                SizedBox(height: widget.informationGap),
                statusMessage,
              ],
            ],
          ],
        );
        final actionTitle = switch (attendance.phase) {
          AttendancePhase.fetchingLecture =>
            submissionResult != null ? '수업 확인 중' : '수업 조회 중',
          AttendancePhase.enteringCode => '번호 입력 중',
          AttendancePhase.locating => '위치 확인 중',
          AttendancePhase.submitting => '출석 제출 중',
          AttendancePhase.idle =>
            submissionResult != null
                ? '수업 다시 확인'
                : attendance.error != null
                ? '다시 시도'
                : _interactionError != null && hasConfirmedLecture
                ? '출결 다시 시도'
                : !hasConfirmedLecture
                ? '수업 새로고침'
                : '출결 번호 입력',
        };
        final action = ElevatedButton(
          onPressed: attendance.isBusy
              ? null
              : !hasConfirmedLecture
              ? _refreshLecture
              : () => _handleAttendance(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            tapTargetSize: mobile ? MaterialTapTargetSize.shrinkWrap : null,
            visualDensity: mobile ? VisualDensity.standard : null,
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                ? Theme.of(context).brightness == Brightness.light
                      ? palette.brandNavy
                      : palette.brandBlue
                : colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                child: AnimatedOpacity(
                  opacity: canEnterCode ? 1 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 120),
                  child: const Icon(Icons.edit_note_rounded, size: 18),
                ),
              ),
              Expanded(
                child: AppAnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final outgoing in previous)
                        Positioned.fill(child: outgoing),
                      current ?? const SizedBox.shrink(),
                    ],
                  ),
                  child: Text(
                    actionTitle,
                    key: ValueKey(actionTitle),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
        if (widget.presentationBuilder case final builder?) {
          return builder(
            AttendancePresentation(
              lecture: lectureInformation,
              lectureKey: lectureInformation == null
                  ? null
                  : (lecture!.name, lecture.time),
              status: statusMessage,
              action: action,
            ),
          );
        }
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
          children: [layout],
        );
      },
    );
  }

  String _statusTitle(AttendanceState attendance) {
    final result = attendance.submissionResult;
    if (result != null) {
      return result.isUnconfirmed ? '출결 처리 여부 확인 불가' : '출결 안내';
    }
    if (attendance.isLectureStale && !attendance.sessionExpired) {
      return attendance.error == null ? '수업 정보 확인 중' : '학교 연결 지연';
    }
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

  String? _statusDescription(AttendanceState attendance) {
    return switch (attendance.phase) {
      AttendancePhase.fetchingLecture => null,
      AttendancePhase.enteringCode => '수업에서 안내한 출결 번호를 입력해 주세요.',
      AttendancePhase.locating => null,
      AttendancePhase.submitting => null,
      AttendancePhase.idle => null,
    };
  }

  /// 인증번호 입력창 중복 열기 방지
  bool _openingAttendance = false;

  void _refreshLecture() {
    setState(() => _interactionError = null);
    unawaited(ref.read(attendanceProvider.notifier).refreshLectureForInput());
  }

  Future<void> _handleAttendance(BuildContext context) async {
    if (_openingAttendance) return;
    _openingAttendance = true;
    _holdBackdrop();
    setState(() => _interactionError = null);
    final controller = ref.read(attendanceProvider.notifier);
    final session = ref.read(homeControllerProvider);
    var sessionChanged = false;
    final subscription = ref.listenManual(homeControllerProvider, (_, next) {
      if (!next.isLoggedIn || next.userId != session.userId) {
        sessionChanged = true;
        if (mounted) _finishCodeEntry(null);
        final resultRoute = _resultRoute;
        if (resultRoute?.navigator?.mounted == true && resultRoute!.isActive) {
          resultRoute.navigator!.removeRoute(resultRoute);
        }
      }
    });
    try {
      await controller.fetchLecture();
      if (!context.mounted || sessionChanged || !session.isLoggedIn) return;
      final attendance = ref.read(attendanceProvider);
      final lecture = attendance.currentLecture;
      if (lecture == null ||
          attendance.error != null ||
          attendance.isLectureStale) {
        return;
      }
      final result = await controller.performAttendance(
        userId: session.userId,
        confirmUnconfirmedRetry: (_) async =>
            await _requestAttendanceDialog(
              context,
              (dialogContext) => AlertDialog(
                key: const ValueKey('attendance-retry-confirmation'),
                scrollable: true,
                title: const Text('출결 결과 확인'),
                content: const Text(
                  '이전 요청의 처리 여부를 확인하지 못했어요. 학교 출결 내역을 확인한 뒤 다시 입력해 주세요. 다시 입력하면 요청을 한 번 더 보내요.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop('retry'),
                    child: const Text('다시 입력'),
                  ),
                ],
              ),
            ) ==
            'retry',
        requestAuthCode: () => _requestAttendanceDialog(
          context,
          (dialogContext) => AttendanceCodeDialog(
            lecture: lecture,
            onSubmit: (code) => Navigator.of(dialogContext).pop(code),
            onCancel: () => Navigator.of(dialogContext).pop(),
          ),
          codeEntry: true,
        ),
        canContinue: () =>
            context.mounted && session.isLoggedIn && !sessionChanged,
      );
      if (context.mounted && !sessionChanged && result != null) {
        await _codeExit;
        if (!context.mounted || sessionChanged) return;
        await _showResultDialog(context, result);
      }
    } catch (e) {
      if (context.mounted && !sessionChanged) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() => _interactionError = message);
      }
    } finally {
      _openingAttendance = false;
      subscription.close();
      if (mounted) _releaseBackdrop();
    }
  }

  Future<void> _showResultDialog(
    BuildContext context,
    AttendanceSubmissionResult result,
  ) async {
    if (!kIsWeb) {
      unawaited(HapticFeedback.lightImpact());
    }
    _holdBackdrop();
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => AttendanceResultDialog(result: result),
    );
    _resultRoute = route;
    try {
      await Navigator.of(context, rootNavigator: true).push(route);
      await route.completed;
    } finally {
      if (identical(_resultRoute, route)) _resultRoute = null;
      if (mounted) _releaseBackdrop();
    }
  }
}
