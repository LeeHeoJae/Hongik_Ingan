import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_section.dart';

void _expectInactiveActionIcon(WidgetTester tester) {
  final icon = find.byIcon(Icons.edit_note_rounded);
  expect(icon, findsOneWidget);
  expect(
    tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: icon, matching: find.byType(AnimatedOpacity)).first,
        )
        .opacity,
    0,
  );
}

void main() {
  for (final width in [160.0, 340.0]) {
    testWidgets('refresh label stays centered without a visible icon: $width', (
      tester,
    ) async {
      final controller = _PreviewAttendanceController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [attendanceProvider.overrideWith(() => controller)],
          child: MaterialApp(
            theme: themeData,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: AttendanceSection(
                    layoutBuilder: (_, action) => action,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byType(ElevatedButton);
      final before = tester.getRect(action);
      void expectCentered() {
        expect(
          tester.getCenter(find.text('수업 새로고침')).dx,
          closeTo(tester.getCenter(action).dx, 0.1),
        );
        expect(tester.getRect(action), before);
      }

      expectCentered();
      controller.show(
        AttendanceState(
          currentLecture: Lecture(
            name: 'Course',
            time: '10:00',
            attendanceParams: {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.show(const AttendanceState(hasCheckedLecture: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final middle = tester.getCenter(find.text('수업 새로고침')).dx;
      expect(middle, inInclusiveRange(before.center.dx, before.center.dx + 12));
      await tester.pumpAndSettle();
      expectCentered();
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('ready button has a distinct color and clears: $dark', (
      tester,
    ) async {
      final controller = _PreviewAttendanceController();
      final theme = dark ? darkThemeData : themeData;
      final palette = theme.extension<HongikPalette>()!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [attendanceProvider.overrideWith(() => controller)],
          child: MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: SingleChildScrollView(child: AttendanceSection()),
            ),
          ),
        ),
      );
      Color? background() => tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .style!
          .backgroundColor!
          .resolve({});
      final normal = background();
      final lecture = Lecture(
        name: 'Ready course',
        time: '10:00',
        attendanceParams: {},
      );
      controller.show(AttendanceState(currentLecture: lecture));
      await tester.pump();
      expect(background(), dark ? palette.brandBlue : palette.brandNavy);
      expect(background(), isNot(normal));
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
      for (final unavailable in [
        AttendanceState(currentLecture: lecture, isLectureStale: true),
        AttendanceState(currentLecture: lecture, sessionExpired: true),
        AttendanceState(currentLecture: lecture, error: 'Unavailable'),
        AttendanceState(
          currentLecture: lecture,
          phase: AttendancePhase.fetchingLecture,
        ),
        AttendanceState(
          currentLecture: lecture,
          phase: AttendancePhase.submitting,
        ),
        AttendanceState(
          currentLecture: lecture,
          submissionResult: const AttendanceSubmissionResult.notice('Done'),
        ),
        const AttendanceState(hasCheckedLecture: true),
      ]) {
        controller.show(unavailable);
        await tester.pump();
        expect(background(), normal);
        _expectInactiveActionIcon(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }

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
    _expectInactiveActionIcon(tester);
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
    expect(find.text('잠시 후 새로고침으로 다시 확인할 수 있어요.'), findsNothing);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(controller.refreshCount, 2);

    controller.show(
      const AttendanceState(hasCheckedLecture: true, error: '서버에 연결하지 못했어요.'),
    );
    await tester.pump();
    expect(find.text('수업 조회 실패'), findsOneWidget);
    expect(find.text('출결 가능한 수업이 없어요'), findsNothing);
    expect(find.text('서버에 연결하지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(controller.refreshCount, 3);

    final lecture = Lecture(
      name: '검증된 수업',
      time: '화 13:00',
      attendanceParams: {},
    );
    controller.show(
      AttendanceState(hasCheckedLecture: true, currentLecture: lecture),
    );
    await tester.pump();
    expect(find.text('번호 입력 가능'), findsOneWidget);
    expect(find.text('검증된 수업'), findsOneWidget);
    expect(find.text('화 13:00'), findsOneWidget);
    expect(find.text('출결 번호 입력'), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    await tester.tap(find.text('수업 정보 새로고침'));
    await tester.pump();
    expect(controller.refreshCount, 4);

    controller.show(
      AttendanceState(
        hasCheckedLecture: true,
        currentLecture: lecture,
        phase: AttendancePhase.enteringCode,
      ),
    );
    await tester.pump();
    expect(find.text('출결 번호 입력 중'), findsOneWidget);
    expect(find.text('번호 입력 중'), findsOneWidget);
    _expectInactiveActionIcon(tester);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '수업 정보 새로고침'))
          .onPressed,
      isNull,
    );

    controller.show(
      AttendanceState(
        hasCheckedLecture: true,
        currentLecture: lecture,
        phase: AttendancePhase.locating,
      ),
    );
    await tester.pump();
    expect(find.text('위치 확인 중'), findsWidgets);

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

  testWidgets('갱신 중 기존 수업을 표시하되 번호 입력을 잠근다', (tester) async {
    final controller = _PreviewAttendanceController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [attendanceProvider.overrideWith(() => controller)],
        child: MaterialApp(
          theme: themeData,
          home: const Scaffold(
            body: SingleChildScrollView(child: AttendanceSection()),
          ),
        ),
      ),
    );
    final lecture = Lecture(
      name: '검증된 수업',
      time: '화 13:00',
      attendanceParams: {},
    );
    controller.show(
      AttendanceState(hasCheckedLecture: true, currentLecture: lecture),
    );
    await tester.pump();
    expect(find.text('출결 번호 입력'), findsOneWidget);
    controller.show(
      AttendanceState(
        hasCheckedLecture: true,
        currentLecture: lecture,
        phase: AttendancePhase.fetchingLecture,
      ),
    );
    await tester.pump();
    expect(find.text(lecture.name), findsOneWidget);
    expect(find.text(lecture.time), findsOneWidget);
    expect(find.text('이전 조회 정보'), findsOneWidget);
    expect(find.text('번호 입력 가능'), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '수업 정보 새로고침'))
          .onPressed,
      isNull,
    );
    controller.show(const AttendanceState(hasCheckedLecture: true));
    await tester.pump();
    expect(find.text(lecture.name), findsNothing);
    expect(find.text('이전 조회 정보'), findsNothing);
    expect(find.text('출결 가능한 수업이 없어요'), findsOneWidget);
    controller.show(
      AttendanceState(hasCheckedLecture: true, currentLecture: lecture),
    );
    await tester.pump();
    expect(find.text('번호 입력 가능'), findsOneWidget);
    expect(find.text('이전 조회 정보'), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final result in [
      const AttendanceSubmissionResult.notice('출석이 완료됐어요.'),
      const AttendanceSubmissionResult.notice('인증번호가 올바르지 않아요.'),
      const AttendanceSubmissionResult.unconfirmed(
        '출결 처리 여부를 확인하지 못했어요. 학교 출결 내역을 확인해 주세요.',
      ),
    ]) {
      testWidgets(
        'submission message stays primary during failed follow-up (dark: $dark, ${result.status})',
        (tester) async {
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = _PreviewAttendanceController();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [attendanceProvider.overrideWith(() => controller)],
              child: MaterialApp(
                theme: dark ? darkThemeData : themeData,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: SingleChildScrollView(child: AttendanceSection()),
                ),
              ),
            ),
          );
          final lecture = Lecture(
            name: 'Previous Course',
            time: '10:00',
            attendanceParams: {},
          );
          for (final phase in [
            AttendancePhase.fetchingLecture,
            AttendancePhase.idle,
          ]) {
            controller.show(
              AttendanceState(
                currentLecture: lecture,
                hasCheckedLecture: true,
                submissionResult: result,
                isLectureStale: true,
                phase: phase,
                error: '출결 서버 SSO 연동에 실패했어요.',
              ),
            );
            await tester.pump();
            expect(find.text(result.message), findsOneWidget);
            expect(find.text('Previous Course'), findsNothing);
            expect(find.text('이전 조회 정보'), findsNothing);
            expect(find.text('출결 서버 SSO 연동에 실패했어요.'), findsNothing);
            expect(find.text('번호 입력 가능'), findsNothing);
            expect(find.text('출결 번호 입력'), findsNothing);
            expect(tester.takeException(), isNull);
          }
          final refresh = find.widgetWithText(ElevatedButton, '수업 다시 확인');
          await tester.ensureVisible(refresh);
          await tester.tap(refresh);
          await tester.pump();
          expect(controller.refreshCount, 2);
          expect(find.text(result.message), findsOneWidget);
        },
      );
    }

    testWidgets(
      'stale lecture offers refresh without code entry (dark: $dark)',
      (tester) async {
        final controller = _PreviewAttendanceController();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [attendanceProvider.overrideWith(() => controller)],
            child: MaterialApp(
              theme: dark ? darkThemeData : themeData,
              home: const Scaffold(
                body: SingleChildScrollView(child: AttendanceSection()),
              ),
            ),
          ),
        );
        final lecture = Lecture(
          name: 'Course',
          time: '10:00',
          attendanceParams: {},
        );
        controller.show(
          AttendanceState(
            currentLecture: lecture,
            hasCheckedLecture: true,
            isLectureStale: true,
          ),
        );
        await tester.pump();
        expect(find.text('Course'), findsOneWidget);
        expect(find.text('이전 조회 정보'), findsOneWidget);
        expect(find.text('수업 정보 확인 중'), findsOneWidget);
        expect(find.text('출결 번호 입력'), findsNothing);
        await tester.tap(find.text('수업 새로고침'));
        expect(controller.refreshCount, 2);
        controller.show(
          AttendanceState(
            currentLecture: lecture,
            hasCheckedLecture: true,
            isLectureStale: true,
            error: '학교 연결이 지연되고 있어요.',
          ),
        );
        await tester.pump();
        expect(find.text('Course'), findsOneWidget);
        expect(find.text('학교 연결 지연'), findsOneWidget);
        expect(find.textContaining('이전 조회 정보'), findsOneWidget);
        expect(find.text('출결 번호 입력'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('좁은 화면에서 긴 수업 정보와 큰 글자를 줄바꿈한다 (dark: $dark)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _PreviewAttendanceController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [attendanceProvider.overrideWith(() => controller)],
          child: MaterialApp(
            theme: dark ? darkThemeData : themeData,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: AttendanceSection(),
              ),
            ),
          ),
        ),
      );
      controller.show(
        AttendanceState(
          hasCheckedLecture: true,
          currentLecture: Lecture(
            name: '디지털 미디어 디자인과 인터랙션 프로그래밍 실습',
            time: '월요일 10:00–12:50 · 제4공학관 401호',
            attendanceParams: {},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final refresh = find.widgetWithText(TextButton, '수업 정보 새로고침');
      await tester.ensureVisible(refresh);
      await tester.pumpAndSettle();
      expect(tester.getSize(refresh).height, greaterThanOrEqualTo(44));
      await tester.tap(refresh);
      await tester.pump();
      expect(controller.refreshCount, 2);
      controller.show(
        const AttendanceState(
          hasCheckedLecture: true,
          error: '서버 연결을 확인해 주세요.',
        ),
      );
      await tester.pump();
      expect(find.text('서버 연결을 확인해 주세요.'), findsOneWidget);
      expect(find.text('번호 입력 가능'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

class _PreviewAttendanceController extends AttendanceController {
  int refreshCount = 0;

  @override
  AttendanceState build() => const AttendanceState();

  @override
  Future<void> fetchLecture({
    bool forceRefresh = false,
    bool isAutomatic = false,
  }) async {
    if (forceRefresh) refreshCount++;
  }

  void show(AttendanceState next) => state = next;
}
