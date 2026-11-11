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
    }
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
}
