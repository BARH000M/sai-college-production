import 'package:flutter/material.dart';

abstract final class SaiColors {
  static const red = Color(0xFFD00018);
  static const deepRed = Color(0xFFAE0011);
  static const navy = Color(0xFF111D52);
  static const gold = Color(0xFFD8A52F);
  static const background = Color(0xFFF4F6FB);
  static const border = Color(0xFFE1E6F0);
  static const muted = Color(0xFF7A88A5);
  static const success = Color(0xFF23845B);
  static const warning = Color(0xFFB87912);
}

final saiTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Cairo',
  colorScheme: ColorScheme.fromSeed(
    seedColor: SaiColors.red,
    primary: SaiColors.red,
    onPrimary: Colors.white,
    secondary: SaiColors.gold,
    surface: Colors.white,
    onSurface: SaiColors.navy,
    error: SaiColors.deepRed,
  ),
  scaffoldBackgroundColor: SaiColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: SaiColors.navy,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: SaiColors.border),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SaiColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SaiColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SaiColors.red, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: SaiColors.red,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: const Color(0xFFFFE9EC),
    height: 72,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    labelTextStyle: WidgetStateProperty.all(
      const TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.w600),
    ),
  ),
);
