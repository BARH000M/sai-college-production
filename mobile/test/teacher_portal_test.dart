import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/ui/teacher_portal.dart';

void main() {
  test('teacher navigation excludes administrative and finance pages', () {
    expect(Access.allows({Role.teacher}, PageId.classes), isTrue);
    expect(Access.allows({Role.teacher}, PageId.assignments), isTrue);
    expect(Access.allows({Role.teacher}, PageId.finance), isFalse);
    expect(Access.allows({Role.teacher}, PageId.users), isFalse);
    expect(Access.allows({Role.student}, PageId.users), isFalse);
  });

  test('class mapping excludes other classes and cross-class submissions', () {
    final result = mapTeacherClasses(
      [
        {'id': 'a'},
        {'id': 'b'},
      ],
      [
        {'id': 's1', 'class_id': 'a'},
        {'id': 's2', 'class_id': 'b'},
      ],
      [
        {'id': 'c1', 'class_id': 'a'},
        {'id': 'c2', 'class_id': 'b'},
      ],
      [
        {'id': 'l1', 'course_id': 'c1'},
        {'id': 'l2', 'course_id': 'c2'},
      ],
      [
        {'id': 'h1', 'course_id': 'c1'},
        {'id': 'h2', 'course_id': 'c2'},
      ],
      [
        {'id': 'ok', 'homework_id': 'h1', 'student_id': 's1'},
        {'id': 'cross', 'homework_id': 'h1', 'student_id': 's2'},
      ],
      [
        {'id': 'session1', 'class_id': 'a'},
        {'id': 'session2', 'class_id': 'b'},
      ],
      [
        {'lesson_id': 'l1', 'student_id': 's1'},
        {'lesson_id': 'l1', 'student_id': 's2'},
      ],
    );
    expect(result.first.students.map((row) => row['id']), ['s1']);
    expect(result.first.submissions.map((row) => row['id']), ['ok']);
    expect(result.first.sessions.map((row) => row['id']), ['session1']);
    expect(result.first.progress.map((row) => row['student_id']), ['s1']);
    expect(result.last.submissions, isEmpty);
  });

  testWidgets('empty class shows real empty states and no attendance write', (
    tester,
  ) async {
    const data = TeacherClassData(
      row: {'name': 'Class A', 'program': 'Chinese'},
      students: [],
      courses: [],
      homework: [],
      submissions: [],
      sessions: [],
      progress: [],
    );
    await tester.pumpWidget(
      const MaterialApp(home: TeacherClassPage(data: data)),
    );
    expect(find.text('لا يوجد طلاب نشطون في هذه الشعبة.'), findsOneWidget);
    expect(find.text('لا توجد مقررات نشطة لهذه الشعبة.'), findsOneWidget);
    expect(find.text('لا توجد واجبات متاحة.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('dashboard distinguishes loading, error and empty states', (
    tester,
  ) async {
    final pending = Completer<List<TeacherClassData>>();
    await tester.pumpWidget(
      MaterialApp(home: TeacherPortal(loader: () => pending.future)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('لا توجد شعب مسندة إلى حسابك.'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: TeacherPortal(
          key: const ValueKey('error'),
          loader: () async => throw StateError('unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('تعذر تحميل بيانات المعلم. تحقق من الاتصال وصلاحيات الحساب.'),
      findsOneWidget,
    );
  });
}
