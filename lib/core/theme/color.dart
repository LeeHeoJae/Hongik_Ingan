import 'package:flutter/material.dart';

final class AppColor {
  static const hkMidnightBlue = Color(0xFF05014A);
  static const hkMediumBlue = Color(0xFF1833DB);
  static const hkAzureBlue = Color(0xFF0381FE);
  static const hkBrightGray = Color(0xFFEEEEF0);
  static const hkStoneGray = Color(0xFF313339);
  static const wowGreen = Color(0xFF22D979);
  static const wowRed = Color(0XFFFF4433);
}

@immutable
final class HongikPalette extends ThemeExtension<HongikPalette> {
  const HongikPalette({
    required this.brandNavy,
    required this.brandBlue,
    required this.brandRed,
    required this.success,
    required this.warning,
  });

  final Color brandNavy;
  final Color brandBlue;
  final Color brandRed;
  final Color success;
  final Color warning;

  static const light = HongikPalette(
    brandNavy: AppColor.hkMidnightBlue,
    brandBlue: AppColor.hkAzureBlue,
    brandRed: Color(0xFFE31B23),
    success: AppColor.wowGreen,
    warning: Color(0xFFFFB020),
  );

  static const dark = HongikPalette(
    brandNavy: Color(0xFF8EA2FF),
    brandBlue: Color(0xFF64B5FF),
    brandRed: Color(0xFFFF6B70),
    success: Color(0xFF55E29A),
    warning: Color(0xFFFFC857),
  );

  @override
  HongikPalette copyWith({
    Color? brandNavy,
    Color? brandBlue,
    Color? brandRed,
    Color? success,
    Color? warning,
  }) {
    return HongikPalette(
      brandNavy: brandNavy ?? this.brandNavy,
      brandBlue: brandBlue ?? this.brandBlue,
      brandRed: brandRed ?? this.brandRed,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  HongikPalette lerp(ThemeExtension<HongikPalette>? other, double t) {
    if (other is! HongikPalette) {
      return this;
    }
    return HongikPalette(
      brandNavy: Color.lerp(brandNavy, other.brandNavy, t)!,
      brandBlue: Color.lerp(brandBlue, other.brandBlue, t)!,
      brandRed: Color.lerp(brandRed, other.brandRed, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
