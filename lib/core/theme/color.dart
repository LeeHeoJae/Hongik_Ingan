import 'package:flutter/material.dart';

final class AppColor {
  // Primary Color
  static const hkMidnightBlue = Color(0xFF05014A);
  static const hkMediumBlue = Color(0xFF1833DB);

  // Secondary Color
  static const hkWhite = Color(0xFFFFFFFF);
  static const hkBlack = Color(0xFF000000);

  // Shade Color
  static const hkBrightGray = Color(0xFFEEEEF0);
  static const hkLightGray = Color(0xFFD0D0D2);
  static const hkMediumGray = Color(0xFF989A9F);
  static const hkDarkGray = Color(0xFF53565F);
  static const hkStoneGray = Color(0xFF313339);

  // Highlight Color: Blue
  static const hkNavy = Color(0xFF020079);
  static const hkAzureBlue = Color(0xFF0381FE);
  static const hkMint = Color(0xFF69EBFF);

  // Highlight Color: Wow
  static const wowSealBrown = Color(0xFF3a1F04);
  static const wowBrick = Color(0xFF99522C);
  static const wowAutumn = Color(0xFFD2691E);
  static const wowSand = Color(0xFFC2B280);
  static const wowBeige = Color(0xFFF5F5DC);
  static const wowGreen = Color(0xFF22D979);
  static const wowSpringGreen = Color(0xFFC2F2D6);
  static const wowGoldenYellow = Color(0xFFF3E600);
  static const wowRed = Color(0xFFFF4433);
}

@immutable
final class HongikPalette extends ThemeExtension<HongikPalette> {
  const HongikPalette({
    required this.brandNavy,
    required this.brandBlue,
    required this.brandRed,
    required this.success,
    required this.warning,
    required this.cardSurface,
    required this.cardSurfaceMuted,
    required this.cardOutline,
    required this.cardShadow,
    required this.textSecondary,
    required this.seatAvailable,
    required this.seatModerate,
    required this.seatCrowded,
  });

  final Color brandNavy;
  final Color brandBlue;
  final Color brandRed;
  final Color success;
  final Color warning;
  final Color cardSurface;
  final Color cardSurfaceMuted;
  final Color cardOutline;
  final Color cardShadow;
  final Color textSecondary;
  final Color seatAvailable;
  final Color seatModerate;
  final Color seatCrowded;

  static const light = HongikPalette(
    brandNavy: AppColor.hkMidnightBlue,
    brandBlue: AppColor.hkAzureBlue,
    brandRed: AppColor.wowRed,
    success: AppColor.wowGreen,
    warning: AppColor.wowAutumn,
    cardSurface: AppColor.hkWhite,
    cardSurfaceMuted: AppColor.hkBrightGray,
    cardOutline: AppColor.hkLightGray,
    cardShadow: Color(0x16000000),
    textSecondary: AppColor.hkDarkGray,
    seatAvailable: AppColor.wowGreen,
    seatModerate: AppColor.hkAzureBlue,
    seatCrowded: AppColor.wowRed,
  );

  static const dark = HongikPalette(
    brandNavy: AppColor.hkAzureBlue,
    brandBlue: AppColor.hkAzureBlue,
    brandRed: AppColor.wowRed,
    success: AppColor.wowGreen,
    warning: AppColor.wowGoldenYellow,
    cardSurface: AppColor.hkStoneGray,
    cardSurfaceMuted: AppColor.hkDarkGray,
    cardOutline: AppColor.hkMediumGray,
    cardShadow: Color(0x66000000),
    textSecondary: AppColor.hkLightGray,
    seatAvailable: AppColor.wowGreen,
    seatModerate: AppColor.hkAzureBlue,
    seatCrowded: AppColor.wowRed,
  );

  @override
  HongikPalette copyWith({
    Color? brandNavy,
    Color? brandBlue,
    Color? brandRed,
    Color? success,
    Color? warning,
    Color? cardSurface,
    Color? cardSurfaceMuted,
    Color? cardOutline,
    Color? cardShadow,
    Color? textSecondary,
    Color? seatAvailable,
    Color? seatModerate,
    Color? seatCrowded,
  }) {
    return HongikPalette(
      brandNavy: brandNavy ?? this.brandNavy,
      brandBlue: brandBlue ?? this.brandBlue,
      brandRed: brandRed ?? this.brandRed,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      cardSurface: cardSurface ?? this.cardSurface,
      cardSurfaceMuted: cardSurfaceMuted ?? this.cardSurfaceMuted,
      cardOutline: cardOutline ?? this.cardOutline,
      cardShadow: cardShadow ?? this.cardShadow,
      textSecondary: textSecondary ?? this.textSecondary,
      seatAvailable: seatAvailable ?? this.seatAvailable,
      seatModerate: seatModerate ?? this.seatModerate,
      seatCrowded: seatCrowded ?? this.seatCrowded,
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
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      cardSurfaceMuted: Color.lerp(
        cardSurfaceMuted,
        other.cardSurfaceMuted,
        t,
      )!,
      cardOutline: Color.lerp(cardOutline, other.cardOutline, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      seatAvailable: Color.lerp(seatAvailable, other.seatAvailable, t)!,
      seatModerate: Color.lerp(seatModerate, other.seatModerate, t)!,
      seatCrowded: Color.lerp(seatCrowded, other.seatCrowded, t)!,
    );
  }
}
