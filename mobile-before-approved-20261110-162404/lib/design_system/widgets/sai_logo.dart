import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/sai_theme.dart';
import '../assets/app_assets.dart';

/// The official college crest.
///
/// Used by the login screen (plain rounded image) and by the embedded screen
/// headers (bordered white square, app-bar style).
class SaiLogo extends StatelessWidget {
  const SaiLogo({super.key, this.size = 46, this.framed = false});

  final double size;

  /// When true the crest sits inside a bordered white square.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final crest = Image.asset(
      AppAssets.saiLogo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.school, size: size * 0.7, color: SaiColors.maroon),
    );

    if (!framed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: crest,
      );
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: SaiColors.border),
      ),
      child: crest,
    );
  }
}