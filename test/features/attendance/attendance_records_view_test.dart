import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_overview_provider.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_history_repository.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_overview_service.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_overview.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_records_view.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_history_view.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'attendance_overview_test.dart' show testCourse, publishedHtml;

const privateCourse = AttendanceCourse(
  key: AttendanceCourseKey(
    year: '2026',
    semester: '2',
    courseCode: '654321',
    section: '1',
  ),
  name: '비공개 테스트 과목',
  category: '학부',
);
const _output = String.fromEnvironment('ATTENDANCE_RECORDS_REVIEW_OUTPUT');

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final scenario in [
    (name: 'mobile', size: const Size(390, 844), scale: 1.0, dark: false),
    (name: 'mobile-dark', size: const Size(390, 844), scale: 1.0, dark: true),
    (name: 'large-text', size: const Size(320, 480), scale: 2.0, dark: false),
    (name: 'desktop', size: const Size(1440, 900), scale: 1.0, dark: false),
  ]) {
    testWidgets('school and requests flow at ${scenario.name}', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Service();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        _subject(
          service,
          boundary: boundary,
          scale: scenario.scale,
          dark: scenario.dark,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('attendance-history-button')));
      await tester.pumpAndSettle();
      expect(service.courseReads, 1);
      expect(service.detailReads, 0);
      await _capture(tester, boundary, '${scenario.name}-courses');
      await tester.tap(
        find.byKey(ValueKey('attendance-course-${testCourse.key.id}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('미입력'), findsOneWidget);
      expect(find.text('출석'), findsOneWidget);
      await _capture(tester, boundary, '${scenario.name}-published');
      final tableScroll = find.byKey(
        PageStorageKey('attendance-detail-${testCourse.key.id}'),
      );
      await tester.drag(tableScroll, const Offset(0, -180));
      await tester.pumpAndSettle();
      final offset = tester
          .widget<SingleChildScrollView>(tableScroll)
          .controller!
          .offset;
      final horizontal = find.byKey(
        const PageStorageKey('attendance-table-horizontal'),
      );
      final heading = find.byKey(const ValueKey('attendance-table-heading'));
      await tester.drag(heading, const Offset(-120, 0));
      await tester.pumpAndSettle();
      final horizontalOffset = tester
          .widget<SingleChildScrollView>(horizontal)
          .controller!
          .offset;
      await tester.tap(find.text('요청 기록'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('학교 출결'));
      await tester.pumpAndSettle();
      expect(find.text('새로운 서버 표시'), findsOneWidget);
      expect(service.detailReads, 1);
      expect(
        tester.widget<SingleChildScrollView>(tableScroll).controller!.offset,
        offset,
      );
      expect(
        tester.widget<SingleChildScrollView>(horizontal).controller!.offset,
        horizontalOffset,
      );
      await tester.tap(find.byTooltip('과목 목록'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('attendance-course-${testCourse.key.id}')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SingleChildScrollView>(tableScroll).controller!.offset,
        closeTo(offset, 0.01),
      );
      expect(
        tester.widget<SingleChildScrollView>(horizontal).controller!.offset,
        closeTo(horizontalOffset, 0.01),
      );
      expect(
        tester.widget<SingleChildScrollView>(heading).controller!.offset,
        closeTo(horizontalOffset, 0.01),
      );
      await tester.tap(find.byTooltip('과목 목록'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(privateCourse.name));
      await tester.tap(find.text(privateCourse.name));
      await tester.pumpAndSettle();
      expect(find.text('출석부가 공개되지 않았어요.'), findsOneWidget);
      await _capture(tester, boundary, '${scenario.name}-private');
      final action = find.text('이 과목의 요청 기록 보기');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('이 과목의 서버 응답'),
        120,
        scrollable: find
            .descendant(
              of: find.byType(AttendanceHistoryView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('이 과목의 서버 응답'), findsOneWidget);
      expect(find.text('이전 기록'), findsNothing);
      await _capture(tester, boundary, '${scenario.name}-requests');
      await tester.tap(find.text('전체 요청 기록'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('이전 기록'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(AttendanceHistoryView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('이전 기록'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceRecordsView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semester matrix and selection at ${scenario.name}', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final entries = [
        for (var week = 1; week <= 15; week++)
          for (final schedule in ['화7', '목7', '금7'])
            SchoolAttendanceEntry(
              week: week,
              schedule: schedule,
              lectureLabel: week <= 6 ? _lectureLabel(week, schedule) : '미입력',
              status: week > 6
                  ? '-'
                  : week == 3 && schedule == '목7'
                  ? '지각'
                  : '출석',
            ),
      ];
      final service = _Service(
        detail: SchoolAttendanceDetail(
          course: testCourse,
          isPublished: true,
          entries: entries,
        ),
      );
      await tester.pumpWidget(
        _subject(
          service,
          boundary: boundary,
          scale: scenario.scale,
          dark: scenario.dark,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('attendance-history-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('attendance-course-${testCourse.key.id}')),
      );
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('attendance-cell-1-화7-0'));
      // A complete first row must be visible even in the short, enlarged sheet.
      final sheet = tester.getRect(find.byType(AttendanceRecordsView));
      expect(
        tester.getRect(first).bottom,
        lessThanOrEqualTo(sheet.bottom - 16),
      );
      await _capture(tester, boundary, '${scenario.name}-semester');
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(find.text('09/01(화) / 테스트 교수\n출결: 출석'), findsOneWidget);
      await _capture(tester, boundary, '${scenario.name}-selection');
      await tester.tap(
        find.byTooltip(scenario.name == 'large-text' ? '상세 닫기' : '선택 해제'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attendance-week-jump')));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('attendance-week-6'))).top,
        closeTo(
          tester
              .getRect(find.byKey(const ValueKey('attendance-table-heading')))
              .bottom,
          0.01,
        ),
      );
      expect(
        find.text('이번 주'),
        scenario.scale > 1 ? findsOneWidget : findsNWidgets(2),
      );
      await _capture(tester, boundary, '${scenario.name}-current-week');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('request shortcut does not fetch school data until selected', (
    tester,
  ) async {
    final service = _Service();
    await tester.pumpWidget(
      _subject(service, initialTab: AttendanceRecordsTab.requests),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(service.courseReads, 0);
    await tester.tap(find.text('학교 출결'));
    await tester.pumpAndSettle();
    expect(service.courseReads, 1);
  });

  testWidgets('system back returns to course list before dismissing records', (
    tester,
  ) async {
    final service = _Service();
    await tester.pumpWidget(_subject(service));
    await tester.tap(find.byKey(const ValueKey('attendance-history-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('attendance-course-${testCourse.key.id}')),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('수강과목'), findsOneWidget);
    expect(find.byType(AttendanceRecordsView), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceRecordsView), findsNothing);
  });

  testWidgets('account switch closes the combined view immediately', (
    tester,
  ) async {
    final service = _Service();
    final home = _Home();
    await tester.pumpWidget(_subject(service, home: home));
    await tester.tap(find.byKey(const ValueKey('attendance-history-button')));
    await tester.pumpAndSettle();
    home.show(const HomeState(isLoggedIn: true, userId: 'other'));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceRecordsView), findsNothing);
    expect(find.text('테스트 과목'), findsNothing);
  });

  testWidgets('account switch also dismisses a short-screen entry dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final home = _Home();
    await tester.pumpWidget(_subject(_Service(), home: home, scale: 2));
    await tester.tap(find.byKey(const ValueKey('attendance-history-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('attendance-course-${testCourse.key.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attendance-cell-1-화2-0')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    home.show(const HomeState(isLoggedIn: true, userId: 'other'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AttendanceRecordsView), findsNothing);
    expect(find.text('09/08(화) / 테스트 교수\n출결: 출석'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (_output.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

String _lectureLabel(int week, String schedule) {
  final offset = switch (schedule[0]) {
    '화' => 1,
    '목' => 3,
    _ => 4,
  };
  final date = DateTime.utc(
    2026,
    8,
    31,
  ).add(Duration(days: (week - 1) * 7 + offset));
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month/$day(${schedule[0]}) / 테스트 교수';
}

Widget _subject(
  _Service service, {
  GlobalKey? boundary,
  double scale = 1,
  bool dark = false,
  _Home? home,
  AttendanceRecordsTab initialTab = AttendanceRecordsTab.school,
}) => RepaintBoundary(
  key: boundary,
  child: ProviderScope(
    overrides: [
      campusClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 10, 9, 12),
      ),
      attendanceOverviewServiceProvider.overrideWithValue(service),
      attendanceHistoryRepositoryProvider.overrideWithValue(_History()),
      homeControllerProvider.overrideWith(() => home ?? _Home()),
      attendanceProvider.overrideWith(_Attendance.new),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? darkThemeData : themeData,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => initialTab == AttendanceRecordsTab.school
              ? const Align(
                  alignment: Alignment.topRight,
                  child: AttendanceRecordsButton(),
                )
              : TextButton(
                  onPressed: () => showAttendanceRecords(
                    context,
                    'student',
                    initialTab: initialTab,
                  ),
                  child: const Text('열기'),
                ),
        ),
      ),
    ),
  ),
);

class _Home extends HomeController {
  @override
  HomeState build() => const HomeState(isLoggedIn: true, userId: 'student');
  void show(HomeState value) => state = value;
}

class _Attendance extends AttendanceController {
  @override
  AttendanceState build() => const AttendanceState();
}

class _Service extends AttendanceOverviewService {
  _Service({this.detail}) : super(_UnusedTransport());
  final SchoolAttendanceDetail? detail;
  int courseReads = 0;
  int detailReads = 0;
  @override
  Future<List<AttendanceCourse>> fetchCourses() async {
    courseReads++;
    return [testCourse, privateCourse];
  }

  @override
  Future<SchoolAttendanceDetail> fetchDetail(AttendanceCourse course) async {
    detailReads++;
    return course.key.id == privateCourse.key.id
        ? SchoolAttendanceDetail(course: course, isPublished: false)
        : detail ??
              AttendanceOverviewService.parseDetail(publishedHtml, course);
  }
}

class _UnusedTransport extends Fake implements SchoolHttpTransport {}

class _History extends AttendanceHistoryRepository {
  @override
  Future<List<AttendanceRequestRecord>> load(String userId) async => [
    AttendanceRequestRecord(
      id: 'new',
      lectureName: privateCourse.name,
      requestedAt: DateTime.utc(2026, 10, 9, 1),
      authCode: '0123',
      courseKey: privateCourse.key,
      hasServerResponse: true,
      message: '이 과목의 서버 응답',
    ),
    AttendanceRequestRecord(
      id: 'old',
      lectureName: '이전 기록',
      requestedAt: DateTime.utc(2026, 10, 8, 1),
      authCode: '4321',
      hasServerResponse: true,
      message: '이전 요청의 서버 응답',
    ),
  ];
}
