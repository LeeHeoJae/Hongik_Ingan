import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/home/domain/session_recovery_result.dart';
import 'widgets/home_attendance_density.dart';

/// The displayed snapshot shared by the attendance body and its space budget.
class HomeAttendancePresentation {
  const HomeAttendancePresentation({
    required this.isLoggedIn,
    required this.recovering,
    required this.userId,
    required this.attendance,
    required this.history,
    this.held = false,
    this.recoveryPhase = SessionRecoveryPhase.idle,
    this.sessionLoading = false,
  });

  final bool isLoggedIn;
  final bool recovering;
  final String? userId;
  final AttendanceState attendance;
  final AsyncValue<List<AttendanceRequestRecord>>? history;
  final bool held;
  final SessionRecoveryPhase recoveryPhase;
  final bool sessionLoading;

  bool get showHistory =>
      userId != null &&
      attendance.submissionResult == null &&
      (attendance.currentLecture == null || attendance.error != null);

  bool get balanceSummary =>
      isLoggedIn && showHistory && (history?.asData?.value.isNotEmpty ?? false);

  // Count only gaps rendered by HomeAttendancePanel in this presentation.
  double heightReduction(HomeAttendanceDensity density) {
    var sectionGaps = recovering && !isLoggedIn ? 0 : 1;
    var contentGaps = 1; // Gap before the primary action.
    var itemGaps = 0;
    if (isLoggedIn) {
      final hasDisplayLecture = attendance.hasDisplayLecture;
      if (hasDisplayLecture) {
        contentGaps++; // Lecture information to status.
        itemGaps++; // Lecture name to time.
      }
      if (showHistory) {
        sectionGaps++;
        contentGaps++; // Divider to recent requests.
        itemGaps++; // Recent requests heading to body.
        contentGaps +=
            history?.when(
              data: (value) => value.length > 1 ? 1 : 0,
              loading: () => 0,
              error: (_, _) => 0,
            ) ??
            0;
      }
    } else if (!recovering) {
      contentGaps += 2; // Status to form, password to login options.
    }
    return density.heightReduction +
        (isLoggedIn
            ? HomeAttendanceDensity.regular.sessionDividerGap -
                  density.sessionDividerGap
            : 0) +
        sectionGaps *
            (HomeAttendanceDensity.regular.sectionGap - density.sectionGap) +
        contentGaps *
            (HomeAttendanceDensity.regular.contentGap - density.contentGap) +
        itemGaps * (HomeAttendanceDensity.regular.itemGap - density.itemGap);
  }
}

/// Keeps the displayed data stable until the interaction and keyboard close.
class HomeAttendancePresentationHold {
  bool _active = false;
  bool _untilKeyboardCloses = false;
  String? _userId;
  AttendanceState? _attendance;
  AsyncValue<List<AttendanceRequestRecord>>? _history;

  bool get active => _active;

  void updateInteraction(bool active, HomeAttendancePresentation live) {
    _active = active;
    if (active) {
      _untilKeyboardCloses = true;
      _attendance ??= live.attendance;
      _userId = live.userId;
      if (_userId != null) _history ??= live.history;
    }
  }

  bool resolveKeyboard(double inset) {
    final hold = _active || (_untilKeyboardCloses && inset > 0);
    if (!hold) {
      _attendance = null;
      _history = null;
      _userId = null;
      _untilKeyboardCloses = false;
    }
    return hold;
  }

  HomeAttendancePresentation resolve(HomeAttendancePresentation live) {
    if (!live.isLoggedIn || live.userId != _userId || _attendance == null) {
      return live;
    }
    return HomeAttendancePresentation(
      isLoggedIn: live.isLoggedIn,
      recovering: live.recovering,
      recoveryPhase: live.recoveryPhase,
      sessionLoading: live.sessionLoading,
      userId: live.userId,
      attendance: _attendance!,
      history: _history,
      held: true,
    );
  }
}
