import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_campus_summary.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

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
      items: ['점심밥', '점심국', '주메뉴', '반찬', '김치', '후식'],
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
      final summary = HomeCampusSummary.menu(
        subject(),
        DateTime(2026, 10, 1, entry.hour, entry.minute),
      );
      expect(summary.eyebrow, entry.label);
      expect(summary.status, isNot(contains('교직원')));
      expect(summary.status, isNot(contains('~')));
      expect(summary.facts, isEmpty);
    });
  }

  test('중식 선택지와 모든 메뉴를 보존하고 상세 선택을 변경하지 않는다', () {
    final state = subject();
    final summary = HomeCampusSummary.menu(state, DateTime(2026, 10, 1, 12));
    expect(summary.status, contains('후식'));
    expect(summary.status, contains('다른 중식 메뉴'));
    expect(state.selectedCafeteriaName, '교직원 식당');
    expect(state.selectedDate, DateTime(2026, 10, 2));
  });

  test('석식 종료 시 오늘 식사 종료를 표시한다', () {
    final summary = HomeCampusSummary.menu(
      subject(),
      DateTime(2026, 10, 1, 19),
    );
    expect(summary.status, '오늘 식사 종료');
  });

  test('주말에는 시간과 관계없이 다음 월요일 첫 식사를 표시한다', () {
    final state = subject(menuDate: DateTime(2026, 10, 5));
    for (final day in [3, 4]) {
      final summary = HomeCampusSummary.menu(
        state,
        DateTime(2026, 10, day, 23),
      );
      expect(summary.eyebrow, '다음 월요일 · 조식');
      expect(summary.status, contains('아침밥'));
    }
  });

  test('주말의 미조회 메뉴를 다른 날 식단으로 대체하지 않는다', () {
    final summary = HomeCampusSummary.menu(subject(), DateTime(2026, 10, 3));
    expect(summary.eyebrow, '다음 월요일');
    expect(summary.status, '메뉴 조회 전');
  });

  test('미조회와 조회 중, 조회된 빈 메뉴를 구분한다', () {
    final state = subject().copyWith(menus: []);
    final now = DateTime(2026, 10, 1, 12);
    expect(HomeCampusSummary.menu(state, now).status, '메뉴 조회 전');
    expect(
      HomeCampusSummary.menu(state.copyWith(isLoading: true), now).status,
      '메뉴 확인 중',
    );
    expect(
      HomeCampusSummary.menu(
        state.copyWith(menus: [DailyMenu.noMenu(date: date)]),
        now,
      ).status,
      '등록된 메뉴가 없어요',
    );
    final monday = DateTime(2026, 10, 5);
    final weekend = HomeCampusSummary.menu(
      state.copyWith(menus: [DailyMenu.noMenu(date: monday)]),
      DateTime(2026, 10, 3),
    );
    expect(weekend.eyebrow, '다음 월요일');
    expect(weekend.status, '등록된 메뉴가 없어요');
  });

  test('시간이 비어 있거나 불완전하면 기존 앱의 기본 제공 시간을 사용한다', () {
    final state = subject(
      source: const [
        MealMenu(type: MealType.lunch, time: '11:30', items: ['점심밥']),
        MealMenu(type: MealType.dinner, time: '', items: ['저녁밥']),
      ],
    );
    expect(
      HomeCampusSummary.menu(state, DateTime(2026, 10, 1, 13)).eyebrow,
      '중식',
    );
    expect(
      HomeCampusSummary.menu(state, DateTime(2026, 10, 1, 14)).eyebrow,
      '석식',
    );
    expect(
      HomeCampusSummary.menu(state, DateTime(2026, 10, 1, 18, 50)).status,
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
      final summary = HomeCampusSummary.menu(state, DateTime(2026, 10, 1, 12));
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
    final summary = HomeCampusSummary.seats(state);
    expect(summary.eyebrow, 'T동 노트북 열람실');
    expect(summary.status, '35석 남음');
    expect(summary.facts.map((fact) => fact.value), ['15석', '20석']);
    expect(state.selectedLocation, SeatLocation.rBuilding);
  });

  test('T동 갱신 실패는 이전 수치임을 표시하고 다른 건물 오류는 무시한다', () {
    expect(
      HomeCampusSummary.seats(
        seats(errors: const {SeatLocation.tBuilding: '연결 실패'}),
      ).warning,
      '갱신 실패 · 이전 정보',
    );
    expect(
      HomeCampusSummary.seats(
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
    expect(HomeCampusSummary.seats(state).status, '노트북 좌석 정보 없음');
    expect(HomeCampusSummary.seats(SeatState()).status, '좌석 조회 전');
    expect(
      HomeCampusSummary.seats(
        SeatState(loadingLocations: const {SeatLocation.tBuilding}),
      ).status,
      '좌석 확인 중',
    );
  });
}
