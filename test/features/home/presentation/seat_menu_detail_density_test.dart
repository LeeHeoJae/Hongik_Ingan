import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_date_selector.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_content.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_selector.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_status_content.dart';
import 'package:hongik_ingan/features/seat/presentation/widgets/seat_location_selector.dart';

void main() {
  for (final width in [390.0, 900.0]) {
    testWidgets('주말 상세에는 이번 주 날짜와 대체 안내를 표시한다: $width', (tester) async {
      final dates = MenuDateRange.currentWeekdaysFor(DateTime(2026, 10, 3));
      await tester.pumpWidget(
        _subject(
          const CafeteriaMenuContent(useAdaptiveGrid: true),
          width: width,
          menuState: CafeteriaMenuState(
            baseDate: DateTime(2026, 10, 3),
            selectedDate: dates.last,
            dates: dates,
            menus: [for (final date in dates) DailyMenu.noMenu(date: date)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('이번 주 · 09월 28일 ~ 10월 02일'), findsOneWidget);
      expect(find.text('다음 주 식단이 아직 공개되지 않아 이번 주 식단을 보여드려요.'), findsOneWidget);
      final selector = tester.widget<CafeteriaMenuDateSelector>(
        find.byType(CafeteriaMenuDateSelector),
      );
      expect(selector.dates, dates);
      expect(selector.selectedDate, DateTime(2026, 10, 2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('넓은 열람실에서 조회 결과가 없으면 선택과 안내를 함께 배치한다', (tester) async {
    await tester.pumpWidget(
      _subject(
        const SeatStatusContent(useGrid: true),
        seatState: SeatState(),
        height: 320,
      ),
    );
    await tester.pumpAndSettle();

    final group = tester.getRect(
      find.byKey(const ValueKey('seat-compact-state')),
    );
    expect(group.width, greaterThan(600));
    expect(find.text('건물 선택'), findsNothing);
    expect(find.byType(SeatLocationSelector), findsOneWidget);
    expect(find.text('표시할 좌석 정보가 없어요'), findsOneWidget);
    expect(find.text('열람실별 좌석'), findsNothing);
    _expectVisibleInStage(tester, '새로고침');
    expect(tester.takeException(), isNull);
  });

  testWidgets('긴 좌석 오류와 다시 시도 동작은 짧은 상세 영역에서 스크롤로 접근한다', (tester) async {
    final message = List.filled(24, '연결 상태를 확인해 주세요. ').join();
    await tester.pumpWidget(
      _subject(
        const SeatStatusContent(useGrid: true),
        seatState: SeatState(errors: {SeatLocation.tBuilding: message}),
        height: 320,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('열람실 현황을 불러오지 못했어요'), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    await tester.ensureVisible(find.text('다시 시도'));
    await tester.pumpAndSettle();
    _expectVisibleInStage(tester, '다시 시도');
    expect(tester.takeException(), isNull);
  });

  testWidgets('조회된 열람실은 선택과 좌석 결과를 두 열에 표시한다', (tester) async {
    await tester.pumpWidget(
      _subject(
        const SeatStatusContent(useGrid: true),
        seatState: SeatState(statuses: {SeatLocation.tBuilding: _seatStatus()}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('seat-compact-state')), findsNothing);
    expect(find.text('열람실별 좌석'), findsNothing);
    expect(find.text('제1열람실'), findsOneWidget);
    expect(
      tester.getRect(find.text('제1열람실')).top,
      greaterThan(tester.getRect(find.byType(SeatLocationSelector)).bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('넓은 학식에서 빈 날짜는 선택과 안내를 함께 배치한다', (tester) async {
    await tester.pumpWidget(
      _subject(
        const CafeteriaMenuContent(useAdaptiveGrid: true),
        menuState: _menuState(),
        height: 320,
      ),
    );
    await tester.pumpAndSettle();

    final group = tester.getRect(
      find.byKey(const ValueKey('menu-compact-state')),
    );
    expect(group.width, greaterThan(600));
    expect(find.text('날짜와 식당'), findsNothing);
    expect(find.text('선택한 식당의 메뉴'), findsNothing);
    expect(find.text('메뉴를 준비하고 있어요'), findsOneWidget);
    _expectVisibleInStage(tester, '새로고침');
    expect(tester.takeException(), isNull);
  });

  testWidgets('짧은 학식 상세 영역에서 오류와 다시 시도를 함께 표시한다', (tester) async {
    final date = DateTime(2026, 9, 21);
    await tester.pumpWidget(
      _subject(
        const CafeteriaMenuContent(useAdaptiveGrid: true),
        menuState: _menuState(
          menus: [
            DailyMenu.failure(
              date: date,
              status: MenuDayStatus.networkError,
              message: '식당 메뉴 페이지에 연결할 수 없어요.',
            ),
          ],
        ),
        height: 320,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('식당 메뉴를 불러오지 못했어요'), findsOneWidget);
    _expectVisibleInStage(tester, '다시 시도');
    expect(tester.takeException(), isNull);
  });

  testWidgets('학식에서 메뉴가 없는 식당에서 다른 식당으로 전환하면 결과를 표시한다', (tester) async {
    final date = DateTime(2026, 9, 21);
    await tester.pumpWidget(
      _subject(
        const CafeteriaMenuContent(useAdaptiveGrid: true),
        menuState: _menuState(
          selectedCafeteriaName: '교직원 식당',
          menus: [
            DailyMenu(
              date: date,
              weekday: '월',
              cafeterias: const [
                CafeteriaMenu(
                  name: '제2기숙사',
                  priceInfo: '학생 4,000원',
                  meals: [
                    MealMenu(
                      type: MealType.lunch,
                      time: '11:30',
                      items: ['백미밥'],
                    ),
                  ],
                ),
                CafeteriaMenu(name: '교직원 식당', priceInfo: '', meals: []),
              ],
            ),
          ],
        ),
        height: 320,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('선택한 식당의 메뉴가 없어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-compact-state')), findsOneWidget);
    _expectVisibleInStage(tester, '새로고침');

    await tester.tap(find.text('기숙사 식당'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('menu-compact-state')), findsNothing);
    expect(find.text('백미밥'), findsOneWidget);
    expect(
      tester.getRect(find.text('백미밥')).top,
      greaterThan(
        tester.getRect(find.byType(CafeteriaMenuDateSelector)).bottom,
      ),
    );
    expect(find.text('09월 21일'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('119px 열람실 상세 영역에서 큰 글자와 결과 동작에 스크롤로 접근한다', (tester) async {
    await tester.pumpWidget(
      _subject(
        const SeatStatusContent(useGrid: true),
        seatState: SeatState(),
        width: 320,
        height: 119,
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('표시할 좌석 정보가 없어요'), findsOneWidget);
    await tester.ensureVisible(find.text('새로고침'));
    await tester.pumpAndSettle();
    _expectVisibleInStage(tester, '새로고침');
    expect(tester.takeException(), isNull);
  });

  testWidgets('119px 학식 상세 영역에서 큰 글자와 두 선택기·재시도에 접근한다', (tester) async {
    final date = DateTime(2026, 9, 21);
    await tester.pumpWidget(
      _subject(
        const CafeteriaMenuContent(useAdaptiveGrid: true),
        menuState: _menuState(
          menus: [
            DailyMenu(
              date: date,
              weekday: '월',
              cafeterias: const [
                CafeteriaMenu(name: '제2기숙사', priceInfo: '', meals: []),
                CafeteriaMenu(name: '교직원 식당', priceInfo: '', meals: []),
              ],
            ),
          ],
        ),
        width: 320,
        height: 119,
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('등록된 메뉴가 없어요'), findsOneWidget);
    await tester.ensureVisible(find.text('교직원 식당'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('교직원 식당'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('새로고침'));
    await tester.pumpAndSettle();
    _expectVisibleInStage(tester, '새로고침');
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 보통 높이의 열람실 빈 상태는 선택기 바로 아래에 안내를 묶는다', (tester) async {
    await tester.pumpWidget(
      _subject(
        const SeatStatusContent(useGrid: true),
        seatState: SeatState(),
        width: 390,
        height: 430,
      ),
    );
    await tester.pumpAndSettle();

    final selector = tester.getRect(find.byType(SeatLocationSelector));
    final status = tester.getRect(find.text('표시할 좌석 정보가 없어요'));
    expect(status.top - selector.bottom, lessThan(52));
    _expectTopAlignedGroup(tester, 'seat-compact-state');
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 보통 높이의 학식 빈 상태는 식당 선택과 안내를 함께 배치한다', (tester) async {
    final date = DateTime(2026, 9, 21);
    await tester.pumpWidget(
      _subject(
        const CafeteriaMenuContent(useAdaptiveGrid: true),
        menuState: _menuState(
          menus: [
            DailyMenu(
              date: date,
              weekday: '월',
              cafeterias: const [
                CafeteriaMenu(name: '제2기숙사', priceInfo: '', meals: []),
                CafeteriaMenu(name: '교직원 식당', priceInfo: '', meals: []),
              ],
            ),
          ],
        ),
        width: 390,
        height: 430,
      ),
    );
    await tester.pumpAndSettle();

    final selector = tester.getRect(find.byType(CafeteriaSelector));
    final status = tester.getRect(find.text('등록된 메뉴가 없어요'));
    expect(status.top - selector.bottom, lessThan(52));
    _expectTopAlignedGroup(tester, 'menu-compact-state');
    expect(tester.takeException(), isNull);
  });
}

Widget _subject(
  Widget child, {
  SeatState? seatState,
  CafeteriaMenuState? menuState,
  double width = 900,
  double height = 520,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      if (seatState != null)
        seatControllerProvider.overrideWith(() => _SeatFixture(seatState)),
      if (menuState != null)
        cafeteriaMenuControllerProvider.overrideWith(
          () => _MenuFixture(menuState),
        ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          key: const ValueKey('detail-stage'),
          width: width,
          height: height,
          child: child,
        ),
      ),
    ),
  );
}

void _expectVisibleInStage(WidgetTester tester, String label) {
  final stage = tester.getRect(find.byKey(const ValueKey('detail-stage')));
  final action = tester.getRect(find.text(label));
  expect(action.top, greaterThanOrEqualTo(stage.top));
  expect(action.bottom, lessThanOrEqualTo(stage.bottom));
}

void _expectTopAlignedGroup(WidgetTester tester, String key) {
  final stage = tester.getRect(find.byKey(const ValueKey('detail-stage')));
  final group = tester.getRect(find.byKey(ValueKey(key)));
  expect(group.top, closeTo(stage.top, 1));
}

SeatStatus _seatStatus() {
  return SeatStatus(
    location: SeatLocation.tBuilding,
    updatedAt: DateTime(2026, 9, 21, 13),
    seats: const [
      Seat(
        name: '계',
        totalSeats: 200,
        usedSeats: 100,
        availableSeats: 100,
        usageRate: 50,
      ),
      Seat(
        name: '제1열람실',
        totalSeats: 200,
        usedSeats: 100,
        availableSeats: 100,
        usageRate: 50,
      ),
    ],
  );
}

CafeteriaMenuState _menuState({
  List<DailyMenu> menus = const [],
  String? selectedCafeteriaName,
}) {
  final date = DateTime(2026, 9, 21);
  return CafeteriaMenuState(
    baseDate: date,
    selectedDate: date,
    dates: MenuDateRange.displayWeekdaysFor(date),
    menus: menus,
    selectedCafeteriaName: selectedCafeteriaName,
  );
}

class _SeatFixture extends SeatController {
  _SeatFixture(this.initial);

  final SeatState initial;

  @override
  SeatState build() => initial;

  @override
  Future<void> refresh() async {}

  @override
  void selectLocation(SeatLocation location) {
    state = state.copyWith(selectedLocation: location);
  }
}

class _MenuFixture extends CafeteriaMenuController {
  _MenuFixture(this.initial);

  final CafeteriaMenuState initial;

  @override
  CafeteriaMenuState build() => initial;

  @override
  Future<void> refresh() async {}

  @override
  void selectCafeteria(String name) {
    state = state.copyWith(selectedCafeteriaName: name);
  }
}
