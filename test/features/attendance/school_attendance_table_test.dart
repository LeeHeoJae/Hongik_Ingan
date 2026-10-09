import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_overview.dart';
import 'package:hongik_ingan/features/attendance/presentation/school_attendance_table.dart';
import 'attendance_overview_test.dart' show testCourse;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))).load();
  });

  testWidgets('header and week column stay fixed while both axes scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject([
        for (var week = 1; week <= 15; week++)
          for (final schedule in ['화2', '화3', '목7', '금8', '금9'])
            SchoolAttendanceEntry(
              week: week,
              schedule: schedule,
              lectureLabel: '09/08(화) / 교수',
              status: '출석',
            ),
      ]),
    );
    await tester.pumpAndSettle();
    final header = find.byKey(const ValueKey('attendance-table-heading'));
    final week = find.byKey(const ValueKey('attendance-week-1'));
    final headerTop = tester.getTopLeft(header).dy;
    final weekLeft = tester.getTopLeft(week).dx;
    final body = find.byKey(
      const PageStorageKey('attendance-table-horizontal'),
    );
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('attendance-cell-1-화2-0'))),
      const Offset(-250, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(week).dx, weekLeft);
    final bodyController = tester
        .widget<SingleChildScrollView>(body)
        .controller!;
    final headingController = tester
        .widget<SingleChildScrollView>(header)
        .controller!;
    expect(bodyController.offset, greaterThan(0));
    expect(headingController.offset, closeTo(bodyController.offset, 0.01));
    await tester.drag(header, const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(headingController.offset, closeTo(bodyController.offset, 0.01));
    await tester.drag(
      find.byKey(PageStorageKey('attendance-detail-${testCourse.key.id}')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(header).dy, headerTop);
    final week8 = find.byKey(const ValueKey('attendance-week-8'));
    final cell8 = find.byKey(const ValueKey('attendance-cell-8-화2-0'));
    expect(
      tester.getTopLeft(week8).dy,
      closeTo(tester.getTopLeft(cell8).dy, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'duplicates, missing slots and unfamiliar raw labels are preserved',
    (tester) async {
      await tester.pumpWidget(
        _subject(const [
          SchoolAttendanceEntry(
            week: 1,
            schedule: '화2',
            lectureLabel: '미입력',
            status: '-',
          ),
          SchoolAttendanceEntry(
            week: 1,
            schedule: '화2',
            lectureLabel: '보강 일정은 추후 안내 / 담당 교수',
            status: '학교가 제공한 새로운 긴 출결 표시',
          ),
          SchoolAttendanceEntry(
            week: 2,
            schedule: '화2',
            lectureLabel: '09/15(화) / 테스트 교수',
            status: '출석',
          ),
        ], scale: 2),
      );
      await tester.pumpAndSettle();
      expect(find.text('화 2교시'), findsNWidgets(2));
      expect(find.text('정보 없음'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      final second = find.byKey(const ValueKey('attendance-cell-1-화2-1'));
      await tester.drag(
        find.byKey(const PageStorageKey('attendance-table-horizontal')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(
        find.text('보강 일정은 추후 안내 / 담당 교수\n출결: 학교가 제공한 새로운 긴 출결 표시'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(
              find.ancestor(of: second, matching: find.byType(Semantics)).first,
            )
            .label,
        contains('1주차, 화 2교시'),
      );
      await tester.tap(find.byTooltip('상세 닫기'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('attendance-entry-detail')),
        findsNothing,
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard activation opens an entry with its original lecture label',
    (tester) async {
      await tester.pumpWidget(
        _subject(const [
          SchoolAttendanceEntry(
            week: 1,
            schedule: '목7',
            lectureLabel: '09/10(목) / 테스트 교수',
            status: '결석',
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('09/10(목) / 테스트 교수\n출결: 결석'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recent lecture shortcut jumps directly without a week picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject([
        for (var week = 1; week <= 15; week++)
          SchoolAttendanceEntry(
            week: week,
            schedule: '화2',
            lectureLabel: week == 6 ? '09/15(화) / 교수' : '미입력',
            status: '-',
          ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('최근 수업'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('attendance-week-jump')));
    await tester.pumpAndSettle();
    final heading = tester.getRect(
      find.byKey(const ValueKey('attendance-table-heading')),
    );
    final week = tester.getRect(
      find.byKey(const ValueKey('attendance-week-6')),
    );
    expect(week.top, closeTo(heading.bottom, 0.01));
    expect(find.byType(PopupMenuButton<int>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-unentered tables explain why the shortcut is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(const [
        SchoolAttendanceEntry(
          week: 1,
          schedule: '화2',
          lectureLabel: '미입력',
          status: '-',
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('attendance-week-jump')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byTooltip('이동할 강의 날짜가 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _subject(List<SchoolAttendanceEntry> entries, {double scale = 1}) =>
    ProviderScope(
      overrides: [
        campusClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 9, 12),
        ),
      ],
      child: MaterialApp(
        theme: themeData,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                height: 500,
                child: SchoolAttendanceTable(
                  detail: SchoolAttendanceDetail(
                    course: testCourse,
                    isPublished: true,
                    entries: entries,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
