import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_choice_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_section.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/meal_choice_controls.dart';

const _meals = [
  MealMenu(
    type: MealType.lunch,
    time: '11:30~14:00',
    items: ['제육볶음', '밥', '국'],
    option: 'A',
  ),
  MealMenu(
    type: MealType.lunch,
    time: '11:30~14:00',
    items: ['돈까스', '김치'],
    option: 'B',
  ),
];

class _Votes extends MealChoiceService {
  LunchPoll poll = const LunchPoll(
    id: 'poll',
    options: {
      'A': ['제육볶음', '밥', '국'],
      'B': ['돈까스', '김치'],
    },
    aVotes: 12,
    bVotes: 8,
  );
  Completer<LunchPoll>? pending;
  Completer<LunchPoll?>? read;
  bool fail = false;
  bool readFail = false;
  final writes = <String?>[];
  @override
  Future<LunchPoll?> fetch(String date, {bool force = false}) async {
    if (readFail) throw StateError('offline');
    return read == null ? poll : await read!.future;
  }

  @override
  Future<LunchPoll> setChoice(
    String date,
    LunchPoll poll,
    String? choice,
  ) async {
    writes.add(choice);
    if (fail) throw StateError('offline');
    if (pending != null) return pending!.future;
    return this.poll = poll.withChoice(choice, optimistic: true);
  }
}

