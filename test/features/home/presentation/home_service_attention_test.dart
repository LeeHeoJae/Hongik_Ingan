import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/features/home/presentation/layouts/home_service_workspace.dart';

void main() {
  final panel = find.byKey(const ValueKey('home-service-attendance'));
  Color color(WidgetTester tester) => tester.widget<Material>(panel).color!;

  testWidgets(
    'a new lecture during a pulse keeps the current color and timing',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      await tester.tap(find.text('열람실'));
      await tester.pumpAndSettle();
      h.show('course-1');
      await tester.pump();
      final baseline = color(tester);
      await tester.pump(const Duration(milliseconds: 200));
      final peak = color(tester);
      expect(peak, isNot(baseline));
      h.show('course-2');
      await tester.pump();
      expect(color(tester), peak);
      await tester.pump(const Duration(milliseconds: 800));
      expect(color(tester), baseline);
      await tester.pump(const Duration(milliseconds: 16));
      final pulse =
          tester
                  .widget<AnimatedBuilder>(
                    find
                        .ancestor(
                          of: panel,
                          matching: find.byType(AnimatedBuilder),
                        )
                        .first,
                  )
                  .animation
              as Animation<double>;
      expect(pulse.status, AnimationStatus.completed);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pulses once per lecture and resets for a new session', (
    tester,
  ) async {
    final h = _Harness();
    await h.mount(tester);
    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    h.show('course-1');
    await tester.pump();
    final settledColor = color(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(color(tester), isNot(settledColor));
    await tester.pumpAndSettle();
    expect(color(tester), settledColor);
    h.show(null);
    await tester.pump();
    h.show('course-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(color(tester), settledColor);
    await tester.tap(find.text('로그인·출결'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    expect(color(tester), settledColor);
    h.show('course-2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(color(tester), isNot(settledColor));
    await tester.pumpAndSettle();
    h.show(null, scope: null);
    await tester.pump();
    h.show('course-1', scope: 'student');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(color(tester), isNot(settledColor));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an existing lecture and primary discoveries stay still', (
    tester,
  ) async {
    final h = _Harness(initial: 'course-1');
    await h.mount(tester);
    h.show('course-2');
    await tester.pump();
    await tester.tap(find.text('열람실'));
    await tester.pumpAndSettle();
    final settledColor = color(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(color(tester), settledColor);
    h.show('course-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(color(tester), settledColor);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 1200.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'static cue fits large text with reduced motion: $width $dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final h = _Harness();
          await h.mount(tester, dark: dark, reducedMotion: true, textScale: 2);
          await tester.tap(find.text('열람실'));
          await tester.pumpAndSettle();
          h.show('course-1');
          await tester.pump();
          final settledColor = color(tester);
          await tester.pump(const Duration(milliseconds: 200));
          expect(color(tester), settledColor);
          expect(
            (tester.widget<Material>(panel).shape as RoundedRectangleBorder)
                .side
                .width,
            2,
          );
          expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
          final caption = find.text('출결 가능');
          expect(
            tester.renderObject<RenderParagraph>(caption).didExceedMaxLines,
            isFalse,
          );
          final bounds = tester.getRect(panel);
          final captionBounds = tester.getRect(caption);
          expect(captionBounds.top, greaterThanOrEqualTo(bounds.top));
          expect(captionBounds.bottom, lessThanOrEqualTo(bounds.bottom));
          expect(captionBounds.right, lessThanOrEqualTo(bounds.right));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _Harness {
  _Harness({String? initial})
    : data = ValueNotifier((id: initial, scope: 'student' as String?));
  final ValueNotifier<({String? id, String? scope})> data;

  void show(String? id, {String? scope = 'student'}) =>
      data.value = (id: id, scope: scope);

  Future<void> mount(
    WidgetTester tester, {
    bool dark = false,
    bool reducedMotion = false,
    double textScale = 1,
  }) async {
    addTearDown(data.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: dark ? darkThemeData : themeData,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reducedMotion,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: data,
              builder: (context, value, child) => HomeServiceWorkspace(
                availableHeight: 900,
                attentionScope: value.scope,
                detailBuilder: (_, _) => const SizedBox(height: 180),
                summaryBuilder: (service, _) => HomeServiceSummaryData(
                  attentionKey: service == HomeService.attendance
                      ? value.id
                      : null,
                  eyebrow: service == HomeService.attendance && value.id != null
                      ? '출결 가능'
                      : null,
                  status: service == HomeService.attendance && value.id != null
                      ? '디지털 미디어 디자인과 인터랙션 프로그래밍 실습'
                      : '확인 중',
                  secondary:
                      service == HomeService.attendance && value.id != null
                      ? '10:00'
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
