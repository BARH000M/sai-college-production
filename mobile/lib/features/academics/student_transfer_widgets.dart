import 'package:flutter/material.dart';

import '../../core/sai_theme.dart';
import 'class_models.dart';

/// Numbered section used by the student transfer screen.
class TransferStepCard extends StatelessWidget {
  const TransferStepCard({
    super.key,
    required this.index,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String index;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: SaiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: SaiColors.maroon, shape: BoxShape.circle),
                child: Text(
                  index,
                  style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: SaiColors.ink),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

/// Class picker showing each class with its remaining seats.
class TransferClassDropdown extends StatelessWidget {
  const TransferClassDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final SaiClass? value;
  final List<SaiClass> items;
  final ValueChanged<SaiClass?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final known = value != null && items.any((item) => item.id == value!.id);
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: SaiColors.cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SaiColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: known ? value!.id : null,
          isExpanded: true,
          hint: Text(hint ?? label, style: const TextStyle(fontSize: 11.5, color: SaiColors.muted)),
          icon: const Icon(Icons.expand_more, size: 18, color: SaiColors.muted),
          style: const TextStyle(
              fontSize: 11.5, fontFamily: 'Cairo', color: SaiColors.ink, fontWeight: FontWeight.w600),
          items: items
              .map((item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(
                      '${item.name} · متاح ${item.available}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            final match = items.where((item) => item.id == id).toList();
            onChanged(match.isEmpty ? null : match.first);
          },
        ),
      ),
    );
  }
}

/// Live seats summary for the destination class, warning when the selection
/// exceeds the remaining capacity.
class TransferCapacityPanel extends StatelessWidget {
  const TransferCapacityPanel({
    super.key,
    required this.destination,
    required this.selectedCount,
    required this.overCapacity,
  });

  final SaiClass destination;
  final int selectedCount;
  final bool overCapacity;

  @override
  Widget build(BuildContext context) {
    final free = destination.available;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: overCapacity ? SaiColors.dangerTint : SaiColors.goldTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: overCapacity
              ? SaiColors.danger.withValues(alpha: 0.3)
              : SaiColors.gold.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _CapStat(label: 'المسجلون', value: '${destination.enrolled}'),
              _CapStat(label: 'السعة', value: '${destination.capacity}'),
              _CapStat(label: 'المتاح', value: '$free'),
              _CapStat(label: 'المحدد', value: '$selectedCount'),
            ],
          ),
          if (overCapacity) ...[
            const SizedBox(height: 7),
            Text(
              free <= 0
                  ? 'الصف الهدف ممتلئ — اختر صفاً آخر أو ارفع السعة من شاشة الصفوف.'
                  : 'المحدد أكبر من المقاعد المتاحة ($free). خفّف التحديد أو اختر صفاً آخر.',
              style: const TextStyle(
                  fontSize: 10, height: 1.6, fontWeight: FontWeight.w600, color: SaiColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class _CapStat extends StatelessWidget {
  const _CapStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SaiColors.ink)),
          Text(label, style: const TextStyle(fontSize: 9, color: SaiColors.muted)),
        ],
      ),
    );
  }
}