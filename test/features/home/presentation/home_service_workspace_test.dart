import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_service_workspace.dart';

void main() {
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
                  measureContent: true,
                  dockAuxiliaryBelow: true,
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

  testWidgets(
    'Mobile attendance remains bottom aligned above two fixed auxiliary rows',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final height = ValueNotifier<double>(220);
      addTearDown(height.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HomeServiceWorkspace(
                availableHeight: 844,
                measureContent: true,
                dockAuxiliaryBelow: true,
                detailBuilder: (service, _) => service == HomeService.attendance
                    ? ValueListenableBuilder<double>(
                        valueListenable: height,
                        builder: (context, value, child) => SizedBox(
                          height: value,
                          child: const Column(
                            children: [
                              Text('Attendance content'),
                              Spacer(),
                              Text('Attendance end'),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(height: 180),
                summaryBuilder: (_, _) =>
                    const HomeServiceSummaryData(status: 'Ready'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('home-service-attendance'));
      final seat = find.byKey(const ValueKey('home-service-seat'));
      final menu = find.byKey(const ValueKey('home-service-menu'));
      final seatBefore = tester.getRect(seat);
      final menuBefore = tester.getRect(menu);
      expect(tester.getSize(panel).height, 220);
      expect(tester.getRect(panel).bottom, 604);
      expect(tester.getRect(panel).bottom + 12, seatBefore.top);
      expect(menuBefore.top, seatBefore.bottom + 12);
      expect(seatBefore.width, tester.getRect(panel).width);
      expect(menuBefore.bottom, 844);
      height.value = 360;
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, 360);
      expect(tester.getRect(panel).bottom, 604);
      expect(tester.getRect(panel).bottom + 12, tester.getRect(seat).top);
      expect(tester.getRect(menu).top, tester.getRect(seat).bottom + 12);
      expect(tester.getRect(seat), seatBefore);
      expect(tester.getRect(menu), menuBefore);
      height.value = 1000;
      await tester.pumpAndSettle();
      expect(tester.getRect(panel).height, tester.getRect(seat).top - 12);
      expect(tester.getRect(menu).bottom, 844);
      await tester.ensureVisible(find.text('Attendance end'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Attendance end')).bottom,
        lessThanOrEqualTo(tester.getRect(panel).bottom),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(menu).bottom, 544);
      expect(tester.getRect(panel).bottom + 12, tester.getRect(seat).top);
      expect(tester.getRect(panel).height, tester.getRect(seat).top - 12);
      expect(tester.takeException(), isNull);
    },
  );

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
                measureContent: true,
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
      expect((after.top - before.top).abs(), greaterThan(10));
      expect(
        intermediate.top,
        inExclusiveRange(
          before.top < after.top ? before.top : after.top,
          before.top > after.top ? before.top : after.top,
        ),
      );
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
                    measureContent: true,
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
                  measureContent: true,
                  detailBuilder: (service, _) => ValueListenableBuilder<double>(
                    valueListenable: height,
                    builder: (_, value, _) => SizedBox(
                      height: value,
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
      expect(tester.getSize(panel).height, width > 1000 ? 554 : 1000);
      expect(
        tester.getRect(find.byKey(const ValueKey('home-service-seat'))),
        seatBefore,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('home-service-menu'))),
        menuBefore,
      );
      await tester.ensureVisible(find.text('end-attendance'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('end-attendance')).bottom,
        lessThanOrEqualTo(714),
      );
      if (width > 1000) {
        final scrollable = find.descendant(
          of: find.byKey(const PageStorageKey('home-detail-attendance')),
          matching: find.byType(Scrollable),
        );
        final before = tester
            .state<ScrollableState>(scrollable)
            .position
            .pixels;
        await tester.tap(find.text('열람실'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('로그인·출결'));
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          before,
        );
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
    bool Function(HomeService service)? hasLongContent,
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
              child: HomeServiceWorkspace(
                availableHeight: availableHeight,
                detailBuilder: (service, isPrimary) => scrollableDetails
                    ? _ScrollDetail(service: service)
                    : _CounterDetail(service: service),
                summaryBuilder: (service, ref) => HomeServiceSummaryData(
                  status: '확인 중',
                  facts: withSummaryFacts
                      ? const [(label: '선택', value: 'T동')]
                      : const [],
                ),
                onPrimaryChanged: onPrimaryChanged,
                hasLongContent: hasLongContent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('모바일은 보조 영역 둘을 위에 두고 반복 전환해 상세 상태를 유지한다', (tester) async {
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
    expect(seat.bottom, lessThan(attendance.top));
    expect(menu.bottom, lessThan(attendance.top));
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
    expect(promotedSeat.height, 380);
    await tester.tap(find.text('학식 메뉴'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-menu'))).height,
      380,
    );
    expect(tester.takeException(), isNull);
  });

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
    expect(attendance.height, 440);
    expect(tester.getRect(seat).height, 214);
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
    expect(seat.height, 154);
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
        builder: (context, isLong, child) => subject(
          hasLongContent: (service) => isLong || service == HomeService.seat,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final attendance = find.byKey(const ValueKey('home-service-attendance'));
    expect(tester.getRect(attendance).height, 440);
    await tester.tap(find.byKey(const ValueKey('detail-attendance')));
    await tester.pump();
    expect(find.text('attendance: 1'), findsOneWidget);

    forceLong.value = true;
    await tester.pumpAndSettle();
    expect(tester.getRect(attendance).height, 560);
    forceLong.value = false;
    await tester.pumpAndSettle();
    expect(tester.getRect(attendance).height, 440);

    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-seat'))).height,
      560,
    );
    await tester.tap(find.text('로그인·출결'));
    await tester.pumpAndSettle();
    expect(tester.getRect(attendance).height, 440);
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
