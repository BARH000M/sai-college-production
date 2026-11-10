import 'package:flutter/material.dart';

class SaiColors {
  static const red = Color(0xFF9B1025),
      gold = Color(0xFFC59A4D),
      ink = Color(0xFF20242B),
      muted = Color(0xFF78808B),
      bg = Color(0xFFF7F8FA),
      line = Color(0xFFE8EAED);
}

ThemeData saiTheme() {
  final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(seedColor: SaiColors.red),
      scaffoldBackgroundColor: SaiColors.bg);
  return base.copyWith(
      textTheme: base.textTheme
          .apply(bodyColor: SaiColors.ink, displayColor: SaiColors.ink),
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: SaiColors.ink,
          elevation: 0,
          centerTitle: false),
      cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: SaiColors.line))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SaiColors.line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SaiColors.line))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: SaiColors.red,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))));
}
