import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_data_source.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/attendance/debug/attendance_test_controls.dart';
import 'package:hongik_ingan/features/attendance/debug/attendance_test_environment.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_code_form.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_result_dialog.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_records_view.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_section.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/presentation/home_screen.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';

import '../../support/attendance_test_host.dart';
import '../../support/dismiss_attendance_records.dart';
import '../../support/load_app_fonts.dart';

void main() {
  const reviewOutput = String.fromEnvironment('ATTENDANCE_TEST_REVIEW_OUTPUT');
  if (reviewOutput.isNotEmpty) {
    setUpAll(() async {
      await loadAppFonts();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
  }

  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0, dark: false),
    (size: const Size(1440, 900), scale: 1.0, dark: true),
    (size: const Size(320, 740), scale: 2.0, dark: true),
  ]) {
    testWidgets('현재 홈을 유지하며 출결 소스만 전환한다 $scenario', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final host = AttendanceTestHost();
      final container = host.container;
      final navigation = _NavigationObserver();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorObservers: [navigation],
              theme: themeData,
              darkTheme: darkThemeData,
              themeMode: scenario.dark ? ThemeMode.dark : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scenario.scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: const HomeScreen(),
            ),
          ),
        ),
      );
      try {
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pumpAndSettle();
        final homeState = tester.state(find.byType(HomeScreen));
        final attendanceState = tester.state(find.byType(AttendanceSection));
        final controller = container.read(attendanceProvider.notifier);
        final session = container.read(homeControllerProvider);
        final menuState = container.read(cafeteriaMenuControllerProvider);
        final seatState = container.read(seatControllerProvider);
        expect(
          container.read(attendanceProvider).currentLecture?.name,
          '실제 수업',
        );
        expect(host.realTransport.lectureRequests, 1);
        expect(find.text('성공 결과 보기'), findsNothing);
        expect(find.text('실패 결과 보기'), findsNothing);
        expect(find.text('출결 화면 테스트'), findsNothing);
        final testToggle = find.byKey(const ValueKey('attendance-test-toggle'));
        expect(testToggle, findsOneWidget);
        expect(find.byType(PopupMenuButton<Object>), findsNothing);
        expect(
          find.byType(DropdownButtonFormField<AttendanceTestScenario>),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AttendanceSection),
            matching: find.byType(AttendanceTestControls),
          ),
          findsNothing,
        );
        expect(tester.getSize(testToggle), const Size(44, 44));
        expect(find.byKey(const ValueKey('home-debug-tools')), findsOneWidget);
        final idleButtonStyle = tester.widget<IconButton>(testToggle).style!;
        final idleBackground = scenario.dark
            ? darkThemeData.colorScheme.primaryContainer
            : themeData.colorScheme.surfaceContainerHigh;
        final idleForeground = scenario.dark
            ? darkThemeData.colorScheme.onPrimaryContainer
            : themeData.colorScheme.onSurfaceVariant;
        expect(
          idleButtonStyle.backgroundColor!.resolve(<WidgetState>{}),
          idleBackground,
        );
        expect(
          idleButtonStyle.foregroundColor!.resolve(<WidgetState>{}),
          idleForeground,
        );
        await _tap(tester, testToggle);
        final source = container.read(attendanceDataSourceOverrideProvider)!;
        final transport = source.transport as AttendanceTestTransport;
        void expectSameHome() {
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(tester.state(find.byType(HomeScreen)), same(homeState));
          expect(
            tester.state(find.byType(AttendanceSection)),
            same(attendanceState),
          );
          expect(
            ProviderScope.containerOf(tester.element(find.byType(HomeScreen))),
            same(container),
          );
          expect(container.read(attendanceProvider.notifier), same(controller));
          expect(container.read(homeControllerProvider), same(session));
          expect(
            container.read(cafeteriaMenuControllerProvider),
            same(menuState),
          );
          expect(container.read(seatControllerProvider), same(seatState));
        }

        expectSameHome();
        expect(navigation.pushes, 1);
        expect(
          container.read(attendanceProvider).currentLecture?.name,
          '모바일 앱 프로그래밍',
        );
        final activeButtonStyle = tester.widget<IconButton>(testToggle).style!;
        expect(
          activeButtonStyle.backgroundColor!.resolve(<WidgetState>{}),
          scenario.dark
              ? darkThemeData.colorScheme.primary
              : themeData.colorScheme.primary,
        );
        expect(
          activeButtonStyle.foregroundColor!.resolve(<WidgetState>{}),
          scenario.dark
              ? darkThemeData.colorScheme.onPrimary
              : themeData.colorScheme.onPrimary,
        );
        expect(host.realTransport.lectureRequests, 1);
        if (reviewOutput.isNotEmpty) {
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1);
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '$reviewOutput/inline-${scenario.size.width.toInt()}-${scenario.scale}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
        await _tap(tester, find.text('출결 번호 입력'));
        expect(find.byType(AttendanceCodeDialog), findsOneWidget);
        await tester.enterText(find.byType(TextField), '1234');
        await tester.pump();
        await _tap(tester, find.widgetWithText(ElevatedButton, '제출'));
        expect(find.byType(AttendanceResultDialog), findsOneWidget);
        expect(transport.submissions, hasLength(1));
        expect(host.realTransport.attendance.submissions, isEmpty);
        expect(host.realHistory.writes, 0);
        await _tap(tester, find.text('확인'));
        final recordsButton = find.byKey(
          const ValueKey('attendance-history-button'),
        );
        await _tap(tester, recordsButton);
        await _tap(tester, find.text('요청 기록'));
        expect(
          find.descendant(
            of: find.byType(AttendanceRecordsView),
            matching: find.text('출석이 완료됐어요.'),
          ),
          findsOneWidget,
        );
        await dismissAttendanceRecords(tester);
        await tester.pumpAndSettle();
        final routesBeforeDisable = navigation.pushes;
        await _tap(tester, testToggle);
        expectSameHome();
        expect(navigation.pushes, routesBeforeDisable);
        expect(container.read(attendanceDataSourceOverrideProvider), isNull);
        expect(
          container.read(attendanceProvider).currentLecture?.name,
          '실제 수업',
        );
        expect(host.realTransport.lectureRequests, 2);
        expect(
          container.read(attendanceHistoryRepositoryProvider),
          same(host.realHistory),
        );
        expect(host.realHistory.writes, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        host.dispose();
      }
    });
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _NavigationObserver extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}
