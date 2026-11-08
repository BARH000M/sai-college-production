import 'package:flutter/material.dart';

import '../core/sai_theme.dart';

/// The maroon title bar that opens every mockup screen, with an optional
/// white action button sitting inside it.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.actionIcon = Icons.add,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(11, 9, 9, 9),
      decoration: BoxDecoration(
        color: SaiColors.maroon,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actionIcon, size: 14, color: SaiColors.maroon),
                    const SizedBox(width: 4),
                    Text(
                      actionLabel!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SaiColors.maroon),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small tinted status chip used on class cards and role rows.
class TintChip extends StatelessWidget {
  const TintChip({super.key, required this.label, required this.color, required this.tint, this.icon});

  final String label;
  final Color color;
  final Color tint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}