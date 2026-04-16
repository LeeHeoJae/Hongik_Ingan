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
);
