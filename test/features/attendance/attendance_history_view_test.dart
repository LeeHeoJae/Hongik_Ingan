import 'dart:async';
import '../../support/request_history_launcher.dart';
import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/presentation/widgets/content_loading_skeleton.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_history_repository.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_history_view.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

import '../../support/load_app_fonts.dart';

void main() {
  const reviewOutput = String.fromEnvironment(
    'ATTENDANCE_HISTORY_REVIEW_OUTPUT',
  );
  if (reviewOutput.isNotEmpty) {
    setUpAll(() async {
      await loadAppFonts();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    for (final scenario in [
      (name: 'mobile', size: const Size(390, 844), scale: 1.0, dark: false),
      (name: 'mobile-dark', size: const Size(390, 844), scale: 1.0, dark: true),
      (name: 'large-text', size: const Size(320, 400), scale: 2.0, dark: false),
      (name: 'desktop', size: const Size(1440, 900), scale: 1.0, dark: false),
    ]) {
      testWidgets('renders history review ${scenario.name}', (tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        final repository = _Repository()
          ..records = [
            _record(
              '[101617] 기계학습기초',
              id: 'first',
              message: '출석확인이 완료되었습니다.[출석]',
            ),
            _record('[101617] 기계학습기초', id: 'second', response: false),
            _record('[123456] 디지털 미디어 디자인과 인터랙션 프로그래밍 실습'),
          ];
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _subject(
              repository,
              scale: scenario.scale,
              dark: scenario.dark,
            ),
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey('attendance-history-button')),
        );
        await tester.pumpAndSettle();
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('$reviewOutput/${scenario.name}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'groups repeated course requests and prioritizes each raw response',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const course = '[101617] 기계학습기초';
      const firstMessage = '출석확인이 완료되었습니다.[출석]';
      const secondMessage = '요청 결과를 아직 확인하지 못했어요.';
      final repository = _Repository()
        ..records = [
          _record(course, id: 'first', message: firstMessage),
          _record(
            course,
            id: 'second',
            response: false,
            message: secondMessage,
          ),
        ];
      await tester.pumpWidget(_subject(repository));
      await tester.tap(find.byKey(const ValueKey('attendance-history-button')));
      await tester.pumpAndSettle();
      final first = find.byKey(
        const ValueKey('attendance-history-record-first'),
      );
      final second = find.byKey(
        const ValueKey('attendance-history-record-second'),
      );
      Finder inside(Finder group, String text) =>
          find.descendant(of: group, matching: find.text(text));
      expect(inside(first, '기계학습기초'), findsOneWidget);
      expect(inside(first, '수업 코드 101617'), findsOneWidget);
      expect(inside(first, firstMessage), findsOneWidget);
      expect(inside(first, secondMessage), findsNothing);
      final number = inside(first, '출결 번호  0123');
      final time = inside(first, '요청 시각  2026.10.04 10:02:03');
      expect(number, findsOneWidget);
      expect(time, findsOneWidget);
      expect(
        tester.getRect(inside(first, firstMessage)).bottom,
        lessThan(tester.getRect(number).top),
      );
      expect(tester.getRect(number).bottom, lessThan(tester.getRect(time).top));
      expect(
        find.descendant(of: first, matching: find.byType(Scrollable)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: first,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );
      await tester.ensureVisible(second);
      await tester.pumpAndSettle();
      expect(inside(second, '기계학습기초'), findsOneWidget);
      expect(inside(second, secondMessage), findsOneWidget);
      expect(inside(second, '서버 결과 확인 불가'), findsOneWidget);
      expect(
        find.descendant(
          of: second,
          matching: find.byIcon(Icons.warning_amber_rounded),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(second).top,
        greaterThan(tester.getRect(first).bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(320, 640), scale: 2.0),
    (size: const Size(1440, 900), scale: 1.0),
  ]) {
    testWidgets('history geometry matches across themes $scenario', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<Rect>? baseline;
      for (final dark in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final repository = _Repository()
          ..records = [
            _record(
              'A long lecture title with a response that wraps',
              id: 'parity',
            ),
          ];
        await tester.pumpWidget(
          _subject(repository, scale: scenario.scale, dark: dark),
        );
        await tester.tap(
          find.byKey(const ValueKey('attendance-history-button')),
        );
        await tester.pumpAndSettle();
        final record = find.byKey(
          const ValueKey('attendance-history-record-parity'),
        );
        final texts = find.descendant(of: record, matching: find.byType(Text));
        final geometry = [
          tester.getRect(record),
          for (var index = 0; index < texts.evaluate().length; index++)
            tester.getRect(texts.at(index)),
        ];
        if (baseline == null) {
          baseline = geometry;
        } else {
          expect(geometry, baseline);
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'keeps course names intact when they do not have a numeric prefix',
    (tester) async {
      const names = ['[ABC] 기계학습기초', '[101617]', '자료구조[101617]'];
      final repository = _Repository()
        ..records = [for (final name in names) _record(name)];
      await tester.pumpWidget(_subject(repository));
      await tester.tap(find.byKey(const ValueKey('attendance-history-button')));
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: find.byType(AttendanceHistoryView),
        matching: find.byType(Scrollable),
      );
      for (final name in names) {
        await tester.scrollUntilVisible(find.text(name), 100, scrollable: list);
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('수업 코드 101617'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0, dark: false),
    (size: const Size(320, 400), scale: 2.0, dark: false),
    (size: const Size(320, 640), scale: 2.0, dark: true),
    (size: const Size(1440, 900), scale: 1.0, dark: false),
  ]) {
    testWidgets('reads all fields and scrolls long results $scenario', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository()
        ..records = [
          _record('디지털 미디어 디자인과 인터랙션 프로그래밍 실습', response: true),
          _record('응답을 확인하지 못한 수업', response: false),
        ];
      await tester.pumpWidget(
        _subject(repository, scale: scenario.scale, dark: scenario.dark),
      );
      final button = find.byKey(const ValueKey('attendance-history-button'));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('출결 내역'), findsOneWidget);
      expect(find.text('디지털 미디어 디자인과 인터랙션 프로그래밍 실습'), findsOneWidget);
      expect(find.text('요청 시각  2026.10.04 10:02:03'), findsWidgets);
      expect(find.text('출결 번호  0123'), findsWidgets);
      expect(
        find.byType(BottomSheet),
        scenario.size.width < 960 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(Dialog),
        scenario.size.width >= 960 ? findsOneWidget : findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('서버 결과 확인 불가'),
        100,
        scrollable: find.descendant(
          of: find.byType(AttendanceHistoryView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('서버 결과 확인 불가'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel('닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceHistoryView), findsNothing);
    });
  }

  testWidgets('shows loading, error recovery and empty history', (
    tester,
  ) async {
    final repository = _Repository();
    repository.pending = Completer<List<AttendanceRequestRecord>>();
    await tester.pumpWidget(_subject(repository));
    await tester.tap(find.byKey(const ValueKey('attendance-history-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ContentLoadingSkeleton), findsOneWidget);
    repository.pending!.completeError(StateError('Read failed'));
    await tester.pumpAndSettle();
    expect(find.text('요청 기록을 불러오지 못했어요.'), findsOneWidget);
    repository.pending = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('아직 출결 요청 기록이 없어요.'), findsOneWidget);
    expect(repository.reads, 2);
    expect(tester.takeException(), isNull);
  });

  for (final logout in [false, true]) {
    testWidgets(
      'closes the history on ${logout ? 'logout' : 'account switch'} during a pending read',
      (tester) async {
        final repository = _Repository();
        repository.pending = Completer<List<AttendanceRequestRecord>>();
        await tester.pumpWidget(_subject(repository));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(RequestHistoryLauncher)),
        );
        await tester.tap(
          find.byKey(const ValueKey('attendance-history-button')),
        );
        await tester.pumpAndSettle();
        final home = container.read(homeControllerProvider.notifier) as _Home;
        home.show(HomeState(isLoggedIn: !logout, userId: 'other'));
        await tester.pumpAndSettle();
        expect(find.byType(AttendanceHistoryView), findsNothing);
        repository.pending!.complete([_record('이전 계정의 수업')]);
        await tester.pumpAndSettle();
        expect(find.text('이전 계정의 수업'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _subject(
  _Repository repository, {
  double scale = 1,
  bool dark = false,
}) => ProviderScope(
  overrides: [
    attendanceHistoryRepositoryProvider.overrideWithValue(repository),
    homeControllerProvider.overrideWith(_Home.new),
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
    home: const Scaffold(
      body: Align(
        alignment: Alignment.topRight,
        child: RequestHistoryLauncher(),
      ),
    ),
  ),
);

AttendanceRequestRecord _record(
  String name, {
  bool response = true,
  String? id,
  String? message,
}) => AttendanceRequestRecord(
  id: id ?? name,
  lectureName: name,
  requestedAt: DateTime.utc(2026, 10, 4, 1, 2, 3),
  authCode: '0123',
  hasServerResponse: response,
  message:
      message ??
      (response
          ? '인증번호가 올바르지 않아요. 수업에서 안내한 네 자리 번호를 확인한 뒤 다시 시도해 주세요.'
          : '네트워크 오류가 발생했어요.'),
);

class _Repository extends AttendanceHistoryRepository {
  List<AttendanceRequestRecord> records = [];
  Completer<List<AttendanceRequestRecord>>? pending;
  int reads = 0;
  @override
  Future<List<AttendanceRequestRecord>> load(String userId) async {
    reads++;
    return pending == null ? records : pending!.future;
  }
}

class _Home extends HomeController {
  @override
  HomeState build() => const HomeState(isLoggedIn: true, userId: 'student');
  void show(HomeState value) => state = value;
}
