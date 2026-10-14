import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/update/domain/update_check_result.dart';
import 'package:hongik_ingan/features/update/domain/update_info.dart';
import 'package:hongik_ingan/features/update/presentation/update_dialog.dart';
import 'package:hongik_ingan/features/update/presentation/version_info_button.dart';

import '../../support/load_app_fonts.dart';

const _available = UpdateCheckResult.available(
  UpdateInfo(
    currentVersion: '1.4.0',
    latestVersion: '1.4.1',
    notice: '홈 화면과 전자출결 사용성을 개선했어요.',
    updateUrl: 'https://example.com/releases/1.4.1',
  ),
);

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('version button stays aligned dark=$dark scale=$scale', (
        tester,
      ) async {
        final heights = <double>[];
        for (final available in [false, true]) {
          var taps = 0;
          await tester.pumpWidget(
            _subject(
              dark: dark,
              scale: scale,
              child: Center(
                child: VersionInfoButton(
                  version: '1.4.0',
                  hasUpdate: available,
                  onPressed: () => taps++,
                ),
              ),
            ),
          );
          final button = find.byType(VersionInfoButton);
          final text = find.text('v1.4.0');
          final arrow = find.byIcon(Icons.chevron_right);
          final bounds = tester.getRect(button);
          heights.add(bounds.height);
          expect(bounds.height, greaterThanOrEqualTo(44));
          expect(tester.getCenter(text).dy, closeTo(bounds.center.dy, 0.01));
          expect(tester.getCenter(arrow).dy, closeTo(bounds.center.dy, 0.01));
          expect(bounds.center.dx, 400);
          if (available) {
            expect(
              tester.getCenter(find.byIcon(Icons.update)).dy,
              bounds.center.dy,
            );
          }
          await tester.tap(button);
          expect(taps, 1);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(taps, 2);
          expect(tester.takeException(), isNull);
        }
        expect(heights[0], heights[1]);
      });
    }
  }

  for (final size in [
    const Size(390, 844),
    const Size(320, 620),
    const Size(1440, 900),
  ]) {
    for (final dark in [false, true]) {
      for (final result in [
        const UpdateCheckResult.upToDate(),
        _available,
        const UpdateCheckResult.checking(),
        const UpdateCheckResult.failed(),
      ]) {
        testWidgets('version dialog ${result.status.name} $size dark=$dark', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var retries = 0;
          await tester.pumpWidget(
            _subject(
              dark: dark,
              scale: size.width == 320 ? 2 : 1,
              child: UpdateDialog(
                currentVersion: '1.4.0',
                result: result,
                onRetry: () => retries++,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text('v1.4.0'), findsOneWidget);
          expect(
            find.text('업데이트하기'),
            result.info == null ? findsNothing : findsOneWidget,
          );
          if (result.status == UpdateCheckStatus.failed) {
            expect(find.text('최신 버전이에요'), findsNothing);
            await tester.tap(find.text('다시 확인'));
            expect(retries, 1);
          }
          if (result.status == UpdateCheckStatus.checking) {
            expect(find.byType(LinearProgressIndicator), findsOneWidget);
            expect(find.text('최신 버전이에요'), findsNothing);
          }
          if (result.status == UpdateCheckStatus.upToDate) {
            expect(find.text('최신 버전이에요'), findsOneWidget);
            expect(find.text('업데이트 내역'), findsNothing);
          }
          final close = find.text(result.info == null ? '닫기' : '나중에');
          final closeRect = tester.getRect(close);
          expect(closeRect.top, greaterThanOrEqualTo(0));
          expect(closeRect.bottom, lessThanOrEqualTo(size.height));
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            '${size.width.toInt()}-${dark ? 'dark' : 'light'}-${result.status.name}',
          );
          if (result.info != null && size.width == 320) {
            await tester.drag(
              find.byType(SingleChildScrollView).first,
              const Offset(0, -600),
            );
            await tester.pumpAndSettle();
            expect(
              find.text('홈 화면과 전자출결 사용성을 개선했어요.').hitTestable(),
              findsOneWidget,
            );
          }
        });
      }
    }
  }

  testWidgets('button visual comparison', (tester) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        _subject(
          dark: dark,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VersionInfoButton(
                  version: '1.4.0',
                  hasUpdate: false,
                  onPressed: () {},
                ),
                const SizedBox(height: 18),
                VersionInfoButton(
                  version: '1.4.0',
                  hasUpdate: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await _capture(tester, 'buttons-${dark ? 'dark' : 'light'}');
    }
  });
}

Widget _subject({required Widget child, bool dark = false, double scale = 1}) {
  return MaterialApp(
    theme: themeData,
    darkTheme: darkThemeData,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: RepaintBoundary(
      key: const ValueKey('update-visual'),
      child: Scaffold(body: child),
    ),
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['UPDATE_VISUAL_DIR'];
  if (directory == null) return;
  await tester.pump(const Duration(milliseconds: 300));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('update-visual')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
