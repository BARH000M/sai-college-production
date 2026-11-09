import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/sai_theme.dart';

/// Tone of a [SaiStatStrip].
enum SaiStatTone { gold, cream }

/// One figure in a [SaiStatStrip].
class SaiStatItem {
  const SaiStatItem({
    required this.label,
    required this.value,
    this.color = SaiColors.ink,
  });

  final String label;
  final String value;
  final Color color;
}

/// The tinted figure strip that sits under a section header.
///
/// The classes screen and the attendance register each hand-build this shape;
/// naming it gives later modules the same summary treatment.
class SaiStatStrip extends StatelessWidget {
  const SaiStatStrip({
    super.key,
    required this.items,
    this.tone = SaiStatTone.gold,
  });

  final List<SaiStatItem> items;
  final SaiStatTone tone;

  @override
  Widget build(BuildContext context) {
    final isGold = tone == SaiStatTone.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isGold ? SaiColors.goldTint : SaiColors.creamDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGold
              ? SaiColors.gold.withValues(alpha: 0.28)
              : SaiColors.border,
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 22,
                color: SaiColors.gold.withValues(alpha: 0.25),
              ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    items[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: items[i].color,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    items[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: SaiColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}