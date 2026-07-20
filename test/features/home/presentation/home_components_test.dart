import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/dashboard.dart';

void main() {
  Widget buildSubject({
    required double width,
    VoidCallback? onMenuTap,
    VoidCallback? onSeatTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: CampusQuickActions(
              compact: true,
              onMenuTap: onMenuTap ?? () {},
              onSeatTap: onSeatTap ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('컴팩트 캠퍼스 바로가기는 충분한 너비에서 2열로 표시된다', (tester) async {
    await tester.pumpWidget(buildSubject(width: 320));

    final menuTop = tester.getTopLeft(find.text('주간 식당 메뉴')).dy;
    final seatTop = tester.getTopLeft(find.text('열람실 좌석 현황')).dy;
    expect((menuTop - seatTop).abs(), lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('컴팩트 캠퍼스 바로가기는 좁은 너비에서 세로로 전환된다', (tester) async {
    var seatTapCount = 0;
    await tester.pumpWidget(
      buildSubject(width: 280, onSeatTap: () => seatTapCount++),
    );

    final menuTop = tester.getTopLeft(find.text('주간 식당 메뉴')).dy;
    final seatTop = tester.getTopLeft(find.text('열람실 좌석 현황')).dy;
    expect(seatTop, greaterThan(menuTop));

    await tester.tap(find.text('열람실 좌석 현황'));
    await tester.pump();
    expect(seatTapCount, 1);
  });
}
