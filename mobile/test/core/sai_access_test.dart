import 'package:flutter_test/flutter_test.dart';
import 'package:sai_college_mobile/core/security/sai_access.dart';
import 'package:sai_college_mobile/core/security/sai_role.dart';

void main() {
  test('all nine database roles parse', () {
    expect(SaiRole.values.length, 9);
    for (final role in SaiRole.values) {
      expect(SaiRole.parse(role.databaseValue), role);
    }
    expect(SaiRole.parse('unknown'), isNull);
  });

  test('multi-role grants are unioned', () {
    final modules = SaiAccess.visibleModules([SaiRole.teacher, SaiRole.accountant]);
    expect(modules.contains(SaiModule.attendance), isTrue);
    expect(modules.contains(SaiModule.finance), isTrue);
    expect(modules.contains(SaiModule.content), isFalse);
  });

  test('no roles means no visible modules', () {
    expect(SaiAccess.visibleModules([]), isEmpty);
  });
}
