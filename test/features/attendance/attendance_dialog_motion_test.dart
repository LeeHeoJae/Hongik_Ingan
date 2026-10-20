import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_submission_result.dart';
import 'package:hongik_ingan/features/attendance/domain/lecture.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_code_form.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_dialog_state.dart';

import '../../support/load_app_fonts.dart';

void main() {
  const output = String.fromEnvironment('ATTENDANCE_MOTION_REVIEW_OUTPUT');
  if (output.isNotEmpty) {
    setUpAll(() async {
      await loadAppFonts();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
  }
  for (final viewport in [
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(768, 900), scale: 1.0),
    (size: const Size(1440, 900), scale: 1.0),
    (size: const Size(390, 520), scale: 1.0),
    (size: const Size(320, 620), scale: 2.0),
  ]) {
    for (final keyboard in [false, true]) {
      testWidgets(
        'surface and footer share motion $viewport keyboard=$keyboard',
        (tester) async {
          tester.view.physicalSize = viewport.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final flow = ValueNotifier(const AttendanceDialogState.input());
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: themeData,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(viewport.scale)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        AttendanceCodeRoute<void>(
                          context: context,
                          builder: (context) => AttendanceCodeDialog(
                            lecture: Lecture(
                              name: 'Lecture',
                              time: '12:00',
                              attendanceParams: {},
                            ),
                            flow: flow,
                            onSubmit: (_) => flow.value =
                                const AttendanceDialogState.processing(
                                  'Checking location',
                                ),
                            onCancel: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          if (keyboard) {
            final surface = find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first;
            await tester.enterText(find.byType(TextField), '07');
            final input = tester.widget<TextField>(find.byType(TextField));
            input.controller!.selection = const TextSelection.collapsed(
              offset: 1,
            );
            await tester.pump();
            // Reverse mid-flight and reopen without jumping to either target.
            for (final inset in [
              40.0,
              100.0,
              180.0,
              100.0,
              0.0,
              180.0,
              280.0,
            ]) {
              final beforeInset = tester.getRect(surface);
              tester.view.viewInsets = FakeViewPadding(bottom: inset);
              await tester.pump();
              expect(tester.getRect(surface), beforeInset);
              // The shared frame starts its controller after target layout.
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 16));
              final frame = tester.getRect(surface);
              expect(frame, isNot(beforeInset));
              expect(frame.top, greaterThanOrEqualTo(0));
              final button = tester.getRect(
                find.widgetWithText(ElevatedButton, '제출'),
              );
              expect(button.bottom, lessThanOrEqualTo(frame.bottom));
              expect(button.top, greaterThanOrEqualTo(frame.top));
              final current = tester.widget<TextField>(find.byType(TextField));
              expect(current.controller, same(input.controller));
              expect(current.controller!.text, '07');
              expect(current.controller!.selection.baseOffset, 1);
              expect(current.focusNode!.hasFocus, isTrue);
              expect(tester.takeException(), isNull);
            }
            await tester.pump(const Duration(milliseconds: 250));
            final settledInput = tester.getRect(surface);
            expect(
              settledInput.bottom,
              lessThanOrEqualTo(viewport.size.height - 280),
            );
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.getRect(surface), settledInput);
          }
          await tester.enterText(find.byType(TextField), '1234');
          await tester.pump();
          final submit = find.widgetWithText(ElevatedButton, '제출');
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          final dialog = find.byType(Dialog);
          final surface = find
              .descendant(of: dialog, matching: find.byType(Material))
              .first;
          final action = find.descendant(
            of: dialog,
            matching: find.byType(ElevatedButton),
          );
          Rect surfaceRect() => tester.getRect(surface);
          Rect actionRect() => tester.getRect(action);
          void expectFrame() {
            final frame = surfaceRect();
            final button = actionRect();
            expect(button.left, greaterThanOrEqualTo(frame.left));
            expect(button.right, lessThanOrEqualTo(frame.right));
            expect(frame.bottom - button.bottom, inInclusiveRange(7.99, 16.01));
            final viewportRect = tester.getRect(
              find
                  .descendant(
                    of: dialog,
                    matching: find.byType(SingleChildScrollView),
                  )
                  .first,
            );
            expect(viewportRect.bottom, lessThanOrEqualTo(button.top));
            expect(tester.takeException(), isNull);
          }

          Future<void> capture(String stage) async {
            if (output.isEmpty) return;
            await tester.runAsync(() async {
              final img =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              try {
                final bytes = await img.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  '$output/${viewport.size.width.toInt()}-$keyboard-$stage.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                img.dispose();
              }
            });
          }

          final before = surfaceRect();
          final beforeAction = actionRect();
          await tester.tap(submit);
          await tester.pump();
          expect(surfaceRect(), before);
          expect(actionRect(), beforeAction);
          if (keyboard) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 140);
            if (viewport.size.width == 768) {
              // A fast response must not release the keyboard geometry early.
              flow.value = const AttendanceDialogState.result(
                AttendanceSubmissionResult.notice('Immediate response'),
              );
            }
            for (var frame = 0; frame < 5; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              expect(surfaceRect(), before);
              expect(actionRect(), beforeAction);
            }
            tester.view.viewInsets = FakeViewPadding.zero;
            await tester.pump();
            expect(surfaceRect(), before);
          }
          for (var frame = 0; frame < 16; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expectFrame();
            if (frame == 3) await capture('processing-64');
          }
          final settled = surfaceRect();
          await tester.pump(const Duration(milliseconds: 100));
          expect(surfaceRect(), settled);
          await capture('processing');
          flow.value = AttendanceDialogState.result(
            AttendanceSubmissionResult.failure(
              List.filled(20, 'Long server response.').join(' '),
            ),
          );
          await tester.pump();
          expect(surfaceRect(), settled);
          expectFrame();
          for (var frame = 0; frame < 5; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expectFrame();
          }
          await capture('result-80');
          // A second result arriving during growth must continue from this frame.
          final interrupted = surfaceRect();
          final interruptedAction = actionRect();
          flow.value = const AttendanceDialogState.result(
            AttendanceSubmissionResult.notice('Short response'),
          );
          await tester.pump();
          expect(surfaceRect(), interrupted);
          expect(actionRect(), interruptedAction);
          for (var frame = 0; frame < 16; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expectFrame();
          }
          await capture('result');
          await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
          await tester.pumpAndSettle();
          expect(find.byType(AttendanceCodeDialog), findsNothing);
          await tester.pumpWidget(const SizedBox());
          flow.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final sharedFlow in [false, true]) {
    for (final reducedMotion in [false, true]) {
      testWidgets('keyboard motion flow=$sharedFlow reduced=$reducedMotion', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 620);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final flow = ValueNotifier(const AttendanceDialogState.input());
        await tester.pumpWidget(
          MaterialApp(
            theme: themeData,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reducedMotion),
              child: child!,
            ),
            home: AttendanceCodeDialog(
              lecture: Lecture(
                name: 'Lecture',
                time: '12:00',
                attendanceParams: {},
              ),
              flow: sharedFlow ? flow : null,
              onSubmit: (_) {},
              onCancel: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final surface = find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first;
        final before = tester.getRect(surface);
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await tester.pump();
        if (!reducedMotion) expect(tester.getRect(surface), before);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        final middle = tester.getRect(surface);
        expect(middle.top, lessThan(before.top));
        await tester.pump(const Duration(milliseconds: 110));
        final open = tester.getRect(surface);
        expect(open.bottom, lessThanOrEqualTo(300));
        expect(open.top, reducedMotion ? middle.top : lessThan(middle.top));
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pump();
        if (!reducedMotion) expect(tester.getRect(surface), open);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        final returning = tester.getRect(surface);
        expect(returning.top, greaterThan(open.top));
        if (!reducedMotion) expect(returning.top, lessThan(before.top));
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pump();
        if (!reducedMotion) expect(tester.getRect(surface), returning);
        await tester.pumpAndSettle();
        expect(tester.getRect(surface).bottom, lessThanOrEqualTo(340));
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(tester.getRect(surface), before);
        tester.view.physicalSize = const Size(390, 360);
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        final field = tester.getRect(find.byType(TextField));
        expect(field.top, greaterThanOrEqualTo(0));
        expect(field.bottom, lessThanOrEqualTo(100));
        await tester.pumpWidget(const SizedBox());
        flow.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
