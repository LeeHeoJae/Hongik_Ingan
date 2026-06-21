import 'package:flutter/material.dart';

import 'color.dart';

var themeData = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColor.hkBrightGray,
  fontFamily: 'NotoSansKR',
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColor.hkMidnightBlue,
    primary: AppColor.hkMidnightBlue,
    secondary: AppColor.hkAzureBlue,
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
      backgroundColor: AppColor.hkAzureBlue,
      foregroundColor: AppColor.hkWhite,
      elevation: 4,
      shadowColor: AppColor.hkAzureBlue.withValues(alpha: 0.26),
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
    secondary: AppColor.hkMediumBlue,
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
      foregroundColor: AppColor.hkWhite,
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
      textStyle: const TextStyle(fontWeight: .bold, fontSize: 15),
    ),
  ),
);
