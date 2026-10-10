import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/cafeteria_menu_display_formatter.dart';

void main() {
  for (final (type, expected) in [
    (MealType.breakfast, '조식 (8:00~9:00)'),
    (MealType.lunch, '중식 (11:30~14:00)'),
    (MealType.dinner, '석식 (17:30~18:50)'),
  ]) {
    test('missing time preserves the existing title for $type', () {
      expect(CafeteriaMenuDisplayFormatter.mealTitle(type, null), expected);
      expect(CafeteriaMenuDisplayFormatter.mealTitle(type, ''), expected);
    });
  }

  test('a server-provided time is displayed unchanged', () {
    expect(
      CafeteriaMenuDisplayFormatter.mealTitle(MealType.dinner, '17:00~19:00'),
      '석식 (17:00~19:00)',
    );
  });
}
