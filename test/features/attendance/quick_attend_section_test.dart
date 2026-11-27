import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/application/quick_attend_launch.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_code_form.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_section.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

final _lecture = Lecture(name: 'Lecture', time: '12:00', attendanceParams: {});

void main() {
  testWidgets('opens code entry once the lecture is ready', (tester) async {
    final launch = QuickAttendLaunch(requested: true);
    final attendance = _Attendance(
      const AttendanceState(phase: AttendancePhase.fetchingLecture),
    );
    await tester.pumpWidget(_subject(attendance, launch));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeDialog), findsNothing);
    expect(launch.isPending, isTrue);

    attendance.show(
      AttendanceState(hasCheckedLecture: true, currentLecture: _lecture),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeDialog), findsOneWidget);
    expect(launch.isPending, isFalse);

    await tester.tap(find.bySemanticsLabel('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeDialog), findsNothing);

    // 닫은 뒤 수업 정보가 다시 들어와도 또 열지 않는다.
    attendance.show(
      AttendanceState(hasCheckedLecture: true, currentLecture: _lecture),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeDialog), findsNothing);
  });

  testWidgets('gives up when there is no lecture now', (tester) async {
    final launch = QuickAttendLaunch(requested: true);
    final attendance = _Attendance(
      const AttendanceState(hasCheckedLecture: true),
    );
    await tester.pumpWidget(_subject(attendance, launch));
    await tester.pumpAndSettle();
    expect(launch.isPending, isFalse);

    attendance.show(
      AttendanceState(hasCheckedLecture: true, currentLecture: _lecture),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeDialog), findsNothing);
  });

  testWidgets('a normal launch never opens code entry by itself', (
    tester,
  ) async {
    final attendance = _Attendance(
      AttendanceState(hasCheckedLecture: true, currentLecture: _lecture),
    );
    await tester.pumpWidget(
      _subject(attendance, QuickAttendLaunch(requested: false)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeDialog), findsNothing);
  });
}

Widget _subject(_Attendance attendance, QuickAttendLaunch launch) =>
    ProviderScope(
      overrides: [
        attendanceProvider.overrideWith(() => attendance),
        homeControllerProvider.overrideWith(_Home.new),
        quickAttendLaunchProvider.overrideWithValue(launch),
      ],
      child: MaterialApp(
        theme: themeData,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 500,
              child: SingleChildScrollView(child: AttendanceSection()),
            ),
          ),
        ),
      ),
    );

class _Home extends HomeController {
  @override
  HomeState build() => const HomeState(isLoggedIn: true, userId: 'student');
}

class _Attendance extends AttendanceController {
  _Attendance(this._initial);
  final AttendanceState _initial;

  @override
  AttendanceState build() => _initial;

  void show(AttendanceState next) => state = next;

  @override
  Future<void> fetchLecture({
    bool forceRefresh = false,
    bool isAutomatic = false,
  }) async {}

  @override
  Future<AttendanceSubmissionResult?> performAttendance({
    required Future<String?> Function() requestAuthCode,
    required bool Function() canContinue,
    String? userId,
    Future<bool> Function(AttendanceSubmissionResult)? confirmUnconfirmedRetry,
  }) async {
    await requestAuthCode();
    return null;
  }
}
