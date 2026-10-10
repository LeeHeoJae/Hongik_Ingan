import 'package:flutter/material.dart';

import 'home_attendance_density.dart';

/// The heading is outside the information column but part of the button's card.
class HomeAttendanceActionScope extends InheritedWidget {
  const HomeAttendanceActionScope({
    super.key,
    required this.bodyTop,
    required this.bottomPadding,
    required super.child,
  });

  final double bodyTop;
  final double bottomPadding;

  static double bodyTopOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HomeAttendanceActionScope>()
          ?.bodyTop ??
      0;

  static double bottomPaddingOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<HomeAttendanceActionScope>()
          ?.bottomPadding ??
      0;

  @override
  bool updateShouldNotify(HomeAttendanceActionScope oldWidget) =>
      bodyTop != oldWidget.bodyTop || bottomPadding != oldWidget.bottomPadding;
}

class HomeAttendanceCardScope extends InheritedWidget {
  const HomeAttendanceCardScope({
    super.key,
    required this.height,
    required this.availableHeight,
    required super.child,
  });

  final double height;
  final double availableHeight;

  static double? heightOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<HomeAttendanceCardScope>()
      ?.height;

  static double? availableHeightOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<HomeAttendanceCardScope>()
      ?.availableHeight;

  @override
  bool updateShouldNotify(HomeAttendanceCardScope oldWidget) =>
      height != oldWidget.height ||
      availableHeight != oldWidget.availableHeight;
}

class HomeAttendanceActionLayout extends StatelessWidget {
  const HomeAttendanceActionLayout({
    super.key,
    required this.content,
    required this.action,
  });

  final Widget content;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            MediaQuery.sizeOf(context).width >= 960 &&
            constraints.maxWidth >= 480 &&
            MediaQuery.textScalerOf(context).scale(14) <= 19;
        if (!wide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              content,
              SizedBox(
                height: HomeAttendanceDensityScope.bodyOf(context).contentGap,
              ),
              action,
            ],
          );
        }
        final bodyTop = HomeAttendanceActionScope.bodyTopOf(context);
        final cardHeight = HomeAttendanceCardScope.heightOf(context);
        final availableHeight = HomeAttendanceCardScope.availableHeightOf(
          context,
        );
        final minimumHeight = availableHeight == null
            ? 280.0
            : (availableHeight -
                      bodyTop -
                      HomeAttendanceActionScope.bottomPaddingOf(context))
                  .clamp(0.0, 280.0);
        const actionWidth = 160.0;
        const actionGap = 24.0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: actionWidth + actionGap),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumHeight),
                child: Align(alignment: Alignment.centerLeft, child: content),
              ),
            ),
            Positioned(
              top: -bodyTop,
              height: cardHeight,
              bottom: cardHeight == null ? 0 : null,
              right: 0,
              width: actionWidth,
              child: Center(
                child: SizedBox(width: actionWidth, height: 44, child: action),
              ),
            ),
          ],
        );
      },
    );
  }
}
