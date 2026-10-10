import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';

final class CafeteriaMenuDisplayFormatter {
  const CafeteriaMenuDisplayFormatter._();

  static List<CafeteriaMenu> orderedCafeterias(List<CafeteriaMenu> source) {
    final cafeterias = [...source];
    cafeterias.sort((a, b) {
      final aScore = a.isDormitory ? 0 : 1;
      final bScore = b.isDormitory ? 0 : 1;
      return aScore.compareTo(bScore);
    });
    return List.unmodifiable(cafeterias);
  }

  static String shortCafeteriaName(String name) {
    if (CafeteriaMenu.isDormitoryName(name)) {
      return '기숙사 식당';
    }
    if (name.contains('교직원')) {
      return '교직원 식당';
    }
    return name;
  }

  static String mealTitle(MealType type, String? time) {
    final schedule = type.defaultServingTime;
    final value = time == null || time.isEmpty
        ? '${_formatMinute(schedule.startMinute)}~${_formatMinute(schedule.endMinute)}'
        : time;
    return '${type.label} ($value)';
  }

  static String _formatMinute(int minute) =>
      '${minute ~/ 60}:${(minute % 60).toString().padLeft(2, '0')}';
}
