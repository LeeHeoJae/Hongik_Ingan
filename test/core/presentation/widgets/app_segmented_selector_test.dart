import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/presentation/widgets/app_segmented_selector.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/core/theme/color.dart';

void main() {
  testWidgets('selection follows RTL order with large multiline labels', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(
                width: 280,
                child: StatefulBuilder(
                  builder: (context, setState) => AppSegmentedSelector<int>(
                    items: const [0, 1, 2],
                    selectedItem: selected,
                    labelOf: (item) => 'Long label $item',
                    onSelected: (item) => setState(() => selected = item),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final before = _indicatorRect(tester);
    await tester.tap(find.text('Long label 2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(_indicatorRect(tester).left, lessThan(before.left));
    await tester.pumpAndSettle();
    expect(
      _indicatorRect(tester).center.dx,
      closeTo(tester.getCenter(find.text('Long label 2')).dx, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  for (final theme in [themeData, darkThemeData]) {
    final isDark = theme.brightness == Brightness.dark;
    final selectionColor = isDark
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.primary;

    for (final width in [320.0, 900.0]) {
      testWidgets('one opaque selection moves continuously through reversals: '
          '${theme.brightness}, $width', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 400);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(_subject(theme: theme, width: width));
        final start = _indicatorRect(tester);
        await tester.tap(find.text('Second'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 45));

        void expectTransition() {
          final decoration = _decoration(tester);
          final color = decoration.color!;
          expect(
            find.byKey(const ValueKey('app-segmented-selection')),
            findsOneWidget,
          );
          expect(color.a, 1);
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

        expectTransition();
        final middle = _indicatorRect(tester);
        expect(middle.left, greaterThan(start.left));
        expect(middle.left, lessThan(start.left + start.width));
        await tester.tap(find.text('First'));
        await tester.pump();
        expect(_indicatorRect(tester).left, closeTo(middle.left, 0.01));
        await tester.pump(const Duration(milliseconds: 45));
        expect(_indicatorRect(tester).left, lessThan(middle.left));
        expectTransition();
        await tester.pumpAndSettle();
        expect(_indicatorRect(tester), start);
        expect(_decoration(tester).color, selectionColor);
        expect(tester.takeException(), isNull);
      });
    }

    for (final quiet in [false, true]) {
      testWidgets('text stays readable throughout selection and reversal: '
          '${theme.brightness}, quiet=$quiet', (tester) async {
        await tester.pumpWidget(_subject(theme: theme, quiet: quiet));
        final surface = theme.extension<HongikPalette>()!.cardSurfaceMuted;
        for (final target in ['Second', 'First', 'Second']) {
          await tester.tap(find.text(target));
          await tester.pump();
          for (var frame = 0; frame < 12; frame++) {
            for (var index = 0; index < 2; index++) {
              final label = index == 0 ? 'First' : 'Second';
              final baseStyle = tester.widget<Text>(find.text(label)).style!;
              final selectedStyle =
                  (tester
                              .widget<RichText>(
                                find.byKey(
                                  ValueKey('segmented-selected-$index'),
                                ),
                              )
                              .text
                          as TextSpan)
                      .style!;
              for (final pair in [
                (surface, baseStyle.color!),
                (_decoration(tester).color!, selectedStyle.color!),
              ]) {
                final (background, foreground) = pair;
                expect(
                  tester.widget<Text>(find.text(label)).style!.fontWeight,
                  FontWeight.w600,
                );
                final first = foreground.computeLuminance();
                final second = background.computeLuminance();
                final contrast = first > second
                    ? (first + 0.05) / (second + 0.05)
                    : (second + 0.05) / (first + 0.05);
                expect(
                  contrast,
                  greaterThanOrEqualTo(4.5),
                  reason: '$label at frame $frame',
                );
              }
            }
            await tester.pump(const Duration(milliseconds: 8));
          }
        }
        await tester.pumpAndSettle();
      });
    }

    testWidgets('reduced motion applies selection immediately: '
        '${theme.brightness}', (tester) async {
      await tester.pumpWidget(_subject(theme: theme, disableAnimations: true));
      await tester.tap(find.text('Second'));
      await tester.pump();
      expect(
        _indicatorRect(tester).center.dx,
        closeTo(tester.getCenter(find.text('Second')).dx, 0.01),
      );
      expect(_decoration(tester).color, selectionColor);
    });

    testWidgets('keyboard activation preserves selected semantics: '
        '${theme.brightness}', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_subject(theme: theme));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        _indicatorRect(tester).center.dx,
        closeTo(tester.getCenter(find.text('Second')).dx, 0.01),
      );
      expect(_decoration(tester).color, selectionColor);
      final node = tester.getSemantics(find.text('Second'));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isFocused, Tristate.isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });
  }
}

Rect _indicatorRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('app-segmented-selection')));

BoxDecoration _decoration(WidgetTester tester) {
  return tester
          .widget<DecoratedBox>(
            find.byKey(const ValueKey('app-segmented-selection')),
          )
          .decoration
      as BoxDecoration;
}

Widget _subject({
  required ThemeData theme,
  double width = 320,
  bool disableAnimations = false,
  bool quiet = false,
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
            child: StatefulBuilder(builder: _selectorBuilder(quiet: quiet)),
          ),
        ),
      ),
    ),
  );
}

StatefulWidgetBuilder _selectorBuilder({bool quiet = false}) {
  var selected = 'First';
  return (context, setState) => AppSegmentedSelector<String>(
    items: const ['First', 'Second'],
    selectedItem: selected,
    labelOf: (item) => item,
    onSelected: (item) => setState(() => selected = item),
    quiet: quiet,
  );
}
