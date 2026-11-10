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
  attendance,
  schedule,
  assignments,
  content,
  users,
  downloads,
  inventory,
  transport,
  portfolio,
  housing,
  certificates,
  frontCms,
  alumni,
  settings,
}

class Access {
  static Set<Role> parse(Iterable<String> values) =>
      Role.values.where((r) => values.contains(r.name)).toSet();
  static bool allows(Set<Role> roles, PageId page) {
    if (roles.isEmpty) return false;
    if (roles.contains(Role.super_admin)) return true;
    if (roles.contains(Role.admin)) return page != PageId.users;
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
      PageId.downloads => {
        Role.teacher,
        Role.student,
        Role.parent,
        Role.content_editor,
      },
      PageId.inventory => {Role.accountant, Role.receptionist},
      PageId.transport => {
        Role.receptionist,
        Role.teacher,
        Role.student,
        Role.parent,
      },
      PageId.portfolio => {Role.teacher, Role.student, Role.parent},
      PageId.housing => {Role.receptionist, Role.student, Role.parent},
      PageId.certificates => {Role.receptionist, Role.student, Role.parent},
      PageId.frontCms => {Role.content_editor},
      PageId.alumni => {Role.receptionist},
      PageId.settings => <Role>{},
      PageId.exams => {Role.teacher, Role.student, Role.parent},
      PageId.reports => {Role.accountant},
      PageId.attendance ||
      PageId.schedule => {Role.teacher, Role.student, Role.parent},
      PageId.assignments => {Role.teacher, Role.student, Role.parent},
      PageId.content => {Role.content_editor},
      _ => <Role>{},
    };
    return roles.intersection(required).isNotEmpty;
  }

  static bool manages(Set<Role> roles, PageId page) {
    if (!allows(roles, page)) return false;
    if (roles.contains(Role.super_admin) || roles.contains(Role.admin)) {
      return true;
    }
    return switch (page) {
      PageId.attendance ||
      PageId.exams ||
      PageId.assignments => roles.contains(Role.teacher),
      PageId.admissions => roles.contains(Role.receptionist),
      PageId.finance => roles.contains(Role.accountant),
      PageId.library => roles.contains(Role.librarian),
      PageId.content || PageId.frontCms => roles.contains(Role.content_editor),
      PageId.downloads => roles.contains(Role.content_editor),
      PageId.inventory => roles.contains(Role.accountant),
      PageId.transport ||
      PageId.housing ||
      PageId.certificates ||
      PageId.alumni => roles.contains(Role.receptionist),
      PageId.portfolio => roles.contains(Role.teacher),
      _ => false,
    };
  }
}
