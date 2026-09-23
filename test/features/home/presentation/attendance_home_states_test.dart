import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_section.dart';

void main() {
  testWidgets('수업 조회 전부터 출결 진행 중까지 실제 상태만 표시한다', (tester) async {
    final controller = _PreviewAttendanceController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [attendanceProvider.overrideWith(() => controller)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AttendanceSection()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('수업 확인 전'), findsOneWidget);
    expect(find.text('검증된 수업'), findsNothing);

    controller.show(
      const AttendanceState(phase: AttendancePhase.fetchingLecture),
    );
    await tester.pump();
    expect(find.text('수업 조회 중'), findsWidgets);
    expect(find.text('검증된 수업'), findsNothing);

    controller.show(const AttendanceState(hasCheckedLecture: true));
    await tester.pump();
    expect(find.text('출결 가능한 수업이 없어요'), findsOneWidget);
    await tester.tap(find.text('수업 새로고침'));
    await tester.pump();
    expect(controller.refreshCount, 1);

    controller.show(
      const AttendanceState(hasCheckedLecture: true, error: '서버에 연결하지 못했어요.'),
    );
    await tester.pump();
    expect(find.text('수업 조회 실패'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(controller.refreshCount, 2);

    final lecture = Lecture(
      name: '검증된 수업',
      time: '화 13:00',
      attendanceParams: {},
    );
    controller.show(
      AttendanceState(hasCheckedLecture: true, currentLecture: lecture),
    );
    await tester.pump();
    expect(find.text('수업 확인 완료'), findsOneWidget);
    expect(find.text('검증된 수업'), findsOneWidget);
    expect(find.text('화 13:00'), findsOneWidget);
    expect(find.text('출결 번호 입력'), findsOneWidget);

    controller.show(
      AttendanceState(
        hasCheckedLecture: true,
        currentLecture: lecture,
        phase: AttendancePhase.submitting,
      ),
    );
    await tester.pump();
    expect(find.text('출석 제출 중'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _PreviewAttendanceController extends AttendanceController {
  int refreshCount = 0;

  @override
  AttendanceState build() => const AttendanceState();

  @override
  Future<void> fetchLecture({bool forceRefresh = false}) async {
    if (forceRefresh) refreshCount++;
  }

  void show(AttendanceState next) => state = next;
}
