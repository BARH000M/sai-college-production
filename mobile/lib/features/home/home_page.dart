import 'package:flutter/material.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/feature_catalog.dart';
import '../../core/sai_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.identity,
    required this.role,
    required this.onOpenModules,
    required this.onOpenFeature,
  });

  final AppIdentity identity;
  final AppRole role;
  final VoidCallback onOpenModules;
  final ValueChanged<FeatureModule> onOpenFeature;

  @override
  Widget build(BuildContext context) {
    final available = modulesForRole(role).where((module) => module.id != 'home').toList();
    final preferredIds = switch (role) {
      AppRole.student => ['courses', 'homework', 'review', 'timetable'],
      AppRole.parent => ['students', 'attendance', 'finance', 'timetable'],
      AppRole.teacher => ['academics', 'attendance', 'homework', 'courses'],
      AppRole.accountant => ['finance', 'reports', 'attendance', 'staff'],
      AppRole.receptionist => ['admissions', 'reception', 'students', 'attendance'],
      AppRole.librarian => ['library', 'students', 'communications', 'reports'],
      AppRole.contentEditor => ['authoring', 'media', 'approvals', 'courses'],
      AppRole.admin || AppRole.superAdmin => ['admissions', 'students', 'academics', 'finance'],
    };
    final shortcuts = <FeatureModule>[];
    for (final id in preferredIds) {
      for (final module in available) {
        if (module.id == id && !shortcuts.contains(module)) shortcuts.add(module);
      }
    }
    for (final module in available) {
      if (shortcuts.length >= 4) break;
      if (!shortcuts.contains(module)) shortcuts.add(module);
    }
    final firstName = identity.fullName.trim().split(RegExp(r'\s+')).first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [SaiColors.navy, Color(0xFF263A79)],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مرحبًا، $firstName', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text(role.label, style: const TextStyle(color: Color(0xFFD9E0FA), fontSize: 13)),
              const SizedBox(height: 20),
              const Text('بوابتك إلى خدمات كلية ساي', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'اختر خدمة متاحة لحسابك. تُحمّل البيانات من النظام بصلاحيات حسابك.',
                style: TextStyle(color: Color(0xFFE3E8F7), height: 1.7, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Text('الوصول السريع', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
            TextButton(onPressed: onOpenModules, child: const Text('كل الخدمات')),
          ],
        ),
        const SizedBox(height: 8),
        if (shortcuts.isEmpty)
          const _InfoCard(text: 'لا توجد وحدات مسندة لهذا الدور. راجع مسؤول النظام.'),
        ...shortcuts.map((module) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ShortcutCard(module: module, onTap: () => onOpenFeature(module)),
            )),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined, color: SaiColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تُعرض الخدمات حسب الأدوار المسندة لحسابك، وتظل صلاحيات البيانات مطبقة في قاعدة البيانات.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SaiColors.muted, height: 1.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.module, required this.onTap});
  final FeatureModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFFFFE9EC), borderRadius: BorderRadius.circular(14)),
                child: Icon(module.icon, color: SaiColors.red),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.label, style: const TextStyle(fontWeight: FontWeight.w700, color: SaiColors.navy)),
                    const SizedBox(height: 3),
                    Text(module.pillar, style: const TextStyle(fontSize: 12, color: SaiColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: SaiColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, style: const TextStyle(color: SaiColors.muted, height: 1.7)),
        ),
      );
}
