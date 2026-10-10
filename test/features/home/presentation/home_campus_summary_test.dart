import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_campus_summary.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_service_workspace.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

HomeServiceSummaryData _menuSummary(CafeteriaMenuState state, DateTime now) =>
    HomeCampusSummary.menu(state.menus, now, isLoading: state.isLoading);

HomeServiceSummaryData _seatSummary(SeatState state) => HomeCampusSummary.seats(
  status: state.statuses[SeatLocation.tBuilding],
  error: state.errors[SeatLocation.tBuilding],
  loading: state.loadingLocations.contains(SeatLocation.tBuilding),
);

void main() {
  final date = DateTime(2026, 10, 1);
  const meals = [
    MealMenu(
      type: MealType.breakfast,
      time: '08:00~09:00',
      items: ['아침밥', '아침국'],
    ),
    MealMenu(
      type: MealType.lunch,
      time: '11:30~14:00',
      items: ['백미밥', '점심국', '주메뉴', '반찬', '김치', '후식'],
    ),
    MealMenu(type: MealType.lunch, time: '11:30~14:00', items: ['다른 중식 메뉴']),
    MealMenu(type: MealType.dinner, time: '17:00~19:00', items: ['저녁밥']),
  ];
  CafeteriaMenuState subject({
    DateTime? menuDate,
    List<MealMenu> source = meals,
  }) {
    final target = menuDate ?? date;
    return CafeteriaMenuState(
      baseDate: date,
      selectedDate: date.add(const Duration(days: 1)),
      dates: MenuDateRange.displayWeekdaysFor(date),
      selectedCafeteriaName: '교직원 식당',
      menus: [
        DailyMenu(
          date: target,
          weekday: MenuDateRange.weekdayLabel(target),
          cafeterias: [
            const CafeteriaMenu(
              name: '교직원 식당',
              priceInfo: '',
              meals: [
                MealMenu(
                  type: MealType.lunch,
                  time: '11:30~14:00',
                  items: ['교직원 메뉴'],
                ),
              ],
            ),
            CafeteriaMenu(name: '제2기숙사', priceInfo: '', meals: source),
          ],
        ),
      ],
    );
  }

  for (final entry in [
    (hour: 7, minute: 0, label: '조식'),
    (hour: 8, minute: 59, label: '조식'),
    (hour: 9, minute: 0, label: '중식'),
    (hour: 13, minute: 59, label: '중식'),
    (hour: 14, minute: 0, label: '석식'),
    (hour: 18, minute: 59, label: '석식'),
  ]) {
    test('${entry.hour}:${entry.minute}에는 ${entry.label}을 표시한다', () {
      final summary = _menuSummary(
        subject(),
        DateTime(2026, 10, 1, entry.hour, entry.minute),
      );
      expect(summary.eyebrow, entry.label);
      expect(summary.status, isNot(contains('교직원')));
      expect(summary.status, isNot(contains('~')));
      expect(summary.facts, isEmpty);
    });
  }

  test('중식 선택지마다 일부 메뉴를 요약하고 상세 식단과 선택을 보존한다', () {
    final state = subject();
    final summary = _menuSummary(state, DateTime(2026, 10, 1, 12));
    expect(summary.status, 'A안 · 점심국 · 주메뉴 · 반찬 · 외 1개\nB안 · 다른 중식 메뉴');
    expect(state.menus.single.cafeterias.last.meals, meals);
    expect(state.selectedCafeteriaName, '교직원 식당');
    expect(state.selectedDate, DateTime(2026, 10, 2));
  });

  test('중식 두 안에서 밥과 김치만 제외하고 국을 포함한 앞 3개를 표시한다', () {
    final state = subject(
      source: const [
        MealMenu(
          type: MealType.lunch,
          time: '11:30~14:00',
          items: [
            '백미밥',
            '오징어무국',
            '불맛제육볶음',
            '치킨너겟&머스타드s',
            '상추&쌈장',
            '배추김치',
            '후식',
          ],
        ),
        MealMenu(
          type: MealType.lunch,
          time: '11:30~14:00',
          items: ['잡곡밥', '옥수수스프', '연어치즈까스&타르s', '로제떡볶이', '깍두기'],
        ),
      ],
    );
    expect(
      _menuSummary(state, DateTime(2026, 10, 1, 12)).status,
      'A안 · 오징어무국 · 불맛제육볶음 · 치킨너겟&머스타드s · 외 2개\n'
      'B안 · 옥수수스프 · 연어치즈까스&타르s · 로제떡볶이',
    );
  });

  test('조식·석식은 앞 3개만 표시하고 단일 중식은 기존 요약을 유지한다', () {
    for (final entry in [
      (type: MealType.breakfast, hour: 8),
      (type: MealType.lunch, hour: 12),
      (type: MealType.dinner, hour: 18),
    ]) {
      final state = subject(
        source: [
          MealMenu(
            type: entry.type,
            time: '',
            items: const [' 백미 밥 ', '유부된장국', '주요리', '반찬', '총각김치', '후식'],
          ),
        ],
      );
      expect(
        _menuSummary(state, DateTime(2026, 10, 1, entry.hour)).status,
        entry.type == MealType.lunch
            ? '유부된장국 · 주요리 · 반찬 · 후식'
            : '유부된장국 · 주요리 · 반찬 · 외 1개',
      );
    }
  });

  test('조식·석식의 제외 후 메뉴가 3개 이하면 생략 표시 없이 전부 보여준다', () {
    for (final entry in [
      (type: MealType.breakfast, hour: 8),
      (type: MealType.dinner, hour: 18),
    ]) {
      const items = ['잡곡밥', '김치찌개', '계란말이', '김', '배추김치'];
      final state = subject(
        source: [MealMenu(type: entry.type, time: '', items: items)],
      );
      final summary = _menuSummary(state, DateTime(2026, 10, 1, entry.hour));
      expect(summary.status, '김치찌개 · 계란말이 · 김');
      expect(state.menus.single.cafeterias.last.meals.single.items, items);
    }
  });

  test('밥과 김치가 들어간 요리는 제외하지 않는다', () {
    final state = subject(
      source: const [
        MealMenu(
          type: MealType.lunch,
          time: '',
          items: ['김치볶음밥', '제육덮밥', '김치찌개', '김치전', '배추김치'],
        ),
      ],
    );
    expect(
      _menuSummary(state, DateTime(2026, 10, 1, 12)).status,
      '김치볶음밥 · 제육덮밥 · 김치찌개 · 김치전',
    );
  });

  test('밥·김치만 있는 선택지도 빈 문자열로 숨기지 않는다', () {
    final state = subject(
      source: const [
        MealMenu(type: MealType.lunch, time: '', items: ['백미밥', '포기김치']),
        MealMenu(type: MealType.lunch, time: '', items: ['돈까스']),
      ],
    );
    expect(
      _menuSummary(state, DateTime(2026, 10, 1, 12)).status,
      'A안 · 밥·김치만 등록되어 있어요\nB안 · 돈까스',
    );
  });

  test('석식 종료 시 오늘 식사 종료를 표시한다', () {
    final summary = _menuSummary(subject(), DateTime(2026, 10, 1, 19));
    expect(summary.status, '오늘 식사 종료');
  });

  test('주말 보조 메뉴는 다음 주 식단이 있어도 오늘 메뉴가 없다고 표시한다', () {
    final state = subject(menuDate: DateTime(2026, 10, 5));
    for (final day in [3, 4]) {
      final summary = _menuSummary(state, DateTime(2026, 10, day, 23));
      expect(summary.eyebrow, isNull);
      expect(summary.status, '오늘은 등록된 메뉴가 없어요');
    }
  });

  test('주말 보조 메뉴에 이번 주 식단을 대신 표시하지 않는다', () {
    final summary = _menuSummary(subject(), DateTime(2026, 10, 3));
    expect(summary.eyebrow, isNull);
    expect(summary.status, '오늘은 등록된 메뉴가 없어요');
  });

  test('미조회와 조회 중, 조회된 빈 메뉴를 구분한다', () {
    final state = subject().copyWith(menus: []);
    final now = DateTime(2026, 10, 1, 12);
    expect(_menuSummary(state, now).status, '메뉴 조회 전');
    expect(
      _menuSummary(state.copyWith(isLoading: true), now).status,
      '메뉴 확인 중',
    );
    expect(
      _menuSummary(
        state.copyWith(menus: [DailyMenu.noMenu(date: date)]),
        now,
      ).status,
      '등록된 메뉴가 없어요',
    );
    final monday = DateTime(2026, 10, 5);
    final weekend = _menuSummary(
      state.copyWith(menus: [DailyMenu.noMenu(date: monday)]),
      DateTime(2026, 10, 3),
    );
    expect(weekend.eyebrow, isNull);
    expect(weekend.status, '오늘은 등록된 메뉴가 없어요');
  });

  test('시간이 비어 있거나 불완전하면 기존 앱의 기본 제공 시간을 사용한다', () {
    final state = subject(
      source: const [
        MealMenu(type: MealType.lunch, time: '11:30', items: ['점심밥']),
        MealMenu(type: MealType.dinner, time: '', items: ['저녁밥']),
      ],
    );
    expect(_menuSummary(state, DateTime(2026, 10, 1, 13)).eyebrow, '중식');
    expect(_menuSummary(state, DateTime(2026, 10, 1, 14)).eyebrow, '석식');
    expect(
      _menuSummary(state, DateTime(2026, 10, 1, 18, 50)).status,
      '오늘 식사 종료',
    );
  });

  test('오늘의 조회 실패와 휴무를 구분한다', () {
    for (final day in [
      DailyMenu.failure(
        date: date,
        status: MenuDayStatus.networkError,
        message: '조회 실패',
      ),
      DailyMenu(
        date: date,
        weekday: '목',
        cafeterias: const [],
        status: MenuDayStatus.noMenu,
        message: '공휴일에는 식당을 운영하지 않아요.',
      ),
    ]) {
      final state = subject().copyWith(menus: [day]);
      final summary = _menuSummary(state, DateTime(2026, 10, 1, 12));
      expect(
        summary.status,
        day.status == MenuDayStatus.noMenu ? day.message : '메뉴 조회 실패',
      );
    }
  });

  Seat room(String name, int available) => Seat(
    name: name,
    totalSeats: 50,
    usedSeats: 50 - available,
    availableSeats: available,
    usageRate: 0,
  );
  SeatState seats({Map<SeatLocation, String> errors = const {}}) => SeatState(
    selectedLocation: SeatLocation.rBuilding,
    errors: errors,
    statuses: {
      SeatLocation.tBuilding: SeatStatus(
        location: SeatLocation.tBuilding,
        updatedAt: date,
        seats: [
          room('계', 45),
          room('일반열람실', 10),
          room('3층 노트북열람실1', 15),
          room('4층 노트북열람실2', 20),
        ],
      ),
      SeatLocation.rBuilding: SeatStatus(
        location: SeatLocation.rBuilding,
        updatedAt: date,
        seats: [room('계', 50)],
      ),
    },
  );

  test('다른 건물을 선택해도 T동 노트북 좌석만 합산한다', () {
    final state = seats();
    final summary = _seatSummary(state);
    expect(summary.eyebrow, 'T동 노트북 열람실');
    expect(summary.status, '35석 남음');
    expect(summary.facts.map((fact) => fact.value), ['15석', '20석']);
    expect(state.selectedLocation, SeatLocation.rBuilding);
  });

  test('T동 갱신 실패는 이전 수치임을 표시하고 다른 건물 오류는 무시한다', () {
    expect(
      _seatSummary(
        seats(errors: const {SeatLocation.tBuilding: '연결 실패'}),
      ).warning,
      '갱신 실패 · 이전 정보',
    );
    expect(
      _seatSummary(
        seats(errors: const {SeatLocation.rBuilding: '연결 실패'}),
      ).warning,
      isNull,
    );
  });

  test('노트북 세부 정보가 없으면 전체 좌석을 대신 표시하지 않는다', () {
    final state = SeatState(
      statuses: {
        SeatLocation.tBuilding: SeatStatus(
          location: SeatLocation.tBuilding,
          updatedAt: date,
          seats: [room('계', 50)],
        ),
      },
    );
    expect(_seatSummary(state).status, '노트북 좌석 정보 없음');
    expect(_seatSummary(SeatState()).status, '좌석 조회 전');
    expect(
      _seatSummary(
        SeatState(loadingLocations: const {SeatLocation.tBuilding}),
      ).status,
      '좌석 확인 중',
    );
  });
}
