import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_code_form.dart';

void main() {
  const reviewOutput = String.fromEnvironment('ATTENDANCE_CODE_REVIEW_OUTPUT');
  if (reviewOutput.isNotEmpty) {
    setUpAll(() async {
      await (FontLoader('NotoSansKR')
            ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    for (final scenario in [
      (
        name: 'mobile-keyboard',
        size: const Size(390, 844),
        inset: 320.0,
        scale: 1.0,
        dark: false,
      ),
      (
        name: 'short-keyboard',
        size: const Size(390, 520),
        inset: 320.0,
        scale: 1.0,
        dark: false,
      ),
      (
        name: 'large-text',
        size: const Size(320, 620),
        inset: 280.0,
        scale: 2.0,
        dark: true,
      ),
      (
        name: 'desktop',
        size: const Size(1440, 900),
        inset: 0.0,
        scale: 1.0,
        dark: false,
      ),
    ]) {
      testWidgets('renders code review ${scenario.name}', (tester) async {
        _viewport(tester, scenario.size);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _subject(
              submitted: [],
              scale: scenario.scale,
              dark: scenario.dark,
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '0705');
        tester.view.viewInsets = FakeViewPadding(bottom: scenario.inset);
        await tester.pumpAndSettle();
        final submit = find.widgetWithText(ElevatedButton, '제출');
        expect(submit.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(submit).bottom,
          lessThanOrEqualTo(scenario.size.height - scenario.inset),
        );
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('$reviewOutput/${scenario.name}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      });
    }
  }
  testWidgets('submit stays inside a short viewport with the keyboard open', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 520));
    final submitted = <String>[];
    await tester.pumpWidget(_subject(submitted: submitted));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0705');
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final submit = find.widgetWithText(ElevatedButton, '제출');
    expect(tester.getRect(submit).bottom, lessThanOrEqualTo(200));
    expect(submit.hitTestable(), findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(submitted, ['0705']);
    expect(find.byType(AttendanceCodeForm), findsNothing);
  });

  testWidgets('normal keyboard layout fits without scrolling', (tester) async {
    _viewport(tester, const Size(390, 844));
    await tester.pumpWidget(_subject(submitted: []));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(_dialogScroll(tester).position.maxScrollExtent, 0);
    final field = tester.getRect(find.byType(TextField));
    final submit = tester.getRect(find.widgetWithText(ElevatedButton, '제출'));
    expect(field.bottom, lessThan(submit.top));
    expect(submit.bottom, lessThan(524));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard respects safe areas and physical pixel ratio', (
    tester,
  ) async {
    _viewport(tester, const Size(1170, 2532));
    tester.view.devicePixelRatio = 3;
    tester.view.viewPadding = const FakeViewPadding(top: 132, bottom: 102);
    tester.view.padding = const FakeViewPadding(top: 132, bottom: 102);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(_subject(submitted: []));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 960);
    tester.view.padding = const FakeViewPadding(top: 132);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byTooltip('닫기')).top, greaterThanOrEqualTo(44));
    expect(
      tester.getRect(find.widgetWithText(ElevatedButton, '제출')).bottom,
      lessThanOrEqualTo(524),
    );
    expect(_dialogScroll(tester).position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long course scrolls while close and submit stay in place', (
    tester,
  ) async {
    _viewport(tester, const Size(320, 620));
    final submitted = <String>[];
    await tester.pumpWidget(
      _subject(
        submitted: submitted,
        scale: 2,
        course:
            '[123456] ${List.filled(8, '디지털 미디어 디자인과 인터랙션 프로그래밍 실습').join(' ')}',
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('attendance-code-scroll-body')),
      findsOneWidget,
    );
    final submit = find.widgetWithText(ElevatedButton, '제출');
    final close = find.byTooltip('닫기');
    final submitBefore = tester.getRect(submit);
    final closeBefore = tester.getRect(close);
    expect(_dialogScroll(tester).position.maxScrollExtent, greaterThan(0));
    _dialogScroll(tester).position.jumpTo(0);
    await tester.pump();
    expect(tester.getRect(submit), submitBefore);
    expect(tester.getRect(close), closeBefore);
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0123');
    await tester.pump();
    expect(submit.hitTestable(), findsOneWidget);
    expect(tester.getRect(submit).bottom, lessThanOrEqualTo(340));
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(submitted, ['0123']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('extremely short viewport scrolls all controls into reach', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 360));
    final submitted = <String>[];
    await tester.pumpWidget(_subject(submitted: submitted));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('attendance-code-scroll-all')),
      findsOneWidget,
    );
    final close = find.byTooltip('닫기');
    await tester.ensureVisible(close);
    await tester.pumpAndSettle();
    expect(close.hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0705');
    await tester.pump();
    final submit = find.widgetWithText(ElevatedButton, '제출');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(tester.getRect(submit).bottom, lessThanOrEqualTo(100));
    expect(submit.hitTestable(), findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(submitted, ['0705']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard cycles and orientation preserve focus, value and selection',
    (tester) async {
      _viewport(tester, const Size(390, 620));
      final submitted = <String>[];
      await tester.pumpWidget(_subject(submitted: submitted));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0705');
      final initialField = tester.widget<TextField>(find.byType(TextField));
      initialField.controller!.selection = const TextSelection.collapsed(
        offset: 2,
      );
      for (final scenario in [
        (size: const Size(390, 620), inset: 280.0),
        (size: const Size(390, 620), inset: 320.0),
        (size: const Size(620, 320), inset: 160.0),
        (size: const Size(390, 620), inset: 0.0),
        (size: const Size(390, 620), inset: 320.0),
      ]) {
        tester.view.physicalSize = scenario.size;
        tester.view.viewInsets = FakeViewPadding(bottom: scenario.inset);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller, same(initialField.controller));
        expect(field.controller!.text, '0705');
        expect(field.controller!.selection.baseOffset, 2);
        expect(field.focusNode!.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      }
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(submitted, ['0705']);
    },
  );

  testWidgets(
    'four digits enable explicit submit and submission happens once',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final submitted = <String>[];
      await tester.pumpWidget(
        _subject(submitted: submitted, closeOnSubmit: false),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(ElevatedButton, '제출');
      await tester.enterText(find.byType(TextField), '07');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, isEmpty);
      await tester.enterText(find.byType(TextField), 'a07056');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '0705',
      );
      expect(submitted, isEmpty);
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(submitted, ['0705']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing with keyboard open cancels and reopening starts empty', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 620));
    final submitted = <String>[];
    await tester.pumpWidget(_subject(submitted: submitted));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '07');
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeForm), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceCodeForm), findsNothing);
    expect(submitted, isEmpty);
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}

ScrollableState _dialogScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Widget _subject({
  required List<String> submitted,
  double scale = 1,
  bool dark = false,
  String course = '[101617] 기계학습기초',
  bool closeOnSubmit = true,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? darkThemeData : themeData,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AttendanceCodeDialog(
            lecture: Lecture(
              name: course,
              time: '화 14:00',
              attendanceParams: {},
            ),
            onSubmit: (code) {
              submitted.add(code);
              if (closeOnSubmit) Navigator.of(dialogContext).pop(code);
            },
            onCancel: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        child: const Text('열기'),
      ),
    ),
  ),
);
