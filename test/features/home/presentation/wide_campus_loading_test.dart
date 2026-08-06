import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/wide_campus_info_card.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/wide_menu_preview.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/wide_seat_preview.dart';
import 'package:hongik_ingan/features/menu/application/menu_controller.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';

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
    final menuState = MenuState(
      baseDate: today,
      selectedDate: today,
      dates: [today],
    );

    await tester.pumpWidget(frame(WideMenuPreview(state: menuState)));
    expect(find.byType(WidePreviewLoading), findsOneWidget);
    expect(find.text('메뉴 정보가 없습니다'), findsNothing);

    await tester.pumpWidget(
      frame(
        WideSeatPreview(
          state: SeatState(),
          onLocationSelected: (_) {},
          compact: true,
        ),
      ),
    );
    expect(find.byType(WidePreviewLoading), findsOneWidget);
    expect(find.text('좌석 정보가 없습니다'), findsNothing);
  });
}
