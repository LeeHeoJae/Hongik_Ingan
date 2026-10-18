import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_body_motion.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_content_size_reporter.dart';

void main() {
  Widget subject(
    ValueNotifier<bool> ready, {
    bool bottomAligned = true,
    bool reducedMotion = false,
    ValueChanged<Size>? onSize,
    VoidCallback? onHistory,
    VoidCallback? onStatus,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: Align(
          alignment: bottomAligned ? Alignment.bottomLeft : Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: ValueListenableBuilder(
              valueListenable: ready,
              builder: (context, found, _) => HomeContentSizeReporter(
                onSize: onSize ?? (_) {},
                child: AttendanceBodyMotion(
                  bottomAligned: bottomAligned,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AttendanceMotionPart(
                        fade: false,
                        child: SizedBox(key: ValueKey('heading'), height: 40),
                      ),
                      AttendanceMotionPart(
                        contentKey: 'lecture',
                        child: found
                            ? const SizedBox(
                                key: ValueKey('lecture'),
                                height: 100,
                                child: Text('Lecture'),
                              )
                            : null,
                      ),
                      AttendanceMotionPart(
                        contentKey: found,
                        child: SizedBox(
                          key: ValueKey('status-$found'),
                          height: 30,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onStatus,
                            child: Text(found ? 'Ready' : 'Checking'),
                          ),
                        ),
                      ),
                      AttendanceMotionPart(
                        contentKey: 'history',
                        child: found
                            ? null
                            : SizedBox(
                                key: const ValueKey('history'),
                                height: 80,
                                child: TextButton(
                                  onPressed: onHistory,
                                  child: const Text('History'),
                                ),
                              ),
                      ),
                      const AttendanceMotionPart(
                        fade: false,
                        child: SizedBox(key: ValueKey('action'), height: 44),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  double fadeOf(WidgetTester tester, String key) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  for (final bottomAligned in [false, true]) {
    testWidgets('body parts move continuously, bottom=$bottomAligned', (
      tester,
    ) async {
      final ready = ValueNotifier(false);
      addTearDown(ready.dispose);
      final sizes = <Size>[];
      var historyTaps = 0;
      var statusTaps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        subject(
          ready,
          bottomAligned: bottomAligned,
          onSize: sizes.add,
          onHistory: () => historyTaps++,
          onStatus: () => statusTaps++,
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byKey(const ValueKey('status-false')));
      final beforeHeading = tester.getRect(
        find.byKey(const ValueKey('heading')),
      );
      final actionBottom = tester
          .getRect(find.byKey(const ValueKey('action')))
          .bottom;

      ready.value = true;
      await tester.pump();
      final current = find.byKey(const ValueKey('status-true'));
      expect(tester.getRect(current).topLeft, before.topLeft);
      expect(
        tester.getRect(find.byKey(const ValueKey('heading'))),
        beforeHeading,
      );
      expect(fadeOf(tester, 'lecture'), 0);
      expect(sizes.last.height, 214);
      await tester.tap(find.text('History'), warnIfMissed: false);
      expect(historyTaps, 0);
      expect(find.bySemanticsLabel('History'), findsNothing);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(fadeOf(tester, 'history'), 0);
      expect(fadeOf(tester, 'lecture'), inExclusiveRange(0, 1));
      final during = tester.getRect(current);
      await tester.tap(find.text('Ready'));
      expect(statusTaps, 1);
      await tester.pump(const Duration(milliseconds: 260));
      final after = tester.getRect(current);
      expect(during.top, inExclusiveRange(before.top, after.top));
      expect(after.height, before.height);
      if (bottomAligned) {
        expect(
          tester.getRect(find.byKey(const ValueKey('action'))).bottom,
          actionBottom,
        );
      }
      expect(sizes.map((size) => size.height).toList(), [194, 214]);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reversing a body transition keeps the painted position', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    await tester.pumpWidget(subject(ready));
    await tester.pumpAndSettle();
    ready.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final before = tester.getRect(find.byKey(const ValueKey('status-true')));
    ready.value = false;
    await tester.pump();
    final returning = find.byKey(const ValueKey('status-false')).last;
    expect(tester.getRect(returning).topLeft, before.topLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('status-true')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refreshing the same lecture does not replay its entrance', (
    tester,
  ) async {
    final stage = ValueNotifier('ready');
    addTearDown(stage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: stage,
            builder: (context, status, _) => AttendanceBodyMotion(
              bottomAligned: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AttendanceMotionPart(
                    contentKey: 'same-lecture',
                    child: SizedBox(
                      key: ValueKey('same-lecture'),
                      width: 300,
                      height: 100,
                      child: Text('Lecture'),
                    ),
                  ),
                  AttendanceMotionPart(contentKey: status, child: Text(status)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byKey(const ValueKey('same-lecture')));
    for (final status in ['refreshing', 'ready']) {
      stage.value = status;
      await tester.pump();
      expect(fadeOf(tester, 'same-lecture'), 1);
      expect(
        tester.getRect(find.byKey(const ValueKey('same-lecture'))),
        before,
      );
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion applies the final body immediately', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    await tester.pumpWidget(subject(ready, reducedMotion: true));
    await tester.pumpAndSettle();
    ready.value = true;
    await tester.pump();
    expect(find.text('History'), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
    final rect = tester.getRect(find.byKey(const ValueKey('status-true')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getRect(find.byKey(const ValueKey('status-true'))), rect);
    expect(tester.takeException(), isNull);
  });
}
