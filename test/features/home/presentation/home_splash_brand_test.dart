import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/home/presentation/home_splash_messages.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_splash_brand.dart';

import '../../../support/load_app_fonts.dart';

const _text = ValueKey('home-splash-text');
const _preview = ValueKey('preview');

Widget _subject({
  double width = 358,
  double scale = 1,
  double keyboard = 0,
  double viewportHeight = 844,
  double heightBudget = double.infinity,
  bool animate = false,
  bool reduced = false,
  bool dark = false,
  List<String> messages = const ['공강 만세'],
  VoidCallback? onInfo,
}) => ProviderScope(
  overrides: [homeSplashAnimationProvider.overrideWithValue(animate)],
  child: MaterialApp(
    theme: dark ? darkThemeData : themeData,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: Size(390, viewportHeight),
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
          disableAnimations: reduced,
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: _preview,
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: width,
                    height: 120,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                key: const ValueKey('preview-logo'),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF05014A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: Image.asset(
                                    'assets/images/icon_foreground.png',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: HomeSplashBrand(
                                  messages: messages,
                                  hidden: keyboard > 0,
                                  heightBudget: heightBudget,
                                ),
                              ),
                              IconButton(
                                onPressed: onInfo ?? () {},
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: const Icon(Icons.info_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Rect _bounds(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return [
        Offset.zero,
        Offset(box.size.width, 0),
        Offset(0, box.size.height),
        Offset(box.size.width, box.size.height),
      ]
      .map((point) => box.localToGlobal(point))
      .map((point) => Rect.fromLTWH(point.dx, point.dy, 0, 0))
      .reduce((a, b) => a.expandToInclude(b));
}

void _expectAnchor(WidgetTester tester) {
  final text = tester.renderObject<RenderBox>(find.byKey(_text));
  final midpoint = text.localToGlobal(Offset(text.size.width / 2, 0));
  final corner = tester.getRect(find.text('홍익인간')).bottomRight;
  expect((midpoint - corner).distance, lessThan(0.01));
}

void main() {
  testWidgets('catalog and active messages ignore header width when selected', (
    tester,
  ) async {
    await tester.runAsync(loadAppFonts);
    final source = File(
      'research/splash-message-candidates.md',
    ).readAsStringSync();
    final entries = <String, String>{};
    for (final line in source.split('\n')) {
      final match = RegExp(r'^(\d{3})\. (.+)$').firstMatch(line);
      if (match == null || line.contains('~~')) continue;
      entries[match[1]!] = match[2]!.split(' `[').first.trim();
    }
    expect(entries, isNotEmpty);
    final visibleIds = <String, List<String>>{};
    for (final scenario in [
      (228.0, 1.0),
      (275.0, 1.0),
      (358.0, 1.0),
      (358.0, 1.2),
    ]) {
      final visible = <String>[];
      for (final entry in entries.entries) {
        await tester.pumpWidget(
          _subject(
            width: scenario.$1,
            scale: scenario.$2,
            messages: [entry.value],
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: entry.key);
        expect(find.byKey(_text), findsOneWidget, reason: entry.key);
        expect(tester.widget<Text>(find.byKey(_text)).data, entry.value);
        visible.add(entry.key);
        _expectAnchor(tester);
      }
      expect(visible.length, entries.length);
      visibleIds['header${scenario.$1.toInt()}_scale${scenario.$2}'] = visible;
    }
    for (final width in [228.0, 358.0]) {
      for (final (index, message) in homeSplashMessages.indexed) {
        await tester.pumpWidget(_subject(width: width, messages: [message]));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'active ${index + 1}');
        expect(
          find.byKey(_text),
          findsOneWidget,
          reason: 'active ${index + 1}',
        );
        expect(tester.widget<Text>(find.byKey(_text)).data, message);
        _expectAnchor(tester);
      }
    }
    const output = String.fromEnvironment('SPLASH_AUDIT_OUTPUT');
    if (output.isNotEmpty) {
      File(output).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'candidateCount': entries.length,
          'visibleIds': visibleIds,
          'texts': entries,
        }),
      );
    }
  });
  testWidgets('top-edge midpoint stays on the title corner while pulsing', (
    tester,
  ) async {
    await tester.runAsync(loadAppFonts);
    for (final text in ['공강!', '공강 만세']) {
      await tester.pumpWidget(_subject(messages: [text], animate: true));
      await tester.pump();
      for (var frame = 0; frame < 4; frame++) {
        _expectAnchor(tester);
        await tester.pump(const Duration(milliseconds: 125));
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('title aligns with the logo without reserving splash height', (
    tester,
  ) async {
    await tester.runAsync(loadAppFonts);
    for (final scale in [1.0, 1.2]) {
      await tester.pumpWidget(
        _subject(scale: scale, messages: const ['공강 만세!']),
      );
      await tester.pumpAndSettle();
      final title = tester.getRect(find.text('홍익인간'));
      final logo = tester.getRect(find.byKey(const ValueKey('preview-logo')));
      final brand = tester.getRect(find.byType(HomeSplashBrand));
      expect(title.center.dy, closeTo(logo.center.dy, 0.01));
      expect(brand.height, 48);
      _expectAnchor(tester);
    }
  });
  testWidgets('uses remaining height rather than a viewport cutoff', (
    tester,
  ) async {
    await tester.runAsync(loadAppFonts);
    await tester.pumpWidget(_subject(viewportHeight: 620, heightBudget: 120));
    await tester.pumpAndSettle();
    expect(find.byKey(_text), findsOneWidget);
    expect(find.text('신속 출결'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(_text)).style!.fontFamily,
      'Pretendard',
    );
    await tester.pumpWidget(_subject(viewportHeight: 844, heightBudget: 60));
    await tester.pumpAndSettle();
    expect(find.byKey(_text), findsNothing);
  });
  testWidgets(
    'default copy overlays standard headers without increasing their height',
    (tester) async {
      await tester.runAsync(loadAppFonts);
      for (final width in [275.0, 358.0]) {
        await tester.pumpWidget(
          _subject(width: width, messages: homeSplashMessages),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(_text), findsOneWidget);
        final brand = tester.getRect(find.byType(HomeSplashBrand));
        expect(brand.height, 48);
        _expectAnchor(tester);
        expect(find.text('신속 출결'), findsNothing);
      }
      await tester.pumpWidget(_subject(scale: 1.2, messages: const ['공강 만세!']));
      await tester.pumpAndSettle();
      expect(find.byKey(_text), findsOneWidget);
      expect(tester.getRect(find.byType(HomeSplashBrand)).height, 48);
    },
  );
  testWidgets('rotated splash overlays headers in both themes and widths', (
    tester,
  ) async {
    await tester.runAsync(loadAppFonts);
    await tester.runAsync(() async {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    for (final dark in [false, true]) {
      for (final width in [288.0, 358.0, 340.0]) {
        await tester.pumpWidget(
          _subject(
            width: width,
            dark: dark,
            messages: const ['상태 이상: 집 가고 싶음'],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(_text), findsOneWidget);
        final brand = tester.getRect(find.byType(HomeSplashBrand));
        _expectAnchor(tester);
        expect(brand.height, 48);
        expect(find.text('신속 출결'), findsNothing);
        expect(tester.takeException(), isNull);
        const directory = String.fromEnvironment('SPLASH_PREVIEW_DIR');
        if (directory.isNotEmpty) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(_preview),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            final file = File(
              '$directory/header-${dark ? 'dark' : 'light'}-${width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
      }
    }
  });

  testWidgets('keeps the random choice when width changes', (tester) async {
    await tester.runAsync(loadAppFonts);
    const message = '캠퍼스가 미로인가요?';
    const messages = [message];
    await tester.pumpWidget(_subject(width: 228, messages: messages));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(_text)).data, message);
    await tester.pumpWidget(
      _subject(width: 358, dark: true, messages: messages),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(_text)).data, message);
    await tester.pumpWidget(_subject(width: 228, messages: messages));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(_text)).data, message);
    await tester.pumpWidget(_subject(width: 358, messages: messages));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(_text)).data, message);
  });

  testWidgets(
    'hides on keyboard, large text, invalid copy and insufficient space',
    (tester) async {
      await tester.runAsync(loadAppFonts);
      for (final subject in [
        _subject(keyboard: 300),
        _subject(heightBudget: 60),
        _subject(width: 288, scale: 2),
        _subject(messages: const []),
        _subject(messages: const ['', '  ', 'first\nsecond']),
      ]) {
        await tester.pumpWidget(subject);
        await tester.pumpAndSettle();
        expect(find.byKey(_text), findsNothing);
        expect(find.text('홍익인간'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();
      expect(find.byKey(_text), findsOneWidget);
    },
  );

  testWidgets(
    'pulse repeats without changing layout and respects reduced motion',
    (tester) async {
      await tester.runAsync(loadAppFonts);
      await tester.pumpWidget(_subject(animate: true));
      await tester.pump();
      final layout = tester.getRect(find.byType(HomeSplashBrand));
      final maximum = _bounds(tester, find.byKey(_text));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        _bounds(tester, find.byKey(_text)).width / maximum.width,
        closeTo(1.7 / 1.8, 0.002),
      );
      expect(tester.getRect(find.byType(HomeSplashBrand)), layout);
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        _bounds(tester, find.byKey(_text)).width,
        closeTo(maximum.width, 0.01),
      );
      await tester.pumpWidget(_subject(animate: true, reduced: true));
      await tester.pumpAndSettle();
      final still = _bounds(tester, find.byKey(_text));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_bounds(tester, find.byKey(_text)), still);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('does not block adjacent information button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_subject(onInfo: () => taps++));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton));
    expect(taps, 1);
  });
}
