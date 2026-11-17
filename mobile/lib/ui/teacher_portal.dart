import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'components.dart';
import '../data/homework_files.dart';
import 'live_courses.dart';

class TeacherClassData {
  const TeacherClassData({
    required this.row,
    required this.students,
    required this.courses,
    required this.homework,
    required this.submissions,
    required this.sessions,
    required this.progress,
  });
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> students,
      courses,
      homework,
      submissions,
      sessions,
      progress;
}

Future<List<TeacherClassData>> loadTeacherClasses() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw StateError('انتهت الجلسة. يرجى تسجيل الدخول.');
  final classes = await client
      .from('classes')
      .select('id,name,program,capacity')
      .eq('teacher_id', user.id)
      .order('name');
  if (classes.isEmpty) return [];
  final ids = classes.map((row) => row['id'] as String).toList();
  final students = await client
      .from('students')
      .select('id,class_id,full_name,admission_no')
      .inFilter('class_id', ids)
      .eq('status', 'active')
      .order('full_name');
  final courses = await client
      .from('learning_courses')
      .select('id,class_id,title,description,level')
      .inFilter('class_id', ids)
      .eq('is_active', true)
      .order('title');
  final sessions = await client
      .from('attendance_sessions')
      .select('id,class_id,attendance_date,status')
      .inFilter('class_id', ids)
      .order('attendance_date', ascending: false);
  final courseIds = courses.map((row) => row['id'] as String).toList();
  final lessons = courseIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client
            .from('learning_lessons')
            .select('id,course_id')
            .inFilter('course_id', courseIds);
  final homework = courseIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client
            .from('learning_homework')
            .select(
              'id,course_id,title,instructions,due_at,max_score,is_published,attachment_path,attachment_file_name',
            )
            .inFilter('course_id', courseIds)
            .order('due_at');
  final homeworkIds = homework.map((row) => row['id'] as String).toList();
  final studentIds = students.map((row) => row['id'] as String).toList();
  final lessonIds = lessons.map((row) => row['id'] as String).toList();
  final progress = lessonIds.isEmpty || studentIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client
            .from('learning_lesson_progress')
            .select('lesson_id,student_id,status')
            .inFilter('lesson_id', lessonIds)
            .inFilter('student_id', studentIds);
  final submissions = homeworkIds.isEmpty || studentIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client
            .from('learning_homework_submissions')
            .select(
              'id,homework_id,student_id,status,content,score,feedback,submitted_at,submission_path,submission_file_name',
            )
            .inFilter('homework_id', homeworkIds)
            .inFilter('student_id', studentIds);
  return mapTeacherClasses(
    classes,
    students,
    courses,
    lessons,
    homework,
    submissions,
    sessions,
    progress,
  );
}

List<TeacherClassData> mapTeacherClasses(
  List<Map<String, dynamic>> classes,
  List<Map<String, dynamic>> students,
  List<Map<String, dynamic>> courses,
  List<Map<String, dynamic>> lessons,
  List<Map<String, dynamic>> homework,
  List<Map<String, dynamic>> submissions,
  List<Map<String, dynamic>> sessions,
  List<Map<String, dynamic>> progress,
) {
  return classes.map((row) {
    final id = row['id'];
    final classStudents = students.where((s) => s['class_id'] == id).toList();
    final classCourses = courses.where((c) => c['class_id'] == id).toList();
    final classCourseIds = classCourses.map((c) => c['id']).toSet();
    final classHomework = homework
        .where((h) => classCourseIds.contains(h['course_id']))
        .toList();
    final classHomeworkIds = classHomework.map((h) => h['id']).toSet();
    final classStudentIds = classStudents.map((s) => s['id']).toSet();
    final classLessonIds = lessons
        .where((lesson) => classCourseIds.contains(lesson['course_id']))
        .map((lesson) => lesson['id'])
        .toSet();
    return TeacherClassData(
      row: row,
      students: classStudents,
      courses: classCourses,
      homework: classHomework,
      submissions: submissions
          .where(
            (s) =>
                classHomeworkIds.contains(s['homework_id']) &&
                classStudentIds.contains(s['student_id']),
          )
          .toList(),
      sessions: sessions.where((s) => s['class_id'] == id).toList(),
      progress: progress
          .where(
            (p) =>
                classLessonIds.contains(p['lesson_id']) &&
                classStudentIds.contains(p['student_id']),
          )
          .toList(),
    );
  }).toList();
}

class TeacherPortal extends StatefulWidget {
  const TeacherPortal({super.key, this.loader});
  final Future<List<TeacherClassData>> Function()? loader;
  @override
  State<TeacherPortal> createState() => _TeacherPortalState();
}

