import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/attendance/presentation/attendance_status_message.dart';

void main() {
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
