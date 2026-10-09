import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_mobile_layout.dart';

void main() {
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
