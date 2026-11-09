import 'package:flutter_test/flutter_test.dart';
import 'package:sai_college_mobile/core/app_identity.dart';
import 'package:sai_college_mobile/core/app_role.dart';
import 'package:sai_college_mobile/core/security/permissions.dart';

AppIdentity identityWith(List<AppRole> roles) => AppIdentity(
      userId: '00000000-0000-0000-0000-000000000000',
      fullName: 'مستخدم اختبار',
      email: 'test@example.com',
      roles: roles,
    );

void main() {
  group('SaiPermissions — single roles', () {
    test('super admin manages classes, students, admissions and roles', () {
      final permissions = SaiPermissions.of(identityWith(const [AppRole.superAdmin]));
      expect(permissions.canManageClasses, isTrue);
      expect(permissions.canManageStudents, isTrue);
      expect(permissions.canManageAdmissions, isTrue);
      expect(permissions.canManageBranches, isTrue);
      expect(permissions.canManageRoles, isTrue);
      expect(permissions.isStaff, isTrue);
      expect(permissions.isLearner, isFalse);
    });

    test('teacher marks attendance and authors content, but manages no classes', () {
      final permissions = SaiPermissions.of(identityWith(const [AppRole.teacher]));
      expect(permissions.canMarkAttendance, isTrue);
      expect(permissions.canAuthorContent, isTrue);
      expect(permissions.canUseLibrary, isTrue);
      expect(permissions.canManageClasses, isFalse);
      expect(permissions.canManageStudents, isFalse);
      expect(permissions.canManageAdmissions, isFalse);
      expect(permissions.canManageRoles, isFalse);
    });

    test('receptionist manages students and admissions, not classes', () {
      final permissions = SaiPermissions.of(identityWith(const [AppRole.receptionist]));
      expect(permissions.canManageStudents, isTrue);
      expect(permissions.canManageAdmissions, isTrue);
      expect(permissions.canMarkAttendance, isTrue);
      expect(permissions.canManageClasses, isFalse);
    });

    test('accountant reads finance but never marks attendance', () {
      final permissions = SaiPermissions.of(identityWith(const [AppRole.accountant]));
      expect(permissions.canReadFinance, isTrue);
      expect(permissions.canMarkAttendance, isFalse);
      expect(permissions.isStaff, isTrue);
    });

    test('librarian uses the library and marks attendance, no finance', () {
      final permissions = SaiPermissions.of(identityWith(const [AppRole.librarian]));
      expect(permissions.canUseLibrary, isTrue);
      expect(permissions.canMarkAttendance, isFalse);
      expect(permissions.canReadFinance, isFalse);
    });

    test('content editor authors content but holds no operational capability', () {
      final permissions = SaiPermissions.of(identityWith(const [AppRole.contentEditor]));
      expect(permissions.canAuthorContent, isTrue);
      expect(permissions.canManageClasses, isFalse);
      expect(permissions.canManageStudents, isFalse);
      expect(permissions.canManageAdmissions, isFalse);
    });

    test('student is a learner with finance and library access only', () {
      final permissions = SaiPermissions.of(identityWith(const [AppRole.student]));
      expect(permissions.isLearner, isTrue);
      expect(permissions.isStaff, isFalse);
      expect(permissions.canReadOwnLearnerData, isTrue);
      expect(permissions.canReadFinance, isTrue);
      expect(permissions.canUseLibrary, isTrue);
      expect(permissions.canMarkAttendance, isFalse);
      expect(permissions.canManageStudents, isFalse);
    });

    test('parent is a learner who cannot operate staff workflows', () {
      final permissions = SaiPermissions.of(identityWith(const [AppRole.parent]));
      expect(permissions.isLearner, isTrue);
      expect(permissions.isStaff, isFalse);
      expect(permissions.canReadOwnLearnerData, isTrue);
      expect(permissions.canManageStudents, isFalse);
      expect(permissions.canMarkAttendance, isFalse);
      expect(permissions.canManageRoles, isFalse);
    });

    test('admin is everything a super admin is except role management', () {
      final permissions = SaiPermissions.of(identityWith(const [AppRole.admin]));
      expect(permissions.canManageClasses, isTrue);
      expect(permissions.canManageBranches, isTrue);
      expect(permissions.canManageRoles, isFalse);
    });
  });

  group('SaiPermissions — multi-role accounts', () {
    test('teacher plus receptionist receives the union of capabilities', () {
      final permissions =
          SaiPermissions.of(identityWith(const [AppRole.teacher, AppRole.receptionist]));
      expect(permissions.hasMultipleRoles, isTrue);
      expect(permissions.canMarkAttendance, isTrue); // teacher
      expect(permissions.canManageStudents, isTrue); // receptionist
      expect(permissions.canManageClasses, isFalse); // neither
    });

    test('staff and learner roles on one account satisfy both groups', () {
      final permissions =
          SaiPermissions.of(identityWith(const [AppRole.librarian, AppRole.student]));
      expect(permissions.isStaff, isTrue);
      expect(permissions.isLearner, isTrue);
      expect(permissions.canReadOwnLearnerData, isTrue);
      expect(permissions.canUseLibrary, isTrue);
    });

    test('a single role is not reported as multi-role', () {
      final permissions = SaiPermissions.fromRoles(const [AppRole.teacher]);
      expect(permissions.hasMultipleRoles, isFalse);
    });

    test('exposed role set is unmodifiable', () {
      final permissions = SaiPermissions.fromRoles(const [AppRole.teacher]);
      expect(() => permissions.roles.add(AppRole.admin), throwsUnsupportedError);
    });
  });
}