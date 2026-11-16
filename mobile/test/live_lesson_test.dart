import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sai_approved_mobile/ui/live_courses.dart';

class _FakeStore extends LessonStudyStore {
  _FakeStore({this.progress, this.words = const []});

  Map<String, dynamic>? progress;
  final List<Map<String, dynamic>> words;
  final writes = <String>[];

  @override
  Future<String?> resolveStudentId() async => 'student-1';

  @override
  Future<Map<String, dynamic>?> readProgress(String lessonId, String studentId) async => progress;

  @override
  Future<void> writeProgress(
    String lessonId,
    String studentId,
    String status, {
    String? completionBasis,
  }) async {
    writes.add('$status:${completionBasis ?? ''}');
    progress = {'status': status, 'completion_basis': completionBasis};
  }

  @override
  Future<List<Map<String, dynamic>>> loadWords(String lessonId) async => words;

  @override
  Future<Set<String>> loadStudiedWords(String studentId, List<String> wordIds) async => {};

  @override
  Future<void> markWordStudied(String wordId, String studentId) async {
    writes.add('word:$wordId');
  }
}

Map<String, dynamic> _lesson({String? body}) => {
  'id': 'lesson-1',
  'title': 'التعريف بالنفس',
  'summary': 'درس أول',
  'kind': 'lesson',
  'duration_minutes': 45,
  'content_kind': 'reading',
  'content_body': body,
  'content_path': null,
  'content_url': null,
};

void main() {
  testWidgets('student completes reading and vocabulary exercises then finishes the lesson', (
    tester,
  ) async {
    final store = _FakeStore(
      words: const [
        {'id': 'w1', 'hanzi': '你好', 'pinyin': 'nǐ hǎo', 'meaning_ar': 'مرحباً'},
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: LiveLessonPage(
        lesson: _lesson(body: '我叫艾哈迈德。我是学生。老师很好。教室很大。这是我的中文书。'),
        canTrack: true,
        store: store,
      ),
    ));
    await tester.pumpAndSettle();

    // Opening the lesson records in_progress exactly once.
    expect(store.writes, ['in_progress:']);
    expect(find.text('تمرين القراءة'), findsOneWidget);
    expect(find.text('تمرين المفردات'), findsOneWidget);

    // Completion stays disabled until every exercise is done.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'إنهاء الدرس'));
    await tester.pumpAndSettle();
    final finishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'إنهاء الدرس'),
    );
    expect(finishButton.onPressed, isNull);

    await tester.tap(find.text('أنهيت قراءة المادة'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('راجعتها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('راجعتها'));
    await tester.pumpAndSettle();
    expect(store.writes, contains('word:w1'));

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'إنهاء الدرس'));
    await tester.pumpAndSettle();
    final enabledFinish = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'إنهاء الدرس'),
    );
    expect(enabledFinish.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'إنهاء الدرس'));
    await tester.pumpAndSettle();

    expect(store.writes.last, 'completed:self_reported');
    expect(find.textContaining('أكملت تمارين هذا الدرس وسُجّل إكمالك الذاتي'), findsWidgets);
  });

  testWidgets('a lesson without exercises offers no completion', (tester) async {
    final store = _FakeStore();
    await tester.pumpWidget(MaterialApp(
      home: LiveLessonPage(lesson: _lesson(), canTrack: true, store: store),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('لا توجد تمارين مرتبطة بهذا الدرس'), findsOneWidget);
    expect(find.text('إنهاء الدرس'), findsNothing);
  });

  testWidgets('opening a legacy completed lesson never downgrades it', (tester) async {
    final store = _FakeStore(
      progress: {'status': 'completed', 'completion_basis': null},
    );
    await tester.pumpWidget(MaterialApp(
      home: LiveLessonPage(lesson: _lesson(), canTrack: true, store: store),
    ));
    await tester.pumpAndSettle();
    expect(store.writes, isEmpty);
    expect(find.textContaining('غير متحققة'), findsOneWidget);
  });

  testWidgets('study data failure shows a retryable error', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LiveLessonPage(lesson: _lesson(), canTrack: true, store: _FailingStore()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر تحميل بيانات الدرس'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}

class _FailingStore extends LessonStudyStore {
  @override
  Future<String?> resolveStudentId() async => throw StateError('offline');
}
