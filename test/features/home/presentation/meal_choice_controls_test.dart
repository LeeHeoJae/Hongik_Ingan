import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    bool reduceMotion = false,
    bool enableVote = true,
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
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
            ),
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
                  voteDate: enableVote ? date ?? today : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (service.read != null && !service.read!.isCompleted) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('whole menus select, switch and cancel without changing height', (
    tester,
  ) async {
    await mount(tester);
    final before = tester.getRect(find.byType(MealChoiceControls));
    await tester.tap(find.text('제육볶음'));
    await tester.pumpAndSettle();
    expect(find.text('13표'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(tester.getRect(find.byType(MealChoiceControls)), before);
    await tester.tap(find.text('돈까스'));
    await tester.pumpAndSettle();
    expect(find.text('12표'), findsOneWidget);
    expect(find.text('9표'), findsOneWidget);
    await tester.tap(find.text('돈까스'));
    await tester.pumpAndSettle();
    expect(service.writes, ['A', 'B', null]);
    expect(find.text('8표'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(2));
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
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.text('로그인 후 학번으로 투표할 수 있어요.'), findsNothing);
    await tester.tap(find.text('돈까스'));
    expect(service.writes, ['A']);
    semanticsHandle.dispose();
  });

  testWidgets('vote information is available regardless of login', (
    tester,
  ) async {
    for (final account in <String?>[null, 'A123456']) {
      await mount(tester, account: account);
      final info = find.byTooltip('학식 투표 안내');
      expect(tester.getSize(info), const Size(24, 24));
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.text('학식 투표 안내'), findsOneWidget);
      expect(find.text('학번을 사용하는 이유'), findsOneWidget);
      expect(find.text('투표 기록 처리'), findsOneWidget);
      final dialogSurface = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Material),
      );
      expect(tester.getSize(dialogSurface.first).width, lessThanOrEqualTo(400));
      expect(find.textContaining('학번은 투표 서버에 전달되며'), findsOneWidget);
      expect(find.byIcon(Icons.how_to_vote_outlined), findsOneWidget);
      expect(find.byIcon(Icons.key_outlined), findsOneWidget);
      expect(
        tester.getCenter(find.text('확인')).dx,
        closeTo(tester.getCenter(dialogSurface.first).dx, 1),
      );
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('학식 투표 안내'), findsNothing);
      expect(service.writes, isEmpty);
    }
  });

  testWidgets('vote information remains usable at large text on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final dark in [false, true]) {
      await mount(tester, account: null, scale: 2, dark: dark);
      await tester.tap(find.byTooltip('학식 투표 안내'));
      await tester.pumpAndSettle();
      expect(find.text('학식 투표 안내'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('학식 투표 안내'), findsNothing);
    }
  });

  testWidgets('vote information can be opened with the keyboard', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await mount(tester, account: null);
    expect(find.bySemanticsLabel('학식 투표 안내'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('학식 투표 안내'), findsOneWidget);
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
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
      expect(find.text('내 선택을 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      await tester.tap(find.text('제육볶음'));
      expect(service.writes, isEmpty);
      service.personalUnavailable = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(2));
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
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
      expect(find.text('제육볶음'), findsOneWidget);
      await tester.tap(find.text('돈까스'));
      expect(service.writes, isEmpty);
      expect(find.text('로그인 후 학번으로 투표할 수 있어요.'), findsNothing);
    },
  );

  testWidgets('past dates are closed and future dates allow votes', (
    tester,
  ) async {
    await mount(tester, date: today.subtract(const Duration(days: 1)));
    final notice = find.text('중식 · 투표 마감');
    expect(notice, findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
    final info = find.byTooltip('학식 투표 안내');
    expect(
      tester.getRect(notice).right,
      lessThanOrEqualTo(tester.getRect(info).left),
    );
    await tester.tap(find.text('돈까스'));
    expect(service.writes, isEmpty);
    await mount(tester, date: today.add(const Duration(days: 1)));
    expect(notice, findsNothing);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(2));
    await tester.tap(find.text('돈까스'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('제육볶음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('제육볶음'));
    await tester.pumpAndSettle();
    expect(service.writes, ['B', 'A', null]);
    await mount(
      tester,
      date: today.add(const Duration(days: 1)),
      account: null,
    );
    await tester.tap(find.text('돈까스'));
    expect(service.writes, ['B', 'A', null]);
  });

  testWidgets('only a complete pair votes', (tester) async {
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
  });

  testWidgets('closed notice wraps on narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, scale: 2);
    final info = find.byTooltip('학식 투표 안내');
    final header = find.byKey(const ValueKey('meal-section-header'));
    final position = tester.getCenter(info);
    expect(position.dx, closeTo(tester.getCenter(header).dx, 0.1));
    await mount(
      tester,
      date: today.subtract(const Duration(days: 1)),
      scale: 2,
    );
    expect(find.text('중식 · 투표 마감'), findsOneWidget);
    expect(tester.getCenter(info), position);
    expect(
      tester.getRect(find.text('중식 · 투표 마감')).right,
      lessThanOrEqualTo(tester.getRect(info).left),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed notice keeps the information button in place', (
    tester,
  ) async {
    for (final width in [320.0, 900.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await mount(tester);
      final info = find.byTooltip('학식 투표 안내');
      final position = tester.getCenter(info);
      final header = find.byKey(const ValueKey('meal-section-header'));
      final height = tester.getSize(header).height;
      expect(position.dx, closeTo(tester.getCenter(header).dx, 0.1));
      await mount(tester, date: today.subtract(const Duration(days: 1)));
      expect(tester.getCenter(info), position);
      expect(
        tester.getCenter(info).dx,
        closeTo(tester.getCenter(header).dx, 0.1),
      );
      expect(
        tester.getRect(find.text('중식 · 투표 마감')).right,
        lessThanOrEqualTo(tester.getRect(info).left),
      );
      expect(tester.getSize(header).height, height);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('information button does not increase header height', (
    tester,
  ) async {
    for (final width in [320.0, 900.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await mount(tester, enableVote: false);
      final header = find.byKey(const ValueKey('meal-section-header'));
      final height = tester.getSize(header).height;
      await mount(tester);
      if (width == 900) {
        expect(tester.getSize(header).height, height);
        expect(
          tester.getCenter(find.byTooltip('학식 투표 안내')).dy,
          closeTo(tester.getCenter(find.text('중식 · 택1')).dy, 1),
        );
      } else {
        expect(tester.getSize(header).height, greaterThanOrEqualTo(height));
        expect(tester.takeException(), isNull);
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

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
              tester.getRect(find.text('B안')).top,
          lessThanOrEqualTo(30),
        );
        if (width == 900) {
          expect(a.top, b.top);
          final bIcon = find.descendant(
            of: find.byKey(const ValueKey('meal-choice-B')),
            matching: find.byIcon(Icons.favorite_border_rounded),
          );
          expect(tester.getRect(bIcon).right, closeTo(b.right, 1));
          expect(
            tester.getRect(find.text('8표')).right,
            lessThan(tester.getRect(find.text('A안')).left),
          );
          expect(
            tester.getRect(find.text('A안')).right,
            lessThan(tester.getRect(bIcon).left),
          );
          expect(tester.getRect(find.text('B안')).left, greaterThan(a.left));
        } else {
          expect(b.bottom, lessThan(a.top));
          final bIcon = find.descendant(
            of: find.byKey(const ValueKey('meal-choice-B')),
            matching: find.byIcon(Icons.favorite_border_rounded),
          );
          expect(
            tester.getRect(bIcon).right,
            lessThan(tester.getRect(find.text('A안')).left),
          );
          expect(
            tester.getRect(find.text('A안')).right,
            lessThan(tester.getRect(find.text('8표')).left),
          );
          expect(tester.getRect(find.text('B안')).left, greaterThan(a.left));
        }
        expect(
          tester.getRect(find.text('12표')).left -
              tester.getRect(find.text('B안')).right,
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

  testWidgets('wide loading headers mirror around the menu divider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    service.read = Completer<LunchPoll?>();
    await mount(tester);
    final first = find.byKey(const ValueKey('meal-choice-A'));
    final second = find.byKey(const ValueKey('meal-choice-B'));
    final firstLoading = find.descendant(
      of: first,
      matching: find.byKey(const ValueKey('meal-vote-loading-0')),
    );
    final secondLoading = find.descendant(
      of: second,
      matching: find.byKey(const ValueKey('meal-vote-loading-1')),
    );
    final firstLock = find.descendant(
      of: first,
      matching: find.byIcon(Icons.lock_outline_rounded),
    );
    final secondLock = find.descendant(
      of: second,
      matching: find.byIcon(Icons.lock_outline_rounded),
    );
    expect(
      tester.getRect(firstLoading).right,
      lessThan(tester.getRect(find.text('A안')).left),
    );
    expect(
      tester.getRect(find.text('A안')).right,
      lessThan(tester.getRect(firstLock).left),
    );
    expect(
      tester.getRect(secondLock).right,
      lessThan(tester.getRect(find.text('B안')).left),
    );
    expect(
      tester.getRect(find.text('B안')).right,
      lessThan(tester.getRect(secondLoading).left),
    );
  });

  testWidgets('loading wave moves continuously and respects reduced motion', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    service.read = Completer<LunchPoll?>();
    await mount(tester);
    final loading = find.byKey(const ValueKey('meal-vote-loading-0'));
    final wave = find.descendant(
      of: loading,
      matching: find.byKey(const ValueKey('meal-vote-wave')),
    );
    final unit = find.descendant(of: loading, matching: find.text('표'));
    final unitRect = tester.getRect(unit);
    final waveRect = tester.getRect(wave);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
    expect(
      tester.getSemantics(find.byKey(const ValueKey('meal-choice-A'))).label,
      contains('A안, 집계 확인 중'),
    );

    Future<List<int>> pixels() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(wave);
      return (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = data!.buffer.asUint8List().toList();
        image.dispose();
        return bytes;
      }))!;
    }

    final start = await pixels();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await pixels(), isNot(equals(start)));
    expect(tester.getRect(wave), waveRect);
    expect(tester.getRect(unit), unitRect);
    await tester.pump(const Duration(milliseconds: 900));
    expect(await pixels(), equals(start));

    await mount(tester, reduceMotion: true);
    final still = await pixels();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await pixels(), equals(still));
    expect(tester.getRect(unit), unitRect);

    service.read!.complete(service.poll);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meal-vote-loading-0')), findsNothing);
    expect(find.text('12표'), findsOneWidget);
    expect(find.text('8표'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'weekday HTML menus resolve A/B from canonical slots, not row order',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      service.read = Completer<LunchPoll?>();
      final htmlMeals = _meals.reversed
          .map(
            (meal) =>
                MealMenu(type: meal.type, time: meal.time, items: meal.items),
          )
          .toList();
      await mount(tester, meals: htmlMeals);
      expect(find.text('표'), findsNWidgets(2));
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
      final firstBefore = tester.getRect(find.text('돈까스'));
      final secondBefore = tester.getRect(find.text('제육볶음'));
      expect(firstBefore.top, lessThan(secondBefore.top));
      await tester.tap(find.text('돈까스'));
      expect(service.writes, isEmpty);
      service.read!.complete(service.poll);
      await tester.pumpAndSettle();
      expect(find.text('표'), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(2));
      expect(tester.getRect(find.text('돈까스')), firstBefore);
      expect(tester.getRect(find.text('제육볶음')), secondBefore);
      final b = find.byKey(const ValueKey('meal-choice-B'));
      final a = find.byKey(const ValueKey('meal-choice-A'));
      expect(find.descendant(of: b, matching: find.text('A안')), findsOneWidget);
      expect(find.descendant(of: b, matching: find.text('8표')), findsOneWidget);
      expect(find.descendant(of: a, matching: find.text('B안')), findsOneWidget);
      expect(
        find.descendant(of: a, matching: find.text('12표')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: a, matching: find.text('제육볶음')),
        findsOneWidget,
      );
      await tester.tap(find.text('돈까스'));
      await tester.pumpAndSettle();
      expect(service.writes, ['B']);
      await tester.tap(find.text('제육볶음'));
      await tester.pumpAndSettle();
      expect(service.writes, ['B', 'A']);
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
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
      await tester.tap(find.text('새 메뉴'));
      expect(service.writes, ['B']);
    },
  );
}
