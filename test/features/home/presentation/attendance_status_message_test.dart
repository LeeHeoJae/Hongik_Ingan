import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_status_message.dart';

import '../../../support/load_app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
  });

  for (final width in [390.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('status icon centers on the first line at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const title = '출결 가능한 수업이 없어요';
        const referenceKey = ValueKey('first-line-reference');

        for (final theme in [themeData, darkThemeData]) {
          double? singleLineHeight;
          for (final contentWidth in [width - 32, 120.0]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 900),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '출결',
                          key: referenceKey,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            fontSize: width >= 600 ? 18 : null,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(
                          width: contentWidth,
                          child: const AttendanceStatusMessage(
                            title: title,
                            icon: Icons.schedule_rounded,
                            reserveDescriptionSpace: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            final lineHeight = tester.getSize(find.byKey(referenceKey)).height;
            final titleRect = tester.getRect(find.text(title));
            final iconRect = tester.getRect(
              find.byIcon(Icons.schedule_rounded),
            );
            expect(
              iconRect.center.dy,
              closeTo(titleRect.top + lineHeight / 2, 0.01),
            );
            expect(iconRect.size, const Size(18, 18));
            singleLineHeight ??= lineHeight;
            if (contentWidth == 120) {
              expect(titleRect.height, greaterThan(singleLineHeight));
            }
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  }

  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets('status typography stays consistent across themes at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TextStyle? lightStyle;
      Size? lightSize;
      for (final theme in [themeData, darkThemeData]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: AttendanceStatusMessage(
                  title: '로그인이 필요해요',
                  icon: Icons.lock_outline_rounded,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.text('로그인이 필요해요');
        final style = tester.widget<Text>(title).style!;
        if (lightStyle == null) {
          lightStyle = style;
          lightSize = tester.getSize(title);
        } else {
          expect(style.fontSize, lightStyle.fontSize);
          expect(style.fontWeight, lightStyle.fontWeight);
          expect(style.height, lightStyle.height);
          expect(tester.getSize(title), lightSize);
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('empty mobile descriptions reclaim their height and gap', (
    tester,
  ) async {
    Widget mobile(String? description) => MaterialApp(
      theme: themeData,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: AttendanceStatusMessage(
              key: const ValueKey('mobile-status'),
              title: '출결 가능한 수업이 없어요',
              icon: Icons.schedule_rounded,
              description: description,
              reserveDescriptionSpace: false,
            ),
          ),
        ),
      ),
    );
    final slot = find.byKey(const ValueKey('mobile-status'));
    await tester.pumpWidget(mobile(null));
    final emptyHeight = tester.getSize(slot).height;
    for (final empty in ['', '  \n  ']) {
      await tester.pumpWidget(mobile(empty));
      expect(tester.getSize(slot).height, emptyHeight);
    }
    await tester.pumpWidget(mobile('네트워크 연결을 확인해 주세요.'));
    expect(tester.getSize(slot).height, greaterThan(emptyHeight));
    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  final message = List.generate(
    15,
    (i) => '서버 응답 $i: 로그인을 확인하지 못했어요.',
  ).join('\n');
  const statusKey = ValueKey('status-under-test');

  Widget subject(String? description, {bool dark = false}) {
    return MaterialApp(
      theme: (dark ? darkThemeData : themeData).copyWith(
        platform: TargetPlatform.windows,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AttendanceStatusMessage(
                  key: statusKey,
                  title: '로그인하지 못했어요',
                  description: description,
                  descriptionViewportLines: 2,
                  icon: Icons.error_outline_rounded,
                  isError: true,
                ),
                TextButton(onPressed: () {}, child: const Text('다음 입력')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  for (final dark in [false, true]) {
    testWidgets('desktop status uses one scrollbar ($dark)', (tester) async {
      await tester.pumpWidget(subject(message, dark: dark));
      await tester.pumpAndSettle();
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('touch and mouse scrolling keep the status size fixed', (
    tester,
  ) async {
    await tester.pumpWidget(subject(message));
    await tester.pumpAndSettle();
    final slot = find.byKey(statusKey);
    final before = tester.getRect(slot);
    final scroll = find.byType(SingleChildScrollView);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    await tester.drag(scroll, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    position.jumpTo(0);
    await tester.pump();
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(scroll),
        scrollDelta: const Offset(0, 80),
      ),
    );
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(tester.getRect(slot), before);
    await tester.pumpWidget(subject(null));
    await tester.pumpAndSettle();
    expect(tester.getRect(slot), before);
    expect(position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'showing a long error does not steal focus from the next control',
    (tester) async {
      await tester.pumpWidget(subject(null));
      await tester.pumpAndSettle();
      final buttonFocus = Focus.of(tester.element(find.text('다음 입력')));
      buttonFocus.requestFocus();
      await tester.pump();
      await tester.pumpWidget(subject(message));
      await tester.pumpAndSettle();
      expect(buttonFocus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'clearing an error releases its keyboard focus without trapping tab navigation',
    (tester) async {
      await tester.pumpWidget(subject(message));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpWidget(subject(null));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(Focus.of(tester.element(find.text('다음 입력'))).hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long descriptions support keyboard scrolling and leave focus for the next control',
    (tester) async {
      await tester.pumpWidget(subject(message));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(Focus.of(tester.element(find.text('다음 입력'))).hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty and short descriptions do not add a tab stop', (
    tester,
  ) async {
    for (final description in [null, '정보를 확인해 주세요.']) {
      await tester.pumpWidget(subject(description));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(Focus.of(tester.element(find.text('다음 입력'))).hasFocus, isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'screen readers receive the full message and can scroll its viewport',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(subject(message));
      await tester.pumpAndSettle();
      final announcement = find.bySemanticsLabel('로그인하지 못했어요\n$message');
      expect(announcement, findsOneWidget);
      final root = tester.getSemantics(announcement);
      expect(root.getSemanticsData().label, '로그인하지 못했어요\n$message');
      final scrollNodes = <SemanticsNode>[];
      void collect(SemanticsNode node) {
        if (node.getSemanticsData().hasAction(SemanticsAction.scrollUp)) {
          scrollNodes.add(node);
        }
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(root);
      expect(scrollNodes, hasLength(1));
      final node = scrollNodes.single;
      node.owner!.performAction(node.id, SemanticsAction.scrollUp);
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(0),
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
