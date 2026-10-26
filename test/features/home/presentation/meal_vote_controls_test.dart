import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_section.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/meal_vote_controls.dart';

class FakeVotes extends MealVoteService {
  MealVote meal = const MealVote(id: 'menu', items: ['밥', '국']);
  bool fail = false;
  final writes = <int>[];
  Completer<MealVote>? pendingWrite;
  @override
  Future<List<MealVote>> fetch(String date, {bool force = false}) async => [
    meal,
  ];
  @override
  Future<MealVote> setVote(String date, MealVote meal, int choice) async {
    writes.add(choice);
    if (fail) throw StateError('offline');
    if (pendingWrite != null) return pendingWrite!.future;
    return this.meal = MealVote(
      id: meal.id,
      items: meal.items,
      likes: choice == 1 ? 1 : 0,
      dislikes: choice == -1 ? 1 : 0,
      choice: choice,
      version: meal.version + 1,
    );
  }
}

void main() {
  final today = DateTime(2026, 10, 15);
  late FakeVotes service;
  setUp(() => service = FakeVotes());
  tearDown(() => service.dispose());

  Future<void> mount(
    WidgetTester tester, {
    DateTime? date,
    double scale = 1,
    Widget? child,
    String? account = 'A123456',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealVoteAccountProvider.overrideWithValue(account),
          mealVoteServiceProvider.overrideWithValue(service),
          campusClockProvider.overrideWithValue(() => today),
        ],
        child: MaterialApp(
          theme: themeData,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(
                child:
                    child ??
                    MealVoteControls(
                      date: date ?? today,
                      items: const ['밥', '국'],
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'recommend, change and cancel update counts; failed writes remain retryable',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('meal-vote-1')));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('meal-vote--1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('meal-vote--1')));
      await tester.pumpAndSettle();
      expect(service.writes, [1, -1, 0]);
      service.fail = true;
      await tester.tap(find.byKey(const ValueKey('meal-vote-1')));
      await tester.pumpAndSettle();
      expect(find.text('평가를 저장하지 못했어요. 다시 눌러 주세요.'), findsOneWidget);
      service.fail = false;
      await tester.tap(find.byKey(const ValueKey('meal-vote-1')));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pending votes update immediately without progress or disabling',
    (tester) async {
      await mount(tester);
      final pending = Completer<MealVote>();
      service.pendingWrite = pending;
      final vote = find.byKey(const ValueKey('meal-vote-1'));
      final before = tester.getRect(find.byType(MealVoteControls));
      await tester.tap(vote);
      await tester.pump();
      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('평가 저장 중'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<TextButton>(vote).onPressed, isNotNull);
      expect(tester.getRect(find.byType(MealVoteControls)), before);
      pending.complete(
        const MealVote(
          id: 'menu',
          items: ['밥', '국'],
          likes: 10,
          choice: 1,
          version: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('rapid changes display immediately and save the latest choice', (
    tester,
  ) async {
    await mount(tester);
    final pending = Completer<MealVote>();
    service.pendingWrite = pending;
    await tester.tap(find.byKey(const ValueKey('meal-vote-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('meal-vote--1')));
    await tester.pump();
    expect(find.byIcon(Icons.thumb_down), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up), findsNothing);
    await tester.tap(find.byKey(const ValueKey('meal-vote--1')));
    await tester.pump();
    expect(find.text('0'), findsNWidgets(2));
    expect(service.writes, [1]);
    service.pendingWrite = null;
    pending.complete(service.meal.withOptimisticChoice(1));
    await tester.pumpAndSettle();
    expect(service.writes, [1, 0]);
    expect(find.text('0'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'failed optimistic writes restore the previous counts and choice',
    (tester) async {
      service.meal = const MealVote(
        id: 'menu',
        items: ['밥', '국'],
        likes: 7,
        dislikes: 2,
      );
      await mount(tester);
      final pending = Completer<MealVote>();
      service.pendingWrite = pending;
      await tester.tap(find.byKey(const ValueKey('meal-vote-1')));
      await tester.pump();
      expect(find.text('8'), findsOneWidget);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up), findsNothing);
      expect(find.text('평가를 저장하지 못했어요. 다시 눌러 주세요.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('queued failure restores the most recent confirmed vote', (
    tester,
  ) async {
    await mount(tester);
    final pending = Completer<MealVote>();
    service.pendingWrite = pending;
    await tester.tap(find.byKey(const ValueKey('meal-vote-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('meal-vote--1')));
    await tester.pump();
    service.pendingWrite = null;
    service.fail = true;
    pending.complete(service.meal.withOptimisticChoice(1));
    await tester.pumpAndSettle();
    expect(service.writes, [1, -1]);
    expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    expect(find.byIcon(Icons.thumb_down), findsNothing);
    expect(find.text('평가를 저장하지 못했어요. 다시 눌러 주세요.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('past dates show disabled votes', (tester) async {
    await mount(tester, date: today.subtract(const Duration(days: 1)));
    expect(find.text('마감된 평가예요.'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byType(TextButton).first).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('private outage keeps counts visible and retry restores voting', (
    tester,
  ) async {
    service.meal = const MealVote(id: 'menu', items: ['밥', '국'], likes: 7);
    service.personalVotesUnavailable = true;
    await mount(tester);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('내 평가를 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('로그인을 다시 확인해 주세요.'), findsNothing);
    final vote = find.byKey(const ValueKey('meal-vote-1'));
    expect(tester.widget<TextButton>(vote).onPressed, isNull);
    service.personalVotesUnavailable = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(vote).onPressed, isNotNull);
    expect(find.text('다시 시도'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'logged-out viewers see totals without an account selection or active actions',
    (tester) async {
      service.meal = const MealVote(
        id: 'menu',
        items: ['밥', '국'],
        likes: 7,
        dislikes: 2,
        choice: 1,
      );
      await mount(tester, account: null);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('로그인 후 평가할 수 있어요.'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up), findsNothing);
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        expect(button.onPressed, isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'account changes discard a late write from the previous account',
    (tester) async {
      await mount(tester);
      final pending = Completer<MealVote>();
      service.pendingWrite = pending;
      await tester.tap(find.byKey(const ValueKey('meal-vote-1')));
      await tester.pump();
      expect(find.text('평가 저장 중'), findsNothing);
      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
      service.meal = service.meal.withChoice(-1);
      await mount(tester, account: 'B123456');
      expect(find.byIcon(Icons.thumb_down), findsOneWidget);
      pending.complete(service.meal.withChoice(1));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.thumb_down), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up), findsNothing);
      await mount(tester, account: null);
      expect(find.byIcon(Icons.thumb_down), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('narrow layout and large text wrap without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, scale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byType(TextButton), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('votes share one compact control with text-sized halves', (
    tester,
  ) async {
    await mount(tester);
    final left = tester.getRect(find.byKey(const ValueKey('meal-vote-1')));
    final right = tester.getRect(find.byKey(const ValueKey('meal-vote--1')));
    expect(left.height, lessThan(36));
    expect(right.height, lessThan(36));
    expect(left.top, right.top);
    expect(right.left - left.right, closeTo(1, 0.01));
    final controls = tester.getRect(find.byType(MealVoteControls));
    expect((left.left + right.right) / 2, closeTo(controls.center.dx, 0.01));
    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('faculty and non-lunch meals never show voting controls', (
    tester,
  ) async {
    for (final (name, type) in [
      ('교직원식당', MealType.lunch),
      ('제2기숙사', MealType.dinner),
    ]) {
      await mount(
        tester,
        child: CafeteriaMenuSection(
          cafeteria: CafeteriaMenu(
            name: name,
            priceInfo: '',
            meals: [
              MealMenu(type: type, time: '', items: const ['밥', '국']),
            ],
          ),
          voteDate: today,
        ),
      );
      expect(find.byType(MealVoteControls), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'student lunch choices have separate controls without an inline notice',
    (tester) async {
      await mount(
        tester,
        child: CafeteriaMenuSection(
          cafeteria: const CafeteriaMenu(
            name: '제2기숙사',
            priceInfo: '',
            meals: [
              MealMenu(type: MealType.lunch, time: '', items: ['밥', '국']),
              MealMenu(type: MealType.lunch, time: '', items: ['면', '김치']),
            ],
          ),
          voteDate: today,
        ),
      );
      expect(find.byType(MealVoteControls), findsNWidgets(2));
      expect(
        find.text('계정 정보 없이 참여해요. 중복 방지용 임의 식별값을 이 브라우저·앱에 저장해요.'),
        findsNothing,
      );
      expect(find.text('식단 정보가 달라요. 메뉴를 새로고침해 주세요.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
