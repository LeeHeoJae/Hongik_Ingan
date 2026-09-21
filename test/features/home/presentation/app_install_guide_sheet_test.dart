import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';
import 'package:hongik_ingan/features/app_install/presentation/app_install_guide_sheet.dart';

void main() {
  Widget buildSubject(AppInstallTarget target) {
    return MaterialApp(
      home: Scaffold(
        body: AppInstallGuideContent(
          target: target,
          onBack: () {},
          onDismiss: () {},
        ),
      ),
    );
  }

  testWidgets('iPhone 설치 단계를 순서대로 표시한다', (tester) async {
    await tester.pumpWidget(buildSubject(AppInstallTarget.iosManual));

    expect(find.text('iPhone 및 iPad'), findsOneWidget);
    expect(find.textContaining('현재 브라우저의 공유 메뉴'), findsOneWidget);
    expect(find.textContaining('현재 브라우저에서 홍익인간 웹사이트'), findsNothing);
    expect(find.textContaining('공유 버튼'), findsOneWidget);
    expect(find.textContaining('홈 화면에 추가'), findsNWidgets(2));
    expect(find.textContaining('웹 앱으로 열기'), findsNWidgets(2));
    expect(find.text('이전'), findsOneWidget);
  });

  testWidgets('Mac Safari 설치 조건과 Dock 추가 단계를 표시한다', (tester) async {
    await tester.pumpWidget(buildSubject(AppInstallTarget.macSafariManual));

    expect(find.text('Mac용 Safari'), findsOneWidget);
    expect(find.textContaining('macOS Sonoma 14 이상'), findsOneWidget);
    expect(find.textContaining('Dock에 추가'), findsOneWidget);
    expect(find.textContaining('Safari에서 홍익인간 웹사이트'), findsNothing);
    expect(find.textContaining('로그인이 다시 필요'), findsOneWidget);
  });

  testWidgets('브라우저 수동 설치 안내는 현재 페이지에서 바로 메뉴를 열도록 안내한다', (tester) async {
    await tester.pumpWidget(buildSubject(AppInstallTarget.browserManual));

    expect(find.text('브라우저 메뉴를 열어 주세요.'), findsOneWidget);
    expect(find.textContaining('홍익인간 웹사이트를 연 상태'), findsNothing);
    expect(find.textContaining('메뉴 이름과 설치 방식'), findsOneWidget);
  });

  testWidgets('지원하지 않는 브라우저에는 대체 브라우저를 안내한다', (tester) async {
    await tester.pumpWidget(buildSubject(AppInstallTarget.unsupportedBrowser));

    expect(find.text('지원 브라우저 안내'), findsOneWidget);
    expect(find.textContaining('Chrome, Edge 또는 Safari'), findsOneWidget);
  });
}
