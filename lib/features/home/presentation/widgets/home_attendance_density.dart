import 'package:flutter/widgets.dart';

enum HomeAttendanceDensity {
  regular(16, 18),
  compact(12, 12),
  tight(8, 8);

  const HomeAttendanceDensity(this.verticalPadding, this.headingGap);

  final double verticalPadding;
  final double headingGap;

  double get heightReduction =>
      2 * (regular.verticalPadding - verticalPadding) +
      regular.headingGap -
      headingGap;
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

  @override
  bool updateShouldNotify(HomeAttendanceDensityScope oldWidget) =>
      density != oldWidget.density || extraSpace != oldWidget.extraSpace;
}
