import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_service_workspace.dart';

void main() {
  Widget subject({
    ValueChanged<HomeService>? onPrimaryChanged,
    bool reduceMotion = false,
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
                availableHeight: 760,
                detailBuilder: (service, isPrimary) =>
                    _CounterDetail(service: service),
                summaryBuilder: (service, ref) =>
                    const HomeServiceSummaryData(status: '확인 중'),
                onPrimaryChanged: onPrimaryChanged,
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
    expect(menu.top, greaterThan(attendance.bottom));
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
    expect(find.bySemanticsLabel('열람실, 확인 중, 주 영역으로 이동'), findsOneWidget);
    expect(find.bySemanticsLabel('학식 메뉴, 확인 중, 주 영역으로 이동'), findsOneWidget);
    semantics.dispose();
  });
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
