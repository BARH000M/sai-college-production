import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/sai_theme.dart';

/// The standard white card used across the application: 14px radius, hairline
/// border, no elevation.
///
/// This container is currently re-typed by hand in most screens; naming it lets
/// later modules stop repeating the decoration.
class SaiCard extends StatelessWidget {
  const SaiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.backgroundColor = Colors.white,
    this.borderColor = SaiColors.border,
    this.radius = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final body = Padding(padding: padding, child: child);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
      ),
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: body,
            ),
    );
  }
}