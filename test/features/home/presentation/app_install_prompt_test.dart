import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';
import 'package:hongik_ingan/features/app_install/presentation/app_install_prompt.dart';

void main() {
  Widget buildSubject({
    required AppInstallTarget target,
    VoidCallback? onInstall,
    VoidCallback? onDismiss,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 520,
            child: AppInstallPrompt(
              target: target,
              showGuide: false,
              onInstall: onInstall ?? () {},
              onDismiss: onDismiss ?? () {},
              onShowGuide: () {},
              onBack: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('브라우저 설치가 준비되면 설치 동작을 제공한다', (tester) async {
    var installCount = 0;
    var dismissCount = 0;

    await tester.pumpWidget(
      buildSubject(
        target: AppInstallTarget.nativePrompt,
        onInstall: () => installCount++,
        onDismiss: () => dismissCount++,
      ),
    );

    expect(find.text('홍익인간을 앱으로 설치'), findsOneWidget);
    expect(find.text('기기에서 앱처럼 바로 열 수 있어요.'), findsOneWidget);
    expect(find.text('앱 설치'), findsOneWidget);

    await tester.tap(find.text('앱 설치'));
    await tester.pump();
    await tester.tap(find.text('나중에'));
    await tester.pump();

    expect(installCount, 1);
    expect(dismissCount, 1);
  });

  testWidgets('Apple 환경에는 수동 설치 방법을 안내한다', (tester) async {
    await tester.pumpWidget(buildSubject(target: AppInstallTarget.iosManual));

    expect(find.text('홈 화면에서 바로 열 수 있어요.'), findsOneWidget);
    expect(find.text('설치 방법 보기'), findsOneWidget);

    await tester.pumpWidget(
      buildSubject(target: AppInstallTarget.macSafariManual),
    );
    await tester.pump();

    expect(find.text('Dock에서 바로 열 수 있어요.'), findsOneWidget);
  });

  testWidgets('방법 보기는 같은 팝업 안의 안내 화면으로 전환할 수 있다', (tester) async {
    var showGuide = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppInstallPrompt(
                target: AppInstallTarget.iosManual,
                showGuide: showGuide,
                onInstall: () {},
                onDismiss: () {},
                onShowGuide: () => setState(() => showGuide = true),
                onBack: () => setState(() => showGuide = false),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('설치 방법 보기'));
    await tester.pumpAndSettle();

    expect(find.byType(AppInstallPrompt), findsOneWidget);
    expect(find.text('iPhone 및 iPad'), findsOneWidget);
    expect(find.text('설치 방법 보기'), findsNothing);
  });

  testWidgets('좁은 화면과 큰 글자에서도 설치 버튼이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: buildSubject(target: AppInstallTarget.nativePrompt),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('앱 설치'), findsOneWidget);
    expect(find.text('나중에'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
