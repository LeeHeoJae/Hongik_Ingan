import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';
import 'package:hongik_ingan/features/app_install/presentation/app_install_guide_sheet.dart';

void main() {
  Widget buildSubject(AppInstallTarget target) {
    return MaterialApp(
      home: Scaffold(
        body: AppInstallGuideContent(target: target, onDismiss: () {}),
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
    expect(find.textContaining('웹 앱으로 열기'), findsOneWidget);
    expect(find.text('이전'), findsNothing);
    expect(find.bySemanticsLabel('설치 안내 닫기'), findsOneWidget);
  });

  testWidgets('Mac Safari는 버전 안내 없이 Dock 추가 동작을 안내한다', (tester) async {
    await tester.pumpWidget(buildSubject(AppInstallTarget.macSafariManual));

    expect(find.text('Mac용 Safari'), findsOneWidget);
    expect(find.textContaining('macOS Sonoma'), findsNothing);
    expect(find.textContaining('파일 → Dock에 추가'), findsOneWidget);
    expect(find.textContaining('Safari에서 홍익인간 웹사이트'), findsNothing);
    expect(find.textContaining('Dock에 추가 메뉴가 없다면'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('브라우저 수동 설치 안내는 현재 페이지에서 바로 메뉴를 열도록 안내한다', (tester) async {
    await tester.pumpWidget(buildSubject(AppInstallTarget.browserManual));

    expect(find.textContaining('주소창의 설치 아이콘'), findsOneWidget);
    expect(find.textContaining('홍익인간 웹사이트를 연 상태'), findsNothing);
    expect(find.textContaining('페이지를 앱으로 설치'), findsOneWidget);
  });

  testWidgets('Firefox에서는 주소창 버튼 하나를 안내한다', (tester) async {
    await tester.pumpWidget(
      buildSubject(AppInstallTarget.windowsFirefoxManual),
    );

    expect(find.text('Firefox에서 설치'), findsOneWidget);
    expect(find.textContaining('주소창 오른쪽의 웹 앱 버튼'), findsOneWidget);
    expect(find.textContaining('Chrome'), findsNothing);
    expect(find.textContaining('사용할 수 없어요'), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(find.text('이전'), findsNothing);
  });

  testWidgets('Android에서는 현재 브라우저 메뉴로 홈 화면에 추가하도록 안내한다', (tester) async {
    await tester.pumpWidget(buildSubject(AppInstallTarget.androidManual));

    expect(find.text('Android에서 설치'), findsOneWidget);
    expect(find.textContaining('앱 설치 또는 홈 화면에 추가'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('알 수 없는 환경은 메뉴 확인 후 대체 경로를 안내한다', (tester) async {
    await tester.pumpWidget(buildSubject(AppInstallTarget.browserHelp));

    expect(find.text('브라우저 설치 메뉴 확인'), findsOneWidget);
    expect(find.textContaining('있는지 확인해 주세요'), findsOneWidget);
    expect(find.textContaining('설치 메뉴가 없다면'), findsOneWidget);
    expect(find.textContaining('사용할 수 없어요'), findsNothing);
  });
}
