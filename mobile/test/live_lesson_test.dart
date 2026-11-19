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

  List<Map<String, dynamic>> questions = const [];
  Map<String, dynamic>? quizOutcome;
  List<Map<String, dynamic>>? lastSubmittedAnswers;

  @override
  Future<List<Map<String, dynamic>>> loadQuestions(String lessonId) async => questions;

  @override
  Future<Map<String, dynamic>> submitExercise(
    String lessonId,
    List<Map<String, dynamic>> answers,
  ) async {
    lastSubmittedAnswers = answers.map((answer) => Map<String, dynamic>.from(answer)).toList();
    writes.add('quiz:${answers.length}');
    return quizOutcome ?? {
      'total': answers.length,
      'correct': answers.length,
      'score': 100,
      'passed': true,
      'results': [for (final a in answers) {'question': a['question'], 'correct': true}],
    };
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

  testWidgets('server-graded quiz records assessed completion on pass', (
    tester,
  ) async {
    final store = _FakeStore(progress: {'status': 'in_progress', 'completion_basis': null})
      ..questions = const [
        {
          'id': 'q1',
          'kind': 'vocabulary',
          'prompt': 'ما معنى 你好؟',
          'choices': ['مرحباً', 'وداعاً'],
          'position': 1,
        },
      ];
    await tester.pumpWidget(MaterialApp(
      home: LiveLessonPage(lesson: _lesson(), canTrack: true, store: store),
    ));
    await tester.pumpAndSettle();

    expect(find.text('التقييم المُصحَّح'), findsOneWidget);
    // Submit stays disabled until at least one answer is chosen.
    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'إرسال الإجابات (0 / 1)'),
    );
    expect(disabled.onPressed, isNull);

    await tester.tap(find.text('مرحباً'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'إرسال الإجابات (1 / 1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إرسال الإجابات (1 / 1)'));
    await tester.pumpAndSettle();

    expect(store.writes, contains('quiz:1'));
    expect(find.textContaining('النتيجة: 1 من 1'), findsOneWidget);
    expect(find.textContaining('اجتزت تقييم هذا الدرس'), findsOneWidget);
  });

  testWidgets('a failed quiz offers retry and no completion claim', (tester) async {
    final store = _FakeStore(progress: {'status': 'in_progress', 'completion_basis': null})
      ..questions = const [
        {
          'id': 'q1',
          'kind': 'listening',
          'prompt': 'استمع واختر',
          'choices': ['أ', 'ب'],
          'position': 1,
        },
      ]
      ..quizOutcome = {
        'total': 1,
        'correct': 0,
        'score': 0,
        'passed': false,
        'results': [
          {'question': 'q1', 'correct': false},
        ],
      };
    await tester.pumpWidget(MaterialApp(
      home: LiveLessonPage(lesson: _lesson(), canTrack: true, store: store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('أ'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'إرسال الإجابات (1 / 1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إرسال الإجابات (1 / 1)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('النتيجة: 0 من 1'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsWidgets);
    expect(find.textContaining('اجتزت تقييم'), findsNothing);
  });

  testWidgets('true/false exercises submit the selected choice for server grading', (
    tester,
  ) async {
    final store = _FakeStore(
      progress: {'status': 'in_progress', 'completion_basis': null},
    )..questions = const [
      {
        'id': 'q-true-false',
        'kind': 'true_false',
        'prompt': 'الشمس نجم؟',
        'choices': ['صح', 'خطأ'],
        'position': 1,
      },
    ];
    await tester.pumpWidget(MaterialApp(
      home: LiveLessonPage(lesson: _lesson(), canTrack: true, store: store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('صح'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'إرسال الإجابات (1 / 1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إرسال الإجابات (1 / 1)'));
    await tester.pumpAndSettle();

    expect(store.lastSubmittedAnswers, [
      {'question': 'q-true-false', 'choice': 0},
    ]);
    expect(find.textContaining('النتيجة: 1 من 1'), findsOneWidget);
  });
}

class _FailingStore extends LessonStudyStore {
  @override
  Future<String?> resolveStudentId() async => throw StateError('offline');
}
