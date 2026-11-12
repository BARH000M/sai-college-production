import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/access.dart';
import 'components.dart';
import 'vocabulary_practice.dart';

const _lessonMediaBucket = 'lesson-media';

class LiveCourseCatalog extends StatefulWidget {
  const LiveCourseCatalog({super.key, required this.roles});
  final Set<Role> roles;

  @override
  State<LiveCourseCatalog> createState() => _LiveCourseCatalogState();
}

class _LiveCourseCatalogState extends State<LiveCourseCatalog> {
  late Future<List<Map<String, dynamic>>> courses;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    courses = _loadCourses(widget.roles);
  }

  Future<List<Map<String, dynamic>>> _loadCourses(Set<Role> roles) async {
    final client = Supabase.instance.client;
    final staff = roles.any((role) => {
      Role.super_admin, Role.admin, Role.teacher, Role.content_editor,
    }.contains(role));
    if (!staff && roles.contains(Role.student)) {
      final user = client.auth.currentUser;
      if (user == null) throw StateError('انتهت الجلسة. يرجى تسجيل الدخول.');
      final student = await client.from('students').select('class_id')
          .eq('user_id', user.id).maybeSingle();
      final classId = student?['class_id'];
      if (classId == null) return [];
      return client.from('learning_courses')
          .select('id,title,description,level')
          .eq('is_active', true).eq('class_id', classId).order('title');
    }
    return client
        .from('learning_courses')
        .select('id,title,description,level')
        .eq('is_active', true)
        .order('title');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: courses,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: EmptyPanel(
            'تعذر تحميل المقررات. تحقق من اتصال الإنترنت وصلاحية الحساب.',
              retry: () => setState(_reload),
            ),
          ),
        );
      }
      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
      if (rows.isEmpty) {
        return Center(
          child: EmptyPanel(
            'لا توجد مقررات نشطة متاحة لهذا الحساب بعد.',
            retry: () => setState(_reload),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeading('المقررات المنشورة')),
              IconButton(
                tooltip: 'تحديث من قاعدة البيانات المشتركة',
                onPressed: () => setState(_reload),
                icon: const Icon(Icons.refresh_rounded, color: gold),
              ),
            ],
          ),
          for (final course in rows)
            SaiCard(
              padding: 9,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LiveCourseLessons(
                    course: course,
                    canTrack: widget.roles.contains(Role.student),
                  ),
                ),
              ),
              child: ListTile(
                leading: const Icon(Icons.menu_book_rounded, color: gold),
                title: Text('${course['title'] ?? 'مقرر'}'),
                subtitle: Text(
                  [course['level'], course['description']]
                      .where((value) => value != null && '$value'.trim().isNotEmpty)
                      .join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_left_rounded, color: gold),
              ),
            ),
        ],
      );
    },
  );
}

class LiveCourseLessons extends StatefulWidget {
  const LiveCourseLessons({super.key, required this.course, required this.canTrack});
  final Map<String, dynamic> course;
  final bool canTrack;

  @override
  State<LiveCourseLessons> createState() => _LiveCourseLessonsState();
}

