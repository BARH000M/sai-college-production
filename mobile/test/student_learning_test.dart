import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/ui/live_courses.dart';

void main() {
  test('student can reach learning but not administrative destinations', () {
    expect(Access.allows({Role.student}, PageId.courses), isTrue);
    for (final page in [
      PageId.users,
      PageId.settings,
      PageId.content,
      PageId.reports,
    ]) {
      expect(Access.allows({Role.student}, page), isFalse);
    }
  });

  testWidgets('lesson progress notice distinguishes exercise completion from legacy rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LessonProgressNotice(status: null)),
      ),
    );
    expect(find.textContaining('لا توجد حالة إكمال مسجلة'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LessonProgressNotice(status: 'in_progress')),
      ),
    );
    expect(find.textContaining('قيد الدراسة'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LessonProgressNotice(status: 'completed')),
      ),
    );
    expect(find.textContaining('غير متحققة'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonProgressNotice(status: 'completed', basis: 'self_reported'),
        ),
      ),
    );
    expect(find.textContaining('أكملت تمارين هذا الدرس'), findsOneWidget);
    expect(find.textContaining('غير معتمد'), findsOneWidget);
  });
}
