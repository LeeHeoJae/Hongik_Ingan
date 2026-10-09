import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_segmented_selector.dart';
import 'package:hongik_ingan/core/theme/theme.dart';

void main() {
  for (final theme in [themeData, darkThemeData]) {
    final isDark = theme.brightness == Brightness.dark;
    final selectionColor = isDark
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.primary;

    for (final width in [320.0, 900.0]) {
      testWidgets('selection keeps its hue through transitions and reversals: '
          '${theme.brightness}, $width', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 400);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(_subject(theme: theme, width: width));
        await tester.tap(find.text('Second'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 45));

        void expectTransition() {
          for (final label in ['First', 'Second']) {
            final decoration = _decoration(tester, label);
            final color = decoration.color!;
            expect(color.a, greaterThan(0));
            expect(color.a, lessThan(1));
            expect(color.r, closeTo(selectionColor.r, 0.00001));
            expect(color.g, closeTo(selectionColor.g, 0.00001));
            expect(color.b, closeTo(selectionColor.b, 0.00001));
            if (isDark) {
              expect(decoration.boxShadow, isNull);
            } else {
              final shadow = decoration.boxShadow!.single;
              expect(shadow.color.a, closeTo(color.a * 0.20, 0.00001));
              expect(shadow.blurRadius, 18);
              expect(shadow.spreadRadius, 0.4);
              expect(shadow.offset, const Offset(0, 5));
            }
          }
        }

        expectTransition();
        await tester.tap(find.text('First'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 45));
        expectTransition();
        await tester.pumpAndSettle();
        expect(_decoration(tester, 'First').color, selectionColor);
        expect(_decoration(tester, 'Second').color!.a, 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('reduced motion applies selection immediately: '
        '${theme.brightness}', (tester) async {
      await tester.pumpWidget(_subject(theme: theme, disableAnimations: true));
      await tester.tap(find.text('Second'));
      await tester.pump();
      expect(_decoration(tester, 'First').color!.a, 0);
      expect(_decoration(tester, 'Second').color, selectionColor);
    });

    testWidgets('keyboard activation preserves selected semantics: '
        '${theme.brightness}', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_subject(theme: theme));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_decoration(tester, 'Second').color, selectionColor);
      final node = tester.getSemantics(find.text('Second'));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isFocused, Tristate.isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });
  }
}

BoxDecoration _decoration(WidgetTester tester, String label) {
  final container = find.ancestor(
    of: find.text(label),
    matching: find.byType(AnimatedContainer),
  );
  return tester
          .widget<DecoratedBox>(
            find.descendant(of: container, matching: find.byType(DecoratedBox)),
          )
          .decoration
      as BoxDecoration;
}

Widget _subject({
  required ThemeData theme,
  double width = 320,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: 46,
            child: StatefulBuilder(builder: _selectorBuilder()),
          ),
        ),
      ),
    ),
  );
}

StatefulWidgetBuilder _selectorBuilder() {
  var selected = 'First';
  return (context, setState) => AppSegmentedSelector<String>(
    items: const ['First', 'Second'],
    selectedItem: selected,
    labelOf: (item) => item,
    onSelected: (item) => setState(() => selected = item),
  );
}
