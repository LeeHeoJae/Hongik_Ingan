import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_service_workspace.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_attendance_action_layout.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_attendance_density.dart';

void main() {
  void setViewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget subject({
    bool mobile = false,
    double attendanceHeight = 220,
    bool hold = false,
    bool balance = false,
    double viewportHeight = 720,
  }) => ProviderScope(
    child: MaterialApp(
      theme: themeData,
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeServiceWorkspace(
            availableHeight: 900,
            viewportHeight: viewportHeight,
            holdLayout: hold,
            balanceMobileAttendance: balance,
            adaptiveMobileLayout: mobile,
            detailBuilder: (service, _) {
              if (service != HomeService.attendance) {
                return const SizedBox(height: 260);
              }
              final action = SizedBox(
                key: const ValueKey('motion-attendance-action'),
                height: 44,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Action'),
                ),
              );
              return mobile
                  ? SizedBox(
                      key: const ValueKey('motion-attendance-body'),
                      height: attendanceHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Attendance'),
                          const Spacer(),
                          action,
                        ],
                      ),
                    )
                  : HomeAttendanceActionScope(
                      bodyTop: 16,
                      bottomPadding: 16,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: HomeAttendanceActionLayout(
                          content: const Text('Attendance'),
                          action: action,
                        ),
                      ),
                    );
            },
            summaryBuilder: (service, _) => HomeServiceSummaryData(
              status: service == HomeService.menu
                  ? 'Rice noodles soup vegetables chicken salad and fruit'
                  : 'Ready',
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'held mobile geometry retains body spacing until release or resize',
    (tester) async {
      setViewport(tester, 390);
      await tester.pumpWidget(subject(mobile: true));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('home-service-attendance'));
      final body = find.byKey(const ValueKey('motion-attendance-body'));
      final before = tester.getRect(card);
      await tester.pumpWidget(subject(mobile: true, hold: true, balance: true));
      await tester.pumpAndSettle();
      expect(tester.getRect(card), before);
      expect(HomeAttendanceDensityScope.extraSpaceOf(tester.element(body)), 0);
      await tester.pumpWidget(
        subject(mobile: true, hold: true, viewportHeight: 200),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(card), before);
      expect(
        HomeAttendanceDensityScope.of(tester.element(body)),
        HomeAttendanceDensity.regular,
      );
      tester.view.physicalSize = const Size(320, 900);
      await tester.pumpAndSettle();
      expect(
        HomeAttendanceDensityScope.of(tester.element(body)),
        HomeAttendanceDensity.tight,
      );
      await tester.pumpWidget(subject(mobile: true, balance: true));
      await tester.pumpAndSettle();
      expect(
        HomeAttendanceDensityScope.of(tester.element(body)),
        HomeAttendanceDensity.regular,
      );
      expect(
        HomeAttendanceDensityScope.extraSpaceOf(tester.element(body)),
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  double opacity(WidgetTester tester, HomeService service) => tester
      .widget<FadeTransition>(
        find
            .descendant(
              of: find.byKey(
                ValueKey('home-service-${service.name}-detail-layer'),
                skipOffstage: false,
              ),
              matching: find.byType(FadeTransition, skipOffstage: false),
              skipOffstage: false,
            )
            .first,
      )
      .opacity
      .value;

  for (final mobile in [true, false]) {
    testWidgets('painted action follows the moving card, mobile=$mobile', (
      tester,
    ) async {
      setViewport(tester, mobile ? 390 : 1200);
      await tester.pumpWidget(subject(mobile: mobile));
      await tester.pumpAndSettle();

      void expectAligned() {
        if (opacity(tester, HomeService.attendance) == 0) return;
        final card = tester.getRect(
          find.byKey(const ValueKey('home-service-attendance')),
        );
        final action = tester.getRect(
          find.byKey(const ValueKey('motion-attendance-action')),
        );
        expect(
          mobile ? action.bottom : action.center.dy,
          closeTo(mobile ? card.bottom : card.center.dy, 0.1),
        );
        expect(action.left, greaterThanOrEqualTo(card.left));
        expect(action.right, lessThanOrEqualTo(card.right + 0.1));
        if (mobile) {
          final body = tester.getRect(
            find.byKey(const ValueKey('motion-attendance-body')),
          );
          expect(body.top, greaterThanOrEqualTo(card.top - 0.1));
          expect(body.bottom, closeTo(card.bottom, 0.1));
        }
      }

      expectAligned();
      await tester.tap(find.text(HomeService.seat.title));
      await tester.pump();
      expectAligned();
      // Reverse while the outgoing action is still painted. Neither anchor
      // nor opacity may jump when primary/auxiliary roles change.
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectAligned();
      }
      final beforeReverse = tester.getRect(
        find.byKey(const ValueKey('motion-attendance-action')),
      );
      await tester.tap(find.text(HomeService.attendance.title));
      await tester.pump();
      expectAligned();
      expect(
        tester.getRect(find.byKey(const ValueKey('motion-attendance-action'))),
        beforeReverse,
      );
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectAligned();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text(HomeService.seat.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(HomeService.attendance.title));
      await tester.pump();
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectAligned();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail becomes readable as its card grows, mobile=$mobile', (
      tester,
    ) async {
      setViewport(tester, mobile ? 390 : 1200);
      await tester.pumpWidget(subject(mobile: mobile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(HomeService.seat.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(opacity(tester, HomeService.seat), 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(opacity(tester, HomeService.attendance), 0);
      // Early in the card's expansion, miniature text must stay subdued.
      expect(opacity(tester, HomeService.seat), inExclusiveRange(0, 0.25));
      await tester.pump(const Duration(milliseconds: 140));
      expect(opacity(tester, HomeService.seat), 1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('hidden detail resumes measurement at the resized final width', (
    tester,
  ) async {
    setViewport(tester, 390);
    await tester.pumpWidget(subject(mobile: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text(HomeService.seat.title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 96));
    tester.view.physicalSize = const Size(430, 900);
    await tester.pump();
    final body = find.byKey(
      const ValueKey('motion-attendance-body'),
      skipOffstage: false,
    );
    expect(tester.getSize(body).width, 390);
    await tester.pump(const Duration(milliseconds: 64));
    expect(opacity(tester, HomeService.attendance), 0);
    await tester.pump();
    expect(tester.getSize(body).width, 430);
    expect(opacity(tester, HomeService.seat), inExclusiveRange(0, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact summary keeps its final wrapping during a card move', (
    tester,
  ) async {
    setViewport(tester, 390);
    await tester.pumpWidget(subject(mobile: true));
    await tester.pumpAndSettle();
    final text = find.text(
      'Rice noodles soup vegetables chicken salad and fruit',
      skipOffstage: false,
    );
    final finalSize = tester.renderObject<RenderParagraph>(text).size;
    final finalLines = tester.widget<Text>(text).maxLines;
    for (final service in [HomeService.menu, HomeService.attendance]) {
      await tester.tap(find.text(service.title));
      await tester.pump();
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.renderObject<RenderParagraph>(text).size, finalSize);
        expect(tester.widget<Text>(text).maxLines, finalLines);
      }
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile workspace height follows the card transition', (
    tester,
  ) async {
    setViewport(tester, 390);
    await tester.pumpWidget(subject(mobile: true, attendanceHeight: 1000));
    await tester.pumpAndSettle();
    final workspace = find.byType(HomeServiceWorkspace);
    await tester.ensureVisible(find.text(HomeService.seat.title));
    await tester.pumpAndSettle();
    final before = tester.getSize(workspace).height;
    await tester.tap(find.text(HomeService.seat.title));
    await tester.pump();
    expect(tester.getSize(workspace).height, before);
    await tester.pump(const Duration(milliseconds: 80));
    final during = tester.getSize(workspace).height;
    await tester.pump(const Duration(milliseconds: 320));
    final after = tester.getSize(workspace).height;
    expect(during, inExclusiveRange(after, before));
    final card = tester.getRect(
      find.byKey(const ValueKey('home-service-seat')),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(workspace).height, after);
    expect(
      tester.getRect(find.byKey(const ValueKey('home-service-seat'))),
      card,
    );
    expect(tester.takeException(), isNull);
  });
}
