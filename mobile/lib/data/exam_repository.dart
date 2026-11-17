import 'package:supabase_flutter/supabase_flutter.dart';

/// Phase 4A examinations contract — mirrors src/portal/lib/examinations.ts and
/// supabase/deployment/phase4a-examinations/001_examinations.sql.
const examStatuses = <String, String>{
  'draft': 'مسودة',
  'marks_entry': 'رصد الدرجات',
  'review': 'قيد المراجعة',
  'published': 'منشورة',
  'cancelled': 'ملغاة',
};

const gradeLabels = <String, String>{
  'excellent': 'ممتاز',
  'very_good': 'جيد جداً',
  'good': 'جيد',
  'acceptable': 'مقبول',
  'weak': 'ضعيف',
  'fail': 'راسب',
};

/// Mirrors the server bands in private.sai_exam_grade.
String? gradeForScore(num? score, num maxScore) {
  if (score == null || maxScore <= 0) return null;
  final ratio = score / maxScore;
  if (ratio >= 0.9) return 'excellent';
  if (ratio >= 0.8) return 'very_good';
  if (ratio >= 0.7) return 'good';
  if (ratio >= 0.6) return 'acceptable';
  if (ratio >= 0.5) return 'weak';
  return 'fail';
}

const examTransitions = <String, List<String>>{
  'draft': ['marks_entry', 'cancelled'],
  'marks_entry': ['review', 'cancelled'],
  'review': ['marks_entry', 'published'],
  'published': ['review'],
  'cancelled': [],
};

bool canTransitionExam(String from, String to) =>
    examTransitions[from]?.contains(to) ?? false;

bool _hasControl(String value) =>
    value.runes.any((rune) => rune < 32 || rune == 127);

class ExamDraftInput {
  const ExamDraftInput({
    required this.classRow,
    required this.subject,
    required this.title,
    required this.date,
    this.courseId,
    this.startTime,
    this.endTime,
    this.room,
    this.maxScore = 100,
  });
  final Map<String, dynamic> classRow;
  final String subject, title, date;
  final String? courseId, startTime, endTime, room;
  final num maxScore;
}

String? validateExamDraft(
  ExamDraftInput draft, {
  String? sessionStarts,
  String? sessionEnds,
}) {
  final title = draft.title.trim();
  if (title.runes.length < 2 || title.runes.length > 160 || _hasControl(title)) {
    return 'عنوان الاختبار يجب أن يكون بين حرفين و١٦٠ حرفاً دون محارف تحكم.';
  }
  final subject = draft.subject.trim();
  if (subject.runes.length < 2 ||
      subject.runes.length > 120 ||
      _hasControl(subject)) {
    return 'اسم المادة يجب أن يكون بين حرفين و١٢٠ حرفاً دون محارف تحكم.';
  }
  if (DateTime.tryParse(draft.date) == null) return 'تاريخ الاختبار غير صالح.';
  if (sessionStarts != null && draft.date.compareTo(sessionStarts) < 0 ||
      sessionEnds != null && draft.date.compareTo(sessionEnds) > 0) {
    return 'تاريخ الاختبار خارج الجلسة الأكاديمية.';
  }
  if (draft.startTime != null &&
      draft.endTime != null &&
      draft.startTime!.isNotEmpty &&
      draft.endTime!.isNotEmpty &&
      draft.endTime!.compareTo(draft.startTime!) <= 0) {
    return 'وقت النهاية يجب أن يكون بعد وقت البداية.';
  }
  final room = draft.room?.trim() ?? '';
  if (room.isNotEmpty && (room.runes.length > 60 || _hasControl(room))) {
    return 'اسم القاعة غير صالح.';
  }
  if (draft.maxScore <= 0 || draft.maxScore > 1000) {
    return 'الدرجة العظمى يجب أن تكون بين ١ و١٠٠٠.';
  }
  return null;
}

String? validateMark(String score, num maxScore) {
  if (score.trim().isEmpty) return null;
  final value = num.tryParse(score.trim());
  if (value == null) return 'الدرجة غير صالحة.';
  if (value < 0 || value > maxScore) {
    return 'الدرجة يجب أن تكون بين صفر و$maxScore.';
  }
  return null;
}

