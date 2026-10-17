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
import 'package:hongik_ingan/features/home/presentation/widgets/home_splash_space.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_mobile_header.dart';

import '../../../support/load_app_fonts.dart';

const _text = ValueKey('home-splash-text');
const _preview = ValueKey('preview');

Widget _subject({
  double width = 358,
  double scale = 1,
  double keyboard = 0,
  double viewportHeight = 844,
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

Widget _geometrySubject({
  Rect? obstacle,
  Widget? obstacleChild,
  bool contentOnly = false,
  bool offstage = false,
  double opacity = 1,
  double height = 300,
  double width = 600,
  double headerTop = 20,
  double headerScale = 1,
  double textScale = 1,
  bool animate = false,
  bool animateLayout = false,
}) => ProviderScope(
  overrides: [homeSplashAnimationProvider.overrideWithValue(animate)],
  child: MaterialApp(
    theme: themeData,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: HomeSplashSpace(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      left: 16,
                      right: 16,
                      child: HomeMobileHeader(
                        animate: animateLayout,
                        top: headerTop,
                        scale: headerScale,
                        width: width - 32,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const HomeSplashObstacle(
                              child: SizedBox(width: 44, height: 44),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: HomeSplashBrand(messages: ['공강 만세!']),
                            ),
                            HomeSplashObstacle(
                              child: IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.info_outline),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (obstacle != null)
                      Positioned.fromRect(
                        rect: obstacle,
                        child: Offstage(
                          offstage: offstage,
                          child: Opacity(
                            opacity: opacity,
                            child: contentOnly
                                ? HomeSplashContent(
                                    child: ColoredBox(
                                      color: Colors.blue,
                                      child:
                                          obstacleChild ??
                                          const SizedBox.expand(),
                                    ),
                                  )
                                : HomeSplashObstacle(
                                    child:
                                        obstacleChild ??
                                        const SizedBox.expand(),
                                  ),
                          ),
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
);

void _expectAnchor(WidgetTester tester) {
  final text = tester.renderObject<RenderBox>(find.byKey(_text));
  final midpoint = text.localToGlobal(Offset(text.size.width / 2, 0));
  final corner = tester.getRect(find.text('홍익인간')).bottomRight;
  expect((midpoint - corner).distance, lessThan(0.01));
}

void main() {
  testWidgets(
    'permits shallow text overlap but protects text centers and controls',
    (tester) async {
      await tester.runAsync(loadAppFonts);
      var visible = true;
      Widget subject(double bottom, {bool button = false}) => MaterialApp(
        home: Scaffold(
          body: HomeSplashSpace(
            child: Stack(
              children: [
                Positioned(
                  left: 100,
                  top: 100,
                  width: 100,
                  child: HomeSplashContent(
                    child: Semantics(
                      button: button,
                      child: const Text(
                        'TEXT',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 20,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 100,
                  top: bottom - 10,
                  width: 100,
                  height: 10,
                  child: HomeSplashGuard(
                    polygon: const [
                      Offset.zero,
                      Offset(100, 0),
                      Offset(100, 10),
                      Offset(0, 10),
                    ],
                    onVisibilityChanged: (value) => visible = value,
                    child: const ColoredBox(color: Colors.yellow),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(subject(20));
      await tester.pumpAndSettle();
      final text = tester.renderObject<RenderParagraph>(find.text('TEXT'));
      final glyph = text
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
          )
          .first
          .toRect();
      final top = text.localToGlobal(glyph.topLeft).dy;
      await tester.pumpWidget(subject(top + 2));
      await tester.pumpAndSettle();
      expect(visible, isTrue);
      await tester.pumpWidget(subject(top + glyph.height / 2));
      await tester.pumpAndSettle();
      expect(visible, isFalse);
      await tester.pumpWidget(subject(top + 2));
      await tester.pumpAndSettle();
      expect(visible, isTrue);
      await tester.pumpWidget(subject(top + 2, button: true));
      await tester.pumpAndSettle();
      expect(visible, isFalse);
    },
  );

  testWidgets(
    'follows current animated header coordinates without visibility oscillation',
    (tester) async {
      await tester.runAsync(loadAppFonts);
      await tester.pumpWidget(_geometrySubject(animateLayout: true));
      await tester.pumpAndSettle();
      final original = _bounds(tester, find.byKey(_text));
      final size = tester.getSize(find.byType(HomeSplashBrand));
      final obstacle = Rect.fromCenter(
        center: original.center + const Offset(0, 120),
        width: 24,
        height: 24,
      );
      var transitions = 0;
      var lastVisible = true;
      for (final top in [140.0, 20.0]) {
        await tester.pumpWidget(
          _geometrySubject(
            headerTop: top,
            animateLayout: true,
            obstacle: obstacle,
          ),
        );
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final visible = find.byKey(_text).evaluate().isNotEmpty;
          if (visible != lastVisible) transitions++;
          lastVisible = visible;
          expect(tester.getSize(find.byType(HomeSplashBrand)), size);
          expect(tester.takeException(), isNull);
        }
        expect(lastVisible, top == 20);
      }
      expect(transitions, 2);
      _expectAnchor(tester);
    },
  );

  testWidgets(
    'uses actual space with large text and transformed mobile headers',
    (tester) async {
      await tester.runAsync(loadAppFonts);
      for (final scale in [1.0, 1.5, 2.0]) {
        await tester.pumpWidget(
          _geometrySubject(height: 220, headerScale: 1.3, textScale: scale),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(_text), findsOneWidget);
        _expectAnchor(tester);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'hides for a real target and restores the same copy without moving the header',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.runAsync(loadAppFonts);
        await tester.pumpWidget(_geometrySubject());
        await tester.pumpAndSettle();
        final header = tester.getRect(find.byType(HomeSplashBrand));
        final obstacle = Rect.fromCenter(
          center: _bounds(tester, find.byKey(_text)).center,
          width: 20,
          height: 20,
        );
        await tester.pumpWidget(_geometrySubject(obstacle: obstacle));
        await tester.pumpAndSettle();
        expect(find.byKey(_text), findsNothing);
        expect(find.semantics.byLabel('공강 만세!'), findsNothing);
        expect(tester.getRect(find.byType(HomeSplashBrand)), header);
        await tester.pumpWidget(
          _geometrySubject(obstacle: obstacle, offstage: true),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.byKey(_text)).data, '공강 만세!');
        expect(find.semantics.byLabel('공강 만세!'), findsOne);
        expect(tester.getRect(find.byType(HomeSplashBrand)), header);
        _expectAnchor(tester);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'allows empty card padding but protects visible glyphs and controls',
    (tester) async {
      await tester.runAsync(loadAppFonts);
      await tester.pumpWidget(_geometrySubject());
      await tester.pumpAndSettle();
      final obstacle = Rect.fromCenter(
        center: _bounds(tester, find.byKey(_text)).center,
        width: 24,
        height: 24,
      );
      await tester.pumpWidget(
        _geometrySubject(obstacle: obstacle, contentOnly: true),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_text), findsOneWidget);
      await tester.pumpWidget(
        _geometrySubject(
          obstacle: obstacle,
          contentOnly: true,
          obstacleChild: const Text('X'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_text), findsNothing);
      await tester.pumpWidget(
        _geometrySubject(
          obstacle: obstacle,
          contentOnly: true,
          opacity: 0,
          obstacleChild: const Text('X'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_text), findsOneWidget);
      await tester.pumpWidget(
        _geometrySubject(
          obstacle: obstacle,
          contentOnly: true,
          obstacleChild: Semantics(
            button: true,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_text), findsNothing);
    },
  );

  testWidgets(
    'clips against the real viewport and stops pulsing while blocked',
    (tester) async {
      await tester.runAsync(loadAppFonts);
      await tester.pumpWidget(_geometrySubject(height: 140, headerTop: 100));
      await tester.pumpAndSettle();
      expect(find.byKey(_text), findsNothing);
      await tester.pumpWidget(_geometrySubject(height: 220, headerTop: 100));
      await tester.pumpAndSettle();
      expect(find.byKey(_text), findsOneWidget);
      final obstacle = Rect.fromCenter(
        center: _bounds(tester, find.byKey(_text)).center,
        width: 20,
        height: 20,
      );
      await tester.pumpWidget(
        _geometrySubject(
          height: 220,
          headerTop: 100,
          animate: true,
          obstacle: obstacle,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_text), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_text), findsNothing);
    },
  );

  testWidgets('active messages ignore header width when selected', (
    tester,
  ) async {
    await tester.runAsync(loadAppFonts);
    expect(homeSplashMessages, isNotEmpty);
    for (final scenario in [
      (228.0, 1.0),
      (275.0, 1.0),
      (358.0, 1.0),
      (358.0, 1.2),
    ]) {
      for (final (index, message) in homeSplashMessages.indexed) {
        await tester.pumpWidget(
          _subject(width: scenario.$1, scale: scenario.$2, messages: [message]),
        );
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
  testWidgets('does not hide solely because of viewport height or large text', (
    tester,
  ) async {
    await tester.runAsync(loadAppFonts);
    await tester.pumpWidget(_subject(viewportHeight: 620));
    await tester.pumpAndSettle();
    expect(find.byKey(_text), findsOneWidget);
    expect(find.text('신속 출결'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(_text)).style!.fontFamily,
      'Pretendard',
    );
    await tester.pumpWidget(_subject(viewportHeight: 844, scale: 1.5));
    await tester.pumpAndSettle();
    expect(find.byKey(_text), findsOneWidget);
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

  testWidgets('hides on keyboard and invalid copy', (tester) async {
    await tester.runAsync(loadAppFonts);
    for (final subject in [
      _subject(keyboard: 300),
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
  });

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
