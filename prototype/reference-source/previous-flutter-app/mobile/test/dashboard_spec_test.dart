import 'package:flutter_test/flutter_test.dart';
import 'package:sai_school/auth/profile.dart';
import 'package:sai_school/core/api.dart';
import 'package:sai_school/features/home/dashboard_spec.dart';
import 'package:sai_school/routing/app_role.dart';

Profile _profile({String role = 'admin'}) => Profile(
    id: 'u1',
    email: 'admin@sai-college.com',
    fullName: 'مدير الكلية',
    role: role,
    active: true);

void main() {
  group('specsFor', () {
    for (final role in AppRole.values) {
      test('${role.name} produces a non-empty, well-formed spec list', () {
        final specs =
            specsFor(role: role, api: SchoolApi(), profile: _profile());
        expect(specs, isNotEmpty);
        for (final spec in specs) {
          expect(spec.label.trim(), isNotEmpty);
          expect(spec.load, isNotNull);
        }
        final labels = specs.map((s) => s.label).toList();
        expect(labels.toSet().length, labels.length,
            reason: 'duplicate stat label in ${role.name}');
      });
    }
    test('only the admin dashboard surfaces the posting backlog as an alert',
        () {
      final adminSpecs =
          specsFor(role: AppRole.admin, api: SchoolApi(), profile: _profile());
      final teacherSpecs = specsFor(
          role: AppRole.teacher,
          api: SchoolApi(),
          profile: _profile(role: 'teacher'));
      expect(adminSpecs.any((s) => s.alertWhenPositive), isTrue);
      expect(teacherSpecs.any((s) => s.label.contains('تحصيل')), isFalse);
    });
    test('the accountant dashboard is finance-only', () {
      final specs = specsFor(
          role: AppRole.accountant, api: SchoolApi(), profile: _profile());
      expect(specs.any((s) => s.label.contains('الدفتر')), isTrue);
      expect(specs.any((s) => s.label.contains('الطلاب')), isFalse);
    });
    test('the parent dashboard counts linked children, not all students', () {
      final specs = specsFor(
          role: AppRole.parent,
          api: SchoolApi(),
          profile: _profile(role: 'parent'));
      expect(specs.any((s) => s.label == 'أبنائي'), isTrue);
      expect(specs.any((s) => s.label == 'الطلاب'), isFalse);
    });
    test('the owner dashboard is institution-scoped', () {
      expect(
          specsFor(role: AppRole.owner, api: SchoolApi(), profile: _profile())
              .first
              .label,
          'المؤسسات');
    });
  });
  group('roleNote', () {
    test('every role explains its own scope', () {
      for (final role in AppRole.values) {
        expect(roleNote(role, _profile()).trim(), isNotEmpty);
      }
    });
    test('the teacher note names the database as the boundary', () {
      expect(roleNote(AppRole.teacher, _profile()), contains('قاعدة البيانات'));
    });
  });
}
