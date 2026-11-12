import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'components.dart';
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
            .select('id,course_id,title,due_at,max_score')
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
            .select('id,homework_id,student_id,status,content,score,feedback')
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

class TeacherClassPage extends StatelessWidget {
  const TeacherClassPage({super.key, required this.data});
  final TeacherClassData data;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: darkRed,
      title: Text('${data.row['name']}'),
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
                builder: (_) =>
                    LiveCourseLessons(course: course, canTrack: false),
              ),
            ),
            child: ListTile(
              title: Text('${course['title']}'),
              trailing: const Icon(Icons.chevron_left),
            ),
          ),
        const SectionHeading('الواجبات والتسليمات'),
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
                      '${data.students.where((s) => s['id'] == submission['student_id']).first['full_name']} · ${submission['status']}',
                    ),
                    subtitle: Text(
                      '${submission['content'] ?? 'لا توجد إجابة نصية'}'
                      '${submission['score'] == null ? '' : '\n${submission['score']} / ${homework['max_score']}'}'
                      '${submission['feedback'] == null ? '' : '\n${submission['feedback']}'}',
                    ),
                  ),
              ],
            ),
          ),
        const Text('مراجعة الدرجات متاحة عبر بوابة الويب وفق صلاحيات الخادم.'),
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
