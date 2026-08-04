import 'package:flutter/material.dart';

import 'color.dart';

var themeData = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.hkBrightGray,
  fontFamily: 'NotoSansKR',
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColor.hkMidnightBlue,
    primary: AppColor.hkMidnightBlue,
    onPrimary: AppColor.hkWhite,
    secondary: AppColor.hkAzureBlue,
    onSecondary: AppColor.hkMidnightBlue,
    surface: AppColor.hkWhite,
    brightness: Brightness.light,
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
  scaffoldBackgroundColor: AppColor.hkBlack,
  fontFamily: 'NotoSansKR',
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColor.hkMidnightBlue,
    primary: AppColor.hkAzureBlue,
    onPrimary: AppColor.hkMidnightBlue,
    secondary: AppColor.hkMint,
    onSecondary: AppColor.hkMidnightBlue,
    surface: AppColor.hkStoneGray,
    brightness: Brightness.dark,
  ),
  extensions: const [HongikPalette.dark],
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColor.hkStoneGray,
    foregroundColor: AppColor.hkWhite,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColor.hkAzureBlue,
      foregroundColor: AppColor.hkMidnightBlue,
      disabledBackgroundColor: AppColor.hkDarkGray,
      disabledForegroundColor: AppColor.hkLightGray,
      elevation: 2,
      shadowColor: Colors.transparent,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColor.hkMint, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColor.hkDarkGray),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColor.hkWhite.withValues(alpha: 0.14)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColor.hkStoneGray,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: .circular(16)),
    titleTextStyle: const TextStyle(
      fontSize: 20,
      fontWeight: .bold,
      color: AppColor.hkWhite,
    ),
    contentTextStyle: TextStyle(
      fontSize: 15,
      color: AppColor.hkWhite.withValues(alpha: 0.8),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColor.hkAzureBlue,
      disabledForegroundColor: AppColor.hkMediumGray,
      textStyle: const TextStyle(fontWeight: .bold, fontSize: 15),
    ),
  ),
);
