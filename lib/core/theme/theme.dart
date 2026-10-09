import 'package:flutter/material.dart';

import 'color.dart';

var themeData = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.hkCanvas,
  fontFamily: 'Pretendard',
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: AppColor.hkMidnightBlue,
        primary: AppColor.hkActionBlue,
        onPrimary: AppColor.hkWhite,
        secondary: AppColor.hkAzureBlue,
        onSecondary: AppColor.hkMidnightBlue,
        surface: AppColor.hkWhite,
        brightness: Brightness.light,
      ).copyWith(
        primaryContainer: AppColor.hkAccentSurface,
        secondaryContainer: AppColor.hkSeatSurface,
        onSecondaryContainer: AppColor.hkMidnightBlue,
        tertiaryContainer: AppColor.hkMenuSurface,
        onTertiaryContainer: AppColor.hkStoneGray,
        onPrimaryContainer: AppColor.hkMidnightBlue,
        onSurface: AppColor.hkStoneGray,
        onSurfaceVariant: AppColor.hkDarkGray,
        surfaceContainerLowest: AppColor.hkWhite,
        surfaceContainerLow: AppColor.hkWhite,
        surfaceContainer: AppColor.hkBrightGray,
        surfaceContainerHigh: AppColor.hkLightGray,
        outline: AppColor.hkMediumGray,
        outlineVariant: AppColor.hkLightGray,
        surfaceTint: Colors.transparent,
      ),
  extensions: const [HongikPalette.light],
  tooltipTheme: const TooltipThemeData(
    waitDuration: Duration(milliseconds: 500),
    exitDuration: Duration.zero,
    preferBelow: false,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColor.hkMidnightBlue,
    foregroundColor: AppColor.hkWhite,
    centerTitle: true,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColor.hkActionBlue,
      foregroundColor: AppColor.hkWhite,
      disabledBackgroundColor: AppColor.hkLightGray,
      disabledForegroundColor: AppColor.hkDarkGray,
      elevation: 4,
      shadowColor: AppColor.hkMidnightBlue.withValues(alpha: 0.26),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColor.hkMediumBlue, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColor.hkLightGray),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColor.hkWhite,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: .circular(16)),
    titleTextStyle: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 20,
      fontWeight: .bold,
      color: AppColor.hkMidnightBlue,
    ),
    contentTextStyle: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 15,
      color: Colors.black87,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColor.hkMediumBlue,
      disabledForegroundColor: AppColor.hkMediumGray,
      textStyle: const TextStyle(
        fontFamily: 'Pretendard',
        fontWeight: .bold,
        fontSize: 15,
      ),
    ),
  ),
);

var darkThemeData = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.darkBackground,
  fontFamily: 'Pretendard',
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: AppColor.hkMidnightBlue,
        primary: AppColor.darkAccentBlue,
        onPrimary: AppColor.darkOnAccent,
        secondary: AppColor.darkAccentMint,
        onSecondary: AppColor.darkOnAccent,
        surface: AppColor.darkSurface,
        brightness: Brightness.dark,
      ).copyWith(
        primaryContainer: AppColor.darkAccentContainer,
        onPrimaryContainer: AppColor.darkOnAccentContainer,
        secondaryContainer: AppColor.darkSeatSurface,
        onSecondaryContainer: AppColor.darkSeatIcon,
        tertiaryContainer: AppColor.darkMenuSurface,
        onTertiaryContainer: AppColor.darkMenuIcon,
        error: AppColor.darkError,
        onError: AppColor.darkOnAccent,
        onSurface: AppColor.darkTextPrimary,
        onSurfaceVariant: AppColor.darkTextSecondary,
        surfaceDim: AppColor.darkBackground,
        surfaceBright: AppColor.darkSurfaceRaised,
        surfaceContainerLowest: AppColor.darkBackground,
        surfaceContainerLow: AppColor.darkSurface,
        surfaceContainer: AppColor.darkSurfaceMuted,
        surfaceContainerHigh: AppColor.darkSurfaceRaised,
        surfaceContainerHighest: AppColor.darkSurfaceRaised,
        outline: AppColor.darkCardOutline,
        outlineVariant: AppColor.darkCardOutline,
        surfaceTint: Colors.transparent,
      ),
  extensions: const [HongikPalette.dark],
  tooltipTheme: const TooltipThemeData(
    waitDuration: Duration(milliseconds: 500),
    exitDuration: Duration.zero,
    preferBelow: false,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColor.darkSurface,
    foregroundColor: AppColor.darkTextPrimary,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColor.darkAccentBlue,
      foregroundColor: AppColor.darkOnAccent,
      disabledBackgroundColor: AppColor.hkDarkGray,
      disabledForegroundColor: AppColor.darkTextSecondary,
      elevation: 2,
      shadowColor: Colors.transparent,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColor.darkAccentMint, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColor.hkDarkGray),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColor.darkCardOutline),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColor.darkSurface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: .circular(16)),
    titleTextStyle: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 20,
      fontWeight: .bold,
      color: AppColor.darkTextPrimary,
    ),
    contentTextStyle: const TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 15,
      color: AppColor.darkTextSecondary,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColor.darkAccentBlue,
      disabledForegroundColor: AppColor.hkMediumGray,
      textStyle: const TextStyle(
        fontFamily: 'Pretendard',
        fontWeight: .bold,
        fontSize: 15,
      ),
    ),
  ),
);
