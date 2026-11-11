import 'package:flutter/material.dart';

/// Palette taken from the SAI College mobile mockup: warm cream paper,
/// maroon brand colour, muted gold seal accents.
abstract final class SaiColors {
  static const maroon = Color(0xFF8E1116);
  static const maroonDeep = Color(0xFF69090D);
  static const maroonTint = Color(0xFFF8E7E8);
  static const gold = Color(0xFFC9A24B);
  static const goldTint = Color(0xFFF8F0DE);
  static const cream = Color(0xFFFBF6EA);
  static const creamDeep = Color(0xFFF3EBD8);
  static const ink = Color(0xFF2C2621);
  static const muted = Color(0xFF8B8078);
  static const border = Color(0xFFEBE2D1);
  static const success = Color(0xFF2F9E6B);
  static const successTint = Color(0xFFE7F5EC);
  static const warning = Color(0xFFB57F10);
  static const warningTint = Color(0xFFFCF2DC);
  static const danger = Color(0xFFBC3B2E);
  static const dangerTint = Color(0xFFFBE8E6);

  // Aliases kept so previously written screens keep compiling.
  static const red = maroon;
  static const deepRed = maroonDeep;
  static const navy = ink;
  static const background = cream;
}

final saiTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Cairo',
  colorScheme: ColorScheme.fromSeed(
    seedColor: SaiColors.maroon,
    primary: SaiColors.maroon,
    onPrimary: Colors.white,
    secondary: SaiColors.gold,
    surface: Colors.white,
    onSurface: SaiColors.ink,
    error: SaiColors.danger,
  ),
  scaffoldBackgroundColor: SaiColors.cream,
  appBarTheme: const AppBarTheme(
    backgroundColor: SaiColors.cream,
    foregroundColor: SaiColors.ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: SaiColors.border),
    ),
  ),
  dividerTheme: const DividerThemeData(color: SaiColors.border, thickness: 1, space: 1),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    hintStyle: const TextStyle(fontSize: 12.5, color: SaiColors.muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SaiColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SaiColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SaiColors.maroon, width: 1.4),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      backgroundColor: SaiColors.maroon,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      foregroundColor: SaiColors.ink,
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      side: const BorderSide(color: SaiColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: SaiColors.maroon,
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    side: const BorderSide(color: SaiColors.border),
    labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600, color: SaiColors.ink),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    indicatorColor: Colors.transparent,
    height: 70,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(
        fontFamily: 'Cairo',
        fontSize: 9.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: selected ? SaiColors.maroon : SaiColors.muted,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(size: 22, color: selected ? SaiColors.maroon : SaiColors.muted);
    }),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: SaiColors.ink,
    contentTextStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 12.5),
    behavior: SnackBarBehavior.floating,
  ),
);