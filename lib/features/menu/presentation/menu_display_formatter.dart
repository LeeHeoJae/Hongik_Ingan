import 'package:hongik_ingan/features/menu/domain/menu.dart';

final class MenuDisplayFormatter {
  const MenuDisplayFormatter._();

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

  static String compactPriceInfo(String priceInfo) {
    final studentPrice = RegExp(r'학생\s*([\d,]+원)').firstMatch(priceInfo);
    if (studentPrice != null) {
      return '학생 ${studentPrice.group(1)!}';
    }
    final price = RegExp(r'([\d,]+원)').firstMatch(priceInfo);
    if (price != null) {
      return price.group(1)!;
    }
    return priceInfo;
  }

  static String mealTitle(MealType type, String? time) {
    final fallbackTime = switch (type) {
      MealType.breakfast => '8:00~9:00',
      MealType.lunch => '11:30~14:00',
      MealType.dinner => '17:30~18:50',
    };
    final value = time == null || time.isEmpty ? fallbackTime : time;
    return '${type.label} ($value)';
  }
}
