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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text('خدماتك', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: SaiColors.navy)),
        const SizedBox(height: 4),
        Text('الوحدات المتاحة لدور ${role.label}', style: const TextStyle(color: SaiColors.muted)),
        const SizedBox(height: 20),
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
            child: Text(title, style: const TextStyle(color: SaiColors.red, fontWeight: FontWeight.w700)),
          ),
          ...modules.map((module) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: ListTile(
                    onTap: () => onOpenFeature(module),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFE9EC),
                      foregroundColor: SaiColors.red,
                      child: Icon(module.icon),
                    ),
                    title: Text(module.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(module.tabs.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_left),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
