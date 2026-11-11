import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/sai_theme.dart';
import '../typography/sai_text_styles.dart';
import 'sai_card.dart';

/// Figure tile used for dashboard summaries: tinted icon, value, caption.
class SaiMetricCard extends StatelessWidget {
  const SaiMetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accentColor = SaiColors.maroon,
    this.tint = SaiColors.maroonTint,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SaiCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: accentColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SaiTextStyles.numeric.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SaiTextStyles.caption,
          ),
        ],
      ),
    );
  }
}