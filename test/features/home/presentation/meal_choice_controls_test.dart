import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_choice_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_key.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_section.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/meal_choice_controls.dart';
import 'package:hongik_ingan/features/home/presentation/home_service_summary_provider.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_service_workspace.dart';

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
  bool ownUnavailable = false;
  bool storageUnavailable = false;
  Object? writeError;
  bool uncertainWrite = false;
  final freshReads = <String>[];
  final writes = <String?>[];
  @override
  bool personalUnavailableFor(String date) => ownUnavailable;
  @override
  bool storageUnavailableFor(String date) => storageUnavailable;
  @override
  Future<LunchPoll?> fetch(
    String date, {
    bool force = false,
    bool fresh = false,
  }) async {
    if (fresh) freshReads.add(date);
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
    if (writeError != null) throw writeError!;
    if (uncertainWrite) {
      this.poll = poll.withChoice(choice, optimistic: true);
      throw DioException(
        requestOptions: RequestOptions(path: '/api/meal-choice'),
      );
    }
    if (fail) throw StateError('offline');
    if (pending != null) return pending!.future;
    return this.poll = poll.withChoice(choice, optimistic: true);
  }
}

class _MenuController extends CafeteriaMenuController {
  @override
  CafeteriaMenuState build() {
    final today = DateTime(2026, 10, 26);
    return CafeteriaMenuState(
      baseDate: today,
      selectedDate: today,
      dates: [today],
      menus: [
        DailyMenu(
          date: today,
          weekday: '월',
          cafeterias: const [
            CafeteriaMenu(name: '제2기숙사', priceInfo: '', meals: _meals),
          ],
        ),
      ],
    );
  }
}

