import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sai_approved_mobile/core/access.dart';
import 'package:sai_approved_mobile/data/exam_repository.dart';
import 'package:sai_approved_mobile/ui/exams_screen.dart';

const classRow = {
  'id': 'c1',
  'name': 'الصف الأول',
  'branch_id': 'b1',
  'academic_session_id': 's1',
  'teacher_id': 't1',
};
final examRow = {
  'id': 'e1',
  'branch_id': 'b1',
  'academic_session_id': 's1',
  'class_id': 'c1',
  'course_id': null,
  'subject': 'اللغة الصينية',
  'title': 'اختبار منتصف الفصل',
  'exam_date': '2026-03-15',
  'start_time': '09:00',
  'end_time': '11:00',
  'room': 'قاعة 1',
  'max_score': 100,
  'status': 'marks_entry',
  'published_at': null,
};
final rosterRows = [
  {
    'student_id': 'st1',
    'full_name': 'الطالب الأول',
    'admission_no': 'A-1',
    'result_id': null,
    'score': null,
    'grade': null,
    'note': null,
  },
  {
    'student_id': 'st2',
    'full_name': 'الطالب الثاني',
    'admission_no': 'A-2',
    'result_id': 'r2',
    'score': 40,
    'grade': 'fail',
    'note': null,
  },
];

class FakeExamRepository extends ExamRepository {
  List<Map<String, dynamic>> classRows = [classRow];
  List<Map<String, dynamic>> examRows = [examRow];
  List<Map<String, dynamic>> rosterData = rosterRows;
  List<Map<String, dynamic>> family = [];
  bool fail = false;
  final saves = <Map<String, dynamic>>[];
  final transitions = <String>[];
  final created = <ExamDraftInput>[];

  @override
  Future<List<Map<String, dynamic>>> classes() async {
    if (fail) throw Exception('offline');
    return classRows;
  }

  @override
  Future<List<Map<String, dynamic>>> exams({String? classId}) async =>
      examRows;

  @override
  Future<List<Map<String, dynamic>>> roster(String examId) async => rosterData;

  @override
  Future<List<Map<String, dynamic>>> familyResults() async {
    if (fail) throw Exception('offline');
    return family;
  }

  @override
  Future<void> createExam(ExamDraftInput draft) async {
    created.add(draft);
    examRows = [...examRows, ...[]];
  }

  @override
  Future<void> transition(String examId, String from, String to) async {
    if (!canTransitionExam(from, to)) throw const FormatException('انتقال');
    transitions.add('$from>$to');
  }

  @override
  Future<void> saveMark(
    String examId,
    Map<String, dynamic> entry,
    String score,
    String note,
    num maxScore,
  ) async {
    final problem = validateMark(score, maxScore);
    if (problem != null) throw FormatException(problem);
    saves.add({
      'exam_id': examId,
      'student_id': entry['student_id'],
      'result_id': entry['result_id'],
      'score': score.trim().isEmpty ? null : num.parse(score.trim()),
      'note': note.trim().isEmpty ? null : note.trim(),
    });
  }
}