void main() {
  final today = DateTime(2026, 10, 26);
  late _Votes service;
  setUp(() => service = _Votes());
  tearDown(() => service.dispose());

  Future<void> mount(
    WidgetTester tester, {
    String? account = 'A123456',
    DateTime? date,
    double scale = 1,
    bool dark = false,
    List<MealMenu> meals = _meals,
    String name = '제2기숙사',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealVoteAccountProvider.overrideWithValue(account),
          mealChoiceServiceProvider.overrideWithValue(service),
          campusClockProvider.overrideWithValue(() => today),
        ],
        child: MaterialApp(
          theme: dark ? darkThemeData : themeData,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CafeteriaMenuSection(
                  cafeteria: CafeteriaMenu(
                    name: name,
                    priceInfo: '',
                    meals: meals,
                  ),
                  voteDate: date ?? today,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('whole menus select, switch and cancel without changing height', (
    tester,
  ) async {
    await mount(tester);
    final before = tester.getRect(find.byType(MealChoiceControls));
    await tester.tap(find.text('제육볶음'));
    await tester.pumpAndSettle();
    expect(find.text('13표'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(tester.getRect(find.byType(MealChoiceControls)), before);
    await tester.tap(find.text('돈까스'));
    await tester.pumpAndSettle();
    expect(find.text('12표'), findsOneWidget);
    expect(find.text('9표'), findsOneWidget);
    await tester.tap(find.text('돈까스'));
    await tester.pumpAndSettle();
    expect(service.writes, ['A', 'B', null]);
    expect(find.text('8표'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('rapid A to B input updates both counts and serializes writes', (
    tester,
  ) async {
    await mount(tester);
    final pending = Completer<LunchPoll>();
    service.pending = pending;
    await tester.tap(find.text('제육볶음'));
    await tester.pump();
    await tester.tap(find.text('돈까스'));
    await tester.pump();
    expect(find.text('12표'), findsOneWidget);
    expect(find.text('9표'), findsOneWidget);
    expect(service.writes, ['A']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    service.pending = null;
    pending.complete(service.poll.withChoice('A', optimistic: true));
    await tester.pumpAndSettle();
    expect(service.writes, ['A', 'B']);
    expect(find.text('9표'), findsOneWidget);
  });

  testWidgets(
    'queued failure restores the latest confirmed choice and counts',
    (tester) async {
      await mount(tester);
      final pending = Completer<LunchPoll>();
      service.pending = pending;
      await tester.tap(find.text('제육볶음'));
      await tester.pump();
      await tester.tap(find.text('돈까스'));
      await tester.pump();
      service.pending = null;
      service.fail = true;
      pending.complete(service.poll.withChoice('A', optimistic: true));
      await tester.pumpAndSettle();
      expect(find.text('13표'), findsOneWidget);
      expect(find.text('8표'), findsOneWidget);
      expect(find.text('선택을 저장하지 못했어요. 다시 눌러 주세요.'), findsOneWidget);
      service.fail = false;
      await tester.tap(find.text('돈까스'));
      await tester.pumpAndSettle();
      expect(find.text('9표'), findsOneWidget);
    },
  );

  testWidgets('logout and account changes discard late writes', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await mount(tester);
    final pending = Completer<LunchPoll>();
    service.pending = pending;
    await tester.tap(find.text('제육볶음'));
    await tester.pump();
    service.poll = service.poll.withChoice('B');
    await mount(tester, account: 'B123456');
    pending.complete(service.poll.withChoice('A', optimistic: true));
    await tester.pumpAndSettle();
    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('meal-choice-B')),
    );
    expect(semantics.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(semantics.label, contains('B안, 8표'));
    await mount(tester, account: null);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.text('로그인 후 학번으로 투표할 수 있어요.'), findsNothing);
    await tester.tap(find.text('돈까스'));
    expect(service.writes, ['A']);
    semanticsHandle.dispose();
  });

  testWidgets('logged out voting explains the lock on touch, hover and focus', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await mount(tester, account: null);
    final a = find.byKey(const ValueKey('meal-choice-A'));
    final b = find.byKey(const ValueKey('meal-choice-B'));
    const hint = '로그인 후 학번으로 투표할 수 있어요.';
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
    expect(find.text(hint), findsNothing);
    final semantics = tester.getSemantics(a);
    expect(semantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(semantics.hint, hint);

    await tester.tap(a);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(hint), findsOneWidget);
    expect(service.writes, isEmpty);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(hint), findsNothing);

    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(b));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(hint), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(hint), findsNothing);
    await mouse.removePointer();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(hint), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(service.writes, isEmpty);
    semanticsHandle.dispose();
  });

  testWidgets(
    'personal outage preserves public totals and retry restores action',
    (tester) async {
      service.personalUnavailable = true;
      await mount(tester);
      expect(find.text('12표'), findsOneWidget);
      expect(find.text('내 선택을 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      await tester.tap(find.text('제육볶음'));
      expect(service.writes, isEmpty);
      service.personalUnavailable = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('제육볶음'));
      await tester.pumpAndSettle();
      expect(service.writes, ['A']);
    },
  );

  testWidgets(
    'failed public reads never show zero votes; menus remain visible',
    (tester) async {
      service.readFail = true;
      await mount(tester);
      expect(find.text('0표'), findsNothing);
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('제육볶음'), findsOneWidget);
      await tester.tap(find.text('돈까스'));
      expect(service.writes, isEmpty);
    },
  );

  testWidgets(
    'past and future dates are read only; only a complete pair votes',
    (tester) async {
      for (final date in [
        today.subtract(const Duration(days: 1)),
        today.add(const Duration(days: 1)),
      ]) {
        await mount(tester, date: date);
        await tester.tap(find.text('돈까스'));
        expect(service.writes, isEmpty);
      }
      for (final meals in [
        [_meals.first],
        [
          const MealMenu(type: MealType.lunch, time: '', items: ['밥']),
        ],
      ]) {
        await mount(tester, meals: meals);
        expect(find.byType(MealChoiceControls), findsNothing);
      }
      await mount(tester, name: '교직원식당');
      expect(find.byType(MealChoiceControls), findsNothing);
    },
  );

  testWidgets('compact headers, stable theme geometry and large touch areas', (
    tester,
  ) async {
    for (final width in [320.0, 900.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      Rect? lightRect;
      for (final dark in [false, true]) {
        await mount(tester, dark: dark, meals: _meals.reversed.toList());
        final a = tester.getRect(find.byKey(const ValueKey('meal-choice-A')));
        final b = tester.getRect(find.byKey(const ValueKey('meal-choice-B')));
        expect(a.height, greaterThanOrEqualTo(44));
        expect(b.height, greaterThanOrEqualTo(44));
        expect(
          tester.getRect(find.text('제육볶음')).top -
              tester.getRect(find.text('A안')).top,
          lessThanOrEqualTo(30),
        );
        if (width == 900) {
          expect(a.top, b.top);
          expect(tester.getRect(find.text('12표')).right, closeTo(a.right, 1));
          expect(tester.getRect(find.text('B안')).left, greaterThan(b.left));
        } else {
          expect(a.bottom, lessThan(b.top));
          expect(tester.getRect(find.text('A안')).left, greaterThan(a.left));
        }
        expect(
          tester.getRect(find.text('12표')).left -
              tester.getRect(find.text('A안')).right,
          closeTo(6, 1),
        );
        if (dark) {
          expect(a, lightRect);
        } else {
          lightRect = a;
        }
        expect(tester.takeException(), isNull);
      }
      await mount(tester, scale: 2);
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
    'weekday HTML menus resolve A/B from canonical slots, not row order',
    (tester) async {
      final htmlMeals = _meals.reversed
          .map(
            (meal) =>
                MealMenu(type: meal.type, time: meal.time, items: meal.items),
          )
          .toList();
      await mount(tester, meals: htmlMeals);
      final a = find.byKey(const ValueKey('meal-choice-A'));
      expect(
        find.descendant(of: a, matching: find.text('제육볶음')),
        findsOneWidget,
      );
      await tester.tap(find.text('제육볶음'));
      await tester.pumpAndSettle();
      expect(service.writes, ['A']);
    },
  );

  testWidgets(
    'identical HTML menus retain distinct slots; mismatch cannot vote',
    (tester) async {
      service.poll = const LunchPoll(
        id: 'same',
        options: {
          'A': ['밥'],
          'B': ['밥'],
        },
      );
      const htmlMeals = [
        MealMenu(type: MealType.lunch, time: '', items: ['밥']),
        MealMenu(type: MealType.lunch, time: '', items: ['밥']),
      ];
      await mount(tester, meals: htmlMeals);
      await tester.tap(find.byKey(const ValueKey('meal-choice-B')));
      await tester.pumpAndSettle();
      expect(service.writes, ['B']);
      await mount(
        tester,
        meals: [
          htmlMeals.first,
          const MealMenu(type: MealType.lunch, time: '', items: ['새 메뉴']),
        ],
      );
      expect(find.text('식단 정보가 달라요. 메뉴를 새로고침해 주세요.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      await tester.tap(find.text('새 메뉴'));
      expect(service.writes, ['B']);
    },
  );
}
