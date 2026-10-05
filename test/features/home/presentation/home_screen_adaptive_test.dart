import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/app.dart';
import 'package:hongik_ingan/core/app_info.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_date_selector.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_selector.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/presentation/home_screen.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/app_info_dialog.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_campus_summary.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_code_form.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:hongik_ingan/features/seat/presentation/widgets/seat_location_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [
    const Size(1200, 800),
    const Size(1228, 714),
    const Size(1440, 900),
    const Size(800, 900),
  ]) {
    testWidgets('home page fits without scrolling $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final previousVersion = AppInfo.version;
      AppInfo.version = '1.4.0';
      addTearDown(() => AppInfo.version = previousVersion);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _subject(homeState: const HomeState(), populated: true),
      );
      await tester.pumpAndSettle();
      final page = find
          .descendant(
            of: find.byKey(const ValueKey('home-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final service in ['로그인·출결', '열람실', '학식 메뉴']) {
        if (service != '로그인·출결') {
          await tester.tap(find.text(service).first);
          await tester.pumpAndSettle();
        }
        final position = tester.state<ScrollableState>(page).position;
        expect(position.maxScrollExtent, 0, reason: '$size $service');
        expect(position.pixels, 0, reason: '$size $service');
        final footer = tester.getRect(
          find.byKey(const ValueKey('home-version-info')),
        );
        expect(footer.bottom, lessThanOrEqualTo(size.height - 24));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('short windows scroll and stop scrolling when expanded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_subject(homeState: const HomeState()));
    await tester.pumpAndSettle();
    final page = find
        .descendant(
          of: find.byKey(const ValueKey('home-page-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(page).position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(position.maxScrollExtent, 0);
    expect(position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0, keyboard: 0.0),
    (size: const Size(1200, 800), scale: 1.0, keyboard: 0.0),
    (size: const Size(320, 620), scale: 2.0, keyboard: 240.0),
  ]) {
    testWidgets(
      'login fields stay in place with validation and long errors $scenario',
      (tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: scenario.keyboard);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          _subject(homeState: const HomeState(), textScale: scenario.scale),
        );
        await tester.pumpAndSettle();
        final action = find.widgetWithText(ElevatedButton, '통합 로그인');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        final idBefore = tester.getRect(fields.first);
        final passwordBefore = tester.getRect(fields.last);
        final actionBefore = tester.getRect(action);
        final slot = find.byKey(const ValueKey('login-status-message'));
        final slotBefore = tester.getRect(slot);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('학번과 비밀번호를 모두 입력해 주세요.'), findsOneWidget);
        expect(tester.getRect(fields.first), idBefore);
        expect(tester.getRect(fields.last), passwordBefore);
        expect(tester.getRect(action), actionBefore);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        final home =
            container.read(homeControllerProvider.notifier)
                as _PreviewHomeController;
        home.show(
          const HomeState(isLoading: true, loginStatus: LoginStatus.loggingIn),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        final longError = List.generate(
          12,
          (i) => '서버 응답 $i: 로그인을 확인하지 못했어요.',
        ).join('\n');
        home.show(
          HomeState(loginStatus: LoginStatus.failed, statusMessage: longError),
        );
        await tester.pumpAndSettle();
        expect(find.text(longError), findsOneWidget);
        expect(tester.getRect(slot), slotBefore);
        expect(tester.getRect(fields.first), idBefore);
        expect(tester.getRect(fields.last), passwordBefore);
        expect(tester.getRect(action), actionBefore);
        final scrollable = find.descendant(
          of: slot,
          matching: find.byType(Scrollable),
        );
        final scrollState = tester.state<ScrollableState>(scrollable);
        expect(scrollState.position.maxScrollExtent, greaterThan(0));
        scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
        await tester.pump();
        expect(scrollState.position.pixels, greaterThan(0));
        home.show(
          const HomeState(
            loginStatus: LoginStatus.failed,
            statusMessage: '입력 정보를 다시 확인해 주세요.',
          ),
        );
        await tester.pumpAndSettle();
        expect(scrollState.position.pixels, 0);
        expect(tester.getRect(fields.first), idBefore);
        expect(tester.getRect(fields.last), passwordBefore);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'mobile interaction errors stay inline and clear on lecture refresh',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final lecture = Lecture(
        name: '테스트 수업',
        time: '월 10:00',
        attendanceParams: {},
      );
      await tester.pumpWidget(
        _subject(
          homeState: const HomeState(isLoggedIn: true, userId: 'student'),
          attendanceState: AttendanceState(
            hasCheckedLecture: true,
            currentLecture: lecture,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final controller =
          container.read(attendanceProvider.notifier)
              as _PreviewAttendanceController;
      controller.failNextAttendance = true;
      await tester.tap(find.widgetWithText(ElevatedButton, '출결 번호 입력'));
      await tester.pumpAndSettle();
      expect(find.text('출결 진행 실패'), findsOneWidget);
      expect(find.text('위치 확인에 실패했어요.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.widgetWithText(ElevatedButton, '출결 다시 시도'), findsOneWidget);
      controller.show(
        AttendanceState(
          currentLecture: lecture,
          phase: AttendancePhase.fetchingLecture,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('출결 진행 실패'), findsNothing);
      expect(find.text('위치 확인에 실패했어요.'), findsNothing);
      expect(find.text('이전 조회 정보'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byType(ElevatedButton).first)
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(390, 844), const Size(1200, 800)]) {
    testWidgets(
      'status title and action stay in place across short messages $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _subject(
            homeState: const HomeState(isLoggedIn: true, userId: 'student'),
            attendanceState: const AttendanceState(hasCheckedLecture: true),
          ),
        );
        await tester.pumpAndSettle();
        final slot = find.byKey(const ValueKey('attendance-status-message'));
        final before = tester.getRect(slot);
        final actionBefore = tester.getRect(find.byType(ElevatedButton).first);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        final controller =
            container.read(attendanceProvider.notifier)
                as _PreviewAttendanceController;
        final element = tester.element(slot);
        for (final state in [
          const AttendanceState(phase: AttendancePhase.fetchingLecture),
          const AttendanceState(
            hasCheckedLecture: true,
            error: '출결 서버에 연결하지 못했어요.',
          ),
          const AttendanceState(hasCheckedLecture: true),
        ]) {
          controller.show(state);
          await tester.pumpAndSettle();
          expect(tester.element(slot), same(element));
          expect(tester.getRect(slot), before);
          expect(
            tester.getRect(find.byType(ElevatedButton).first),
            actionBefore,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'login status stays in place and recovery hides the login form $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_subject(homeState: const HomeState()));
        await tester.pumpAndSettle();
        final slot = find.byKey(const ValueKey('login-status-message'));
        final before = tester.getRect(slot);
        final fieldsBefore = tester.getRect(find.byType(TextField).first);
        final actionBefore = tester.getRect(find.byType(ElevatedButton).first);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        final home =
            container.read(homeControllerProvider.notifier)
                as _PreviewHomeController;
        for (final state in [
          const HomeState(isLoading: true, loginStatus: LoginStatus.loggingIn),
          const HomeState(
            loginStatus: LoginStatus.failed,
            statusMessage: '정보를 확인해 주세요.',
          ),
          const HomeState(),
        ]) {
          home.show(state);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.getRect(slot), before);
          expect(tester.getRect(find.byType(TextField).first), fieldsBefore);
          expect(
            tester.getRect(find.byType(ElevatedButton).first),
            actionBefore,
          );
        }
        home.show(
          const HomeState(
            isLoading: true,
            userId: 'student',
            loginStatus: LoginStatus.recoveringSession,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('다시 로그인 중'), findsNWidgets(2));
        expect(
          tester
              .widget<ElevatedButton>(find.byType(ElevatedButton).first)
              .onPressed,
          isNull,
        );
        home.show(
          const HomeState(
            loginStatus: LoginStatus.failed,
            statusMessage: '복구 실패',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text('복구 실패'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'session recovery leaves only the current attendance state ($width)',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _subject(
            homeState: const HomeState(
              isLoggedIn: true,
              userId: 'student',
              statusMessage: '세션이 만료됐지만 다시 로그인했어요.',
            ),
            attendanceState: const AttendanceState(hasCheckedLecture: true),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('세션이 만료됐지만 다시 로그인했어요.'), findsNothing);
        expect(find.text('출결 가능한 수업이 없어요'), findsOneWidget);
        expect(find.text('잠시 후 새로고침으로 다시 확인할 수 있어요.'), findsNothing);
        expect(find.widgetWithText(ElevatedButton, '수업 새로고침'), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        (container.read(attendanceProvider.notifier)
                as _PreviewAttendanceController)
            .show(
              const AttendanceState(hasCheckedLecture: true, error: '조회 오류'),
            );
        await tester.pumpAndSettle();
        expect(find.text('수업 조회 실패'), findsOneWidget);
        expect(find.text('출결 가능한 수업이 없어요'), findsNothing);
        expect(find.text('세션이 만료됐지만 다시 로그인했어요.'), findsNothing);

        (container.read(homeControllerProvider.notifier)
                as _PreviewHomeController)
            .show(
              const HomeState(
                loginStatus: LoginStatus.expired,
                statusMessage: '세션이 만료되어 로그아웃됐어요.',
              ),
            );
        await tester.pumpAndSettle();
        expect(find.text('다시 로그인이 필요해요'), findsOneWidget);
        expect(find.text('세션이 만료됐어요.'), findsOneWidget);
        expect(find.text('수업 조회 실패'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'recent request history preserves the mobile attendance action position',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _subject(
          homeState: const HomeState(isLoggedIn: true, userId: 'student'),
          attendanceState: AttendanceState(
            hasCheckedLecture: true,
            currentLecture: Lecture(
              name: '검증된 수업',
              time: '10:00',
              attendanceParams: {'lecture': '1'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.widgetWithText(ElevatedButton, '출결 번호 입력');
      final originalRect = tester.getRect(action);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final historyButton = find.byKey(
        const ValueKey('attendance-history-button'),
      );
      expect(tester.getSize(historyButton).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(historyButton).height, greaterThanOrEqualTo(44));
      expect(
        tester
            .getRect(find.byIcon(Icons.history_rounded))
            .overlaps(tester.getRect(find.text('수업을 확인하고 출결 번호를 입력해요.'))),
        isFalse,
        reason:
            'Icon: ${tester.getRect(find.byIcon(Icons.history_rounded))}; '
            'subtitle: ${tester.getRect(find.text('수업을 확인하고 출결 번호를 입력해요.'))}',
      );
      await tester.tap(historyButton);
      await tester.pumpAndSettle();
      expect(find.text('아직 출결 요청 기록이 없어요.'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(tester.getRect(action), originalRect);
      final repository = container.read(attendanceHistoryRepositoryProvider);
      await repository.save(
        'student',
        AttendanceRequestRecord(
          id: 'request',
          lectureName: '검증된 수업',
          requestedAt: DateTime.utc(2026, 10, 4, 1, 2, 3),
          authCode: '0123',
          hasServerResponse: true,
          message: '이미 출석했어요.',
        ),
      );
      await tester.tap(historyButton);
      await tester.pumpAndSettle();
      expect(find.text('이미 출석했어요.'), findsOneWidget);
      expect(find.text('출결 번호  0123'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(tester.getRect(action), originalRect);
      expect(tester.takeException(), isNull);
    },
  );

  const demoOutput = String.fromEnvironment('ATTENDANCE_DEMO_OUTPUT');
  if (demoOutput.isNotEmpty) {
    setUpAll(() async {
      await (FontLoader('NotoSansKR')
            ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    for (final demo in [
      (name: 'mobile', size: const Size(390, 844), mode: ThemeMode.light),
      (name: 'desktop', size: const Size(1200, 900), mode: ThemeMode.light),
      (name: 'mobile-dark', size: const Size(390, 844), mode: ThemeMode.dark),
    ]) {
      testWidgets('renders attendance emphasis demo ${demo.name}', (
        tester,
      ) async {
        tester.view.physicalSize = demo.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        Future<void> capture(String stage) async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('$demoOutput/${demo.name}-$stage.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }

        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _subject(
              homeState: const HomeState(isLoggedIn: true, userId: '20241234'),
              attendanceState: const AttendanceState(hasCheckedLecture: true),
              populated: true,
              themeMode: demo.mode,
              showDebugBanner: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/icon_foreground.png'),
            tester.element(find.byType(HomeScreen)),
          ),
        );
        await tester.pump();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        final attendance =
            container.read(attendanceProvider.notifier)
                as _PreviewAttendanceController;
        await tester.tap(find.text('학식 메뉴'));
        await tester.pumpAndSettle();
        await capture('before');
        await tester.pump(const Duration(seconds: 5));
        expect(attendance.automaticRefreshCount, 1);
        attendance.show(
          AttendanceState(
            hasCheckedLecture: true,
            currentLecture: Lecture(
              name: '컴퓨터그래픽스',
              time: '10:00–11:50',
              attendanceParams: {'lecture': 'demo-1'},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('출결 가능'), findsOneWidget);
        await capture('pulse-00');
        for (var frame = 1; frame <= 10; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
          await capture('pulse-${frame.toString().padLeft(2, '0')}');
        }
        await tester.pumpAndSettle();
        await capture('after');
        await tester.pump(const Duration(seconds: 10));
        expect(attendance.automaticRefreshCount, 1);
        await tester.tap(find.text('로그인·출결'));
        await tester.pump();
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
          await capture('promote-${frame.toString().padLeft(2, '0')}');
        }
        await tester.pumpAndSettle();
        expect(find.text('출결 번호 입력'), findsOneWidget);
        await capture('promoted');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('finds and emphasizes a lecture while attendance is auxiliary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _subject(
        homeState: const HomeState(isLoggedIn: true, userId: 'student'),
        attendanceState: const AttendanceState(hasCheckedLecture: true),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final attendance =
        container.read(attendanceProvider.notifier)
            as _PreviewAttendanceController;
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('home-service-attendance'));
    final originalRect = tester.getRect(panel);
    await tester.pump(const Duration(seconds: 5));
    expect(attendance.automaticRefreshCount, 1);
    attendance.show(
      AttendanceState(
        hasCheckedLecture: true,
        currentLecture: Lecture(
          name: 'Course',
          time: '10:00',
          attendanceParams: {'lecture': '1'},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('출결 가능'), findsOneWidget);
    expect(find.text('Course · 10:00'), findsOneWidget);
    final label = tester.getSemantics(
      find.bySemanticsLabel('로그인·출결, 출결 가능, Course, 10:00, 주 영역으로 이동'),
    );
    expect(label.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    final baseColor = tester.widget<Material>(panel).color;
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Material>(panel).color, isNot(baseColor));
    await tester.pumpAndSettle();
    expect(tester.widget<Material>(panel).color, baseColor);
    expect(tester.getRect(panel), originalRect);
    await tester.pump(const Duration(seconds: 10));
    expect(attendance.automaticRefreshCount, 1);
    await tester.tap(find.text('로그인·출결'));
    await tester.pumpAndSettle();
    expect(find.text('출결 번호 입력'), findsOneWidget);
    expect(
      (tester.widget<Material>(panel).shape as RoundedRectangleBorder)
          .side
          .width,
      1,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final size in [
    const Size(390, 844),
    const Size(320, 640),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'service card motion stays continuous across rapid changes $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _subject(
            homeState: const HomeState(isLoggedIn: true, userId: 'student'),
            attendanceState: AttendanceState(
              hasCheckedLecture: true,
              currentLecture: Lecture(
                name: 'Course',
                time: '10:00',
                attendanceParams: {'lecture': '1'},
              ),
            ),
            populated: true,
          ),
        );
        await tester.pumpAndSettle();
        final cards = [
          for (final name in ['attendance', 'seat', 'menu'])
            find.byKey(ValueKey('home-service-$name')),
        ];
        double movement(Rect before, Rect after) => [
          (before.left - after.left).abs(),
          (before.top - after.top).abs(),
          (before.right - after.right).abs(),
          (before.bottom - after.bottom).abs(),
        ].reduce((a, b) => a > b ? a : b);
        Future<void> switchService(String label, int frames) async {
          var previous = cards.map(tester.getRect).toList();
          await tester.tap(find.text(label));
          await tester.pump();
          for (var i = 0; i < cards.length; i++) {
            expect(
              movement(previous[i], tester.getRect(cards[i])),
              lessThan(0.5),
              reason: 'Card $i jumps at the start of $label',
            );
          }
          for (var frame = 0; frame < frames; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final current = cards.map(tester.getRect).toList();
            for (var i = 0; i < cards.length; i++) {
              expect(
                movement(previous[i], current[i]),
                lessThan(100),
                reason: 'Card $i jumps in $label at frame $frame',
              );
            }
            previous = current;
          }
        }

        await switchService('학식 메뉴', 10);
        await switchService('로그인·출결', 40);
        await switchService('열람실', 40);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(390, 844), const Size(480, 998)]) {
    for (final hasUpdate in [false, true]) {
      testWidgets('모바일 두 보조 행 아래의 버전 위젯을 바로 사용할 수 있다 $size $hasUpdate', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        final previousVersion = AppInfo.version;
        AppInfo.version = '1.4.0';
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          AppInfo.version = previousVersion;
        });
        await tester.pumpWidget(
          _subject(
            homeState: HomeState(
              updateInfo: hasUpdate
                  ? const {
                      'currentVersion': '1.4.0',
                      'latestVersion': '1.4.1',
                      'notice': '모바일 배치를 개선했어요.',
                      'updateUrl': 'https://example.com/releases/1.4.1',
                    }
                  : null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final panel = tester.getRect(
          find.byKey(const ValueKey('home-service-attendance')),
        );
        final seat = tester.getRect(
          find.byKey(const ValueKey('home-service-seat')),
        );
        final menu = tester.getRect(
          find.byKey(const ValueKey('home-service-menu')),
        );
        final version = find.byKey(const ValueKey('home-version-info'));
        final versionRect = tester.getRect(version);
        final header = tester.getRect(find.byTooltip('앱 정보 및 문제 해결'));
        expect(panel.top, greaterThanOrEqualTo(header.bottom + 16));
        expect(seat.top, panel.bottom + 12);
        expect(menu.top, seat.bottom + 12);
        expect(seat.width, panel.width);
        expect(menu.width, panel.width);
        expect(menu.left, panel.left);
        expect(versionRect.top, menu.bottom + 18);
        expect(versionRect.height, 34);
        expect(versionRect.bottom, size.height - 24);
        expect(find.text('업데이트'), findsNothing);
        expect(
          find.byIcon(Icons.update),
          hasUpdate ? findsOneWidget : findsNothing,
        );
        final versionText = find.text('v1.4.0');
        final translation = tester.widget<Transform>(
          find
              .ancestor(of: versionText, matching: find.byType(Transform))
              .first,
        );
        expect(translation.transform.getTranslation().y, -1);
        for (final service in ['attendance', 'seat', 'menu']) {
          expect(
            tester
                .widget<Material>(find.byKey(ValueKey('home-service-$service')))
                .elevation,
            0,
          );
        }
        await tester.tap(version);
        await tester.pumpAndSettle();
        if (hasUpdate) {
          expect(find.text('새로운 버전이 있어요'), findsOneWidget);
          expect(find.text('모바일 배치를 개선했어요.'), findsOneWidget);
        } else {
          expect(find.text('최신 버전이에요.'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('키보드가 화면을 줄여도 선택한 서비스가 유지된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      _subject(populated: true, homeState: const HomeState()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 500);
    await tester.pumpAndSettle();
    expect(find.text('주간 식당 메뉴'), findsOneWidget);
    expect(find.text('통합 로그인'), findsNothing);
    await tester.ensureVisible(find.text('계절 과일'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (size: const Size(390, 844), mode: ThemeMode.light, scale: 1.0),
    (size: const Size(390, 844), mode: ThemeMode.dark, scale: 1.0),
    (size: const Size(1440, 900), mode: ThemeMode.light, scale: 1.0),
    (size: const Size(320, 620), mode: ThemeMode.dark, scale: 2.0),
  ]) {
    testWidgets('늦게 도착한 업데이트를 하단 위젯에서 열 수 있다 $scenario', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      final previousVersion = AppInfo.version;
      AppInfo.version = '1.3.1';
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        AppInfo.version = previousVersion;
      });

      await tester.pumpWidget(
        _subject(
          homeState: const HomeState(),
          themeMode: scenario.mode,
          textScale: scenario.scale,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('앱 정보 및 문제 해결'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('v1.3.1'),
        ),
        findsOneWidget,
      );
      expect(find.text('업데이트 안내'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final controller =
          container.read(homeControllerProvider.notifier)
              as _PreviewHomeController;
      controller.show(
        const HomeState(
          updateInfo: {
            'currentVersion': '1.3.1',
            'latestVersion': '1.4.0',
            'notice': '홈 화면과 전자출결 사용성을 개선했어요.',
            'updateUrl': 'https://example.com/releases/1.4.0',
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('업데이트 안내'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, '닫기'));
      await tester.pumpAndSettle();
      final version = find.byKey(const ValueKey('home-version-info'));
      await tester.ensureVisible(version);
      await tester.pumpAndSettle();
      await tester.tap(version);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(AppInfoDialog), findsNothing);
      expect(find.text('새로운 버전이 있어요'), findsOneWidget);
      expect(find.text('홈 화면과 전자출결 사용성을 개선했어요.'), findsOneWidget);
      expect(find.text('업데이트하기'), findsOneWidget);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('화면을 열어 둬도 식사와 날짜 변경을 반영한다', (tester) async {
    final date = DateTime(2026, 10, 1);
    final clock = NotifierProvider<_PreviewCampusClock, DateTime>(
      () => _PreviewCampusClock(
        DateTime(date.year, date.month, date.day, 13, 59),
      ),
    );
    await tester.pumpWidget(_subject(populated: true, campusClock: clock));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('home-service-menu'));
    final lunch = find.descendant(
      of: panel,
      matching: find.textContaining('돼지고기 두루치기'),
    );
    expect(lunch, findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container
        .read(clock.notifier)
        .show(DateTime(date.year, date.month, date.day, 14));
    await tester.pumpAndSettle();
    expect(lunch, findsNothing);
    expect(
      find.descendant(of: panel, matching: find.textContaining('치킨 가라아게')),
      findsOneWidget,
    );
    final next = date.add(const Duration(days: 1));
    container.read(clock.notifier).show(next);
    await tester.pumpAndSettle();
    final controller =
        container.read(cafeteriaMenuControllerProvider.notifier)
            as _PreviewCafeteriaMenuController;
    expect(
      controller.requestedDates.last,
      MenuDateRange.initialSelectedDateFor(next),
    );
    expect(
      find.descendant(of: panel, matching: find.text('메뉴 조회 전')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('보조 요약은 상세 선택과 독립적으로 학식과 T동 노트북 좌석을 표시한다 $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final date = DateTime(2026, 10, 1);
      await tester.pumpWidget(
        _subject(
          populated: true,
          campusTime: DateTime(date.year, date.month, date.day, 12),
        ),
      );
      await tester.pumpAndSettle();
      final menu = find.byKey(const ValueKey('home-service-menu'));
      final seat = find.byKey(const ValueKey('home-service-seat'));
      final preview = find.descendant(
        of: menu,
        matching: find.textContaining('돼지고기 두루치기'),
      );
      expect(preview, findsOneWidget);
      expect(tester.widget<Text>(preview).data, contains('후식 요구르트'));
      expect(
        find.descendant(of: seat, matching: find.text('85석 남음')),
        findsOneWidget,
      );
      expect(find.text('선택 날짜'), findsNothing);
      expect(find.text('조회 시각'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final menuController = container.read(
        cafeteriaMenuControllerProvider.notifier,
      );
      menuController.selectDate(
        MenuDateRange.initialSelectedDateFor(date).add(const Duration(days: 1)),
      );
      menuController.selectCafeteria('교직원 식당');
      container
          .read(seatControllerProvider.notifier)
          .selectLocation(SeatLocation.rBuilding);
      await tester.pumpAndSettle();
      expect(preview, findsOneWidget);
      expect(
        find.descendant(of: seat, matching: find.text('85석 남음')),
        findsOneWidget,
      );
      expect(
        tester.getRect(preview).bottom,
        lessThanOrEqualTo(tester.getRect(menu).bottom),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('Logout restores the login form without type errors $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _subject(
          homeState: const HomeState(isLoggedIn: true, userId: 'C211136'),
          attendanceState: const AttendanceState(hasCheckedLecture: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('출결 화면 테스트'));
      await tester.pumpAndSettle();
      expect(find.text('샘플 수업 보기'), findsOneWidget);
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.widgetWithText(ElevatedButton, '통합 로그인'), findsOneWidget);
      expect(find.text('로그아웃'), findsNothing);
      expect(tester.takeException(), isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      (container.read(homeControllerProvider.notifier)
              as _PreviewHomeController)
          .show(const HomeState(isLoggedIn: true, userId: 'C211136'));
      await tester.pumpAndSettle();
      expect(find.text('샘플 수업 보기'), findsOneWidget);
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Desktop login feedback keeps the action fixed and stays in the information area',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_subject(homeState: const HomeState()));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(ElevatedButton, '통합 로그인');
      final before = tester.getRect(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final error = find.text('학번과 비밀번호를 모두 입력해 주세요.');
      expect(error, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.getRect(error).right, lessThan(before.left));
      expect(tester.getRect(button), before);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final controller =
          container.read(homeControllerProvider.notifier)
              as _PreviewHomeController;
      controller.show(
        const HomeState(isLoading: true, statusMessage: '홍대 서버와 보안 통신 중...'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getRect(find.byType(ElevatedButton).first), before);
      expect(
        tester
            .widget<ElevatedButton>(find.byType(ElevatedButton).first)
            .onPressed,
        isNull,
      );
      // A long failure stays readable without moving the desktop action.
      controller.show(const HomeState(isLoggedIn: true));
      await tester.pumpAndSettle();
      controller.show(
        HomeState(
          loginStatus: LoginStatus.failed,
          statusMessage: List.filled(16, '서버 연결을 확인하고 있어요.').join('\n'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getRect(find.byType(ElevatedButton).first), before);
      final information = find.byKey(const ValueKey('login-status-message'));
      final scrollable = find.descendant(
        of: information,
        matching: find.byType(Scrollable),
      );
      expect(
        tester
            .state<ScrollableState>(scrollable.first)
            .position
            .maxScrollExtent,
        greaterThan(0),
      );
      controller.show(const HomeState());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Desktop code dialog preserves the underlying panel and action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _subject(
        homeState: const HomeState(isLoggedIn: true, userId: 'C211136'),
        attendanceState: AttendanceState(
          hasCheckedLecture: true,
          currentLecture: Lecture(
            name: '테스트 수업',
            time: '월 10:00',
            attendanceParams: {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('home-service-attendance'));
    final button = find.descendant(
      of: panel,
      matching: find.byType(ElevatedButton),
    );
    final panelBefore = tester.getRect(panel);
    final buttonBefore = tester.getRect(button);
    final titleBefore = tester.getRect(find.text('전자출결'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeForm), findsOneWidget);
    expect(tester.getRect(panel), panelBefore);
    expect(tester.getRect(button), buttonBefore);
    expect(tester.getRect(find.text('전자출결')), titleBefore);
    expect(find.text('출결 번호 입력 중'), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeForm), findsNothing);
    expect(tester.getRect(panel), panelBefore);
    expect(tester.getRect(button), buttonBefore);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final attendance =
        container.read(attendanceProvider.notifier)
            as _PreviewAttendanceController;
    attendance.failNextAttendance = true;
    await tester.tap(button);
    await tester.pumpAndSettle();
    final error = find.text('위치 확인에 실패했어요.');
    expect(error, findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.getRect(error).right, lessThan(buttonBefore.left));
    expect(tester.getRect(button), buttonBefore);
    expect(find.text('출결 진행 실패'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(390, 844),
    const Size(1228, 714),
    const Size(1440, 900),
  ]) {
    testWidgets('로그인과 수업 상태 변경에도 카드 중심과 버튼 위치 유지 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _subject(
          homeState: const HomeState(),
          attendanceState: const AttendanceState(),
        ),
      );
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('home-service-attendance'));
      final before = tester.getRect(panel);
      final body = find.byKey(const ValueKey('home-attendance-body'));
      final bodyBefore = tester.getRect(body);
      final headerBefore = tester.getRect(find.text('홍익인간'));
      final seatBefore = tester.getRect(
        find.byKey(const ValueKey('home-service-seat')),
      );
      final menuBefore = tester.getRect(
        find.byKey(const ValueKey('home-service-menu')),
      );
      final loginButton = tester.getRect(
        find.widgetWithText(ElevatedButton, '통합 로그인'),
      );
      if (size.width >= 960) {
        expect(find.text('전자출결'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('현재 단계:')), findsNothing);
        expect(loginButton.size, const Size(160, 44));
        expect(loginButton.center.dx, closeTo(bodyBefore.right - 80, 0.5));
        expect(loginButton.center.dy, closeTo(bodyBefore.top + 140, 0.5));
        final fields = find.byType(TextField);
        expect(
          tester.getRect(fields.last).top,
          greaterThan(tester.getRect(fields.first).bottom),
        );
        expect(
          loginButton.left,
          greaterThan(tester.getRect(fields.last).right),
        );
      } else {
        expect(loginButton.left, bodyBefore.left);
        expect(
          loginButton.top,
          greaterThan(tester.getRect(find.byType(TextField).last).bottom),
        );
      }
      expect(
        loginButton.width,
        size.width < 480 ? bodyBefore.width : lessThan(bodyBefore.width),
      );
      final titleTop = tester
          .getRect(find.text(size.width >= 960 ? '전자출결' : '통합 로그인').first)
          .top;
      if (size.width >= 1000) expect(before.width, lessThanOrEqualTo(800));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      (container.read(homeControllerProvider.notifier)
              as _PreviewHomeController)
          .show(const HomeState(isLoggedIn: true, userId: 'test-student'));
      final attendance =
          container.read(attendanceProvider.notifier)
              as _PreviewAttendanceController;
      for (final state in [
        const AttendanceState(phase: AttendancePhase.fetchingLecture),
        const AttendanceState(hasCheckedLecture: true),
        const AttendanceState(hasCheckedLecture: true, error: '연결을 확인해 주세요.'),
        AttendanceState(
          hasCheckedLecture: true,
          currentLecture: Lecture(
            name: '테스트 수업',
            time: '월 10:00 - 11:50',
            attendanceParams: {},
          ),
        ),
        for (final phase in [
          AttendancePhase.enteringCode,
          AttendancePhase.locating,
          AttendancePhase.submitting,
        ])
          AttendanceState(
            phase: phase,
            hasCheckedLecture: true,
            currentLecture: Lecture(
              name: '테스트 수업',
              time: '월 10:00 - 11:50',
              attendanceParams: {},
            ),
          ),
      ]) {
        attendance.show(state);
        await tester.pumpAndSettle();
        if (size.width >= 960) {
          final action = tester.getRect(find.byType(ElevatedButton).first);
          expect(action.center.dx, closeTo(loginButton.center.dx, 0.5));
          expect(action.center.dy, closeTo(loginButton.center.dy, 0.5));
          expect(action.size, loginButton.size);
          expect(find.bySemanticsLabel(RegExp('현재 단계:')), findsNothing);
        }
        expect(tester.getRect(panel).left, before.left);
        if (size.width < 600) {
          expect(tester.getRect(panel).bottom, before.bottom);
        } else {
          expect(tester.getRect(panel).top, before.top);
        }
        expect(tester.getRect(panel).width, before.width);
        expect(tester.getRect(body).left, bodyBefore.left);
        if (size.width >= 600) {
          expect(
            tester.getRect(body).top - tester.getRect(panel).top,
            closeTo(bodyBefore.top - before.top, 0.5),
          );
        }
        expect(tester.getRect(body).width, bodyBefore.width);
        expect(tester.getRect(find.text('홍익인간')), headerBefore);
        final content = tester.getRect(
          find.byKey(const ValueKey('home-attendance-main-content')),
        );
        if (size.width >= 600) {
          expect(
            tester.getRect(panel).bottom - content.bottom,
            inInclusiveRange(16, 140),
          );
        } else {
          expect(content.top, greaterThanOrEqualTo(tester.getRect(panel).top));
          expect(
            content.bottom,
            closeTo(tester.getRect(panel).bottom - 16, 0.5),
          );
        }
        final seat = tester.getRect(
          find.byKey(const ValueKey('home-service-seat')),
        );
        final menu = tester.getRect(
          find.byKey(const ValueKey('home-service-menu')),
        );
        expect(seat, seatBefore);
        expect(menu, menuBefore);
        if (state.hasCheckedLecture &&
            state.currentLecture == null &&
            state.error == null) {
          if (size.width >= 600) {
            expect(tester.getRect(panel).height, before.height);
          }
          final refreshButton = tester.getRect(
            find.widgetWithText(ElevatedButton, '수업 새로고침'),
          );
          if (size.width >= 960) {
            expect(refreshButton.center, loginButton.center);
          } else {
            expect(refreshButton.left, bodyBefore.left);
          }
          expect(
            refreshButton.width,
            size.width < 480 ? bodyBefore.width : lessThan(bodyBefore.width),
          );
        }
        if (size.width >= 600) {
          expect(
            tester.getRect(find.text('전자출결')).top - tester.getRect(panel).top,
            closeTo(titleTop - before.top, 0.5),
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (width: 320.0, height: 620.0, scale: 2.0),
    (width: 768.0, height: 360.0, scale: 1.0),
    (width: 1024.0, height: 768.0, scale: 2.0),
    (width: 1228.0, height: 714.0, scale: 1.0),
  ]) {
    testWidgets('긴 열람실·식단 결과 접근 ${scenario.width} 배율 ${scenario.scale}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(scenario.width, scenario.height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _subject(populated: true, textScale: scenario.scale),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('열람실'));
      await tester.tap(find.text('열람실'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('4층 노트북열람실2'));
      await tester.pumpAndSettle();
      final lastRoom = tester.getRect(find.text('4층 노트북열람실2'));
      expect(lastRoom.bottom, lessThanOrEqualTo(scenario.height));
      expect(lastRoom.top, greaterThanOrEqualTo(0));
      if (scenario.width == 1228) {
        final first = tester.getRect(find.text('제1열람실'));
        final second = tester.getRect(find.text('제2열람실'));
        expect(second.left, greaterThan(first.right));
        expect(second.top, first.top);
      }
      await tester.ensureVisible(find.text('학식 메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('학식 메뉴'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('계절 과일'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('계절 과일')).bottom,
        lessThanOrEqualTo(scenario.height),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('모바일에서 로그인 입력과 서비스 선택을 전환 후에도 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_subject());
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'test-student');
    await tester.enterText(find.byType(TextField).last, 'test-password');

    await tester.ensureVisible(find.text('열람실'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-seat'))).top,
      lessThan(200),
    );
    await tester.ensureVisible(find.text('R동'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('R동'));
    await tester.pump();

    await tester.ensureVisible(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-menu'))).top,
      lessThan(200),
    );
    await tester.ensureVisible(find.text('교직원 식당'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('교직원 식당'));
    await tester.pump();

    final menuContainer = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final menuState = menuContainer.read(cafeteriaMenuControllerProvider);
    final otherDate = menuState.dates.firstWhere(
      (date) => !MenuDateRange.isSameDate(date, menuState.selectedDate),
    );
    await tester.ensureVisible(
      find.text(MenuDateRange.weekdayLabel(otherDate)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(MenuDateRange.weekdayLabel(otherDate)));
    await tester.pump();

    await tester.ensureVisible(find.text('로그인·출결'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그인·출결'));
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.first.controller!.text, 'test-student');
    expect(fields.last.controller!.text, 'test-password');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(
      container.read(seatControllerProvider).selectedLocation,
      SeatLocation.rBuilding,
    );
    expect(
      container.read(cafeteriaMenuControllerProvider).selectedCafeteria?.name,
      isNull,
    );
    expect(
      container.read(cafeteriaMenuControllerProvider).selectedCafeteriaName,
      '교직원 식당',
    );
    expect(
      MenuDateRange.isSameDate(
        container.read(cafeteriaMenuControllerProvider).selectedDate,
        otherDate,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 화면과 키보드가 열린 상태에서도 세 기능에 접근할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 620);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _subject(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    await tester.ensureVisible(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('열람실'), findsOneWidget);
    expect(find.text('학식 메뉴'), findsOneWidget);
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('주간 식당 메뉴'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('넓은 홈 화면에서 주 영역은 크고 보조 영역은 오른쪽에 쌓인다', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_subject());
    await tester.pump();

    final attendance = tester.getRect(
      find.byKey(const ValueKey('home-service-attendance')),
    );
    final seat = tester.getRect(
      find.byKey(const ValueKey('home-service-seat')),
    );
    final menu = tester.getRect(
      find.byKey(const ValueKey('home-service-menu')),
    );
    expect(attendance.width, greaterThan(seat.width * 2));
    expect(seat.left, greaterThan(attendance.right));
    expect(menu.top, greaterThan(seat.bottom));
    expect(find.text('등록된 메뉴가 없어요'), findsOneWidget);
    expect(find.text('로그인 정보 처리 안내'), findsOneWidget);
    expect(find.text('공용 기기에서는 주의'), findsNothing);
    expect(find.text('로그인 후 진행'), findsNothing);

    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    expect(find.text('건물 선택'), findsNothing);
    expect(find.byType(SeatLocationSelector), findsOneWidget);
    expect(find.text('열람실별 좌석'), findsNothing);

    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    final promotedMenu = tester.getRect(
      find.byKey(const ValueKey('home-service-menu')),
    );
    expect(promotedMenu.width, attendance.width);
    expect(promotedMenu.top, greaterThan(0));
    expect(promotedMenu.bottom, lessThan(800));
    expect(find.text('날짜와 식당'), findsNothing);
    expect(find.text('선택한 식당의 메뉴'), findsNothing);
    final compactMenu = tester.getRect(
      find.byKey(const ValueKey('menu-compact-state')),
    );
    expect(compactMenu.width, greaterThan(600));
    expect(
      tester.getRect(find.text('등록된 메뉴가 없어요')).top,
      greaterThan(
        tester.getRect(find.byType(CafeteriaMenuDateSelector)).bottom,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('로그인 상태에서 320px·큰 글자·키보드에도 출결과 보조 영역을 사용할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 620);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _subject(
          homeState: const HomeState(isLoggedIn: true, userId: 'C211136'),
          attendanceState: const AttendanceState(hasCheckedLecture: true),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('출결 가능한 수업이 없어요'), findsOneWidget);
    expect(find.text('1 수업 확인'), findsNothing);
    expect(find.text('2 번호 입력'), findsNothing);
    await tester.ensureVisible(find.text('수업 새로고침'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('열람실'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    expect(find.text('열람실 좌석 현황'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('넓은 출결 화면에서 다음 동작을 오른쪽 중앙에 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _subject(
        homeState: const HomeState(isLoggedIn: true, userId: 'C211136'),
        attendanceState: const AttendanceState(hasCheckedLecture: true),
      ),
    );
    await tester.pump();
    expect(find.text('출결 가능한 수업이 없어요'), findsOneWidget);
    final action = tester.getRect(
      find.widgetWithText(ElevatedButton, '수업 새로고침'),
    );
    final body = tester.getRect(
      find.byKey(const ValueKey('home-attendance-body')),
    );
    expect(action.center.dx, closeTo(body.right - 80, 0.5));
    expect(action.center.dy, closeTo(body.top + 140, 0.5));
    expect(
      action.left,
      greaterThan(tester.getRect(find.text('출결 가능한 수업이 없어요')).right),
    );
    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그인·출결'));
    await tester.pumpAndSettle();
    expect(find.text('출결 가능한 수업이 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('첨부 화면 비율에서 홈 제목과 출결 동작이 첫 화면에 보인다', (tester) async {
    tester.view.physicalSize = const Size(1228, 714);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _subject(
        homeState: const HomeState(isLoggedIn: true, userId: 'C211136'),
        attendanceState: const AttendanceState(hasCheckedLecture: true),
      ),
    );
    await tester.pump();
    expect(tester.getRect(find.text('홍익인간')).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(find.text('수업 새로고침')).bottom, lessThan(714));
    final panel = tester.getRect(
      find.byKey(const ValueKey('home-service-attendance')),
    );
    expect(panel.bottom, lessThanOrEqualTo(714));
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 전자출결 주 영역은 내용 높이에 맞추고 보조 영역 위에 정렬한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _subject(
        homeState: const HomeState(isLoggedIn: true, userId: 'C211136'),
        attendanceState: const AttendanceState(hasCheckedLecture: true),
      ),
    );
    await tester.pumpAndSettle();
    final attendance = tester.getRect(
      find.byKey(const ValueKey('home-service-attendance')),
    );
    final seat = tester.getRect(
      find.byKey(const ValueKey('home-service-seat')),
    );
    final menu = tester.getRect(
      find.byKey(const ValueKey('home-service-menu')),
    );
    final content = tester.getRect(
      find.byKey(const ValueKey('home-attendance-main-content')),
    );
    expect(content.bottom, closeTo(attendance.bottom - 16, 0.5));
    expect(attendance.height, closeTo(content.height + 32, 0.5));
    expect(content.top, closeTo(attendance.top + 16, 0.5));
    expect(attendance.bottom + 12, seat.top);
    expect(menu.top, seat.bottom + 12);
    expect(seat.bottom, lessThanOrEqualTo(844));
    expect(tester.getRect(find.text('수업 새로고침')).bottom, lessThan(seat.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('높은 데스크톱은 헤더와 두 카드 열을 같은 시작선에 둔다', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_subject(populated: true));
    await tester.pumpAndSettle();
    final header = tester.getRect(find.text('홍익인간'));
    final panel = tester.getRect(
      find.byKey(const ValueKey('home-service-attendance')),
    );
    expect(header.top, greaterThan(40));
    final menu = tester.getRect(
      find.byKey(const ValueKey('home-service-menu')),
    );
    final seat = tester.getRect(
      find.byKey(const ValueKey('home-service-seat')),
    );
    expect(header.bottom, lessThan(seat.top));
    expect(header.left, greaterThan(panel.right));
    expect(menu.top, seat.bottom + 12);
    expect(menu.bottom, isNot(panel.bottom));
    expect((panel.center.dy - (seat.top + menu.bottom) / 2).abs(), lessThan(1));
    expect(seat.height, lessThan(250));
    expect(menu.height, lessThan(250));
    expect(panel.bottom, lessThan(800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일에서 긴 주 영역을 스크롤해도 두 보조 행은 그 아래에 남는다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_subject(populated: true));
    await tester.pumpAndSettle();
    final seatBefore = tester.getRect(
      find.byKey(const ValueKey('home-service-seat')),
    );
    final menuBefore = tester.getRect(
      find.byKey(const ValueKey('home-service-menu')),
    );
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    final attendanceDock = tester.getRect(
      find.byKey(const ValueKey('home-service-attendance')),
    );
    final seatDock = tester.getRect(
      find.byKey(const ValueKey('home-service-seat')),
    );
    expect(attendanceDock.size, menuBefore.size);
    expect(seatDock.size, seatBefore.size);
    expect(attendanceDock.top, seatDock.bottom + 12);
    expect(
      seatDock.top,
      tester.getRect(find.byKey(const ValueKey('home-service-menu'))).bottom +
          12,
    );

    await tester.ensureVisible(find.text('계절 과일'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('계절 과일')).bottom,
      lessThanOrEqualTo(seatDock.top),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-attendance'))),
      attendanceDock,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-seat'))),
      seatDock,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('넓은 화면의 열람실과 학식은 선택과 결과를 분리해 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_subject(populated: true));
    await tester.pump();
    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    expect(find.text('제1열람실'), findsOneWidget);
    expect(find.text('열람실별 좌석'), findsNothing);
    expect(
      tester.getSize(find.byType(SeatLocationSelector)).width,
      lessThanOrEqualTo(240),
    );
    expect(tester.getSize(find.byType(SeatLocationSelector)).height, 46);
    expect(
      tester.getRect(find.text('제1열람실')).top,
      greaterThan(tester.getRect(find.byType(SeatLocationSelector)).bottom),
    );

    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('선택한 식당의 메뉴'), findsNothing);
    expect(find.text('백미밥'), findsOneWidget);
    final dateSelector = tester.getRect(find.byType(CafeteriaMenuDateSelector));
    final cafeteriaSelector = tester.getRect(find.byType(CafeteriaSelector));
    expect(dateSelector.width, lessThanOrEqualTo(280));
    expect(cafeteriaSelector.width, lessThanOrEqualTo(280));
    expect(dateSelector.height, 46);
    expect(cafeteriaSelector.height, 46);
    expect(dateSelector.right, lessThan(cafeteriaSelector.left));
    expect(
      tester.getRect(find.text('백미밥')).top,
      greaterThan(
        tester.getRect(find.byType(CafeteriaMenuDateSelector)).bottom,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _subject({
  HomeState? homeState,
  AttendanceState? attendanceState,
  bool populated = false,
  double? textScale,
  ThemeMode themeMode = ThemeMode.system,
  DateTime? campusTime,
  NotifierProvider<_PreviewCampusClock, DateTime>? campusClock,
  bool showDebugBanner = true,
}) {
  final previewTime = campusTime ?? DateTime(2026, 10, 1, 12);
  return ProviderScope(
    overrides: [
      if (campusClock != null)
        homeCampusTimeProvider.overrideWith((ref) => ref.watch(campusClock)),
      if (campusClock != null)
        campusClockProvider.overrideWith(
          (ref) =>
              () => ref.read(campusClock),
        ),
      if (campusClock == null)
        homeCampusTimeProvider.overrideWithValue(previewTime),
      if (campusClock == null)
        campusClockProvider.overrideWithValue(() => previewTime),
      schoolTransportProvider.overrideWithValue(_FakeSchoolTransport()),
      seatControllerProvider.overrideWith(
        () => _PreviewSeatController(populated),
      ),
      cafeteriaMenuControllerProvider.overrideWith(
        () => _PreviewCafeteriaMenuController(populated),
      ),
      if (homeState != null)
        homeControllerProvider.overrideWith(
          () => _PreviewHomeController(homeState),
        ),
      if (attendanceState != null)
        attendanceProvider.overrideWith(
          () => _PreviewAttendanceController(attendanceState),
        ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: showDebugBanner,
      navigatorKey: navigatorKey,
      builder: (context, child) => textScale == null
          ? child!
          : MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
      theme: themeData,
      themeMode: themeMode,
      darkTheme: darkThemeData,
      home: const HomeScreen(),
    ),
  );
}

class _PreviewHomeController extends HomeController {
  _PreviewHomeController(this.initial);
  final HomeState initial;
  void show(HomeState value) => state = value;

  @override
  HomeState build() => initial;

  @override
  Future<void> logout() async {
    ref.read(attendanceProvider.notifier).resetSession();
    state = state.copyWith(
      isLoading: false,
      isLoggedIn: false,
      autoLogin: false,
      statusMessage: '로그아웃했어요.',
    );
  }

  @override
  Future<void> initializeApp(
    TextEditingController idController,
    TextEditingController pwController,
  ) async {}
}

class _PreviewAttendanceController extends AttendanceController {
  _PreviewAttendanceController(this.initial);
  final AttendanceState initial;
  bool failNextAttendance = false;
  int automaticRefreshCount = 0;
  void show(AttendanceState value) => state = value;

  @override
  AttendanceState build() => initial;

  @override
  Future<void> fetchLecture({
    bool forceRefresh = false,
    bool isAutomatic = false,
  }) async {
    if (isAutomatic) automaticRefreshCount++;
  }

  @override
  Future<AttendanceSubmissionResult?> performAttendance({
    required Future<String?> Function() requestAuthCode,
    required bool Function() canContinue,
    String? userId,
  }) async {
    if (failNextAttendance) {
      failNextAttendance = false;
      throw Exception('위치 확인에 실패했어요.');
    }
    return super.performAttendance(
      userId: userId,
      requestAuthCode: requestAuthCode,
      canContinue: canContinue,
    );
  }
}

class _PreviewSeatController extends SeatController {
  _PreviewSeatController(this.populated);
  final bool populated;

  @override
  SeatState build() => SeatState(
    statuses: populated
        ? {
            SeatLocation.tBuilding: SeatStatus(
              location: SeatLocation.tBuilding,
              updatedAt: DateTime(2026, 9, 23, 12, 0),
              seats: const [
                Seat(
                  name: '계',
                  totalSeats: 200,
                  usedSeats: 80,
                  availableSeats: 120,
                  usageRate: 40,
                ),
                Seat(
                  name: '제1열람실',
                  totalSeats: 60,
                  usedSeats: 40,
                  availableSeats: 20,
                  usageRate: 66.7,
                ),
                Seat(
                  name: '제2열람실',
                  totalSeats: 40,
                  usedSeats: 25,
                  availableSeats: 15,
                  usageRate: 62.5,
                ),
                Seat(
                  name: '3층 노트북열람실1',
                  totalSeats: 50,
                  usedSeats: 10,
                  availableSeats: 40,
                  usageRate: 20,
                ),
                Seat(
                  name: '4층 노트북열람실2',
                  totalSeats: 50,
                  usedSeats: 5,
                  availableSeats: 45,
                  usageRate: 10,
                ),
              ],
            ),
          }
        : const {},
  );

  @override
  Future<void> fetchSelectedStatus({bool forceRefresh = false}) async {}

  @override
  Future<void> fetchStatusForLocation(
    SeatLocation location, {
    bool forceRefresh = false,
  }) async {}

  @override
  Future<void> refresh() async {}

  @override
  void selectLocation(SeatLocation location) {
    state = state.copyWith(selectedLocation: location);
  }
}

class _PreviewCafeteriaMenuController extends CafeteriaMenuController {
  _PreviewCafeteriaMenuController(this.populated);
  final bool populated;
  final List<DateTime> requestedDates = [];

  @override
  CafeteriaMenuState build() {
    final base = MenuDateRange.dateOnly(ref.read(campusClockProvider)());
    final dates = MenuDateRange.displayWeekdaysFor(base);
    final selected = MenuDateRange.initialSelectedDateFor(base);
    return CafeteriaMenuState(
      baseDate: base,
      selectedDate: selected,
      dates: dates,
      menus: [
        DailyMenu(
          date: selected,
          weekday: MenuDateRange.weekdayLabel(selected),
          cafeterias:
              const [
                    CafeteriaMenu(name: '기숙사 식당', priceInfo: '', meals: []),
                    CafeteriaMenu(name: '교직원 식당', priceInfo: '', meals: []),
                  ]
                  .map(
                    (cafeteria) => populated && cafeteria.isDormitory
                        ? const CafeteriaMenu(
                            name: '기숙사 식당',
                            priceInfo: '5,000원',
                            meals: [
                              MealMenu(
                                type: MealType.lunch,
                                time: '11:30~14:00',
                                items: [
                                  '백미밥',
                                  '미역국',
                                  '돼지고기 두루치기',
                                  '계절 나물 무침',
                                  '배추김치',
                                  '후식 요구르트',
                                ],
                              ),
                              MealMenu(
                                type: MealType.dinner,
                                time: '17:00~19:00',
                                items: [
                                  '볶음밥',
                                  '유부 장국',
                                  '치킨 가라아게',
                                  '샐러드와 드레싱',
                                  '깍두기',
                                  '계절 과일',
                                ],
                              ),
                            ],
                          )
                        : cafeteria,
                  )
                  .toList(),
        ),
      ],
    );
  }

  @override
  Future<void> fetchInitialMenu({bool forceRefresh = false}) async {}

  @override
  Future<void> fetchMenuForDate(
    DateTime date, {
    DateTime? baseDate,
    bool forceRefresh = false,
  }) async {
    requestedDates.add(date);
  }

  @override
  Future<void> fetchMenus({
    DateTime? baseDate,
    bool forceRefresh = false,
  }) async {}

  @override
  Future<void> refresh() async {}
}

class _PreviewCampusClock extends Notifier<DateTime> {
  _PreviewCampusClock(this.initial);
  final DateTime initial;
  @override
  DateTime build() => initial;
  void show(DateTime next) => state = next;
}

class _FakeSchoolTransport implements SchoolTransport {
  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    throw UnsupportedError('이 테스트에서는 학교 서버 요청을 사용하지 않습니다.');
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    throw UnsupportedError('이 테스트에서는 학교 서버 요청을 사용하지 않습니다.');
  }

  @override
  Future<void> clearAuthSession() async {}

  @override
  Future<bool> hasAuthSession() async => false;

  @override
  Future<bool> hasCookie(Uri target, String name) async => false;

  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
