import 'dart:async';
import 'package:hongik_ingan/core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_animated_switcher.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/domain/session_recovery_result.dart';
import 'attendance_code_form.dart';
import 'attendance_dialog_state.dart';
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
    this.presentationState,
    this.recoveryPhase = SessionRecoveryPhase.idle,
    this.sessionLoading = false,
  });

  final Widget Function(Widget content, Widget action)? layoutBuilder;
  final Widget Function(AttendancePresentation presentation)?
  presentationBuilder;
  final double informationExtraSpace;
  final double informationGap;
  final double lectureGap;
  final ValueChanged<bool>? onInteractionChanged;
  final AttendanceState? presentationState;
  final SessionRecoveryPhase recoveryPhase;
  final bool sessionLoading;
  @override
  ConsumerState<AttendanceSection> createState() => _AttendanceSectionState();
}

class _AttendanceSectionState extends ConsumerState<AttendanceSection> {
  Completer<String?>? _codeRequest;
  DialogRoute<String>? _codeRoute;
  DialogRoute<void>? _flowRoute;
  ValueNotifier<AttendanceDialogState>? _flow;
  String? _interactionError;
  int _backdropHolds = 0;
  Future<void>? _flowExit;

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
    final resultRoute = _flowRoute;
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
    WidgetBuilder builder,
  ) {
    if (!context.mounted) return Future.value(null);
    final request = Completer<String?>();
    _codeRequest = request;
    final route = DialogRoute<String>(
      context: context,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: builder,
      barrierDismissible: false,
    );
    _codeRoute = route;
    _holdBackdrop();
    final exit = route.completed.then((_) {
      if (mounted) _releaseBackdrop();
    });
    unawaited(
      Navigator.of(context, rootNavigator: true).push(route).then((code) {
        if (identical(_codeRequest, request)) _finishCodeEntry(code);
      }),
    );
    // Keep the retry confirmation's backdrop until its exit has finished.
    return request.future.then((value) async {
      await exit;
      return value;
    });
  }

  Future<String?> _requestFlowCode(BuildContext context, Lecture lecture) {
    final request = Completer<String?>();
    _codeRequest = request;
    final flow = ValueNotifier(const AttendanceDialogState.input());
    _flow = flow;
    final route = AttendanceCodeRoute<void>(
      context: context,
      builder: (dialogContext) => AttendanceCodeDialog(
        lecture: lecture,
        flow: flow,
        onSubmit: (code) {
          if (!identical(_codeRequest, request) || request.isCompleted) return;
          _codeRequest = null;
          flow.value = const AttendanceDialogState.processing('위치를 확인하고 있어요.');
          request.complete(code);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
    _flowRoute = route;
    _holdBackdrop();
    _flowExit = route.completed.then((_) {
      if (identical(_flowRoute, route)) _flowRoute = null;
      if (identical(_flow, flow)) _flow = null;
      flow.dispose();
      if (mounted) _releaseBackdrop();
    });
    unawaited(
      Navigator.of(context, rootNavigator: true).push(route).then((_) {
        if (identical(_codeRequest, request)) {
          _codeRequest = null;
          if (!request.isCompleted) request.complete(null);
        }
      }),
    );
    return request.future;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref
              .read(attendanceProvider.notifier)
              .fetchLecture(forceRefresh: true),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(attendanceProvider, (previous, next) {
      if (_flow?.value.stage == AttendanceDialogStage.processing &&
          (next.phase == AttendancePhase.locating ||
              next.phase == AttendancePhase.submitting)) {
        final message = next.phase == AttendancePhase.submitting
            ? '출석을 제출하고 있어요.'
            : '위치를 확인하고 있어요.';
        if (_flow!.value.message != message) {
          _flow!.value = AttendanceDialogState.processing(message);
        }
      }
      if (next.phase == AttendancePhase.fetchingLecture) {
        _interactionError = null;
      }
    });
    final currentAttendance = ref.watch(attendanceProvider);
    final attendance = widget.presentationState ?? currentAttendance;
    final recoveryMessage =
        attendance.submissionResult == null &&
            (attendance.phase == AttendancePhase.idle ||
                attendance.phase == AttendancePhase.fetchingLecture)
        ? widget.recoveryPhase.message
        : null;
    final lecture = attendance.currentLecture;
    final recoveryFailed =
        recoveryMessage != null && !widget.recoveryPhase.isActive;
    final colorScheme = Theme.of(context).colorScheme;
    final isFetching = attendance.phase == AttendancePhase.fetchingLecture;
    final submissionResult = attendance.submissionResult;
    final displayError =
        _interactionError ??
        (submissionResult == null && recoveryMessage == null
            ? attendance.error
            : null);
    final description =
        submissionResult?.message ??
        (recoveryMessage != null
            ? (lecture != null ? '이전 조회 정보' : null)
            : null) ??
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
    final canEnterCode =
        hasConfirmedLecture && !attendance.isBusy && !widget.sessionLoading;
    final palette =
        Theme.of(context).extension<HongikPalette>() ?? HongikPalette.light;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = MediaQuery.sizeOf(context).width < 600;
        final statusMessage = AttendanceStatusMessage(
          key: const ValueKey('attendance-status-message'),
          title: _interactionError != null
              ? '출결 진행 실패'
              : recoveryMessage ?? _statusTitle(attendance),
          description: description,
          reserveDescriptionSpace: MediaQuery.sizeOf(context).width >= 600,
          isError:
              displayError != null ||
              recoveryFailed ||
              (submissionResult?.isError ?? false),
          isReady: canEnterCode,
          icon: submissionResult != null
              ? submissionResult.isError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded
              : displayError != null || recoveryFailed
              ? Icons.error_outline_rounded
              : recoveryMessage != null && widget.recoveryPhase.isActive
              ? Icons.refresh_rounded
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
        final actionTitle = widget.sessionLoading
            ? '연결 확인 중'
            : switch (attendance.phase) {
                AttendancePhase.fetchingLecture =>
                  submissionResult != null ? '수업 확인 중' : '수업 조회 중',
                AttendancePhase.enteringCode => '번호 입력 중',
                AttendancePhase.locating => '위치 확인 중',
                AttendancePhase.submitting => '출석 제출 중',
                AttendancePhase.idle =>
                  submissionResult != null
                      ? '수업 다시 확인'
                      : attendance.error != null ||
                            (recoveryMessage != null &&
                                !widget.recoveryPhase.isActive)
                      ? '다시 시도'
                      : _interactionError != null && hasConfirmedLecture
                      ? '출결 다시 시도'
                      : !hasConfirmedLecture
                      ? '수업 새로고침'
                      : '출결 번호 입력',
              };
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final actionIcon = SizedBox(
          width: canEnterCode ? 24 : 0,
          child: AnimatedOpacity(
            opacity: canEnterCode ? 1 : 0,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 120),
            child: const Icon(Icons.edit_note_rounded, size: 18),
          ),
        );
        final action = ElevatedButton(
          onPressed: attendance.isBusy || widget.sessionLoading
              ? null
              : !hasConfirmedLecture
              ? _refreshLecture
              : () => _handleAttendance(context),
          style: ElevatedButton.styleFrom(
            enableFeedback: false,
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
              if (reduceMotion)
                actionIcon
              else
                AnimatedSize(
                  duration: const Duration(milliseconds: 120),
                  child: actionIcon,
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
    unawaited(
      AppHaptics.instance.runAction(
        () => ref.read(attendanceProvider.notifier).refreshLectureForInput(),
        isCurrent: () => mounted,
        hasError: () => ref.read(attendanceProvider).error != null,
      ),
    );
  }

  Future<void> _handleAttendance(BuildContext context) async {
    if (_openingAttendance) return;
    _openingAttendance = true;
    _holdBackdrop();
    setState(() => _interactionError = null);
    final controller = ref.read(attendanceProvider.notifier);
    final session = ref.read(homeControllerProvider);
    var sessionChanged = false;
    int? submissionRevision;
    final subscription = ref.listenManual(homeControllerProvider, (_, next) {
      if (!next.isLoggedIn || next.userId != session.userId) {
        sessionChanged = true;
        if (mounted) _finishCodeEntry(null);
        final resultRoute = _flowRoute;
        if (resultRoute?.navigator?.mounted == true && resultRoute!.isActive) {
          resultRoute.navigator!.removeRoute(resultRoute);
        }
      }
    });
    try {
      await controller.fetchLecture(forceRefresh: true);
      if (!context.mounted || sessionChanged || !session.isLoggedIn) return;
      final attendance = ref.read(attendanceProvider);
      final lecture = attendance.currentLecture;
      if (lecture == null ||
          attendance.error != null ||
          attendance.isLectureStale) {
        if (attendance.error != null) AppHaptics.instance.error();
        return;
      }
      final submission = controller.performAttendance(
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
        requestAuthCode: () => _requestFlowCode(context, lecture),
        canContinue: () =>
            context.mounted && session.isLoggedIn && !sessionChanged,
      );
      submissionRevision = controller.submissionRevision;
      final result = await submission;
      if (context.mounted && !sessionChanged && result != null) {
        if (result.isError) {
          AppHaptics.instance.error();
        } else {
          AppHaptics.instance.complete();
        }
        _flow?.value = AttendanceDialogState.result(result);
        await _flowExit;
      }
    } catch (e) {
      if (context.mounted && !sessionChanged) {
        AppHaptics.instance.error();
        final message = e.toString().replaceFirst('Exception: ', '');
        if (_flow != null) {
          _flow!.value = AttendanceDialogState.result(
            AttendanceSubmissionResult.failure(message),
          );
          await _flowExit;
        }
        if (context.mounted && !sessionChanged) {
          setState(() => _interactionError = message);
        }
      }
    } finally {
      final hadFlow = _flowExit != null;
      if (_flowRoute != null &&
          _codeRequest == null &&
          _flow?.value.stage == AttendanceDialogStage.processing) {
        final route = _flowRoute!;
        if (route.isActive) route.navigator?.removeRoute(route);
      }
      await _flowExit;
      _flowExit = null;
      if (!sessionChanged && submissionRevision != null) {
        controller.finishAttendanceFlow(submissionRevision);
      }
      _openingAttendance = false;
      if (hadFlow) AppHaptics.instance.cancel();
      subscription.close();
      if (mounted) _releaseBackdrop();
    }
  }
}
