import 'package:flutter/widgets.dart';

enum HomeAttendanceDensity {
  regular(16, 18),
  compact(12, 12),
  tight(8, 8);

  const HomeAttendanceDensity(this.verticalPadding, this.headingGap);

  final double verticalPadding;
  final double headingGap;

  double get sectionGap => switch (this) {
    regular => 16,
    compact => 12,
    tight => 4,
  };

  double get contentGap => switch (this) {
    regular => 12,
    compact => 10,
    tight => 4,
  };

  double get itemGap => switch (this) {
    regular => 8,
    compact => 6,
    tight => 2,
  };

  double get sessionDividerGap => switch (this) {
    regular => 4,
    compact => 2,
    tight => 0,
  };

  double get heightReduction =>
      2 * (regular.verticalPadding - verticalPadding) +
      regular.headingGap -
      headingGap;

  // Seat and menu headings normally have a 12px gap.
  double get detailHeadingGap => switch (this) {
    regular => 12,
    compact || tight => 8,
  };

  double reductionFor({required bool attendance}) => attendance
      ? heightReduction
      : 2 * (regular.verticalPadding - verticalPadding) +
            regular.detailHeadingGap -
            detailHeadingGap;
}

/// Shared spacing for auxiliary summaries, reduced only after primary spacing.
class HomeSummarySpacing {
  const HomeSummarySpacing([this.compression = 0]);

  final double compression;

  double get verticalPadding => 8 - 4 * compression;
  double get labelGap => 3 - compression;
  double get contentGap => 4 - 2 * compression;
}

class HomeAttendanceDensityScope extends InheritedWidget {
  const HomeAttendanceDensityScope({
    super.key,
    required this.density,
    this.extraSpace = 0,
    required super.child,
  });

  final HomeAttendanceDensity density;
  final double extraSpace;

  static double extraSpaceOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HomeAttendanceDensityScope>()
          ?.extraSpace ??
      0;

  static HomeAttendanceDensity of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HomeAttendanceDensityScope>()
          ?.density ??
      HomeAttendanceDensity.regular;

  static HomeAttendanceDensity bodyOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600
      ? of(context)
      : HomeAttendanceDensity.regular;

  @override
  bool updateShouldNotify(HomeAttendanceDensityScope oldWidget) =>
      density != oldWidget.density || extraSpace != oldWidget.extraSpace;
}
