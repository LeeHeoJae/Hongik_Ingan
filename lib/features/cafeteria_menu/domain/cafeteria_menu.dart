import 'package:flutter/foundation.dart';

enum MealType { breakfast, lunch, dinner }

extension MealTypeLabel on MealType {
  String get label {
    return switch (this) {
      MealType.breakfast => '조식',
      MealType.lunch => '중식',
      MealType.dinner => '석식',
    };
  }
}

@immutable
class MealMenu {
  const MealMenu({required this.type, required this.time, required this.items});

  final MealType type;
  final String time;
  final List<String> items;
}

@immutable
class CafeteriaMenu {
  const CafeteriaMenu({
    required this.name,
    required this.priceInfo,
    required this.meals,
  });

  final String name;
  final String priceInfo;
  final List<MealMenu> meals;

  bool get hasMenu => meals.any((meal) => meal.items.isNotEmpty);

  bool get isDormitory => isDormitoryName(name);

  static bool isDormitoryName(String name) {
    return name.contains('기숙사') || name.contains('학생');
  }
}

enum MenuDayStatus { loaded, noMenu, parseFailed, networkError }

@immutable
class DailyMenu {
  const DailyMenu({
    required this.date,
    required this.weekday,
    required this.cafeterias,
    this.status = MenuDayStatus.loaded,
    this.message,
  });

  final DateTime date;
  final String weekday;
  final List<CafeteriaMenu> cafeterias;
  final MenuDayStatus status;
  final String? message;

  bool get hasMenu {
    return cafeterias.any((cafeteria) => cafeteria.hasMenu);
  }

  bool get isWeekend {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  DailyMenu asNoMenu() {
    return DailyMenu(
      date: date,
      weekday: weekday,
      cafeterias: cafeterias,
      status: MenuDayStatus.noMenu,
      message: message,
    );
  }

  factory DailyMenu.noMenu({required DateTime date}) {
    final normalizedDate = MenuDateRange.dateOnly(date);
    return DailyMenu(
      date: normalizedDate,
      weekday: MenuDateRange.weekdayLabel(normalizedDate),
      cafeterias: const [],
      status: MenuDayStatus.noMenu,
    );
  }

  factory DailyMenu.failure({
    required DateTime date,
    required MenuDayStatus status,
    required String message,
  }) {
    return DailyMenu(
      date: MenuDateRange.dateOnly(date),
      weekday: MenuDateRange.weekdayLabel(date),
      cafeterias: const [],
      status: status,
      message: message,
    );
  }
}

final class MenuDateRange {
  const MenuDateRange._();

  /// 기본으로 선택될 날짜를 결정.
  ///
  /// 주말이면 그 다음 주의 월요일은 반환한다.
  static DateTime initialSelectedDateFor(DateTime baseDate) {
    final base = dateOnly(baseDate);
    if (base.weekday <= DateTime.friday) {
      return base;
    }
    return displayWeekdaysFor(base).first;
  }

  /// [baseDate]에 맞는 월요일~금요일의 [DateTime]들을 반환.
  static List<DateTime> displayWeekdaysFor(DateTime baseDate) {
    final base = dateOnly(baseDate);
    final monday = base.weekday <= DateTime.friday
        ? base.subtract(Duration(days: base.weekday - 1))
        : base.add(Duration(days: 8 - base.weekday));
    return List.generate(
      DateTime.friday,
      (index) => monday.add(Duration(days: index)),
      growable: false,
    );
  }

  /// 시, 분, 초를 제거.
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String weekdayLabel(DateTime date) {
    return switch (date.weekday) {
      DateTime.monday => '월',
      DateTime.tuesday => '화',
      DateTime.wednesday => '수',
      DateTime.thursday => '목',
      DateTime.friday => '금',
      DateTime.saturday => '토',
      DateTime.sunday => '일',
      _ => '',
    };
  }

  static String monthDayLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month월 $day일';
  }
}
