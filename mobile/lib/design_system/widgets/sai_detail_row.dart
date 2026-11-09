import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/sai_theme.dart';

/// One `label : value` line used inside detail sheets and record cards.
///
/// Consolidates the `_InfoLine`, `_DataLine` and `_FieldLabel` variants that
/// were each written separately per screen.
class SaiDetailRow extends StatelessWidget {
  const SaiDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.labelWidth = 88,
    this.valueMaxLines = 2,
  });

  final String label;
  final String value;
  final IconData? icon;
  final double labelWidth;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: SaiColors.muted),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: SaiColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: valueMaxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SaiColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}