class ExamRepository {
  ExamRepository({SupabaseClient? client}) : _injected = client;
  final SupabaseClient? _injected;
  SupabaseClient get client => _injected ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> classes() async =>
      List<Map<String, dynamic>>.from(await client.rpc('sai_exams_classes'));

  Future<List<Map<String, dynamic>>> exams({String? classId}) async {
    var query = client.from('exams').select(
      'id,branch_id,academic_session_id,class_id,course_id,subject,title,'
      'exam_date,start_time,end_time,room,max_score,status,published_at',
    );
    if (classId != null && classId.isNotEmpty) {
      query = query.eq('class_id', classId);
    }
    return List<Map<String, dynamic>>.from(
      await query.order('exam_date', ascending: false).limit(200),
    );
  }

  Future<List<Map<String, dynamic>>> roster(String examId) async =>
      List<Map<String, dynamic>>.from(
        await client.rpc('sai_exam_roster', params: {'wanted_exam': examId}),
      );

  /// Published results visible to the signed-in student or verified parent.
  Future<List<Map<String, dynamic>>> familyResults() async {
    final rows = await client
        .from('exam_results')
        .select('id,exam_id,student_id,score,grade,note,'
            'exam:exams(title,subject,exam_date,max_score)')
        .order('id')
        .limit(200);
    final results = List<Map<String, dynamic>>.from(rows);
    if (results.isEmpty) return results;
    final ids = results.map((row) => row['student_id'] as String).toSet().toList();
    final students = await client
        .from('students')
        .select('id,full_name')
        .inFilter('id', ids);
    final names = {for (final row in students) row['id']: row['full_name']};
    return results
        .map((row) => {...row, 'student_name': names[row['student_id']] ?? '—'})
        .toList();
  }

  Future<void> createExam(ExamDraftInput draft) async {
    final error = validateExamDraft(draft);
    if (error != null) throw FormatException(error);
    final classRow = draft.classRow;
    await client.from('exams').insert({
      'branch_id': classRow['branch_id'],
      'academic_session_id': classRow['academic_session_id'],
      'class_id': classRow['id'],
      'course_id': draft.courseId,
      'subject': draft.subject.trim(),
      'title': draft.title.trim(),
      'exam_date': draft.date,
      'start_time': draft.startTime == null || draft.startTime!.isEmpty
          ? null
          : draft.startTime,
      'end_time': draft.endTime == null || draft.endTime!.isEmpty
          ? null
          : draft.endTime,
      'room': draft.room?.trim().isEmpty ?? true ? null : draft.room!.trim(),
      'max_score': draft.maxScore,
    });
  }

  Future<void> transition(String examId, String from, String to) async {
    if (!canTransitionExam(from, to)) {
      throw const FormatException('انتقال الحالة غير مسموح.');
    }
    final rows = await client
        .from('exams')
        .update({'status': to})
        .eq('id', examId)
        .eq('status', from)
        .select('id');
    if (rows.isEmpty) {
      throw StateError('لم تُحدّث الحالة؛ قد تكون تغيّرت أو لا تملك الصلاحية.');
    }
  }

  Future<void> saveMark(
    String examId,
    Map<String, dynamic> entry,
    String score,
    String note,
    num maxScore,
  ) async {
    final error = validateMark(score, maxScore);
    if (error != null) throw FormatException(error);
    final values = {
      'score': score.trim().isEmpty ? null : num.parse(score.trim()),
      'note': note.trim().isEmpty ? null : note.trim(),
    };
    final resultId = entry['result_id'];
    if (resultId is String) {
      final rows = await client
          .from('exam_results')
          .update(values)
          .eq('id', resultId)
          .eq('exam_id', examId)
          .select('id');
      if (rows.isEmpty) {
        throw StateError('لم يُحدّث السجل؛ تحقق من الصلاحية وحالة الاختبار.');
      }
    } else {
      await client.from('exam_results').insert({
        'exam_id': examId,
        'student_id': entry['student_id'],
        ...values,
      });
    }
  }
}
