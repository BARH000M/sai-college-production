// ignore_for_file: constant_identifier_names
// Enum spelling intentionally matches the protected Postgres role enum.
enum Role {
  super_admin,
  admin,
  teacher,
  accountant,
  receptionist,
  librarian,
  student,
  parent,
  content_editor,
}

enum PageId {
  home,
  systems,
  learning,
  courses,
  classes,
  lesson,
  profile,
  notifications,
  admissions,
  staff,
  finance,
  library,
  exams,
  reports,
}

class Access {
  static Set<Role> parse(Iterable<String> values) =>
      Role.values.where((r) => values.contains(r.name)).toSet();
  static bool allows(Set<Role> roles, PageId page) {
    if (roles.isEmpty) return false;
    if (roles.contains(Role.super_admin) || roles.contains(Role.admin)) {
      return true;
    }
    const common = {
      PageId.home,
      PageId.systems,
      PageId.profile,
      PageId.notifications,
    };
    if (common.contains(page)) return true;
    final required = switch (page) {
      PageId.learning ||
      PageId.courses ||
      PageId.lesson => {Role.student, Role.teacher, Role.content_editor},
      PageId.classes => {
        Role.teacher,
        Role.student,
        Role.parent,
        Role.receptionist,
      },
      PageId.admissions => {Role.receptionist},
      PageId.finance => {Role.accountant, Role.student, Role.parent},
      PageId.library => {Role.librarian, Role.student, Role.teacher},
      PageId.exams => {Role.teacher, Role.student, Role.parent},
      PageId.reports => {Role.accountant},
      _ => <Role>{},
    };
    return roles.intersection(required).isNotEmpty;
  }
}
