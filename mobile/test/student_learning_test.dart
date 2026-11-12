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

  for (final status in [null, 'in_progress', 'completed']) {
    testWidgets('lesson progress $status cannot be marked complete', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LessonProgressNotice(status: status)),
        ),
      );
      expect(find.textContaining('تسجيل الإكمال معطل'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      if (status == 'completed') {
        expect(find.textContaining('غير متحققة'), findsOneWidget);
      }
    });
  }
}
