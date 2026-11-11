import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/sai_theme.dart';
import '../typography/sai_text_styles.dart';
import 'sai_card.dart';

/// Standard card row: tinted leading icon, title, subtitle and a chevron.
///
/// Replaces the per-screen tile variants so cards, spacing and hit areas stay
/// identical across modules.
class SaiListTile extends StatelessWidget {
  const SaiListTile({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.accentColor = SaiColors.maroon,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color accentColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: SaiCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SaiTextStyles.bodyStrong,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SaiTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : const Icon(Icons.chevron_left,
                        size: 20, color: SaiColors.muted)),
          ],
        ),
      ),
    );
  }
}