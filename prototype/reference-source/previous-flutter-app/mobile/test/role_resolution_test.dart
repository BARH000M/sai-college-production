import 'package:flutter_test/flutter_test.dart';
import 'package:sai_school/auth/profile.dart';
import 'package:sai_school/routing/app_role.dart';

Profile _profile({String role = 'parent', bool platformAdmin = false}) =>
    Profile(
      id: '00000000-0000-0000-0000-000000000001',
      email: 'user@sai-college.com',
      fullName: 'مستخدم اختبار',
      role: role,
      active: true,
      platformAdmin: platformAdmin,
    );

void main() {
  group('resolveRole', () {
    test('platform_admin wins over the stored role', () {
      expect(resolveRole(_profile(role: 'admin', platformAdmin: true)),
          AppRole.owner);
      expect(resolveRole(_profile(role: 'teacher', platformAdmin: true)),
          AppRole.owner);
    });
    test('maps each stored role to its dashboard', () {
      expect(resolveRole(_profile(role: 'admin')), AppRole.admin);
      expect(resolveRole(_profile(role: 'teacher')), AppRole.teacher);
      expect(resolveRole(_profile(role: 'parent')), AppRole.parent);
      expect(resolveRole(_profile(role: 'student')), AppRole.student);
    });
    test('the three newer roles resolve to their own dashboards', () {
      expect(resolveRole(_profile(role: 'accountant')), AppRole.accountant);
      expect(resolveRole(_profile(role: 'employee')), AppRole.employee);
    });
    test('an unknown or empty role never escalates', () {
      expect(resolveRole(_profile(role: '')), AppRole.parent);
      expect(resolveRole(_profile(role: 'superuser')), AppRole.parent);
      expect(resolveRole(_profile(role: 'ADMIN ')), AppRole.admin);
    });
  });
  group('role capabilities', () {
    test('only finance roles see the ledger', () {
      expect(AppRole.owner.seesFinance, isTrue);
      expect(AppRole.admin.seesFinance, isTrue);
      expect(AppRole.accountant.seesFinance, isTrue);
      expect(AppRole.teacher.seesFinance, isFalse);
      expect(AppRole.parent.seesFinance, isFalse);
      expect(AppRole.student.seesFinance, isFalse);
      expect(AppRole.employee.seesFinance, isFalse);
    });
    test('only the school admin may run the posting button', () {
      expect(AppRole.admin.canPostFees, isTrue);
      expect(AppRole.owner.canPostFees, isFalse);
      expect(AppRole.accountant.canPostFees, isFalse);
      expect(AppRole.teacher.canPostFees, isFalse);
    });
    test('family roles are the student-scoped ones', () {
      expect(AppRole.parent.isFamily, isTrue);
      expect(AppRole.student.isFamily, isTrue);
      expect(AppRole.admin.isFamily, isFalse);
      expect(AppRole.teacher.isFamily, isFalse);
    });
    test('every role has a distinct Arabic label', () {
      expect(AppRole.values.map((r) => r.label).toSet().length,
          AppRole.values.length);
    });
  });
  group('Profile.fromRow', () {
    test('reads platform_admin and defaults it to false when absent', () {
      final withFlag = Profile.fromRow({
        'id': 'a',
        'email': 'owner@sai.co',
        'full_name': 'مالك',
        'role': 'admin',
        'active': true,
        'platform_admin': true
      });
      expect(withFlag.platformAdmin, isTrue);
      final withoutFlag = Profile.fromRow({
        'id': 'b',
        'email': 'admin@sai.co',
        'full_name': 'مدير',
        'role': 'admin',
        'active': true
      });
      expect(withoutFlag.platformAdmin, isFalse);
    });
    test('a null role falls back to parent rather than admin', () {
      final row = Profile.fromRow({
        'id': 'c',
        'email': '',
        'full_name': null,
        'role': null,
        'active': null
      });
      expect(row.role, 'parent');
      expect(resolveRole(row), AppRole.parent);
      expect(row.active, isTrue);
    });
  });
}
