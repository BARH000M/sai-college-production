import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/data/admissions_repository.dart';
import 'package:sai_approved_mobile/data/module_registry.dart';

void main() {
  test('All nine roles retain settings boundaries', () {
    expect(Role.values.length, 9);
    for (final role in Role.values) {
      expect(Access.allows({role}, PageId.settings),
          role == Role.admin || role == Role.super_admin, reason: role.name);
      expect(Access.manages({role}, PageId.settings),
          role == Role.super_admin, reason: role.name);
    }
  });
  test('Every multi-role combination requires explicit super admin for settings', () {
    for (var mask = 0; mask < (1 << Role.values.length); mask++) {
      final roles = {
        for (final role in Role.values)
          if ((mask & (1 << role.index)) != 0) role,
      };
      expect(Access.manages(roles, PageId.settings),
          roles.contains(Role.super_admin), reason: roles.toString());
      expect(Access.allows(roles, PageId.settings),
          roles.contains(Role.admin) || roles.contains(Role.super_admin));
    }
  });
  test('Admin retains management of other authorized pages', () {
    for (final page in PageId.values.where((p) => p != PageId.settings)) {
      expect(Access.manages({Role.admin}, page),
          Access.allows({Role.admin}, page), reason: page.name);
    }
  });
  test('No roles means no access', () {
    for (final p in PageId.values) {
      expect(Access.allows({}, p), false);
    }
  });
  test('Students and parents cannot access staff or admissions', () {
    for (final r in [Role.student, Role.parent]) {
      for (final p in [PageId.staff, PageId.admissions, PageId.reports]) {
        expect(Access.allows({r}, p), false);
      }
      expect(Access.allows({r}, PageId.classes), false);
      expect(Access.allows({r}, PageId.attendance), false);
    }
  });
  test('Staff directory is wired to the HR contract and admin roles only', () {
    final staff = onlineModules[PageId.staff]!;
    expect(staff.table, 'sai_hr_employees');
    expect(staff.writable, true);
    expect(staff.allowDelete, false);
    expect(Access.allows({Role.super_admin}, PageId.staff), true);
    expect(Access.allows({Role.admin}, PageId.staff), true);
    for (final role in Role.values.where(
      (role) => role != Role.super_admin && role != Role.admin,
    )) {
      expect(Access.allows({role}, PageId.staff), false, reason: role.name);
    }
  });
  test(
    'Teachers use assigned-class access; reception remains front-office scoped',
    () {
      expect(Access.allows({Role.teacher}, PageId.classes), true);
      expect(Access.allows({Role.teacher}, PageId.admissions), false);
      expect(Access.allows({Role.receptionist}, PageId.classes), false);
      expect(Access.allows({Role.receptionist}, PageId.admissions), true);
      expect(Access.allows({Role.receptionist}, PageId.finance), false);
    },
  );
  test('Admission management excludes roles without admissions authority', () {
    for (final role in [
      Role.teacher,
      Role.accountant,
      Role.librarian,
      Role.student,
      Role.parent,
      Role.content_editor,
    ]) {
      expect(Access.manages({role}, PageId.admissions), false);
    }
    for (final role in [Role.super_admin, Role.admin, Role.receptionist]) {
      expect(Access.manages({role}, PageId.admissions), true);
    }
  });
  test(
    'Mobile status choices require the conversion RPC for enrollment',
    () {
      expect(editableAdmissionStatuses.containsKey('accepted'), true);
      expect(editableAdmissionStatuses.containsKey('rejected'), true);
      expect(editableAdmissionStatuses.containsKey('enrolled'), false);
    },
  );
  test('Multiple roles give union of allowed destinations', () {
    expect(Access.allows({Role.librarian}, PageId.finance), false);
    expect(
      Access.allows({Role.librarian, Role.accountant}, PageId.finance),
      true,
    );
    expect(
      Access.allows({Role.librarian, Role.accountant}, PageId.library),
      true,
    );
  });
  test('Unknown role strings never grant access', () {
    expect(Access.parse(['owner', 'SUPER_ADMIN']), isEmpty);
  });
  test('Module roles match the shared web navigation', () {
    expect(Access.allows({Role.librarian}, PageId.downloads), true);
    expect(Access.allows({Role.parent}, PageId.library), true);
    expect(Access.allows({Role.accountant}, PageId.inventory), true);
    expect(Access.allows({Role.receptionist}, PageId.inventory), false);
    expect(Access.allows({Role.teacher}, PageId.transport), false);
  });
}
