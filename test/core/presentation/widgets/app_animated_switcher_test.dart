import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_animated_switcher.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/panel_entrance_transition.dart';

void main() {
  Widget frame({required Widget child, bool disableAnimations = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('키가 바뀐 콘텐츠는 짧게 교차 전환된다', (tester) async {
    Widget subject(String value) {
      return frame(
        child: AppAnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          slideOffset: const Offset(0, 0.04),
          child: Text(value, key: ValueKey(value)),
        ),
      );
    }

    await tester.pumpWidget(subject('이전 상태'));
    await tester.pumpWidget(subject('새 상태'));
    await tester.pump(const Duration(milliseconds: 110));

    expect(find.text('이전 상태'), findsOneWidget);
    expect(find.text('새 상태'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('이전 상태'), findsNothing);
    expect(find.text('새 상태'), findsOneWidget);
  });

  testWidgets('모션 감소 설정에서는 상태를 즉시 교체한다', (tester) async {
    Widget subject(String value) {
      return frame(
        disableAnimations: true,
        child: AppAnimatedSwitcher(child: Text(value, key: ValueKey(value))),
      );
    }

    await tester.pumpWidget(subject('이전 상태'));
    await tester.pumpWidget(subject('새 상태'));
    await tester.pump();

    expect(find.text('이전 상태'), findsNothing);
    expect(find.text('새 상태'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppAnimatedSwitcher),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('모션 감소 설정에서는 패널 이동 효과를 생략한다', (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 320),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      frame(
        disableAnimations: true,
        child: PanelEntranceTransition(
          controller: controller,
          begin: 0,
          end: 1,
          child: const Text('패널'),
        ),
      ),
    );

    expect(find.text('패널'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PanelEntranceTransition),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(PanelEntranceTransition),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
  });
}
