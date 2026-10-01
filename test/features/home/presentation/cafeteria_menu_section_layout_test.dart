import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_section.dart';

void main() {
  for (final width in [390.0, 900.0]) {
    testWidgets('같은 표시 영역에서 식단을 충분히 노출한다 $width', (tester) async {
      tester.view.physicalSize = Size(width, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final meals = [
        for (var index = 0; index < 4; index++)
          MealMenu(
            type: [
              MealType.breakfast,
              MealType.lunch,
              MealType.lunch,
              MealType.dinner,
            ][index],
            time: '11:30~14:00',
            items: [
              for (final item in ['백미밥', '된장국', '제육볶음', '계란말이', '배추김치', '요구르트'])
                '$index $item',
            ],
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CafeteriaMenuSection(
                  cafeteria: CafeteriaMenu(
                    name: '기숙사 식당',
                    priceInfo: '학생 4,000원',
                    meals: meals,
                  ),
                  compact: true,
                  useAdaptiveGrid: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final visibleItems = meals.expand((meal) => meal.items).where((item) {
        final rect = tester.getRect(find.text(item));
        return rect.top >= 0 && rect.bottom <= 480;
      }).length;
      final visibleMeals = ['조식', '중식 · 택1', '석식'].where((title) {
        final rect = tester.getRect(find.text(title));
        return rect.top >= 0 && rect.bottom <= 480;
      }).length;
      // The previous single-column layout exposed 12 and 18 foods respectively.
      expect(visibleItems, greaterThanOrEqualTo(width == 390 ? 20 : 24));
      expect(visibleMeals, 3);
      expect(tester.takeException(), isNull);
    });
  }

  const cafeteria = CafeteriaMenu(
    name: '기숙사 식당',
    priceInfo: '',
    meals: [
      MealMenu(
        type: MealType.breakfast,
        time: '08:00~09:00',
        items: ['조식 밥', '조식 국', '조식 반찬', '조식 과일'],
      ),
      MealMenu(
        type: MealType.lunch,
        time: '11:30~14:00',
        items: ['첫 식단 밥', '첫 식단 국', '첫 식단 반찬', '첫 식단 과일'],
      ),
      MealMenu(
        type: MealType.lunch,
        time: '11:30~14:00',
        items: ['둘째 식단 밥', '둘째 식단 국', '둘째 식단 반찬', '둘째 식단 과일'],
      ),
    ],
  );

  testWidgets('넓은 메뉴에서 식단을 구분하고 음식은 두 열로 읽는다', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: CafeteriaMenuSection(
                  cafeteria: cafeteria,
                  compact: true,
                  useAdaptiveGrid: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('택1'), findsOneWidget);
    expect(find.text('A메뉴'), findsNothing);
    expect(find.text('B메뉴'), findsNothing);
    expect(
      tester.getRect(find.text('조식 국')).top,
      tester.getRect(find.text('조식 밥')).top,
    );
    expect(
      tester.getRect(find.text('첫 식단 국')).top,
      tester.getRect(find.text('첫 식단 밥')).top,
    );
    expect(
      tester.getRect(find.text('첫 식단 밥')).top,
      tester.getRect(find.text('둘째 식단 밥')).top,
    );
    expect(
      tester.getRect(find.text('둘째 식단 밥')).left,
      greaterThan(tester.getRect(find.text('첫 식단 밥')).left),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('넓은 화면에서는 끼니를 나란히 비교한다', (tester) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [700.0, 1040.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const CafeteriaMenuSection(
                  cafeteria: CafeteriaMenu(
                    name: '기숙사 식당',
                    priceInfo: '',
                    meals: [
                      MealMenu(
                        type: MealType.breakfast,
                        time: '',
                        items: ['아침'],
                      ),
                      MealMenu(type: MealType.lunch, time: '', items: ['점심']),
                      MealMenu(type: MealType.dinner, time: '', items: ['저녁']),
                    ],
                  ),
                  compact: true,
                  useAdaptiveGrid: true,
                ),
              ),
            ),
          ),
        ),
      );
      final breakfast = tester.getRect(find.text('조식'));
      final lunch = tester.getRect(find.text('중식'));
      final dinner = tester.getRect(find.text('석식'));
      expect(lunch.top, breakfast.top);
      expect(lunch.left, greaterThan(breakfast.right));
      if (width > 1000) {
        expect(dinner.top, breakfast.top);
        expect(dinner.left, greaterThan(lunch.right));
      } else {
        expect(dinner.top, greaterThan(breakfast.bottom));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('긴 음식명은 보통 글자에서도 전체 폭을 사용한다', (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longItem = '매콤한 돼지고기와 각종 제철 채소를 듬뿍 곁들인 특별 덮밥';
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: CafeteriaMenuSection(
              cafeteria: CafeteriaMenu(
                name: '기숙사 식당',
                priceInfo: '',
                meals: [
                  MealMenu(
                    type: MealType.lunch,
                    time: '',
                    items: [longItem, '밥', '국'],
                  ),
                ],
              ),
              compact: true,
              useAdaptiveGrid: true,
            ),
          ),
        ),
      ),
    );
    final longMenu = tester.getRect(find.text(longItem));
    final rice = tester.getRect(find.text('밥'));
    final soup = tester.getRect(find.text('국'));
    expect(longMenu.width, greaterThan(rice.width * 1.9));
    expect(rice.top, greaterThan(longMenu.bottom));
    expect(soup.top, rice.top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('큰 글자와 긴 메뉴도 가격 조건과 식단 순서를 보존한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longItem = '매콤한 돼지고기와 각종 채소를 곁들인 덮밥';
    const price = '학생 4,000원 / 교직원 5,000원';
    const menu = CafeteriaMenu(
      name: '기숙사 식당',
      priceInfo: price,
      meals: [
        MealMenu(type: MealType.dinner, time: '', items: ['저녁 메뉴']),
        MealMenu(
          type: MealType.breakfast,
          time: '08:00~09:00',
          items: ['아침 메뉴'],
        ),
        MealMenu(
          type: MealType.lunch,
          time: '11:30~13:00',
          items: [longItem, '국'],
        ),
        MealMenu(type: MealType.lunch, time: '12:00~14:00', items: ['두 번째 점심']),
      ],
    );
    for (final theme in [themeData, darkThemeData]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CafeteriaMenuSection(
                  cafeteria: menu,
                  compact: true,
                  useAdaptiveGrid: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(price), findsOneWidget);
      expect(find.text('11:30~13:00'), findsOneWidget);
      expect(find.text('12:00~14:00'), findsOneWidget);
      expect(find.text('운영 시간 미제공'), findsOneWidget);
      expect(find.textContaining('17:30'), findsNothing);
      expect(
        tester.getRect(find.text('국')).top,
        greaterThan(tester.getRect(find.text(longItem)).bottom),
      );
      expect(
        tester.getRect(find.text('두 번째 점심')).top,
        greaterThan(tester.getRect(find.text('국')).bottom),
      );
      expect(
        tester.getRect(find.text('아침 메뉴')).top,
        lessThan(tester.getRect(find.text(longItem)).top),
      );
      await tester.ensureVisible(find.text('저녁 메뉴'));
      expect(tester.getRect(find.text('저녁 메뉴')).bottom, lessThanOrEqualTo(640));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('좁은 메뉴에서 두 중식 식단이 겹치지 않고 모두 표시된다', (tester) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CafeteriaMenuSection(
              cafeteria: cafeteria,
              compact: true,
              useAdaptiveGrid: true,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('둘째 식단 과일'));
    expect(
      tester.getRect(find.text('둘째 식단 밥')).top,
      greaterThan(tester.getRect(find.text('첫 식단 밥')).top),
    );
    expect(tester.takeException(), isNull);
  });
}
