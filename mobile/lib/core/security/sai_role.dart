/// The nine roles defined by public.app_role in migration 001.
enum SaiRole {
  superAdmin('super_admin'), admin('admin'), teacher('teacher'),
  accountant('accountant'), receptionist('receptionist'),
  librarian('librarian'), student('student'), parent('parent'),
  contentEditor('content_editor');

  const SaiRole(this.databaseValue);
  final String databaseValue;

  static SaiRole? parse(String value) {
    for (final role in SaiRole.values) {
      if (role.databaseValue == value) return role;
    }
    return null;
  }
}
