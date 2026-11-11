import 'sai_role.dart';

/// UI visibility only. Supabase RLS is the authority for all data operations.
enum SaiModule {
  dashboard, classes, students, learning, attendance, admissions,
  finance, staff, library, content, notifications, reports, profile, settings,
}

class SaiAccess {
  const SaiAccess._();

  static const Map<SaiRole, Set<SaiModule>> grants = {
    SaiRole.superAdmin: {...SaiModule.values},
    SaiRole.admin: {...SaiModule.values},
    SaiRole.teacher: {SaiModule.dashboard, SaiModule.classes, SaiModule.students,
      SaiModule.learning, SaiModule.attendance, SaiModule.notifications,
      SaiModule.reports, SaiModule.profile, SaiModule.settings},
    SaiRole.accountant: {SaiModule.dashboard, SaiModule.finance,
      SaiModule.notifications, SaiModule.reports, SaiModule.profile, SaiModule.settings},
    SaiRole.receptionist: {SaiModule.dashboard, SaiModule.classes,
      SaiModule.students, SaiModule.admissions, SaiModule.attendance,
      SaiModule.notifications, SaiModule.profile, SaiModule.settings},
    SaiRole.librarian: {SaiModule.dashboard, SaiModule.library,
      SaiModule.notifications, SaiModule.profile, SaiModule.settings},
    SaiRole.student: {SaiModule.dashboard, SaiModule.learning, SaiModule.classes,
      SaiModule.attendance, SaiModule.library, SaiModule.notifications,
      SaiModule.profile, SaiModule.settings},
    SaiRole.parent: {SaiModule.dashboard, SaiModule.students,
      SaiModule.attendance, SaiModule.notifications, SaiModule.profile,
      SaiModule.settings},
    SaiRole.contentEditor: {SaiModule.dashboard, SaiModule.content,
      SaiModule.learning, SaiModule.notifications, SaiModule.profile,
      SaiModule.settings},
  };

  static Set<SaiModule> visibleModules(Iterable<SaiRole> roles) {
    final result = <SaiModule>{};
    for (final role in roles) { result.addAll(grants[role] ?? const {}); }
    return Set.unmodifiable(result);
  }

  static bool canSee(Iterable<SaiRole> roles, SaiModule module) =>
      visibleModules(roles).contains(module);
}
