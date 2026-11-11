import '../../core/security/sai_access.dart';

/// Describes visibility only; route binding will occur after existing router audit.
class SaiNavigationSpec {
  const SaiNavigationSpec(this.module, this.label, this.path);
  final SaiModule module;
  final String label;
  final String path;
}

const saiNavigation = <SaiNavigationSpec>[
  SaiNavigationSpec(SaiModule.dashboard, 'الرئيسية', '/'),
  SaiNavigationSpec(SaiModule.classes, 'الصفوف', '/classes'),
  SaiNavigationSpec(SaiModule.students, 'الطلاب', '/students'),
  SaiNavigationSpec(SaiModule.learning, 'التعلم', '/learning'),
  SaiNavigationSpec(SaiModule.attendance, 'الحضور', '/attendance'),
  SaiNavigationSpec(SaiModule.admissions, 'القبول', '/admissions'),
  SaiNavigationSpec(SaiModule.finance, 'المالية', '/finance'),
  SaiNavigationSpec(SaiModule.staff, 'الموظفون', '/staff'),
  SaiNavigationSpec(SaiModule.library, 'المكتبة', '/library'),
  SaiNavigationSpec(SaiModule.content, 'المحتوى', '/content'),
  SaiNavigationSpec(SaiModule.notifications, 'الإشعارات', '/notifications'),
  SaiNavigationSpec(SaiModule.reports, 'التقارير', '/reports'),
  SaiNavigationSpec(SaiModule.profile, 'حسابي', '/profile'),
  SaiNavigationSpec(SaiModule.settings, 'الإعدادات', '/settings'),
];
