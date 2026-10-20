import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The engine may already report an inset; never subtract the keyboard twice.
MediaQueryData keyboardOverlayMedia(
  MediaQueryData media,
  double keyboardHeight,
) {
  if (keyboardHeight <= 0 || !keyboardHeight.isFinite) return media;
  final bottom = math
      .max(media.viewInsets.bottom, keyboardHeight)
      .clamp(0.0, media.size.height)
      .toDouble();
  return media.copyWith(
    viewInsets: media.viewInsets.copyWith(bottom: bottom),
    padding: media.padding.copyWith(
      bottom: math.max(0.0, media.viewPadding.bottom - bottom),
    ),
  );
}
