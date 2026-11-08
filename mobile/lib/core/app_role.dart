enum AppRole {
  superAdmin,
  admin,
  teacher,
  accountant,
  receptionist,
  librarian,
  student,
  parent,
  contentEditor,
}

extension AppRoleInfo on AppRole {
  String get databaseValue => switch (this) {
        AppRole.superAdmin => 'super_admin',
        AppRole.admin => 'admin',
        AppRole.teacher => 'teacher',
        AppRole.accountant => 'accountant',
        AppRole.receptionist => 'receptionist',
        AppRole.librarian => 'librarian',
        AppRole.student => 'student',
        AppRole.parent => 'parent',
        AppRole.contentEditor => 'content_editor',
      };

  String get label => switch (this) {
        AppRole.superAdmin => 'المشرف العام',
        AppRole.admin => 'مدير الأكاديمية',
        AppRole.teacher => 'المعلم',
        AppRole.accountant => 'المحاسب',
        AppRole.receptionist => 'موظف الاستقبال',
        AppRole.librarian => 'أمين المكتبة',
        AppRole.student => 'الطالب',
        AppRole.parent => 'ولي الأمر',
        AppRole.contentEditor => 'محرر المحتوى',
      };

}

AppRole? parseAppRole(Object? value) {
  final normalized = value?.toString().trim().toLowerCase();
  for (final role in AppRole.values) {
    if (role.databaseValue == normalized) return role;
  }
  return null;
}
