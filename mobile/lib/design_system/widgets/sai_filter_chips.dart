import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/sai_theme.dart';

/// One selectable option for [SaiFilterChips].
class SaiFilterOption {
  const SaiFilterOption({required this.value, required this.label, this.count});

  final String value;
  final String label;

  /// Optional badge count shown next to the label.
  final int? count;
}

/// Horizontally scrollable segmented filter row.
///
/// Mirrors the chip row already used by the roles screen so every module gets
/// identical filter behaviour instead of re-implementing the styling.
class SaiFilterChips extends StatelessWidget {
  const SaiFilterChips({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<SaiFilterOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 7),
              child: _SaiFilterChip(
                option: option,
                selected: option.value == selectedValue,
                onTap: () => onSelected(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SaiFilterChip extends StatelessWidget {
  const _SaiFilterChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SaiFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? SaiColors.maroon : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? SaiColors.maroon : SaiColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : SaiColors.ink,
              ),
            ),
            if (option.count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : SaiColors.creamDeep,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${option.count}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : SaiColors.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}