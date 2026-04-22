import 'package:flutter/material.dart';

import 'color.dart';

var themeData = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.hkBrightGray,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColor.hkMidnightBlue,
    primary: AppColor.hkMidnightBlue,
    secondary: AppColor.hkAzureBlue,
    surface: Colors.white,
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColor.hkMidnightBlue,
    foregroundColor: Colors.white,
    centerTitle: true,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColor.hkAzureBlue,
      foregroundColor: Colors.white,
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
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
      textStyle: const TextStyle(fontWeight: .bold, fontSize: 15),
    ),
  ),
);

var darkThemeData = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFF121212),
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColor.hkMidnightBlue,
    primary: AppColor.hkAzureBlue,
    secondary: AppColor.hkMediumBlue,
    surface: AppColor.hkStoneGray,
    brightness: Brightness.dark,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColor.hkStoneGray,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColor.hkAzureBlue,
      foregroundColor: Colors.white,
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColor.hkStoneGray,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: .circular(16)),
    titleTextStyle: const TextStyle(
      fontSize: 20,
      fontWeight: .bold,
      color: Colors.white,
    ),
    contentTextStyle: TextStyle(
      fontSize: 15,
      color: Colors.white.withValues(alpha: 0.8),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColor.hkAzureBlue,
      textStyle: const TextStyle(fontWeight: .bold, fontSize: 15),
    ),
  ),
);
