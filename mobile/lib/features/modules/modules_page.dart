import 'package:flutter/material.dart';

import '../../core/app_role.dart';
import '../../core/feature_catalog.dart';
import '../../core/sai_theme.dart';

class ModulesPage extends StatelessWidget {
  const ModulesPage({super.key, required this.role, required this.onOpenFeature});

  final AppRole role;
  final ValueChanged<FeatureModule> onOpenFeature;

  @override
  Widget build(BuildContext context) {
    final modules = modulesForRole(role).where((module) => module.id != 'home').toList();
    final groups = <String, List<FeatureModule>>{};
    for (final module in modules) {
      groups.putIfAbsent(module.pillar, () => []).add(module);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(color: SaiColors.maroon, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.grid_view_outlined, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('كل الخدمات', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('الوحدات المتاحة لدورك الحالي', style: TextStyle(color: Color(0xFFEBC98A), fontSize: 9.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const Text('لا توجد وحدات متاحة لهذا الدور.'),
        ...groups.entries.map((entry) => _ModuleGroup(
              title: entry.key,
              modules: entry.value,
              onOpenFeature: onOpenFeature,
            )),
      ],
    );
  }
}

class _ModuleGroup extends StatelessWidget {
  const _ModuleGroup({required this.title, required this.modules, required this.onOpenFeature});
  final String title;
  final List<FeatureModule> modules;
  final ValueChanged<FeatureModule> onOpenFeature;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
            child: Row(
              children: [
                Container(width: 3, height: 12, decoration: BoxDecoration(color: SaiColors.maroon, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(color: SaiColors.ink, fontWeight: FontWeight.w700, fontSize: 11.5)),
              ],
            ),
          ),
          ...modules.map((module) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Card(
                  child: ListTile(
                    onTap: () => onOpenFeature(module),
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: SaiColors.maroonTint, borderRadius: BorderRadius.circular(11)),
                      child: Icon(module.icon, size: 19, color: SaiColors.maroon),
                    ),
                    title: Text(module.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: SaiColors.ink)),
                    subtitle: Text(module.tabs.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: SaiColors.muted)),
                    trailing: const Icon(Icons.chevron_left, size: 17, color: SaiColors.muted),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
