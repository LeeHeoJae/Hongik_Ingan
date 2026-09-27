import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_section.dart';

void main() {
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

  testWidgets('넓은 메뉴에서 조식과 두 중식 식단을 두 열로 읽을 수 있다', (tester) async {
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
      tester.getRect(find.text('조식 밥')).top,
      tester.getRect(find.text('조식 국')).top,
    );
    expect(
      tester.getRect(find.text('첫 식단 밥')).top,
      tester.getRect(find.text('첫 식단 국')).top,
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
