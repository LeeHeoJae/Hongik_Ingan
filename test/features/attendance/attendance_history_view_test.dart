import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/presentation/widgets/content_loading_skeleton.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_history_repository.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_history_view.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

void main() {
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
      expect(find.text('최근 출결 요청'), findsOneWidget);
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
      await tester.tap(find.byTooltip('닫기'));
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
          tester.element(find.byType(AttendanceHistoryButton)),
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
        child: AttendanceHistoryButton(),
      ),
    ),
  ),
);

AttendanceRequestRecord _record(String name, {bool response = true}) =>
    AttendanceRequestRecord(
      id: name,
      lectureName: name,
      requestedAt: DateTime.utc(2026, 10, 4, 1, 2, 3),
      authCode: '0123',
      hasServerResponse: response,
      message: response
          ? '인증번호가 올바르지 않아요. 수업에서 안내한 네 자리 번호를 확인한 뒤 다시 시도해 주세요.'
          : '네트워크 오류가 발생했어요.',
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
