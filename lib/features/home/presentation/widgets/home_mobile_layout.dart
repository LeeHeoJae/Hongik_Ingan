import 'dart:math' as math;

import 'home_attendance_density.dart';

/// A single space budget for the page chrome, detail and auxiliary summaries.
class HomeMobileLayout {
  const HomeMobileLayout._({
    required this.viewportHeight,
    required this.density,
    required this.gap,
    required this.auxiliaryHeight,
    this.topPadding = 0,
    this.bottomPadding = 0,
    this.headerGap = 0,
  });

  factory HomeMobileLayout.page({
    required double availableHeight,
    required double headerHeight,
    required double footerHeight,
    required double minimumMainHeight,
    required bool attendanceIsPrimary,
    required double textScale,
    required double minimumAuxiliaryHeight,
  }) {
    final preferredAuxiliaryHeight = math.max(
      normalAuxiliaryHeight(textScale),
      math.max(
        minimumAuxiliaryHeight,
        _scaledMinimumAuxiliaryHeight(textScale),
      ),
    );
    final compact =
        minimumMainHeight +
            preferredAuxiliaryHeight +
            12 +
            headerHeight +
            footerHeight +
            56 >
        availableHeight;
    final top = compact ? 8.0 : 16.0;
    final bottom = compact ? 8.0 : 24.0;
    final headerGap = compact ? 8.0 : 16.0;
    final fit = HomeMobileLayout.fit(
      viewportHeight:
          availableHeight -
          top -
          bottom -
          headerHeight -
          headerGap -
          footerHeight,
      minimumMainHeight: minimumMainHeight,
      attendanceIsPrimary: attendanceIsPrimary,
      textScale: textScale,
      minimumAuxiliaryHeight: minimumAuxiliaryHeight,
    );
    return HomeMobileLayout._(
      viewportHeight: fit.viewportHeight,
      density: fit.density,
      gap: fit.gap,
      auxiliaryHeight: fit.auxiliaryHeight,
      topPadding: top,
      bottomPadding: bottom,
      headerGap: headerGap,
    );
  }

  factory HomeMobileLayout.fit({
    required double viewportHeight,
    required double minimumMainHeight,
    required bool attendanceIsPrimary,
    required double textScale,
    required double minimumAuxiliaryHeight,
  }) {
    final viewport = math.max(0.0, viewportHeight);
    final minimumAuxiliary = math.max(
      _scaledMinimumAuxiliaryHeight(textScale),
      minimumAuxiliaryHeight,
    );
    final preferredAuxiliary = math.max(
      normalAuxiliaryHeight(textScale),
      minimumAuxiliary,
    );
    var density = HomeAttendanceDensity.regular;
    var gap = 12.0;
    if (minimumMainHeight + preferredAuxiliary + gap > viewport) {
      gap = 8;
      if (attendanceIsPrimary) {
        for (final candidate in HomeAttendanceDensity.values) {
          density = candidate;
          if (minimumMainHeight -
                  candidate.heightReduction +
                  preferredAuxiliary +
                  gap <=
              viewport) {
            break;
          }
        }
      }
    }
    // Re-evaluate the budget after reducing detail spacing. Only remove the
    // remaining shortage from summaries, and preserve their readable minimum.
    final auxiliary =
        (viewport - minimumMainHeight + density.heightReduction - gap)
            .clamp(minimumAuxiliary, preferredAuxiliary)
            .toDouble();
    return HomeMobileLayout._(
      viewportHeight: viewport,
      density: density,
      gap: gap,
      auxiliaryHeight: auxiliary,
    );
  }

  static double normalAuxiliaryHeight(double textScale) =>
      108.0 + math.min(64.0, math.max(0.0, textScale - 1) * 64);

  static double _scaledMinimumAuxiliaryHeight(double textScale) =>
      80.0 + math.min(92.0, math.max(0.0, textScale - 1) * 92);

  final double viewportHeight;
  final HomeAttendanceDensity density;
  final double gap;
  final double auxiliaryHeight;
  final double topPadding;
  final double bottomPadding;
  final double headerGap;
}
