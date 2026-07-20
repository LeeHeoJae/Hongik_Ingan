import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/color.dart';
import 'package:hongik_ingan/features/campus/presentation/campus_sheet_scaffold.dart';

void main() {
  testWidgets('오류 상태는 오류 색상과 해결 행동을 명확히 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampusStateMessage(
            icon: Icons.wifi_off_rounded,
            title: '정보를 불러오지 못했습니다',
            message: '네트워크 연결을 확인해주세요.',
            tone: CampusStateTone.error,
            actionLabel: '다시 시도',
            onAction: () {},
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off_rounded));
    final buttonSize = tester.getSize(find.byType(OutlinedButton));
    expect(icon.color, HongikPalette.light.brandRed);
    expect(buttonSize.height, greaterThanOrEqualTo(48));
    final semanticsLabels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties.label);
    expect(semanticsLabels, contains('정보를 불러오지 못했습니다. 네트워크 연결을 확인해주세요.'));
  });

  testWidgets('큰 글자와 낮은 높이에서도 상태 메시지를 스크롤할 수 있다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: SizedBox(
              width: 280,
              height: 180,
              child: CampusStateMessage(
                icon: Icons.no_food_rounded,
                title: '운영하지 않는 날입니다',
                message: '선택한 날짜에는 식당을 운영하지 않습니다.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('로딩 스켈레톤은 스크린리더에 로딩 상태를 알린다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 360, child: CampusLoadingSkeleton()),
        ),
      ),
    );

    expect(find.bySemanticsLabel('정보를 불러오는 중입니다'), findsOneWidget);
  });
}
