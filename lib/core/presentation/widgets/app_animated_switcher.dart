import 'package:flutter/material.dart';

class AppAnimatedSwitcher extends StatelessWidget {
  const AppAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.reverseDuration,
    this.slideOffset = Offset.zero,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  });

  final Widget child;
  final Duration duration;
  final Duration? reverseDuration;
  final Offset slideOffset;
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : duration,
      reverseDuration: reduceMotion
          ? Duration.zero
          : reverseDuration ?? duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: layoutBuilder,
      transitionBuilder: (child, animation) {
        if (reduceMotion) {
          return child;
        }

        final fadedChild = FadeTransition(opacity: animation, child: child);
        if (slideOffset == Offset.zero) {
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
