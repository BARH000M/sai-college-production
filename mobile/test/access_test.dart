import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/core/access.dart';

void main() {
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
  test('Teachers use assigned-class access; reception remains front-office scoped', () {
    expect(Access.allows({Role.teacher}, PageId.classes), true);
    expect(Access.allows({Role.teacher}, PageId.admissions), false);
    expect(Access.allows({Role.receptionist}, PageId.classes), false);
    expect(Access.allows({Role.receptionist}, PageId.admissions), true);
    expect(Access.allows({Role.receptionist}, PageId.finance), false);
  });
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
