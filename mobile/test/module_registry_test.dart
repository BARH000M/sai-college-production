import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/data/module_registry.dart';

void main() {
  test('Existing homework and library use the same server tables', () {
    expect(onlineModules[PageId.assignments]!.table, 'learning_homework');
    expect(onlineModules[PageId.library]!.table, 'library_items');
    expect(onlineModules[PageId.assignments]!.writable, false);
    expect(onlineModules[PageId.library]!.writable, false);
  });

  test('All new operational pages have live server table mapping', () {
    for (final page in [
      PageId.downloads, PageId.inventory, PageId.transport,
      PageId.portfolio, PageId.housing, PageId.certificates,
      PageId.frontCms, PageId.alumni,
    ]) {
      expect(onlineModules.containsKey(page), true, reason: page.name);
      expect(onlineModules[page]!.writable, true);
    }
  });

  test('Only permitted roles see sensitive pages', () {
    for (final role in [Role.student, Role.parent]) {
      expect(Access.allows({role}, PageId.settings), false);
      expect(Access.allows({role}, PageId.inventory), false);
      expect(Access.manages({role}, PageId.certificates), false);
    }
    expect(Access.allows({Role.super_admin}, PageId.settings), true);
    expect(Access.allows({Role.content_editor}, PageId.frontCms), true);
    expect(Access.manages({Role.content_editor}, PageId.frontCms), true);
    expect(Access.manages({Role.student}, PageId.portfolio), false);
  });
}
