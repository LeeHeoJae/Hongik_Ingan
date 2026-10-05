import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/app_info_dialog.dart';

void main() {
  for (final scenario in [
    (size: const Size(390, 844), scale: 1.0, dark: false, inset: 0.0),
    (size: const Size(320, 620), scale: 2.0, dark: true, inset: 0.0),
    (size: const Size(640, 320), scale: 2.0, dark: false, inset: 0.0),
    (size: const Size(320, 620), scale: 2.0, dark: false, inset: 280.0),
    (size: const Size(1440, 900), scale: 1.0, dark: true, inset: 0.0),
  ]) {
    testWidgets('all info actions remain reachable $scenario', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: scenario.inset);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final calls = <String>[];
      await tester.pumpWidget(
        _subject(
          scale: scenario.scale,
          dark: scenario.dark,
          dialog: AppInfoDialog(
            version: '1.4.0',
            installDescription: '홈 화면에 추가하는 방법을 확인해요.',
            onInstall: () => calls.add('install'),
            onOpenSource: () => calls.add('source'),
            onShareLogs: () => calls.add('logs'),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('홍익인간'), findsOneWidget);
      expect(find.text('v1.4.0'), findsOneWidget);
      final close = find.widgetWithText(TextButton, '닫기');
      final closeRect = tester.getRect(close);
      expect(closeRect.height, greaterThanOrEqualTo(44));
      expect(
        closeRect.bottom,
        lessThanOrEqualTo(scenario.size.height - scenario.inset),
      );
      for (final label in ['앱 설치', '소스 코드', '진단 로그 공유']) {
        final action = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(tester.getRect(close), closeRect);
      }
      expect(calls, ['install', 'source', 'logs']);
      expect(tester.takeException(), isNull);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(AppInfoDialog), findsNothing);
    });
  }

  testWidgets('unavailable actions and an unknown version are omitted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(
        dialog: AppInfoDialog(version: '', onOpenSource: () {}),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('앱 설치'), findsNothing);
    expect(find.text('진단 로그 공유'), findsNothing);
    expect(find.text('v'), findsNothing);
    expect(find.text('소스 코드'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape dismisses the info dialog', (tester) async {
    await tester.pumpWidget(
      _subject(
        dialog: AppInfoDialog(version: '1.4.0', onOpenSource: () {}),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AppInfoDialog), findsNothing);
  });

  testWidgets('manual installation action describes opening instructions', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _subject(
        dialog: AppInfoDialog(
          version: '1.4.0',
          installLabel: '설치 방법 보기',
          installDescription: '주소창에서 앱으로 추가하는 방법을 확인해요.',
          onInstall: () => calls++,
          onOpenSource: () {},
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('앱 설치'), findsNothing);
    await tester.tap(find.text('설치 방법 보기'));
    expect(calls, 1);
  });
}

Widget _subject({
  required AppInfoDialog dialog,
  double scale = 1,
  bool dark = false,
}) => MaterialApp(
  theme: dark ? darkThemeData : themeData,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () =>
            showDialog<void>(context: context, builder: (_) => dialog),
        child: const Text('열기'),
      ),
    ),
  ),
);
