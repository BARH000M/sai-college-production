import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

import '../models/roles.dart';

class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key, required this.roles, required this.open});

  final Set<AppRole> roles;
  final void Function(Feature) open;

  @override
  Widget build(BuildContext context) {
    final allowed = allowedFeatures(roles);
    final entries = <({Feature feature, String title, String subtitle, IconData icon})>[
      (feature: Feature.content, title: 'تأليف الدروس', subtitle: 'التحرير والمراجعة والنشر', icon: Icons.edit_note),
      (feature: Feature.library, title: 'مكتبة الوسائط', subtitle: 'المواد التعليمية والملفات', icon: Icons.perm_media_outlined),
      (feature: Feature.finance, title: 'الرسوم والمالية', subtitle: 'الحسابات والرسوم', icon: Icons.account_balance_wallet_outlined),
      (feature: Feature.staff, title: 'شؤون الموظفين', subtitle: 'إدارة الموظفين', icon: Icons.badge_outlined),
      (feature: Feature.admissions, title: 'الاستقبال والقبول', subtitle: 'طلبات القبول', icon: Icons.support_agent_outlined),
      (feature: Feature.users, title: 'المستخدمون', subtitle: 'إدارة الحسابات والصلاحيات', icon: Icons.manage_accounts_outlined),
      (feature: Feature.classes, title: 'الصفوف والشعب', subtitle: 'دليل الصفوف', icon: Icons.class_outlined),
      (feature: Feature.attendance, title: 'الحضور', subtitle: 'جلسات وسجلات الحضور', icon: Icons.fact_check_outlined),
      (feature: Feature.courses, title: 'المقررات والدروس', subtitle: 'المقررات والمصادر', icon: Icons.menu_book_outlined),
    ];
    final visible = entries.where((entry) => allowed.contains(entry.feature));

    return SaiPageBody(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
      children: [
        const SaiScreenHeader(
          title: 'أنظمة الكلية',
          subtitle: 'الخدمات المتاحة وفق صلاحيات حسابك',
        ),
        for (final entry in visible)
          SaiListTile(
            title: entry.title,
            subtitle: entry.subtitle,
            icon: entry.icon,
            onTap: () => open(entry.feature),
          ),
        if (visible.isEmpty)
          const SaiEmptyState(
            icon: Icons.lock_outline,
            title: 'لا توجد وحدات متاحة',
            message: 'لا يتضمن دورك الحالي صلاحية الوصول إلى أي وحدة. تواصل مع إدارة الكلية.',
          ),
      ],
    );
  }
}