import 'package:flutter_test/flutter_test.dart';
import 'package:sai_school/auth/profile.dart';
import 'package:sai_school/core/api.dart';
import 'package:sai_school/routing/app_role.dart';
import 'package:sai_school/routing/role_router.dart';

Profile profile(String role) => Profile(
      id: '00000000-0000-0000-0000-000000000001',
      email: 'test@example.invalid',
      fullName: 'اختبار',
      role: role,
      active: true,
      teacherId: role == 'teacher' ? 7 : null,
      studentId: role == 'student' ? 9 : null,
    );

Future<void> signOut() async {}

void main() {
  group('role workflow navigation', () {
    test('every role has safe mobile navigation and account access', () {
      for (final role in AppRole.values) {
        final storedRole = role == AppRole.owner ? 'admin' : role.name;
        final items = destinationsFor(
            role: role,
            api: SchoolApi(),
            profile: profile(storedRole),
            onSignOut: signOut);
        expect(items.length, inInclusiveRange(2, 5), reason: role.name);
        expect(items.last.label, 'الحساب', reason: role.name);
        expect(items.map((item) => item.label).toSet().length, items.length);
      }
    });

    test('only school administrators see the fee posting destination', () {
      for (final role in AppRole.values) {
        final items = destinationsFor(
            role: role,
            api: SchoolApi(),
            profile: profile(role.name),
            onSignOut: signOut);
        expect(items.any((item) => item.label == 'ترحيل الرسوم'),
            role == AppRole.admin);
      }
    });

    test('role workspaces are separate', () {
      final expectations = {
        AppRole.teacher: 'فصولي',
        AppRole.employee: 'ملفي الوظيفي',
        AppRole.parent: 'أبنائي',
        AppRole.student: 'دراستي',
      };
      expectations.forEach((role, label) {
        final items = destinationsFor(
            role: role,
            api: SchoolApi(),
            profile: profile(role.name),
            onSignOut: signOut);
        expect(items.any((item) => item.label == label), isTrue);
      });
    });
  });

  group('workflow records', () {
    test('unpublished marks are not represented by a published result model',
        () {
      final result = PublishedResult.fromRow({
        'id': 4,
        'subject': 'الرياضيات',
        'term': 'الفصل الأول',
        'exam_date': '2026-10-20',
        'max_marks': 20,
      }, null);
      expect(result.marks, isNull);
      expect(result.percent, isNull);
      expect(result.examId, 4);
    });

    test('teacher rosters contain only the selected class', () {
      const workspace = TeacherWorkspace(
        classes: [],
        slots: [],
        attendance: [],
        assignments: [],
        students: [
          StudentRecord(id: 1, fullName: 'أ', classId: 10),
          StudentRecord(id: 2, fullName: 'ب', classId: 11),
          StudentRecord(id: 3, fullName: 'ج', classId: 10),
        ],
      );
      expect(workspace.studentsOf(10).map((item) => item.id), [1, 3]);
      expect(workspace.studentsOf(12), isEmpty);
    });

    test('message read state comes from the persisted receipt timestamp', () {
      final unread = MessageRecord.fromRow({
        'id': 1,
        'subject': '',
        'body': '',
        'created_at': '2026-01-01',
        'read_at': null
      });
      final read = MessageRecord.fromRow({
        'id': 2,
        'subject': '',
        'body': '',
        'created_at': '2026-01-01',
        'read_at': '2026-01-02'
      });
      expect(unread.readAt, isNull);
      expect(read.readAt, isNotNull);
    });
  });
}
