import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_content_fade.dart';

void main() {
  Widget subject(int selection, {bool reduced = false, bool initial = false}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: AppContentFade(
              changeKey: selection,
              animateInitially: initial,
              child: const _Editor(),
            ),
          ),
        ),
      );

  Animation<double> opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(AppContentFade),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity;

  testWidgets('selection preserves input, focus and the current child state', (
    tester,
  ) async {
    await tester.pumpWidget(subject(0));
    final field = tester.element(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'saved input');
    await tester.pump();
    await tester.pumpWidget(subject(1));
    expect(opacity(tester).value, 0);
    expect(tester.element(find.byType(TextField)), same(field));
    expect(find.text('saved input'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 90));
    expect(opacity(tester).value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(opacity(tester).value, 1);
    // A data rebuild with the same selection does not hide the content again.
    await tester.pumpWidget(subject(1));
    expect(opacity(tester).value, 1);
  });

  testWidgets(
    'rapid selection continues its fade and reduced motion finishes it',
    (tester) async {
      await tester.pumpWidget(subject(0));
      await tester.pumpWidget(subject(1));
      await tester.pump(const Duration(milliseconds: 60));
      final progress = opacity(tester).value;
      await tester.pumpWidget(subject(2));
      expect(opacity(tester).value, progress);
      await tester.pumpWidget(subject(2, reduced: true));
      expect(opacity(tester).value, 1);
      await tester.pumpWidget(subject(3, reduced: true));
      expect(opacity(tester).value, 1);
    },
  );

  testWidgets('only an explicitly requested initial entrance fades', (
    tester,
  ) async {
    await tester.pumpWidget(subject(0, initial: true));
    expect(opacity(tester).value, 0);
    await tester.pump(const Duration(milliseconds: 180));
    expect(opacity(tester).value, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(subject(0));
    expect(opacity(tester).value, 1);
  });
}

class _Editor extends StatefulWidget {
  const _Editor();

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(controller: _controller, focusNode: _focus);
}
