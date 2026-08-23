import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/cafeteria_menu/application/cafeteria_menu_controller.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/cafeteria_menu_preview.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/campus_preview_state.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/seat_status_preview.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

void main() {
  Widget frame(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 480, height: 320, child: child)),
      ),
    );
  }

  testWidgets('식당과 열람실은 첫 요청 전부터 고정 skeleton을 표시한다', (tester) async {
    final today = DateTime(2026, 7, 30);
    final menuState = CafeteriaMenuState(
      baseDate: today,
      selectedDate: today,
      dates: [today],
    );

    await tester.pumpWidget(frame(CafeteriaMenuPreview(state: menuState)));
    expect(find.byType(CampusPreviewLoadingSkeleton), findsOneWidget);
    expect(find.text('메뉴 정보가 없습니다'), findsNothing);

    await tester.pumpWidget(
      frame(
        SeatStatusPreview(
          state: SeatState(),
          onLocationSelected: (_) {},
          compact: true,
        ),
      ),
    );
    expect(find.byType(CampusPreviewLoadingSkeleton), findsOneWidget);
    expect(find.text('좌석 정보가 없습니다'), findsNothing);
  });

  testWidgets('좌석 갱신 실패 시 이전 정보와 경고를 함께 표시한다', (tester) async {
    final status = SeatStatus(
      location: SeatLocation.tBuilding,
      seats: const [
        Seat(
          name: '제1열람실',
          totalSeats: 10,
          usedSeats: 4,
          availableSeats: 6,
          usageRate: 40,
        ),
      ],
      updatedAt: DateTime(2026, 8, 20, 14, 32),
    );
    final state = SeatState(
      statuses: {SeatLocation.tBuilding: status},
      errors: const {SeatLocation.tBuilding: '네트워크 오류'},
    );

    await tester.pumpWidget(
      frame(
        SeatStatusPreview(
          state: state,
          onLocationSelected: (_) {},
          compact: true,
        ),
      ),
    );

    expect(find.text('갱신 실패, 이전 좌석 정보를 표시하고 있어요.'), findsOneWidget);
    expect(find.text('제1열람실'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('주말에는 다음 주 메뉴가 있어도 학식 미리보기에 안내를 표시한다', (tester) async {
    final date = DateTime(2026, 8, 23);
    final nextMonday = DateTime(2026, 8, 24);
    final menuState = CafeteriaMenuState(
      baseDate: DateTime(2026, 8, 23),
      selectedDate: nextMonday,
      dates: [date],
      menus: [
        DailyMenu(
          date: nextMonday,
          weekday: '월',
          cafeterias: const [
            CafeteriaMenu(
              name: '학생 식당',
              priceInfo: '',
              meals: [
                MealMenu(type: MealType.lunch, time: '', items: ['비빔밥']),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(frame(CafeteriaMenuPreview(state: menuState)));

    expect(find.text('오늘은 학식 메뉴가 없어요'), findsOneWidget);
    expect(
      find.text('주말에는 학식 메뉴를 제공하지 않아요.\n전체 보기에서 다음 주 메뉴를 확인할 수 있어요.'),
      findsOneWidget,
    );
    expect(find.text('학생 식당'), findsNothing);
  });
}
