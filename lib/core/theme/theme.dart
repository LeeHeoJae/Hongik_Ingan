import 'package:flutter/material.dart';

import 'color.dart';

var themeData = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.hkBrightGray,
  fontFamily: 'NotoSansKR',
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: AppColor.hkMidnightBlue,
        primary: AppColor.hkMidnightBlue,
        onPrimary: AppColor.hkWhite,
        secondary: AppColor.hkAzureBlue,
        onSecondary: AppColor.hkMidnightBlue,
        surface: AppColor.hkWhite,
        brightness: Brightness.light,
      ).copyWith(
        primaryContainer: AppColor.hkBrightGray,
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
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColor.hkMidnightBlue,
    foregroundColor: AppColor.hkWhite,
    centerTitle: true,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColor.hkMidnightBlue,
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
      fontSize: 20,
      fontWeight: .bold,
      color: AppColor.hkMidnightBlue,
    ),
    contentTextStyle: const TextStyle(fontSize: 15, color: Colors.black87),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColor.hkAzureBlue,
      disabledForegroundColor: AppColor.hkMediumGray,
      textStyle: const TextStyle(fontWeight: .bold, fontSize: 15),
    ),
  ),
);

var darkThemeData = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.darkBackground,
  fontFamily: 'NotoSansKR',
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
      fontSize: 20,
      fontWeight: .bold,
      color: AppColor.darkTextPrimary,
    ),
    contentTextStyle: const TextStyle(
      fontSize: 15,
      color: AppColor.darkTextSecondary,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColor.darkAccentBlue,
      disabledForegroundColor: AppColor.hkMediumGray,
      textStyle: const TextStyle(fontWeight: .bold, fontSize: 15),
    ),
  ),
);
