import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_section.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_body_motion.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_records_view.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_history_summary.dart';
import '../home_attendance_presentation.dart';
import '../layouts/home_service_workspace.dart';
import 'home_attendance_action_layout.dart';
import 'home_content_size_reporter.dart';
import 'home_attendance_density.dart';
import 'home_login_transition.dart';
import 'home_panel_heading.dart';

class HomeAttendancePanel extends StatefulWidget {
  const HomeAttendancePanel({
    super.key,
    required this.presentation,
    required this.initializingSession,
    required this.animateLayout,
    required this.onInteractionChanged,
    required this.onContentSizeChanged,
    required this.sessionContentBuilder,
    required this.loginStatus,
  });

  final HomeAttendancePresentation presentation;
  final bool initializingSession;
  final bool animateLayout;
  final ValueChanged<bool> onInteractionChanged;
  final VoidCallback onContentSizeChanged;
  final Widget Function(bool isLoggedIn) sessionContentBuilder;
  final Widget loginStatus;

  @override
  State<HomeAttendancePanel> createState() => _HomeAttendancePanelState();
}

class _HomeAttendancePanelState extends State<HomeAttendancePanel> {
  bool _loginFormWasPresented = false;
  double _headingHeight = 48;

  @override
  Widget build(BuildContext context) {
    final density = HomeAttendanceDensityScope.of(context);
    final extraSpace = HomeAttendanceDensityScope.extraSpaceOf(context);
    const loginSubtitle = '로그인하면 수업 정보를 자동으로 확인해요.';
    const attendanceSubtitle = '수업을 확인하고 출결 번호를 입력해요.';
    final presentation = widget.presentation;
    final hasAttendanceSession = presentation.isLoggedIn;
    final recovering = presentation.recovering;
    final userId = presentation.userId;
    final heldPresentation = presentation.held ? presentation.attendance : null;
    final showHistorySummary = presentation.showHistory;
    final historyWidth =
        MediaQuery.textScalerOf(context).scale(14) > 19 ||
            MediaQuery.sizeOf(context).width < 360
        ? 32.0
        : 104.0;
    final historyAtSummary = showHistorySummary && userId != null;
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final historySnapshot = presentation.history;
    final historyKey = historySnapshot?.when(
      data: (records) => Object.hashAll(
        records
            .take(2)
            .map(
              (record) => Object.hash(
                record.id,
                record.lectureName,
                record.requestedAt,
                record.message,
                record.hasKnownResult,
              ),
            ),
      ),
      loading: () => 'loading',
      error: (_, _) => 'error',
    );
    final bodyDensity = MediaQuery.sizeOf(context).width < 600
        ? density
        : HomeAttendanceDensity.regular;
    if (!widget.initializingSession && !hasAttendanceSession) {
      _loginFormWasPresented = !recovering;
    }
    final content = hasAttendanceSession
        ? AttendanceSection(
            presentationState: heldPresentation,
            onInteractionChanged: widget.onInteractionChanged,
            informationExtraSpace: historyAtSummary ? 0 : extraSpace,
            informationGap: bodyDensity.contentGap,
            lectureGap: bodyDensity.itemGap,
            presentationBuilder: (presentation) => HomeAttendanceActionLayout(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AttendanceMotionPart(
                    fade: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        widget.sessionContentBuilder(true),
                        SizedBox(height: bodyDensity.sessionDividerGap),
                        const Divider(height: 1),
                        SizedBox(height: bodyDensity.sectionGap),
                      ],
                    ),
                  ),
                  if (!mobile)
                    AttendanceMotionPart(
                      key: const ValueKey('attendance-motion-status-wide'),
                      contentKey: presentation.statusKey,
                      child: presentation.status,
                    ),
                  AttendanceMotionPart(
                    key: const ValueKey('attendance-motion-lecture'),
                    contentKey: presentation.lectureKey,
                    child: presentation.lecture == null
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!mobile)
                                SizedBox(height: bodyDensity.contentGap),
                              presentation.lecture!,
                              if (mobile)
                                SizedBox(height: bodyDensity.contentGap),
                            ],
                          ),
                  ),
                  if (mobile)
                    AttendanceMotionPart(
                      key: const ValueKey('attendance-motion-status-mobile'),
                      contentKey: presentation.statusKey,
                      child: presentation.status,
                    ),
                  AttendanceMotionPart(
                    key: const ValueKey('attendance-motion-history'),
                    contentKey: historyKey,
                    child: !showHistorySummary || userId == null
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: bodyDensity.sectionGap),
                              const Divider(height: 1),
                              SizedBox(height: bodyDensity.contentGap),
                              AttendanceHistorySummary(
                                userId: userId,
                                historySnapshot: historySnapshot,
                                onRecordPressed: () => showAttendanceRecords(
                                  context,
                                  userId,
                                  initialTab: AttendanceRecordsTab.requests,
                                ),
                                extraSpace: extraSpace,
                                headingGap: bodyDensity.itemGap,
                                recordGap: bodyDensity.contentGap,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              action: presentation.action,
            ),
          )
        : recovering
        ? HomeAttendanceActionLayout(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.sessionContentBuilder(true),
                SizedBox(height: bodyDensity.sessionDividerGap),
                const Divider(height: 1),
                SizedBox(height: bodyDensity.sectionGap),
                widget.loginStatus,
              ],
            ),
            action: const ElevatedButton(
              onPressed: null,
              child: Text('다시 로그인 중'),
            ),
          )
        : widget.sessionContentBuilder(false);
    Widget buildPanel(Widget body, Animation<double> incoming) => Column(
      key: const ValueKey('home-attendance-main-content'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AttendanceMotionPart(
          fade: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              density.verticalPadding,
              16,
              density.headingGap / 2,
            ),
            child: HomeContentSizeReporter(
              onSize: (size) {
                if (!mounted || (_headingHeight - size.height).abs() < 0.5) {
                  return;
                }
                widget.onContentSizeChanged();
                setState(() => _headingHeight = size.height);
              },
              child: HomePanelHeading(
                service: HomeService.attendance,
                title: '전자출결',
                trailing: hasAttendanceSession
                    ? const AttendanceRecordsButton()
                    : null,
                trailingWidth: historyWidth,
                subtitle: hasAttendanceSession || recovering
                    ? attendanceSubtitle
                    : loginSubtitle,
                alternateSubtitle: hasAttendanceSession
                    ? loginSubtitle
                    : attendanceSubtitle,
                transition: incoming,
              ),
            ),
          ),
        ),
        SizedBox(height: density.headingGap / 2),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, density.verticalPadding),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              key: const ValueKey('home-attendance-body'),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width >= 960
                    ? double.infinity
                    : 520,
              ),
              child: body,
            ),
          ),
        ),
      ],
    );
    return HomeLoginTransition(
      isLoggedIn: hasAttendanceSession,
      animateLogin: _loginFormWasPresented,
      bottomAligned: mobile,
      child: content,
      frameBuilder: (context, body, incoming) => HomeAttendanceActionScope(
        bodyTop: density.verticalPadding + _headingHeight + density.headingGap,
        bottomPadding: density.verticalPadding,
        child: AttendanceBodyMotion(
          enabled: widget.animateLayout,
          bottomAligned: mobile,
          child: buildPanel(body, incoming),
        ),
      ),
    );
  }
}
