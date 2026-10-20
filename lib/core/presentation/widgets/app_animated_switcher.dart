import 'package:flutter/material.dart';

import '../app_motion.dart';

class AppAnimatedSwitcher extends StatelessWidget {
  const AppAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = AppMotion.contentDuration,
    this.reverseDuration,
    this.switchInCurve = Curves.easeOutCubic,
    this.switchOutCurve = Curves.easeInCubic,
    this.slideOffset = Offset.zero,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  });

  final Widget child;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve switchInCurve;
  final Curve switchOutCurve;
  final Offset slideOffset;
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  /// Keeps departing content at [width] without including its height in layout.
  static AnimatedSwitcherLayoutBuilder layoutForCurrentChild(double width) =>
      (current, previous) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topLeft,
        children: [
          for (final outgoing in previous)
            Positioned(top: 0, left: 0, width: width, child: outgoing),
          current ?? const SizedBox.shrink(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : duration,
      reverseDuration: reduceMotion
          ? Duration.zero
          : reverseDuration ?? duration,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      layoutBuilder: reduceMotion
          ? (currentChild, previousChildren) =>
                currentChild ?? const SizedBox.shrink()
          : layoutBuilder,
      transitionBuilder: (child, animation) {
        final fadedChild = FadeTransition(
          opacity: reduceMotion ? kAlwaysCompleteAnimation : animation,
          child: AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) {
              final outgoing =
                  animation.status == AnimationStatus.reverse ||
                  animation.status == AnimationStatus.dismissed;
              return IgnorePointer(
                ignoring: outgoing,
                child: ExcludeFocus(
                  excluding: outgoing,
                  child: ExcludeSemantics(excluding: outgoing, child: child!),
                ),
              );
            },
          ),
        );
        if (slideOffset == Offset.zero || reduceMotion) {
          return fadedChild;
        }

        return SlideTransition(
          position: Tween<Offset>(
            begin: slideOffset,
            end: Offset.zero,
          ).animate(animation),
          child: fadedChild,
        );
      },
      child: child,
    );
  }
}
