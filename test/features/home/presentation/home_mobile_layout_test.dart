import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_mobile_layout.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_attendance_density.dart';

void main() {
  test('primary spacing is reduced before the auxiliary gap or summaries', () {
    final layout = HomeMobileLayout.fit(
      viewportHeight: 610,
      minimumMainHeight: 500,
      attendanceIsPrimary: true,
      textScale: 1,
      minimumAuxiliaryHeight: 80,
    );
    expect(layout.density, HomeAttendanceDensity.compact);
    expect(layout.gap, 12);
    expect(layout.auxiliaryHeight, 108);
    expect(layout.summaryCompression, 0);
  });

  test('all services exhaust primary spacing before compressing summaries', () {
    for (final attendance in [true, false]) {
      final layout = HomeMobileLayout.fit(
        viewportHeight: 390,
        minimumMainHeight: 320,
        attendanceIsPrimary: attendance,
        textScale: 1,
        minimumAuxiliaryHeight: 80,
      );
      expect(layout.density, HomeAttendanceDensity.tight);
      expect(layout.auxiliaryHeight, lessThan(108));
      expect(layout.summaryCompression, greaterThan(0));
      expect(layout.mainHeight + layout.gap + layout.auxiliaryHeight, 390);
    }
  });

  test('details use an internal viewport before the page needs to scroll', () {
    HomeMobileLayout detail(double height) => HomeMobileLayout.fit(
      viewportHeight: height,
      minimumMainHeight: 320,
      attendanceIsPrimary: false,
      textScale: 1,
      minimumAuxiliaryHeight: 80,
    );
    final short = detail(300);
    expect(short.auxiliaryHeight, 80);
    expect(short.mainHeight, 212);
    expect(short.mainHeight + short.gap + short.auxiliaryHeight, 300);
    final extreme = detail(240);
    expect(extreme.mainHeight, 180);
    expect(
      extreme.mainHeight + extreme.gap + extreme.auxiliaryHeight,
      greaterThan(240),
    );
    final restored = detail(600);
    expect(restored.density, HomeAttendanceDensity.regular);
    expect(restored.auxiliaryHeight, 108);
    expect(restored.summaryCompression, 0);
  });

  test('attendance retains its full content height for page scrolling', () {
    final layout = HomeMobileLayout.fit(
      viewportHeight: 300,
      minimumMainHeight: 500,
      attendanceIsPrimary: true,
      textScale: 1,
      minimumAuxiliaryHeight: 80,
    );
    expect(layout.mainHeight, 474);
    expect(
      layout.mainHeight + layout.gap + layout.auxiliaryHeight,
      greaterThan(layout.viewportHeight),
    );
  });

  HomeMobileLayout fit(double height, {double minimum = 80}) =>
      HomeMobileLayout.fit(
        viewportHeight: height,
        minimumMainHeight: 500,
        attendanceIsPrimary: true,
        textScale: 1,
        minimumAuxiliaryHeight: minimum,
      );

  test(
    'detail spacing can shrink while summaries retain their normal height',
    () {
      final layout = fit(600);
      expect(layout.auxiliaryHeight, 108);
      expect(
        500 -
            layout.density.heightReduction +
            layout.gap +
            layout.auxiliaryHeight,
        lessThanOrEqualTo(layout.viewportHeight),
      );
    },
  );

  test('summaries lose only the remaining shortage and recover on resize', () {
    for (final height in [590.0, 589.0, 580.0, 589.0, 590.0, 620.0]) {
      final layout = fit(height);
      if (layout.auxiliaryHeight < 108) {
        expect(
          500 -
              layout.density.heightReduction +
              layout.gap +
              layout.auxiliaryHeight,
          height,
        );
      } else {
        expect(layout.auxiliaryHeight, 108);
      }
    }
  });

  test(
    'readable summary minimum takes priority over fitting a short viewport',
    () {
      final layout = fit(540, minimum: 96);
      expect(layout.auxiliaryHeight, 96);
      expect(
        500 -
            layout.density.heightReduction +
            layout.gap +
            layout.auxiliaryHeight,
        greaterThan(layout.viewportHeight),
      );
    },
  );

  test(
    'all services use the same normal auxiliary height when space permits',
    () {
      for (final attendanceIsPrimary in [true, false]) {
        final layout = HomeMobileLayout.page(
          availableHeight: 740,
          headerHeight: 48,
          footerHeight: 34,
          minimumMainHeight: attendanceIsPrimary ? 500 : 320,
          attendanceIsPrimary: attendanceIsPrimary,
          textScale: 1,
          minimumAuxiliaryHeight: 90,
        );
        expect(layout.auxiliaryHeight, 108);
        expect(
          layout.viewportHeight +
              layout.topPadding +
              layout.bottomPadding +
              layout.headerGap +
              48 +
              34,
          740,
        );
      }
    },
  );
}
