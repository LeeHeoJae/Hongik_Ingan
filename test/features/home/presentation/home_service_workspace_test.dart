import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_service_workspace.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_attendance_density.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_campus_summary.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

void main() {
  testWidgets('menu summary emphasizes only the leading label', (tester) async {
    for (final width in [390.0, 1200.0]) {
      for (final dark in [false, true]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        final leading = ValueNotifier<int?>(1);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: dark ? darkThemeData : themeData,
              home: Scaffold(
                body: ValueListenableBuilder<int?>(
                  valueListenable: leading,
                  builder: (context, leadingIndex, _) => HomeServiceWorkspace(
                    availableHeight: 900,
                    viewportHeight: 900,
                    adaptiveMobileLayout: width < 600,
                    wideHeader: const SizedBox(height: 48),
                    detailBuilder: (_, _) => const SizedBox(height: 180),
                    summaryBuilder: (service, _) => service == HomeService.menu
                        ? HomeServiceSummaryData(
                            status: 'A안 · 메뉴 하나\nB안 · 메뉴 둘',
                            leadingMenuIndex: leadingIndex,
                            hasMenuChoices: true,
                          )
                        : const HomeServiceSummaryData(status: 'Ready'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final text = tester.widget<Text>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.textSpan
                        ?.toPlainText(includeSemanticsLabels: false)
                        .contains('B안 · 메뉴 둘') ??
                    false),
          ),
        );
        final span = text.textSpan! as TextSpan;
        Iterable<TextSpan> descendants(TextSpan parent) sync* {
          yield parent;
          for (final child
              in parent.children?.whereType<TextSpan>() ?? <TextSpan>[]) {
            yield* descendants(child);
          }
        }

        final spans = descendants(span).toList();
        final highlighted = spans.firstWhere((child) => child.text == 'B안');
        expect(highlighted.style?.fontWeight, FontWeight.w700);
        expect(
          spans.any(
            (child) =>
                child.style?.color ==
                (dark ? darkThemeData : themeData).colorScheme.primary,
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        final card = find.byKey(const ValueKey('home-service-menu'));
        final before = tester.getRect(card);
        leading.value = null;
        await tester.pumpAndSettle();
        expect(tester.getRect(card), before);
        await tester.pumpWidget(const SizedBox.shrink());
        leading.dispose();
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  for (final width in [390.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Seat refresh preserves summary bounds: $width at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final refreshing = ValueNotifier(false);
        addTearDown(refreshing.dispose);
        final status = SeatStatus(
          location: SeatLocation.tBuilding,
          updatedAt: DateTime(2026, 10, 22),
          seats: const [
            Seat(
              name: '노트북열람실',
              totalSeats: 100,
              usedSeats: 15,
              availableSeats: 85,
              usageRate: 15,
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: themeData,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: refreshing,
                    builder: (_, loading, _) => HomeServiceWorkspace(
                      availableHeight: 900,
                      viewportHeight: 900,
                      adaptiveMobileLayout: width < 600,
                      wideHeader: const SizedBox(height: 48),
                      detailBuilder: (_, _) => const SizedBox(height: 180),
                      summaryBuilder: (service, _) =>
                          service == HomeService.seat
                          ? HomeCampusSummary.seats(
                              status: status,
                              error: null,
                              loading: loading,
                            )
                          : const HomeServiceSummaryData(status: 'Ready'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final panel = find.byKey(const ValueKey('home-service-seat'));
        final before = tester.getRect(panel);
        for (final loading in [true, false]) {
          refreshing.value = loading;
          await tester.pump();
          expect(tester.getRect(panel), before);
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.getRect(panel), before);
          await tester.pumpAndSettle();
          expect(tester.getRect(panel), before);
          expect(find.text('좌석 갱신 중'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final size in [
    const Size(320, 620),
    const Size(768, 360),
    const Size(1200, 900),
  ]) {
    for (final service in [HomeService.seat, HomeService.menu]) {
      testWidgets('Detail viewport stays stable: $service at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final height = ValueNotifier<double>(180);
        addTearDown(height.dispose);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: HomeServiceWorkspace(
                    availableHeight: size.height,
                    viewportHeight: size.height,
                    adaptiveMobileLayout: size.width < 600,
                    attendanceHeightReduction: (_) => 0,
                    wideHeader: const Text('Header'),
                    detailBuilder: (item, _) => ValueListenableBuilder<double>(
                      valueListenable: height,
                      builder: (_, value, _) => SizedBox(
                        height: value,
                        child: Column(
                          children: [
                            TextButton(
                              onPressed: () {},
                              child: Text('select-${item.name}'),
                            ),
                            const Spacer(),
                            Text('end-${item.name}'),
                          ],
                        ),
                      ),
                    ),
                    summaryBuilder: (_, _) =>
                        const HomeServiceSummaryData(status: 'Ready'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(service.title));
        await tester.pumpAndSettle();
        final panel = find.byKey(ValueKey('home-service-${service.name}'));
        final control = find.text('select-${service.name}');
        final panelBefore = tester.getRect(panel);
        final controlBefore = tester.getRect(control);
        for (final nextHeight in [1100.0, 100.0, 700.0]) {
          height.value = nextHeight;
          await tester.pumpAndSettle();
          expect(tester.getRect(panel), panelBefore);
          expect(tester.getRect(control), controlBefore);
        }
        height.value = 1100;
        await tester.pumpAndSettle();
        expect(tester.getRect(panel), panelBefore);
        expect(tester.getRect(control), controlBefore);
        final scrollable = find.descendant(
          of: find.byKey(PageStorageKey('home-detail-${service.name}')),
          matching: find.byType(Scrollable),
        );
        expect(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
          greaterThan(0),
        );
        await tester.ensureVisible(find.text('end-${service.name}'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('end-${service.name}')).bottom,
          lessThanOrEqualTo(size.height),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('좌석 갱신 실패 경고는 큰 글자에서도 잘리지 않는다: $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: themeData,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: HomeServiceWorkspace(
                  availableHeight: 844,
                  viewportHeight: 812,
                  adaptiveMobileLayout: true,
                  detailBuilder: (_, _) => const SizedBox(height: 180),
                  summaryBuilder: (service, _) => service == HomeService.seat
                      ? const HomeServiceSummaryData(
                          eyebrow: 'T동 노트북 열람실',
                          status: '85석 남음',
                          warning: '갱신 실패 · 이전 정보',
                          compactWarning: '이전 정보',
                        )
                      : const HomeServiceSummaryData(status: 'Ready'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final warning = find.text('이전 정보');
      final paragraph = tester.renderObject<RenderParagraph>(warning);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 5),
        ),
        isNotEmpty,
      );
      final card = tester.getRect(
        find.byKey(const ValueKey('home-service-seat')),
      );
      final warningRect = tester.getRect(warning);
      expect(warningRect.top, greaterThanOrEqualTo(card.top));
      expect(warningRect.bottom, lessThanOrEqualTo(card.bottom));
      expect(warningRect.right, lessThanOrEqualTo(card.right));
      expect(find.text('85석 남음'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '열람실, T동 노트북 열람실, 85석 남음, 갱신 실패 · 이전 정보, 주 영역으로 이동',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('Wide header moves smoothly when an auxiliary card is selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const headerKey = ValueKey('test-wide-header');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeServiceWorkspace(
                availableHeight: 900,
                viewportHeight: 850,
                wideHeader: const SizedBox(key: headerKey, height: 48),
                detailBuilder: (service, _) =>
                    SizedBox(height: service == HomeService.seat ? 640 : 260),
                summaryBuilder: (_, _) =>
                    const HomeServiceSummaryData(status: 'Ready'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final header = find.byKey(headerKey);
    for (final label in ['열람실', '학식 메뉴', '로그인·출결']) {
      final before = tester.getRect(header);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(tester.getRect(header).top, closeTo(before.top, 0.5));
      await tester.pump(const Duration(milliseconds: 100));
      final intermediate = tester.getRect(header);
      await tester.pumpAndSettle();
      final after = tester.getRect(header);
      if ((after.top - before.top).abs() <= 1) {
        // Text styles can change a summary's measured height by a pixel.
        expect(after.top, closeTo(before.top, 1));
        expect(intermediate.top, closeTo(before.top, 1));
      } else {
        expect(
          intermediate.top,
          inExclusiveRange(
            before.top < after.top ? before.top : after.top,
            before.top > after.top ? before.top : after.top,
          ),
        );
      }
      final topAuxiliary = label == '열람실'
          ? 'attendance'
          : label == '학식 메뉴'
          ? 'attendance'
          : 'menu';
      final card = tester.getRect(
        find.byKey(ValueKey('home-service-$topAuxiliary')),
      );
      expect(after.bottom + 12, closeTo(card.top, 0.5));
    }
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (width: 1200.0, scale: 1.0, dark: false),
    (width: 1024.0, scale: 1.5, dark: false),
    (width: 1200.0, scale: 1.0, dark: true),
  ]) {
    testWidgets('Long menu demotion completes without retargeting: $scenario', (
      tester,
    ) async {
      tester.view.physicalSize = Size(scenario.width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final menu = ValueNotifier(
        'A option rice noodles soup vegetables and chicken\n'
        'B option pork cutlet salad pasta and dessert',
      );
      addTearDown(menu.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: scenario.dark ? darkThemeData : themeData,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ValueListenableBuilder<String>(
                  valueListenable: menu,
                  builder: (_, status, _) => HomeServiceWorkspace(
                    availableHeight: 900,
                    viewportHeight: 850,
                    wideHeader: const SizedBox(height: 48),
                    detailBuilder: (_, _) => const SizedBox(height: 260),
                    summaryBuilder: (service, _) => HomeServiceSummaryData(
                      status: service == HomeService.menu ? status : 'Ready',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final services = [
        for (final service in HomeService.values) find.byKey(ValueKey(service)),
        find.byKey(const ValueKey('home-wide-header')),
      ];

      for (final updateWhilePrimary in [false, true]) {
        await tester.tap(find.text(HomeService.menu.title));
        await tester.pumpAndSettle();
        if (updateWhilePrimary) {
          menu.value += '\nC option fish potatoes beans and fresh fruit';
          tester.view.physicalSize = Size(scenario.width - 64, 900);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(HomeService.attendance.title));
        await tester.pump();
        final targets = [
          for (final finder in services)
            tester.widget<AnimatedPositioned>(finder),
        ];
        for (var frame = 0; frame < 25; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          for (var index = 0; index < services.length; index++) {
            final target = tester.widget<AnimatedPositioned>(services[index]);
            expect(
              (target.left, target.top, target.width, target.height),
              (
                targets[index].left,
                targets[index].top,
                targets[index].width,
                targets[index].height,
              ),
              reason: 'Frame $frame must use the same final geometry',
            );
          }
        }
        final completed = [
          for (final finder in services) tester.getRect(finder),
        ];
        await tester.pumpAndSettle();
        for (var index = 0; index < services.length; index++) {
          expect(tester.getRect(services[index]), completed[index]);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Summary updates and resizing keep each card fitted to its content',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final summary = ValueNotifier(
        const HomeServiceSummaryData(status: 'Ready'),
      );
      addTearDown(summary.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ValueListenableBuilder<HomeServiceSummaryData>(
                  valueListenable: summary,
                  builder: (context, data, child) => HomeServiceWorkspace(
                    availableHeight: 900,
                    viewportHeight: 850,
                    adaptiveMobileLayout:
                        MediaQuery.sizeOf(context).width < 600,
                    detailBuilder: (service, _) => const SizedBox(height: 220),
                    summaryBuilder: (service, _) => data,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final seat = find.byKey(const ValueKey('home-service-seat'));
      final initialHeight = tester.getSize(seat).height;
      summary.value = const HomeServiceSummaryData(
        status: 'Unable to load the selected location',
        secondary: 'Check the connection and try again in a moment.',
        facts: [(label: 'Location', value: 'Building T')],
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(seat).height, greaterThan(initialHeight));
      for (final width in [1024.0, 390.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(find.byKey(const ValueKey('home-service-attendance')))
              .height,
          220,
        );
        if (width > 1000) {
          final seatRect = tester.getRect(seat);
          final menuRect = tester.getRect(
            find.byKey(const ValueKey('home-service-menu')),
          );
          expect(menuRect.top, closeTo(seatRect.bottom + 12, 0.5));
          for (final service in ['seat', 'menu']) {
            final scrollable = find.descendant(
              of: find.byKey(ValueKey('home-service-$service')),
              matching: find.byType(Scrollable),
            );
            expect(
              tester
                  .state<ScrollableState>(scrollable)
                  .position
                  .maxScrollExtent,
              lessThan(1),
            );
          }
        }
        expect(tester.takeException(), isNull);
      }
      summary.value = const HomeServiceSummaryData(status: 'Ready');
      await tester.pumpAndSettle();
      expect(tester.getSize(seat).height, closeTo(initialHeight, 0.5));
    },
  );

  for (final width in [390.0, 1228.0]) {
    testWidgets('내용에 맞춰 높이를 줄이고 긴 내용에 접근한다: $width', (tester) async {
      tester.view.physicalSize = Size(width, 714);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final height = ValueNotifier<double>(220);
      addTearDown(height.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeServiceWorkspace(
                  availableHeight: 714,
                  viewportHeight: 714,
                  adaptiveMobileLayout: width < 600,
                  attendanceHeightReduction: (_) => 0,
                  detailBuilder: (service, _) => ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (context, value, _) => SizedBox(
                      height:
                          value -
                          (width >= 600 && service == HomeService.attendance
                              ? HomeAttendanceDensityScope.of(
                                  context,
                                ).heightReduction
                              : 0),
                      child: Column(
                        children: [
                          Text('start-${service.name}'),
                          const Spacer(),
                          Text('end-${service.name}'),
                        ],
                      ),
                    ),
                  ),
                  summaryBuilder: (_, _) =>
                      const HomeServiceSummaryData(status: '확인 중'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('home-service-attendance'));
      expect(tester.getSize(panel).height, 220);
      final seatBefore = tester.getRect(
        find.byKey(const ValueKey('home-service-seat')),
      );
      final menuBefore = tester.getRect(
        find.byKey(const ValueKey('home-service-menu')),
      );
      if (width > 1000) {
        final seat = tester.getRect(
          find.byKey(const ValueKey('home-service-seat')),
        );
        final menu = tester.getRect(
          find.byKey(const ValueKey('home-service-menu')),
        );
        expect(seat.top, tester.getRect(panel).top);
        expect(menu.top, seat.bottom + 12);
        expect(menu.bottom, isNot(tester.getRect(panel).bottom));
      }
      height.value = 1000;
      await tester.pumpAndSettle();
      double expectedAttendanceHeight() =>
          1000 -
          (width >= 600
              ? HomeAttendanceDensityScope.of(
                  tester.element(find.text('end-attendance')),
                ).heightReduction
              : 0);
      expect(tester.getSize(panel).height, expectedAttendanceHeight());
      if (width > 1000) {
        final seat = tester.getRect(
          find.byKey(const ValueKey('home-service-seat')),
        );
        final menu = tester.getRect(
          find.byKey(const ValueKey('home-service-menu')),
        );
        expect(seat.topLeft, seatBefore.topLeft);
        expect(seat.width, seatBefore.width);
        expect(seat.height, lessThanOrEqualTo(seatBefore.height));
        expect(menu.left, menuBefore.left);
        expect(menu.width, menuBefore.width);
        expect(menu.top, seat.bottom + 12);
      } else {
        final seat = tester.getRect(
          find.byKey(const ValueKey('home-service-seat')),
        );
        final menu = tester.getRect(
          find.byKey(const ValueKey('home-service-menu')),
        );
        expect(seat.top, greaterThanOrEqualTo(tester.getRect(panel).bottom));
        expect(menu.top, seat.top);
      }
      await tester.ensureVisible(find.text('end-attendance'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('end-attendance')).bottom,
        lessThanOrEqualTo(714),
      );
      if (width > 1000) {
        expect(
          find.descendant(of: panel, matching: find.byType(Scrollable)),
          findsNothing,
        );
        await tester.ensureVisible(find.text('열람실'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('열람실'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('로그인·출결'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('로그인·출결'));
        await tester.pumpAndSettle();
        expect(tester.getSize(panel).height, expectedAttendanceHeight());
      }
      height.value = 220;
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, 220);
      if (width > 1000) {
        final seat = tester.getRect(
          find.byKey(const ValueKey('home-service-seat')),
        );
        final menu = tester.getRect(
          find.byKey(const ValueKey('home-service-menu')),
        );
        expect(seat.top, tester.getRect(panel).top);
        expect(menu.top, seat.bottom + 12);
        expect(menu.bottom, isNot(tester.getRect(panel).bottom));
      }
      expect(tester.takeException(), isNull);
    });
  }

  Widget subject({
    ValueChanged<HomeService>? onPrimaryChanged,
    bool reduceMotion = false,
    bool scrollableDetails = false,
    double availableHeight = 760,
    double contentHeight = 220,
    bool withSummaryFacts = false,
  }) {
    return ProviderScope(
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) => HomeServiceWorkspace(
                  availableHeight: availableHeight,
                  viewportHeight: availableHeight - 32,
                  adaptiveMobileLayout: MediaQuery.sizeOf(context).width < 600,
                  attendanceHeightReduction: (_) => 0,
                  detailBuilder: (service, isPrimary) => Builder(
                    builder: (context) => SizedBox(
                      height:
                          (scrollableDetails ? 320 : contentHeight) -
                          (MediaQuery.sizeOf(context).width >= 600 &&
                                  service == HomeService.attendance
                              ? HomeAttendanceDensityScope.of(
                                  context,
                                ).heightReduction
                              : 0),
                      child: scrollableDetails
                          ? _ScrollDetail(service: service)
                          : _CounterDetail(service: service),
                    ),
                  ),
                  summaryBuilder: (service, ref) => HomeServiceSummaryData(
                    status: '확인 중',
                    facts: withSummaryFacts
                        ? const [(label: '선택', value: 'T동')]
                        : const [],
                  ),
                  onPrimaryChanged: onPrimaryChanged,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('모바일은 보조 영역 둘을 아래에 두고 반복 전환해 상세 상태를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selected = <HomeService>[];

    await tester.pumpWidget(subject(onPrimaryChanged: selected.add));
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
    expect(seat.top, greaterThan(attendance.bottom));
    expect(menu.top, seat.top);
    expect(seat.right, lessThan(menu.left));

    await tester.tap(find.byKey(const ValueKey('detail-attendance')));
    await tester.pump();
    expect(find.text('attendance: 1'), findsOneWidget);

    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-seat')), findsOneWidget);

    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-menu')), findsOneWidget);

    await tester.tap(find.text('로그인·출결'));
    await tester.pumpAndSettle();
    expect(find.text('attendance: 1'), findsOneWidget);
    expect(selected, [
      HomeService.seat,
      HomeService.menu,
      HomeService.attendance,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('넓은 화면은 큰 주 영역 오른쪽에 보조 영역 둘을 쌓는다', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(subject());
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
    expect(attendance.width, greaterThan(seat.width * 2));
    expect(seat.left, greaterThan(attendance.right));
    expect(menu.left, seat.left);
    expect(menu.top, greaterThan(seat.bottom));

    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    final promotedSeat = tester.getRect(
      find.byKey(const ValueKey('home-service-seat')),
    );
    expect(promotedSeat.width, greaterThan(attendance.width / 2));
    expect(promotedSeat.height, greaterThan(attendance.height));
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-menu'))).height,
      greaterThan(promotedSeat.height),
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 900.0, 1200.0]) {
    testWidgets('열람실 주 영역 높이는 내용 변화에 안정적이다: $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final contentHeight = ValueNotifier<double>(220);
      addTearDown(contentHeight.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<double>(
          valueListenable: contentHeight,
          builder: (_, height, _) =>
              subject(availableHeight: 900, contentHeight: height),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('열람실'));
      await tester.pumpAndSettle();
      final seat = find.byKey(const ValueKey('home-service-seat'));
      final before = tester.getRect(seat);
      expect(before.height, width == 1200 ? 400 : 420);

      contentHeight.value = 560;
      await tester.pumpAndSettle();
      expect(tester.getRect(seat), before);
      await tester.tap(find.text('학식 메뉴'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('home-service-menu'))).height,
        greaterThan(before.height),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('900px 작업 폭에서는 보조 영역을 아래에 나란히 배치한다', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(subject(availableHeight: 700));
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
    expect(seat.bottom, lessThan(attendance.top));
    expect(menu.top, seat.top);
    expect(seat.right, lessThan(menu.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('1228×714 화면은 내용이 짧을 때 작업영역과 미리보기를 압축한다', (tester) async {
    tester.view.physicalSize = const Size(1228, 714);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      subject(availableHeight: 714, withSummaryFacts: true),
    );
    await tester.pumpAndSettle();

    final attendance = tester.getRect(
      find.byKey(const ValueKey('home-service-attendance')),
    );
    final seat = find.byKey(const ValueKey('home-service-seat'));
    expect(attendance.height, 220);
    expect(tester.getRect(seat).height, lessThan(attendance.height));
    expect(tester.getRect(seat).left, greaterThan(attendance.right));

    final title = tester.getRect(
      find.descendant(of: seat, matching: find.text('열람실')),
    );
    final status = tester.getRect(
      find.descendant(of: seat, matching: find.text('확인 중')),
    );
    final fact = tester.getRect(
      find.descendant(of: seat, matching: find.text('선택')),
    );
    expect(status.top - title.bottom, lessThan(30));
    expect(fact.top - status.bottom, lessThan(36));
    expect(tester.takeException(), isNull);
  });

  testWidgets('높이가 낮은 넓은 창에서는 주 영역을 최소 높이로 줄이고 내용을 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(1000, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      subject(availableHeight: 420, scrollableDetails: true),
    );
    await tester.pumpAndSettle();

    final attendance = tester.getRect(
      find.byKey(const ValueKey('home-service-attendance')),
    );
    final seat = tester.getRect(
      find.byKey(const ValueKey('home-service-seat')),
    );
    expect(attendance.height, 320);
    expect(seat.height, lessThan(attendance.height));
    expect(find.byKey(const ValueKey('scroll-attendance')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('주 영역의 내용량과 선택에 따라 높이를 바꿔도 상세 상태를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final forceLong = ValueNotifier(false);
    addTearDown(forceLong.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: forceLong,
        builder: (context, isLong, child) =>
            subject(contentHeight: isLong ? 560 : 220),
      ),
    );
    await tester.pumpAndSettle();
    final attendance = find.byKey(const ValueKey('home-service-attendance'));
    expect(tester.getRect(attendance).height, 220);
    await tester.tap(find.byKey(const ValueKey('detail-attendance')));
    await tester.pump();
    expect(find.text('attendance: 1'), findsOneWidget);

    forceLong.value = true;
    await tester.pumpAndSettle();
    expect(tester.getRect(attendance).height, 560);
    forceLong.value = false;
    await tester.pumpAndSettle();
    expect(tester.getRect(attendance).height, 220);

    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-seat'))).height,
      greaterThan(220),
    );
    await tester.tap(find.text('로그인·출결'));
    await tester.pumpAndSettle();
    expect(tester.getRect(attendance).height, 220);
    expect(find.text('attendance: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px와 큰 글자에서도 보조 버튼 이름을 표시한다', (tester) async {
    tester.view.physicalSize = const Size(320, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: subject(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('열람실'), findsOneWidget);
    expect(find.text('학식 메뉴'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('움직임 줄이기 설정을 적용하고 보조 영역의 접근성 이름을 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(subject(reduceMotion: true));
    await tester.pump();

    for (final position in tester.widgetList<AnimatedPositioned>(
      find.byType(AnimatedPositioned),
    )) {
      expect(position.duration, Duration.zero);
    }
    expect(
      tester
          .widget<TweenAnimationBuilder<double>>(
            find.byType(TweenAnimationBuilder<double>),
          )
          .duration,
      Duration.zero,
    );
    expect(find.bySemanticsLabel('열람실, 확인 중, 주 영역으로 이동'), findsOneWidget);
    expect(find.bySemanticsLabel('학식 메뉴, 확인 중, 주 영역으로 이동'), findsOneWidget);
    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    final promotedFocus = tester.widget<Focus>(
      find.byKey(const ValueKey('home-service-seat-detail-focus')),
    );
    expect(promotedFocus.focusNode?.hasPrimaryFocus, isTrue);
    semantics.dispose();
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets('Tab traversal only reaches visible service controls: $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nodes = {
        for (final service in HomeService.values)
          service: FocusNode(debugLabel: service.name),
      };
      addTearDown(() {
        for (final node in nodes.values) {
          node.dispose();
        }
      });
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HomeServiceWorkspace(
                availableHeight: 844,
                viewportHeight: 844,
                adaptiveMobileLayout: width < 600,
                detailBuilder: (service, _) => SizedBox(
                  height: 180,
                  child: Center(
                    child: TextButton(
                      focusNode: nodes[service],
                      onPressed: () {},
                      child: Text('detail-${service.name}'),
                    ),
                  ),
                ),
                summaryBuilder: (_, _) =>
                    const HomeServiceSummaryData(status: 'Ready'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final primary in HomeService.values) {
        if (primary != HomeService.attendance) {
          await tester.tap(find.text(primary.title));
          await tester.pumpAndSettle();
        }
        for (final reverse in [false, true]) {
          nodes[primary]!.requestFocus();
          await tester.pump();
          final visitedServices = <HomeService>{};
          if (reverse) {
            await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          }
          for (var step = 0; step < 6; step++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            final focusContext = FocusManager.instance.primaryFocus?.context;
            expect(focusContext, isNotNull);
            focusContext!.visitAncestorElements((element) {
              final widget = element.widget;
              if (widget is Offstage) {
                expect(
                  widget.offstage,
                  isFalse,
                  reason:
                      'Tab reached a hidden control while $primary is primary',
                );
              }
              for (final service in HomeService.values) {
                if (widget.key == ValueKey('home-service-${service.name}')) {
                  visitedServices.add(service);
                }
              }
              return true;
            });
            for (final service in HomeService.values.where(
              (s) => s != primary,
            )) {
              expect(nodes[service]!.hasFocus, isFalse);
            }
          }
          if (reverse) {
            await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          }
          expect(visitedServices, containsAll(HomeService.values));
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('visible auxiliary summary can be promoted with the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(subject(reduceMotion: true));
    await tester.pumpAndSettle();
    final detailButton = tester.element(
      find.byKey(const ValueKey('detail-attendance')),
    );
    Focus.of(detailButton).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('detail-seat')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-attendance')), findsNothing);
  });

  testWidgets('보조 영역으로 보냈다가 되돌려도 상세 스크롤 위치가 유지된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject(scrollableDetails: true));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('scroll-attendance')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('scroll-attendance')),
      matching: find.byType(Scrollable),
    );
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0));

    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그인·출결'));
    await tester.pumpAndSettle();

    final after = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(after, closeTo(before, 1));
  });

  double opacity(WidgetTester tester, HomeService service, String layer) =>
      tester
          .widget<FadeTransition>(
            find
                .descendant(
                  of: find.byKey(
                    ValueKey('home-service-${service.name}-$layer-layer'),
                  ),
                  matching: find.byType(FadeTransition, skipOffstage: false),
                  skipOffstage: false,
                )
                .first,
          )
          .opacity
          .value;

  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'service content follows movement and reverses continuously: $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(subject());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('detail-attendance')));
        await tester.pumpAndSettle();
        final attendanceElement = tester.element(
          find.byKey(const ValueKey('detail-attendance')),
        );
        await tester.tap(find.text('열람실'));
        await tester.pump();
        expect(opacity(tester, HomeService.attendance, 'detail'), 1);
        expect(opacity(tester, HomeService.seat, 'detail'), 0);
        // Outgoing content is still painted, but cannot act or be announced.
        expect(find.semantics.byLabel('attendance: 1'), findsNothing);
        final outgoingLayer = find.byKey(
          const ValueKey('home-service-attendance-detail-layer'),
        );
        expect(
          tester
              .widget<IgnorePointer>(
                find
                    .descendant(
                      of: outgoingLayer,
                      matching: find.byType(IgnorePointer),
                    )
                    .first,
              )
              .ignoring,
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          opacity(tester, HomeService.attendance, 'detail'),
          inExclusiveRange(0, 1),
        );
        expect(
          opacity(tester, HomeService.seat, 'detail'),
          inExclusiveRange(0, 1),
        );
        final cardRect = tester.getRect(
          find.byKey(const ValueKey(HomeService.seat)),
        );
        final bodyRect = tester.getRect(
          find.ancestor(
            of: find.byKey(const ValueKey('detail-seat')),
            matching: find.byType(_CounterDetail),
          ),
        );
        expect(bodyRect.left, closeTo(cardRect.left, 0.1));
        expect(bodyRect.right, closeTo(cardRect.right, 0.1));
        final outgoing = opacity(tester, HomeService.attendance, 'detail');
        final incoming = opacity(tester, HomeService.seat, 'detail');
        await tester.tap(find.text('로그인·출결'));
        await tester.pump();
        expect(
          opacity(tester, HomeService.attendance, 'detail'),
          closeTo(outgoing, 0.00001),
        );
        expect(
          opacity(tester, HomeService.seat, 'detail'),
          closeTo(incoming, 0.00001),
        );
        await tester.pumpAndSettle();
        expect(
          tester.element(find.byKey(const ValueKey('detail-attendance'))),
          same(attendanceElement),
        );
        expect(find.text('attendance: 1'), findsOneWidget);
        expect(opacity(tester, HomeService.attendance, 'detail'), 1);
        expect(find.byKey(const ValueKey('detail-seat')), findsNothing);
        final focus = tester.widget<Focus>(
          find.byKey(const ValueKey('home-service-attendance-detail-focus')),
        );
        expect(focus.focusNode!.hasFocus, isTrue);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'service content stops immediately when reduced motion is enabled mid-fade',
    (tester) async {
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('열람실'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        opacity(tester, HomeService.seat, 'detail'),
        inExclusiveRange(0, 1),
      );
      await tester.pumpWidget(subject(reduceMotion: true));
      expect(opacity(tester, HomeService.seat, 'detail'), 1);
      expect(opacity(tester, HomeService.attendance, 'detail'), 0);
      expect(find.byKey(const ValueKey('detail-attendance')), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class _ScrollDetail extends StatelessWidget {
  const _ScrollDetail({required this.service});

  final HomeService service;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: ValueKey('scroll-${service.name}'),
      itemCount: 40,
      itemBuilder: (context, index) =>
          SizedBox(height: 48, child: Text('${service.name} item $index')),
    );
  }
}

class _CounterDetail extends StatefulWidget {
  const _CounterDetail({required this.service});

  final HomeService service;

  @override
  State<_CounterDetail> createState() => _CounterDetailState();
}

class _CounterDetailState extends State<_CounterDetail> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        key: ValueKey('detail-${widget.service.name}'),
        onPressed: () => setState(() => count++),
        child: Text('${widget.service.name}: $count'),
      ),
    );
  }
}