void main() {
  test('grade bands and transitions match the shared contract', () {
    expect(gradeForScore(90, 100), 'excellent');
    expect(gradeForScore(89.9, 100), 'very_good');
    expect(gradeForScore(70, 100), 'good');
    expect(gradeForScore(60, 100), 'acceptable');
    expect(gradeForScore(50, 100), 'weak');
    expect(gradeForScore(49.9, 100), 'fail');
    expect(gradeForScore(null, 100), isNull);
    expect(gradeForScore(100, 200), 'weak');
    for (final from in examStatuses.keys) {
      for (final to in examStatuses.keys) {
        expect(
          canTransitionExam(from, to),
          examTransitions[from]!.contains(to),
          reason: '$from -> $to',
        );
      }
    }
    expect(canTransitionExam('draft', 'published'), isFalse);
    expect(canTransitionExam('cancelled', 'draft'), isFalse);
  });

  test('validation rejects invalid exams and marks', () {
    final valid = ExamDraftInput(
      classRow: classRow,
      subject: 'اللغة الصينية',
      title: 'اختبار منتصف الفصل',
      date: '2026-03-15',
      room: 'قاعة 1',
    );
    expect(validateExamDraft(valid), isNull);
    expect(
      validateExamDraft(
        ExamDraftInput(classRow: classRow, subject: 'م', title: 't', date: '2026-03-15'),
      ),
      isNotNull,
    );
    expect(
      validateExamDraft(
        ExamDraftInput(classRow: classRow, subject: 'مادة', title: 't', date: 'bad'),
      ),
      isNotNull,
    );
    expect(
      validateExamDraft(valid, sessionStarts: '2026-04-01', sessionEnds: '2026-06-30'),
      isNotNull,
    );
    expect(
      validateExamDraft(
        ExamDraftInput(
          classRow: classRow,
          subject: 'مادة',
          title: 'اختبار',
          date: '2026-03-15',
          startTime: '11:00',
          endTime: '09:00',
        ),
      ),
      isNotNull,
    );
    expect(validateMark('', 100), isNull);
    expect(validateMark('95', 100), isNull);
    expect(validateMark('101', 100), isNotNull);
    expect(validateMark('-1', 100), isNotNull);
    expect(validateMark('x', 100), isNotNull);
  });

  test('repository writes only the permitted exam and mark contract', () async {
    final calls = <http.Request>[];
    final client = SupabaseClient(
      'https://aeryusbrulqdxjdynwfh.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        calls.add(request);
        if (request.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'test-access',
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'test-refresh',
              'user': {
                'id': 't1',
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': 't1@example.test',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await client.auth.signInWithPassword(
      email: 't1@example.test',
      password: 'synthetic-test-only',
    );
    final repo = ExamRepository(client: client);
    await repo.createExam(
      ExamDraftInput(
        classRow: classRow,
        subject: '  اللغة الصينية ',
        title: ' اختبار ',
        date: '2026-03-15',
        room: ' ',
      ),
    );
    final insert = calls.singleWhere(
      (r) => r.method == 'POST' && r.url.path.endsWith('/exams'),
    );
    expect(jsonDecode(insert.body), {
      'branch_id': 'b1',
      'academic_session_id': 's1',
      'class_id': 'c1',
      'course_id': null,
      'subject': 'اللغة الصينية',
      'title': 'اختبار',
      'exam_date': '2026-03-15',
      'start_time': null,
      'end_time': null,
      'room': null,
      'max_score': 100,
    });
    calls.clear();
    await repo.saveMark('e1', {'student_id': 'st1', 'result_id': null}, '95', 'ممتاز', 100);
    final mark = calls.singleWhere(
      (r) => r.method == 'POST' && r.url.path.endsWith('/exam_results'),
    );
    expect(jsonDecode(mark.body), {
      'exam_id': 'e1',
      'student_id': 'st1',
      'score': 95,
      'note': 'ممتاز',
    });
    await expectLater(
      repo.transition('e1', 'draft', 'published'),
      throwsFormatException,
    );
    await expectLater(
      repo.saveMark('e1', {'student_id': 'st1', 'result_id': null}, '101', '', 100),
      throwsFormatException,
    );
    await client.dispose();
  });

  testWidgets('staff manage classes and enter marks in RTL', (tester) async {
    final repo = FakeExamRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveExamsScreen(roles: {Role.teacher}, repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(ListView))),
      TextDirection.rtl,
    );
    expect(find.text('الصف الأول'), findsOneWidget);
    await tester.tap(find.text('الصف الأول'));
    await tester.pumpAndSettle();
    expect(find.text('اختبار منتصف الفصل'), findsOneWidget);
    await tester.tap(find.text('اختبار منتصف الفصل'));
    await tester.pumpAndSettle();
    expect(find.text('الطالب الأول · A-1'), findsOneWidget);
    expect(find.text('راسب'), findsOneWidget); // saved fail grade for st2
    await tester.enterText(find.byType(TextField).first, '95');
    await tester.pumpAndSettle();
    expect(find.text('ممتاز'), findsOneWidget);
    await tester.ensureVisible(find.text('حفظ الدرجة').first);
    await tester.tap(find.text('حفظ الدرجة').first);
    await tester.pumpAndSettle();
    expect(repo.saves.single['student_id'], 'st1');
    expect(repo.saves.single['score'], 95);
    expect(tester.takeException(), isNull);
  });

  testWidgets('family see published results only, with print action', (tester) async {
    final repo = FakeExamRepository()
      ..family = [
        {
          'id': 'r1',
          'exam_id': 'e1',
          'student_id': 'st1',
          'score': 95,
          'grade': 'excellent',
          'note': null,
          'student_name': 'الطالب الأول',
          'exam': {
            'title': 'اختبار منتصف الفصل',
            'subject': 'اللغة الصينية',
            'exam_date': '2026-03-15',
            'max_score': 100,
          },
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveExamsScreen(
            key: const ValueKey('family-full'),
            roles: {Role.parent},
            repository: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('النتائج المنشورة'), findsOneWidget);
    expect(find.textContaining('ممتاز'), findsOneWidget);
    expect(find.byTooltip('معاينة وطباعة'), findsOneWidget);
    // Empty and error states stay truthful.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveExamsScreen(
            key: const ValueKey('family-empty'),
            roles: {Role.student},
            repository: FakeExamRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('لا توجد نتائج منشورة'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveExamsScreen(
            key: const ValueKey('family-error'),
            roles: {Role.student},
            repository: FakeExamRepository()..fail = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر تحميل'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}
