import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/wide_campus_info_card.dart';

void main() {
  Widget frame(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 480, height: 320, child: child)),
      ),
    );
  }

  testWidgets('캠퍼스 카드 부제목은 짧게 교차 전환된다', (tester) async {
    Widget subject(String subtitle) {
      return frame(
        WideCampusInfoCard(
          icon: Icons.restaurant,
          title: '주간 식당 메뉴',
          subtitle: subtitle,
          onOpen: () {},
          child: const SizedBox.expand(),
        ),
      );
    }

    await tester.pumpWidget(subject('메뉴를 준비하는 중'));
    await tester.pumpWidget(subject('기숙사 식당'));
    await tester.pump(const Duration(milliseconds: 90));

    expect(find.text('메뉴를 준비하는 중'), findsOneWidget);
    expect(find.text('기숙사 식당'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('메뉴를 준비하는 중'), findsNothing);
    expect(find.text('기숙사 식당'), findsOneWidget);
  });
}