class _LiveCourseLessonsState extends State<LiveCourseLessons> {
  late Future<List<Map<String, dynamic>>> lessons;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    lessons = Supabase.instance.client
        .from('learning_lessons')
        .select('id,course_id,title,summary,kind,position,duration_minutes,content_kind,content_url,content_body,content_path,content_file_name')
        .eq('course_id', widget.course['id'])
        .eq('is_published', true)
        .order('position');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: darkRed,
      foregroundColor: ink,
      title: Text('${widget.course['title'] ?? 'المقرر'}'),
      actions: [
        IconButton(
          tooltip: 'تحديث الدروس',
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: lessons,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: EmptyPanel('تعذر تحميل دروس هذا المقرر. تحقق من اتصال الإنترنت وصلاحية الحساب.', retry: () => setState(_reload)),
            ),
          );
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return const Center(child: EmptyPanel('لا توجد دروس منشورة في هذا المقرر.'));
        }
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SaiCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(backgroundColor: darkRed, foregroundColor: ink, title: const Text('تدريب المفردات')),
                  body: LiveVocabularyPractice(courseId: '${widget.course['id']}', canTrack: widget.canTrack),
                ),
              )),
              child: const ListTile(
                leading: Icon(Icons.translate_rounded, color: gold),
                title: Text('تدريب المفردات الصينية'),
                subtitle: Text('مراجعة ذاتية للمفردات المنشورة'),
                trailing: Icon(Icons.chevron_left_rounded, color: gold),
              ),
            ),
            if ((widget.course['description'] as String?)?.trim().isNotEmpty == true)
              SaiCard(child: Text('${widget.course['description']}')),
            const SectionHeading('الدروس المنشورة'),
            for (final lesson in rows)
              SaiCard(
                padding: 8,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LiveLessonPage(
                      lesson: lesson,
                      canTrack: widget.canTrack,
                    ),
                  ),
                ),
                child: ListTile(
                  leading: Icon(_lessonIcon('${lesson['kind'] ?? ''}'), color: gold),
                  title: Text('${lesson['title'] ?? 'درس'}'),
                  subtitle: Text(
                    [lesson['summary'], if (lesson['duration_minutes'] != null) '${lesson['duration_minutes']} دقيقة']
                        .where((value) => value != null && '$value'.trim().isNotEmpty)
                        .join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded, color: gold),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class LiveLessonPage extends StatefulWidget {
  const LiveLessonPage({super.key, required this.lesson, required this.canTrack});
  final Map<String, dynamic> lesson;
  final bool canTrack;

  @override
  State<LiveLessonPage> createState() => _LiveLessonPageState();
}

class _LiveLessonPageState extends State<LiveLessonPage> {
  late final Future<String?> mediaUrl;
  String? studentId;
  bool progressReady = false;
  String? progressStatus;
  String? progressError;

  @override
  void initState() {
    super.initState();
    mediaUrl = _mediaUrl();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (!widget.canTrack) {
      if (mounted) setState(() => progressReady = true);
      return;
    }
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw StateError('انتهت الجلسة. يرجى تسجيل الدخول.');
      final student = await client
          .from('students')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();
      if (student == null) return;
      studentId = student['id'] as String;
      final row = await client
          .from('learning_lesson_progress')
          .select('status')
          .eq('lesson_id', widget.lesson['id'])
          .eq('student_id', studentId!)
          .maybeSingle();
      if (mounted) setState(() => progressStatus = row?['status'] as String?);
    } catch (error) {
      if (mounted) setState(() => progressError = 'تعذر تحميل حالة التقدم: $error');
    } finally {
      if (mounted) setState(() => progressReady = true);
    }
  }

  Future<String?> _mediaUrl() async {
    final path = (widget.lesson['content_path'] as String?)?.trim();
    if (path != null && path.isNotEmpty) {
      return Supabase.instance.client.storage
          .from(_lessonMediaBucket)
          .createSignedUrl(path, 3600);
    }
    final url = (widget.lesson['content_url'] as String?)?.trim();
    return url?.isNotEmpty == true ? url : null;
  }

  Future<void> _openMedia(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _notice('رابط المادة غير صالح.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _notice('تعذر فتح المادة على هذا الجهاز.');
    } catch (_) {
      if (mounted) _notice('تعذر فتح المادة على هذا الجهاز.');
    }
  }

  void _notice(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final body = (widget.lesson['content_body'] as String?)?.trim();
    final contentKind = '${widget.lesson['content_kind'] ?? 'none'}';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkRed,
        foregroundColor: ink,
        title: Text('${widget.lesson['title'] ?? 'الدرس'}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SaiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.lesson['summary'] ?? ''}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.lesson['duration_minutes'] == null ? '' : 'المدة: ${widget.lesson['duration_minutes']} دقيقة · '}نوع المحتوى: ${_contentLabel(contentKind)}',
                ),
              ],
            ),
          ),
          if (body != null && body.isNotEmpty)
            SaiCard(
              child: SelectableText(body, style: Theme.of(context).textTheme.bodyLarge),
            ),
          if ((body == null || body.isEmpty) &&
              (widget.lesson['content_path'] == null || '${widget.lesson['content_path']}'.trim().isEmpty) &&
              (widget.lesson['content_url'] == null || '${widget.lesson['content_url']}'.trim().isEmpty))
            const EmptyPanel('لا توجد مادة تعليمية متاحة لهذا الدرس بعد.'),
          if (contentKind != 'none' &&
              (widget.lesson['content_path'] != null || widget.lesson['content_url'] != null))
            FutureBuilder<String?>(
              future: mediaUrl,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SaiCard(child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return const EmptyPanel('تعذر تجهيز رابط مادة الدرس. تحقق من صلاحيات الملفات.');
                }
                return SaiCard(
                  child: FilledButton.icon(
                    onPressed: () => _openMedia(snapshot.data!),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text('فتح ${_contentLabel(contentKind)}'),
                  ),
                );
              },
            ),
          if (widget.canTrack && progressReady && progressError != null)
            EmptyPanel(progressError!, retry: () {
              setState(() { progressReady = false; progressError = null; });
              _loadProgress();
            }),
          if (widget.canTrack && progressReady && studentId != null && progressError == null)
            LessonProgressNotice(status: progressStatus),
          if (widget.canTrack && progressReady && studentId == null && progressError == null)
            const EmptyPanel('لا يوجد ملف طالب مرتبط بهذا الحساب؛ لم يُسجل تقدم محلي بديل.'),
        ],
      ),
    );
  }
}

class LessonProgressNotice extends StatelessWidget {
  const LessonProgressNotice({super.key, required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) => SaiCard(
    child: Text(
      '${status == 'completed' ? 'توجد حالة إكمال سابقة غير متحققة. ' : status == 'in_progress' ? 'الحالة المسجلة: قيد الدراسة. ' : 'لا توجد حالة إكمال مسجلة. '}'
      'تسجيل الإكمال معطل حتى يتوفر تقييم موثوق.',
    ),
  );
}

IconData _lessonIcon(String kind) => switch (kind) {
  'listening' => Icons.headphones_rounded,
  'speaking' => Icons.record_voice_over_rounded,
  'vocabulary' => Icons.translate_rounded,
  'reading' => Icons.menu_book_rounded,
  'review' => Icons.replay_rounded,
  _ => Icons.play_lesson_rounded,
};

String _contentLabel(String kind) => switch (kind) {
  'video' => 'الفيديو',
  'audio' => 'التسجيل الصوتي',
  'reading' => 'المادة المقروءة',
  'link' => 'الرابط الخارجي',
  _ => 'المادة',
};
