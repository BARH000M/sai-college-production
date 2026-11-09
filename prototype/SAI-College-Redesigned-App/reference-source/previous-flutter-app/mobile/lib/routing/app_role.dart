import '../auth/profile.dart';

/// The seven roles the app renders a home for.
///
/// As of migration 0081, `school_profiles.role` admits all six stored values:
/// `admin | teacher | parent | accountant | employee | student`. `owner` is not
/// a stored role — it is `platform_admin = true`, the same flag the owner
/// console uses.
enum AppRole { owner, admin, accountant, teacher, employee, parent, student }

/// Resolves the effective role. `platform_admin` wins over everything: the
/// owner console must never be reachable by a school admin.
AppRole resolveRole(Profile profile) {
  if (profile.platformAdmin) return AppRole.owner;
  switch (profile.role.trim().toLowerCase()) {
    case 'admin':
      return AppRole.admin;
    case 'accountant':
      return AppRole.accountant;
    case 'teacher':
      return AppRole.teacher;
    case 'employee':
      return AppRole.employee;
    case 'student':
      return AppRole.student;
    case 'parent':
    default:
      return AppRole.parent;
  }
}

extension AppRoleInfo on AppRole {
  String get label {
    switch (this) {
      case AppRole.owner:
        return 'مالك المنصة';
      case AppRole.admin:
        return 'مدير المدرسة';
      case AppRole.accountant:
        return 'محاسب';
      case AppRole.teacher:
        return 'معلم';
      case AppRole.employee:
        return 'موظف';
      case AppRole.parent:
        return 'ولي أمر';
      case AppRole.student:
        return 'طالب';
    }
  }

  bool get seesFinance =>
      this == AppRole.owner ||
      this == AppRole.admin ||
      this == AppRole.accountant;

  bool get canPostFees => this == AppRole.admin;

  bool get isFamily => this == AppRole.parent || this == AppRole.student;

  bool get isClassScoped => this == AppRole.teacher;
}
