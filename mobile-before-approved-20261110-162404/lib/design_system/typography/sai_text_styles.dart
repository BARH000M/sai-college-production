import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/sai_theme.dart';

/// Typography scale used by the design system.
///
/// Sizes are deliberately small and refined, matching the approved mockups
/// (body copy 11–13, card titles 12.5–14, screen titles 15–17). Every style is
/// Cairo-based so a font swap lands in `saiTheme` only.
abstract final class SaiTextStyles {
  static const String _family = 'Cairo';

  static const TextStyle screenTitle = TextStyle(
    fontFamily: _family,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: SaiColors.ink,
    height: 1.4,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: SaiColors.ink,
    height: 1.4,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: _family,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: SaiColors.ink,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: SaiColors.ink,
    height: 1.7,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: _family,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: SaiColors.ink,
    height: 1.6,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _family,
    fontSize: 10.5,
    fontWeight: FontWeight.w400,
    color: SaiColors.muted,
    height: 1.6,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: SaiColors.ink,
    height: 1.5,
  );

  static const TextStyle numeric = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: SaiColors.ink,
    height: 1.3,
  );
}