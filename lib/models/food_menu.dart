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

MealType? mealTypeFromText(String text) {
  if (text.contains('아침') || text.contains('조식')) {
    return MealType.breakfast;
  }
  if (text.contains('점심') || text.contains('중식')) {
    return MealType.lunch;
  }
  if (text.contains('저녁') || text.contains('석식')) {
    return MealType.dinner;
  }
  return null;
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
}

enum FoodMenuDayStatus { loaded, noMenu, parseFailed, networkError }

@immutable
class DailyFoodMenu {
  const DailyFoodMenu({
    required this.date,
    required this.weekday,
    required this.cafeterias,
    this.status = FoodMenuDayStatus.loaded,
    this.message,
  });

  final DateTime date;
  final String weekday;
  final List<CafeteriaMenu> cafeterias;
  final FoodMenuDayStatus status;
  final String? message;

  bool get hasMenu {
    return cafeterias.any((cafeteria) => cafeteria.hasMenu);
  }

  bool get isWeekend {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  DailyFoodMenu asNoMenu() {
    return DailyFoodMenu(
      date: date,
      weekday: weekday,
      cafeterias: cafeterias,
      status: FoodMenuDayStatus.noMenu,
      message: message,
    );
  }

  factory DailyFoodMenu.failure({
    required DateTime date,
    required FoodMenuDayStatus status,
    required String message,
  }) {
    return DailyFoodMenu(
      date: FoodMenuDateRange.dateOnly(date),
      weekday: FoodMenuDateRange.weekdayLabel(date),
      cafeterias: const [],
      status: status,
      message: message,
    );
  }
}

final class FoodMenuDateRange {
  const FoodMenuDateRange._();

  static List<DateTime> around(DateTime baseDate) {
    final today = dateOnly(baseDate);
    return List.generate(5, (index) {
      return today.add(Duration(days: index - 2));
    }, growable: false);
  }

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