class _TeacherPortalState extends State<TeacherPortal> {
  late Future<List<TeacherClassData>> future =
      (widget.loader ?? loadTeacherClasses)();
  @override
  Widget build(BuildContext context) => FutureBuilder<List<TeacherClassData>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return EmptyPanel(
          'تعذر تحميل بيانات المعلم. تحقق من الاتصال وصلاحيات الحساب.',
          retry: () =>
              setState(() => future = (widget.loader ?? loadTeacherClasses)()),
        );
      }
      final classes = snapshot.data!;
      if (classes.isEmpty) {
        return const Center(child: EmptyPanel('لا توجد شعب مسندة إلى حسابك.'));
      }
      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const SectionHeading('شعبي المسندة'),
          const Text(
            'قد تكون البيانات المحمّلة محدودة بعدد الصفوف الذي تسمح به الخدمة؛ الأعداد المعروضة ليست إجماليات مؤكدة.',
          ),
          for (final item in classes)
            SaiCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TeacherClassPage(data: item),
                ),
              ),
              child: ListTile(
                title: Text('${item.row['name']}'),
                subtitle: Text(
                  '${item.students.length} طالب محمّل · ${item.courses.length} مقرر محمّل · ${item.submissions.where((s) => s['status'] == 'submitted').length} تسليم محمّل بانتظار المراجعة',
                ),
                trailing: const Icon(Icons.chevron_left, color: gold),
              ),
            ),
        ],
      );
    },
  );
}

class _HomeworkDraft {
  const _HomeworkDraft({
    required this.courseId,
    required this.title,
    required this.instructions,
    required this.dueAt,
    required this.maxScore,
    required this.isPublished,
    this.attachment,
  });
  final String courseId;
  final String title;
  final String instructions;
  final DateTime dueAt;
  final int maxScore;
  final bool isPublished;
  final PlatformFile? attachment;
}

class _HomeworkGrade {
  const _HomeworkGrade(this.score, this.feedback);
  final num score;
  final String feedback;
}

class TeacherClassPage extends StatefulWidget {
  const TeacherClassPage({super.key, required this.data});
  final TeacherClassData data;

  @override
  State<TeacherClassPage> createState() => _TeacherClassPageState();
}

class _TeacherClassPageState extends State<TeacherClassPage> {
  late TeacherClassData data = widget.data;
  bool busy = false;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _refresh() async {
    final loaded = await loadTeacherClasses();
    final refreshed = loaded.where((item) => item.row['id'] == data.row['id']);
    if (refreshed.isEmpty) throw StateError('تعذر إعادة تحميل بيانات الشعبة.');
    if (mounted) setState(() => data = refreshed.first);
  }