void main() {
  test('result text remains legible in both themes', () {
    for (final theme in [themeData, darkThemeData]) {
      final palette = theme.extension<HongikPalette>()!;
      final background = palette.cardSurface;
      for (final foreground in [
        theme.colorScheme.onSurface,
        theme.colorScheme.primary,
        palette.textSecondary,
      ]) {
        final first = foreground.computeLuminance();
        final second = background.computeLuminance();
        final contrast = first > second
            ? (first + 0.05) / (second + 0.05)
            : (second + 0.05) / (first + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    }
  });
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
    DateTime Function()? clock,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeControllerProvider.overrideWithValue(
            HomeState(isLoggedIn: account != null, userId: account),
          ),
          mealChoiceServiceProvider.overrideWithValue(service),
          campusClockProvider.overrideWithValue(clock ?? () => today),
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

  testWidgets('closes at 14:00 while the screen is open', (tester) async {
    var now = DateTime(2026, 10, 26, 13, 59, 59);
    await mount(tester, clock: () => now);
    expect(find.text('중식 · 투표 마감'), findsNothing);
    now = DateTime(2026, 10, 26, 14);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('중식 · 투표 마감'), findsOneWidget);
    await tester.tap(find.text('제육볶음'));
    await tester.pump();
    expect(service.writes, isEmpty);
    expect(find.text('12표'), findsOneWidget);
    expect(service.freshReads, ['2026-10-26']);
  });

  testWidgets('closed voting preserves the confirmed selection', (
    tester,
  ) async {
    service.poll = service.poll.withChoice('A');
    final semantics = tester.ensureSemantics();
    await mount(tester, date: today.subtract(const Duration(days: 1)));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    final selected = tester.getSemantics(
      find.byKey(const ValueKey('meal-choice-A')),
    );
    expect(selected.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(selected.flagsCollection.isEnabled, ui.Tristate.isFalse);
    await tester.tap(find.text('제육볶음'));
    expect(service.writes, isEmpty);
    semantics.dispose();
  });

  testWidgets('server closure locks voting and refreshes final totals', (
    tester,
  ) async {
    service.writeError = DioException(
      requestOptions: RequestOptions(path: '/api/meal-choice'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/meal-choice'),
        statusCode: 409,
        data: {'error': 'VOTING_CLOSED'},
      ),
    );
    await mount(tester);
    await tester.tap(find.text('제육볶음'));
    await tester.pumpAndSettle();
    expect(find.text('중식 · 투표 마감'), findsOneWidget);
    expect(service.freshReads, ['2026-10-26']);
    expect(find.textContaining('새로고침해 주세요'), findsNothing);
    await tester.tap(find.text('돈까스'));
    expect(service.writes, ['A']);
  });

  testWidgets('changed menu explains that the menu needs refreshing', (
    tester,
  ) async {
    service.writeError = DioException(
      requestOptions: RequestOptions(path: '/api/meal-choice'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/meal-choice'),
        statusCode: 409,
        data: {'error': 'MENU_UNAVAILABLE'},
      ),
    );
    await mount(tester);
    await tester.tap(find.text('제육볶음'));
    await tester.pumpAndSettle();
    expect(find.text('식단이 변경됐어요. 메뉴를 새로고침해 주세요.'), findsOneWidget);
    expect(find.text('중식 · 투표 마감'), findsNothing);
  });

  testWidgets('an uncertain write is reconciled with the saved choice', (
    tester,
  ) async {
    service.uncertainWrite = true;
    await mount(tester);
    await tester.tap(find.text('제육볶음'));
    await tester.pumpAndSettle();
    expect(service.freshReads, ['2026-10-26']);
    expect(find.text('13표'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('failed reconciliation keeps voting locked until retry', (
    tester,
  ) async {
    await mount(tester);
    service.uncertainWrite = true;
    service.readFail = true;
    await tester.tap(find.text('제육볶음'));
    await tester.pumpAndSettle();
    expect(find.text('투표를 불러오지 못했어요.'), findsOneWidget);
    await tester.tap(find.text('돈까스'));
    expect(service.writes, ['A']);
    service.readFail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('13표'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(service.freshReads, ['2026-10-26', '2026-10-26']);
  });

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
    expect(
      tester.widget<Text>(find.text('A안')).style?.color,
      themeData.colorScheme.primary,
    );
    expect(
      tester.widget<Text>(find.text('B안')).style?.color,
      HongikPalette.light.textSecondary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.favorite_rounded)).color,
      themeData.colorScheme.primary,
    );
    await tester.tap(find.text('돈까스'));
    await tester.pumpAndSettle();
    expect(service.writes, ['A', 'B', null]);
    expect(find.text('8표'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(2));
  });

  testWidgets('leading label follows totals and restores on failed vote', (
    tester,
  ) async {
    service.poll = const LunchPoll(
      id: 'poll',
      options: {
        'A': ['제육볶음', '밥', '국'],
        'B': ['돈까스', '김치'],
      },
      aVotes: 1,
      bVotes: 0,
    );
    final semantics = tester.ensureSemantics();
    await mount(tester);
    final beforeA = tester.getRect(find.byKey(const ValueKey('meal-choice-A')));
    final beforeB = tester.getRect(find.byKey(const ValueKey('meal-choice-B')));
    FontWeight? weight(String label) =>
        tester.widget<Text>(find.text(label)).style?.fontWeight;
    expect(weight('A안'), FontWeight.w700);
    expect(weight('B안'), FontWeight.w600);
    expect(
      tester.widget<Text>(find.text('A안')).style?.color,
      themeData.colorScheme.primary,
    );
    expect(
      tester.widget<Text>(find.text('B안')).style?.color,
      HongikPalette.light.textSecondary,
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('meal-choice-A'))).label,
      contains('투표 수 우세'),
    );
    final pending = Completer<LunchPoll>();
    service.pending = pending;
    await tester.tap(find.text('돈까스'));
    await tester.pump();
    expect(weight('A안'), FontWeight.w600);
    expect(weight('B안'), FontWeight.w600);
    expect(
      tester.widget<Text>(find.text('A안')).style?.color,
      HongikPalette.light.textSecondary,
    );
    expect(
      tester.widget<Text>(find.text('B안')).style?.color,
      HongikPalette.light.textSecondary,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('meal-choice-A'))),
      beforeA,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('meal-choice-B'))),
      beforeB,
    );
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(weight('A안'), FontWeight.w700);
    expect(weight('B안'), FontWeight.w600);
    expect(
      tester.widget<Text>(find.text('A안')).style?.color,
      themeData.colorScheme.primary,
    );
    semantics.dispose();
  });

  testWidgets('summary follows optimistic totals and rollback', (tester) async {
    service.poll = const LunchPoll(
      id: 'poll',
      options: {
        'A': ['제육볶음', '밥', '국'],
        'B': ['돈까스', '김치'],
      },
      aVotes: 1,
      bVotes: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealChoiceServiceProvider.overrideWithValue(service),
          campusClockProvider.overrideWithValue(
            () => DateTime(2026, 10, 26, 12),
          ),
          cafeteriaMenuControllerProvider.overrideWith(_MenuController.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) => Text(
                    'leader:${ref.watch(homeServiceSummaryProvider(HomeService.menu)).leadingMenuIndex}',
                  ),
                ),
                CafeteriaMenuSection(
                  cafeteria: const CafeteriaMenu(
                    name: '제2기숙사',
                    priceInfo: '',
                    meals: _meals,
                  ),
                  voteDate: today,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('leader:0'), findsOneWidget);
    final pending = Completer<LunchPoll>();
    service.pending = pending;
    await tester.tap(find.text('돈까스'));
    await tester.pump();
    await tester.pump();
    expect(find.text('leader:null'), findsOneWidget);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('leader:0'), findsOneWidget);
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

  testWidgets('guest voting keeps a pending choice through a rebuild', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await mount(tester, account: null);
    final pending = Completer<LunchPoll>();
    service.pending = pending;
    await tester.tap(find.text('제육볶음'));
    await tester.pump();
    await mount(tester, account: 'B123456');
    pending.complete(service.poll.withChoice('A', optimistic: true));
    await tester.pumpAndSettle();
    expect(service.writes, ['A']);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('meal-choice-A')))
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
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
      expect(find.text('내 선택 구분'), findsOneWidget);
      expect(find.textContaining('한 번 더 누르면 취소'), findsOneWidget);
      expect(find.textContaining('오후 2시에 투표가 마감'), findsOneWidget);
      expect(find.text('투표 기록 처리'), findsOneWidget);
      final dialogSurface = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Material),
      );
      expect(tester.getSize(dialogSurface.first).width, lessThanOrEqualTo(400));
      expect(find.textContaining('학번은 투표 서버에 보내지 않아요'), findsOneWidget);
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

  testWidgets('voting works without a login', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    await mount(tester, account: null);
    final a = find.byKey(const ValueKey('meal-choice-A'));
    expect(
      tester.getSemantics(a).flagsCollection.isEnabled,
      ui.Tristate.isTrue,
    );
    await tester.tap(a);
    await tester.pumpAndSettle();
    expect(service.writes, ['A']);
    await tester.tap(a);
    await tester.pumpAndSettle();
    expect(service.writes, ['A', null]);
    semanticsHandle.dispose();
  });

  testWidgets(
    'personal outage preserves public totals and retry restores action',
    (tester) async {
      service.ownUnavailable = true;
      await mount(tester);
      expect(find.text('12표'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
      expect(find.text('내 선택을 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      await tester.tap(find.text('제육볶음'));
      expect(service.writes, isEmpty);
      service.ownUnavailable = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(2));
      await tester.tap(find.text('제육볶음'));
      await tester.pumpAndSettle();
      expect(service.writes, ['A']);
    },
  );

  testWidgets('storage failure explains how to recover without hiding totals', (
    tester,
  ) async {
    service.ownUnavailable = true;
    service.storageUnavailable = true;
    await mount(tester, account: null);
    expect(find.text('12표'), findsOneWidget);
    expect(
      find.text('기기의 투표 저장소에 접근할 수 없어요. 저장소 설정을 확인해 주세요.'),
      findsOneWidget,
    );
    service.ownUnavailable = false;
    service.storageUnavailable = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    service.writeError = const MealVoteStorageException();
    await tester.tap(find.text('제육볶음'));
    await tester.pumpAndSettle();
    expect(
      find.text('기기의 투표 저장소에 접근할 수 없어요. 저장소 설정을 확인해 주세요.'),
      findsOneWidget,
    );
    expect(find.text('12표'), findsOneWidget);
  });

  testWidgets('unsupported browser suggests another browser', (tester) async {
    service.writeError = UnsupportedError('Web Locks unavailable');
    await mount(tester, account: null);
    await tester.tap(find.text('제육볶음'));
    await tester.pumpAndSettle();
    expect(
      find.text('이 브라우저에서는 투표를 저장할 수 없어요. 다른 브라우저에서 시도해 주세요.'),
      findsOneWidget,
    );
  });

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
    expect(service.writes, ['B', 'A', null, 'B']);
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
      // Narrow headings may wrap differently when the closed label changes.
      if (width >= 900) expect(tester.getSize(header).height, height);
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
