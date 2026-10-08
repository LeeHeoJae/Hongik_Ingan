import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Animates visual geometry without feeding scaled sizes back into layout.
class HomeMobileHeader extends StatelessWidget {
  const HomeMobileHeader({
    super.key,
    required this.top,
    required this.scale,
    required this.width,
    required this.child,
  });

  final double top;
  final double scale;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<HomeMobileHeaderGeometry>(
      tween: _HeaderGeometryTween(
        end: HomeMobileHeaderGeometry(top: top, scale: scale),
      ),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      child: child,
      builder: (context, geometry, child) => Stack(
        children: [
          Positioned(
            top: geometry.top,
            left: 0,
            child: Transform.scale(
              alignment: Alignment.topLeft,
              scale: geometry.scale,
              child: SizedBox(width: width / geometry.scale, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeMobileHeaderGeometry {
  const HomeMobileHeaderGeometry({required this.top, required this.scale});

  final double top;
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is HomeMobileHeaderGeometry &&
      other.top == top &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(top, scale);
}

class _HeaderGeometryTween extends Tween<HomeMobileHeaderGeometry> {
  _HeaderGeometryTween({required HomeMobileHeaderGeometry end})
    : super(end: end);

  @override
  HomeMobileHeaderGeometry lerp(double t) => HomeMobileHeaderGeometry(
    top: lerpDouble(begin!.top, end!.top, t)!,
    scale: lerpDouble(begin!.scale, end!.scale, t)!,
  );
}