  Future<void> _createHomework() async {
    if (busy || data.courses.isEmpty) return;
    final title = TextEditingController();
    final instructions = TextEditingController();
    final score = TextEditingController(text: '100');
    var courseId = data.courses.first['id'] as String;
    var dueAt = DateTime.now().add(const Duration(days: 7));
    var isPublished = true;
    PlatformFile? attachment;

    final draft = await showDialog<_HomeworkDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('إنشاء واجب'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: courseId,
                  decoration: const InputDecoration(labelText: 'المقرر'),
                  items: [
                    for (final course in data.courses)
                      DropdownMenuItem(
                        value: course['id'] as String,
                        child: Text(
                          '${course['title']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) update(() => courseId = value);
                  },
                ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'عنوان الواجب'),
                ),
                TextField(
                  controller: instructions,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'التعليمات'),
                ),
                TextField(
                  controller: score,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الدرجة العظمى'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'موعد التسليم: ${dueAt.toLocal().toString().substring(0, 16)}',
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      initialDate: dueAt,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (selected != null) {
                      update(() {
                        dueAt = DateTime(
                          selected.year,
                          selected.month,
                          selected.day,
                          23,
                          59,
                        );
                      });
                    }
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('نشر للطلاب'),
                  value: isPublished,
                  onChanged: (value) {
                    if (value != null) update(() => isPublished = value);
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final picked = await pickHomeworkFile();
                      if (picked != null) update(() => attachment = picked);
                    } catch (error) {
                      _message('تعذر اختيار الملف: $error');
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(attachment?.name ?? 'ملف تعليمات اختياري'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final parsedScore = int.tryParse(score.text.trim());
                if (title.text.trim().length < 4 ||
                    instructions.text.trim().length > 500 ||
                    parsedScore == null ||
                    parsedScore < 1 ||
                    parsedScore > 1000) {
                  _message('تحقق من العنوان والتعليمات والدرجة (١–١٠٠٠).');
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _HomeworkDraft(
                    courseId: courseId,
                    title: title.text.trim(),
                    instructions: instructions.text.trim(),
                    dueAt: dueAt,
                    maxScore: parsedScore,
                    isPublished: isPublished,
                    attachment: attachment,
                  ),
                );
              },
              child: const Text('حفظ الواجب'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    instructions.dispose();
    score.dispose();
    if (draft == null || !mounted) return;
    setState(() => busy = true);
    String? createdId;
    try {
      final client = Supabase.instance.client;
      final last = await client
          .from('learning_homework')
          .select('position')
          .eq('course_id', draft.courseId)
          .order('position', ascending: false)
          .limit(1);
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw StateError('انتهت الجلسة. سجّل الدخول مجدداً.');
      final inserted = await client
          .from('learning_homework')
          .insert({
            'course_id': draft.courseId,
            'title': draft.title,
            'instructions': draft.instructions.isEmpty
                ? null
                : draft.instructions,
            'due_at': draft.dueAt.toUtc().toIso8601String(),
            'max_score': draft.maxScore,
            'position':
                ((last.firstOrNull?['position'] as num?)?.toInt() ?? 0) + 1,
            'is_published': draft.isPublished,
            'created_by': userId,
          })
          .select('id')
          .single();
      createdId = inserted['id'] as String;
      if (draft.attachment != null) {
        final path = await uploadHomeworkFile(
          '$createdId/instructions',
          draft.attachment!,
        );
        await client
            .from('learning_homework')
            .update({
              'attachment_path': path,
              'attachment_file_name': draft.attachment!.name,
            })
            .eq('id', createdId);
      }
      await _refresh();
      _message('تم حفظ الواجب في قاعدة البيانات المشتركة.');
    } catch (error) {
      if (createdId != null) {
        var refreshFailure = '';
        try {
          await _refresh();
        } catch (refreshError) {
          refreshFailure = ' كما تعذر تحديث القائمة: $refreshError';
        }
        _message(
          'حُفظ الواجب، لكن تعذر ربط ملف التعليمات: $error$refreshFailure',
        );
      } else {
        _message('تعذر إنشاء الواجب: $error');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _gradeSubmission(
    Map<String, dynamic> homework,
    Map<String, dynamic> submission,
  ) async {
    if (busy) return;
    final score = TextEditingController(
      text: submission['score']?.toString() ?? '',
    );
    final feedback = TextEditingController(
      text: submission['feedback']?.toString() ?? '',
    );
    final draft = await showDialog<_HomeworkGrade>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تصحيح الواجب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: score,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'الدرجة من ${homework['max_score']}',
              ),
            ),
            TextField(
              controller: feedback,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'ملاحظات للطالب'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = num.tryParse(score.text.trim());
              final max = (homework['max_score'] as num?)?.toDouble() ?? 0;
              if (parsed == null || parsed < 0 || parsed > max) {
                _message('أدخل درجة بين صفر و$max.');
                return;
              }
              Navigator.pop(
                dialogContext,
                _HomeworkGrade(parsed, feedback.text.trim()),
              );
            },
            child: const Text('حفظ الدرجة'),
          ),
        ],
      ),
    );
    score.dispose();
    feedback.dispose();
    if (draft == null || !mounted) return;
    setState(() => busy = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw StateError('انتهت الجلسة. سجّل الدخول مجدداً.');
      final saved = await client
          .from('learning_homework_submissions')
          .update({
            'status': 'graded',
            'score': draft.score,
            'feedback': draft.feedback.isEmpty ? null : draft.feedback,
            'graded_by': userId,
            'graded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', submission['id'])
          .select('id')
          .maybeSingle();
      if (saved == null) {
        throw StateError('لم تُحفظ الدرجة؛ تحقق من صلاحيات المقرر.');
      }
      await _refresh();
      _message('تم حفظ الدرجة والملاحظات.');
    } catch (error) {
      _message('تعذر حفظ الدرجة: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openFile(String path) async {
    try {
      final url = await homeworkSignedUrl(path);
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('تعذر فتح الملف على هذا الجهاز.');
      }
    } catch (error) {
      _message('تعذر فتح الملف: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: darkRed,
      title: Text('${data.row['name']}'),
      actions: [
        if (busy)
          const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text('${data.row['program']}'),
        const SectionHeading('الطلاب'),
        if (data.students.isEmpty)
          const EmptyPanel('لا يوجد طلاب نشطون في هذه الشعبة.'),
        for (final student in data.students)
          SaiCard(
            child: ListTile(
              title: Text('${student['full_name']}'),
              subtitle: Text('${student['admission_no']}'),
            ),
          ),
        const SectionHeading('حالات التقدم المسجلة'),
        if (data.progress.isEmpty) const Text('لا توجد حالات تقدم مسجلة.'),
        if (data.progress.isNotEmpty)
          Text(
            '${data.progress.length} حالة مسجلة؛ حالات الإكمال السابقة غير متحققة وليست إنجازاً معتمداً.',
          ),
        const SectionHeading('المقررات والدروس'),
        if (data.courses.isEmpty)
          const EmptyPanel('لا توجد مقررات نشطة لهذه الشعبة.'),
        for (final course in data.courses)
          SaiCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LiveCourseLessons(
                  course: course,
                  canTrack: false,
                  canManageAssessments: true,
                  canViewAssessments: true,
                ),
              ),
            ),
            child: ListTile(
              title: Text('${course['title']}'),
              trailing: const Icon(Icons.chevron_left),
            ),
          ),
        Row(
          children: [
            const Expanded(child: SectionHeading('الواجبات والتسليمات')),
            IconButton(
              onPressed: busy || data.courses.isEmpty ? null : _createHomework,
              tooltip: 'إنشاء واجب',
              icon: const Icon(Icons.add_task),
            ),
          ],
        ),
        if (data.homework.isEmpty) const EmptyPanel('لا توجد واجبات متاحة.'),
        for (final homework in data.homework)
          SaiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${homework['title']} · ${homework['due_at']}'),
                for (final submission in data.submissions.where(
                  (row) => row['homework_id'] == homework['id'],
                ))
                  ListTile(
                    title: Text(
                      '${data.students.where((s) => s['id'] == submission['student_id']).firstOrNull?['full_name'] ?? 'طالب'} · ${submission['status']}',
                    ),
                    subtitle: Text(
                      '${submission['content'] ?? 'لا توجد إجابة نصية'}'
                      '${submission['score'] == null ? '' : '\n${submission['score']} / ${homework['max_score']}'}'
                      '${submission['feedback'] == null ? '' : '\n${submission['feedback']}'}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (choice) {
                        if (choice == 'grade') {
                          _gradeSubmission(homework, submission);
                        }
                        if (choice == 'file' &&
                            submission['submission_path'] is String) {
                          _openFile(submission['submission_path'] as String);
                        }
                      },
                      itemBuilder: (_) => [
                        if (submission['submission_path'] is String)
                          PopupMenuItem(
                            value: 'file',
                            child: Text(
                              'عرض ${submission['submission_file_name'] ?? 'الملف'}',
                            ),
                          ),
                        if (submission['status'] != 'graded')
                          const PopupMenuItem(
                            value: 'grade',
                            child: Text('تصحيح'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SectionHeading('جلسات الحضور'),
        if (data.sessions.isEmpty)
          const EmptyPanel('لا توجد جلسات حضور متاحة.'),
        for (final session in data.sessions)
          SaiCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TeacherAttendancePage(
                  session: session,
                  students: data.students,
                ),
              ),
            ),
            child: ListTile(
              title: Text('${session['attendance_date']}'),
              subtitle: Text('${session['status']}'),
              trailing: const Icon(Icons.chevron_left),
            ),
          ),
        const Text(
          'الحضور للعرض فقط حتى التحقق من صلاحيات الكتابة في البيئة المعتمدة.',
        ),
      ],
    ),
  );
}

class TeacherAttendancePage extends StatelessWidget {
  const TeacherAttendancePage({
    super.key,
    required this.session,
    required this.students,
  });
  final Map<String, dynamic> session;
  final List<Map<String, dynamic>> students;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: darkRed,
      title: Text('${session['attendance_date']}'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('attendance_records')
          .select('student_id,status,note')
          .eq('attendance_session_id', session['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyPanel(
            'تعذر تحميل سجلات الحضور. عد إلى الصفحة السابقة وأعد المحاولة.',
          );
        }
        final names = {
          for (final student in students) student['id']: student['full_name'],
        };
        final rows = snapshot.data!
            .where((row) => names.containsKey(row['student_id']))
            .toList();
        if (rows.isEmpty) return const EmptyPanel('لا توجد سجلات حضور متاحة.');
        return ListView(
          children: [
            for (final row in rows)
              ListTile(
                title: Text('${names[row['student_id']]}'),
                subtitle: Text('${row['status']} · ${row['note'] ?? ''}'),
              ),
          ],
        );
      },
    ),
  );
}
