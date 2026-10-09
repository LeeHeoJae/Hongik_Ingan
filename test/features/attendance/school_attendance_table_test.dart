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
    _expectCentered(tester, 6);
    await tester.drag(_tableScroll, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attendance-week-jump')));
    await tester.pumpAndSettle();
    _expectCentered(tester, 6);
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

  for (final target in [1, 15]) {
    testWidgets('week $target centers within the available scroll range', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(_entries(target)));
      await tester.pumpAndSettle();
      final position = tester
          .widget<SingleChildScrollView>(_tableScroll)
          .controller!
          .position;
      expect(
        position.pixels,
        target == 1 ? position.minScrollExtent : position.maxScrollExtent,
      );
      expect(
        tester
            .getRect(find.byKey(ValueKey('attendance-week-$target')))
            .overlaps(tester.getRect(_tableScroll)),
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('attendance-week-jump')));
      await tester.pumpAndSettle();
      expect(
        position.pixels,
        target == 1 ? position.minScrollExtent : position.maxScrollExtent,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'centering accounts for a taller current row and reduced motion',
    (tester) async {
      await tester.pumpWidget(
        _subject(_entries(6, longStatus: true), disableAnimations: true),
      );
      await tester.pumpAndSettle();
      _expectCentered(tester, 6);
      await tester.drag(_tableScroll, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attendance-week-jump')));
      await tester.pump();
      _expectCentered(tester, 6);
      expect(
        tester
            .widget<SingleChildScrollView>(_tableScroll)
            .controller!
            .position
            .isScrollingNotifier
            .value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resizing the open table keeps the reading position', (
    tester,
  ) async {
    final entries = _entries(6);
    await tester.pumpWidget(_subject(entries));
    await tester.pumpAndSettle();
    await tester.drag(_tableScroll, const Offset(0, -180));
    await tester.pumpAndSettle();
    final readingOffset = tester
        .widget<SingleChildScrollView>(_tableScroll)
        .controller!
        .offset;
    await tester.pumpWidget(_subject(entries, height: 520));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SingleChildScrollView>(_tableScroll).controller!.offset,
      readingOffset,
    );
    expect(tester.takeException(), isNull);
  });
}

Finder get _tableScroll =>
    find.byKey(PageStorageKey('attendance-detail-${testCourse.key.id}'));

void _expectCentered(WidgetTester tester, int week) {
  expect(
    tester.getRect(find.byKey(ValueKey('attendance-week-$week'))).center.dy,
    closeTo(tester.getRect(_tableScroll).center.dy, 0.1),
  );
}

List<SchoolAttendanceEntry> _entries(int target, {bool longStatus = false}) => [
  for (var week = 1; week <= 15; week++)
    SchoolAttendanceEntry(
      week: week,
      schedule: '화2',
      lectureLabel: week == target ? '10/08(목) / 교수' : '미입력',
      status: week == target && longStatus
          ? '학교에서 제공하는 길이가 긴 새로운 출결 표시를 그대로 유지해요'
          : '-',
    ),
];

Widget _subject(
  List<SchoolAttendanceEntry> entries, {
  double scale = 1,
  bool disableAnimations = false,
  double height = 500,
}) => ProviderScope(
  overrides: [
    campusClockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 9, 12)),
  ],
  child: MaterialApp(
    theme: themeData,
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: disableAnimations,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: height,
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
