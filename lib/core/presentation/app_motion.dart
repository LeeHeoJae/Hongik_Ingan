import 'package:flutter/animation.dart';

/// Shared timing for content changes and coordinated home layout transitions.
abstract final class AppMotion {
  static const contentDuration = Duration(milliseconds: 220);
  static const layoutDuration = Duration(milliseconds: 400);

  static const layoutIncomingCurve = Interval(
    0.2,
    0.7,
    curve: Curves.easeInOutCubic,
  );
  static const layoutOutgoingCurve = Interval(
    0,
    0.35,
    curve: Curves.easeOutCubic,
  );

  // AnimatedSwitcher reverses its outgoing animation from 1 to 0.
  static const layoutSwitchOutCurve = Interval(
    0.65,
    1,
    curve: Curves.easeInCubic,
  );
}
