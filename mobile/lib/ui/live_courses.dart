import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/access.dart';
import 'components.dart';
import 'vocabulary_practice.dart';
import 'live_assessments.dart';

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
    if (roles.contains(Role.teacher) && !roles.contains(Role.admin) && !roles.contains(Role.super_admin)) {
      final user = client.auth.currentUser;
      if (user == null) throw StateError('انتهت الجلسة. يرجى تسجيل الدخول.');
      final classes = await client.from('classes').select('id').eq('teacher_id', user.id);
      final ids = classes.map((row) => row['id'] as String).toList();
      if (ids.isEmpty) return [];
      return client.from('learning_courses').select('id,title,description,level')
          .eq('is_active', true).inFilter('class_id', ids).order('title');
    }
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
                    canManageAssessments: widget.roles.any((role) =>
                        role == Role.super_admin || role == Role.admin || role == Role.teacher),
                    canViewAssessments: widget.roles.any((role) =>
                        role == Role.super_admin || role == Role.admin || role == Role.teacher
                        || role == Role.student || role == Role.parent),
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
  const LiveCourseLessons({
    super.key,
    required this.course,
    required this.canTrack,
    this.canManageAssessments = false,
    this.canViewAssessments = false,
  });
  final Map<String, dynamic> course;
  final bool canTrack;
  final bool canManageAssessments;
  final bool canViewAssessments;

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
    var query = Supabase.instance.client
        .from('learning_lessons')
        .select('id,course_id,title,summary,kind,position,duration_minutes,content_kind,content_url,content_body,content_path,content_file_name')
        .eq('course_id', widget.course['id'])
        ;
    if (!widget.canManageAssessments) query = query.eq('is_published', true);
    lessons = query.order('position');
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
                      canManageAssessments: widget.canManageAssessments,
                      canViewAssessments: widget.canViewAssessments,
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

/// Data access for the lesson study flow. Injectable so widget tests run
/// without a Supabase connection; the default implementation enforces RLS.
class LessonStudyStore {
  const LessonStudyStore();

  Future<String?> resolveStudentId() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('انتهت الجلسة. يرجى تسجيل الدخول.');
    final student = await client
        .from('students')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();
    return student?['id'] as String?;
  }

  Future<Map<String, dynamic>?> readProgress(String lessonId, String studentId) async {
    final row = await Supabase.instance.client
        .from('learning_lesson_progress')
        .select('status,completion_basis')
        .eq('lesson_id', lessonId)
        .eq('student_id', studentId)
        .maybeSingle();
    return row;
  }

  Future<void> writeProgress(
    String lessonId,
    String studentId,
    String status, {
    String? completionBasis,
  }) async {
    await Supabase.instance.client.from('learning_lesson_progress').upsert({
      'lesson_id': lessonId,
      'student_id': studentId,
      'status': status,
      'completion_basis': completionBasis,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'lesson_id,student_id');
  }

  Future<List<Map<String, dynamic>>> loadWords(String lessonId) async {
    final rows = await Supabase.instance.client
        .from('learning_vocabulary')
        .select('id,hanzi,pinyin,meaning_ar')
        .eq('lesson_id', lessonId)
        .eq('is_published', true)
        .order('position');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Set<String>> loadStudiedWords(String studentId, List<String> wordIds) async {
    if (wordIds.isEmpty) return {};
    final rows = await Supabase.instance.client
        .from('learning_vocab_progress')
        .select('vocabulary_id')
        .eq('student_id', studentId)
        .gt('review_count', 0)
        .inFilter('vocabulary_id', wordIds);
    return {for (final row in rows) row['vocabulary_id'] as String};
  }

  Future<void> markWordStudied(String wordId, String studentId) async {
    final client = Supabase.instance.client;
    final existing = await client
        .from('learning_vocab_progress')
        .select('review_count')
        .eq('vocabulary_id', wordId)
        .eq('student_id', studentId)
        .maybeSingle();
    final count = (existing?['review_count'] as num?)?.toInt() ?? 0;
    final now = DateTime.now().toIso8601String();
    await client.from('learning_vocab_progress').upsert({
      'vocabulary_id': wordId,
      'student_id': studentId,
      'status': 'learning',
      'review_count': count + 1,
      'last_reviewed_at': now,
      'updated_at': now,
    }, onConflict: 'vocabulary_id,student_id');
  }

  /// Student-safe questions: the answer-key column is not granted to clients.
  Future<List<Map<String, dynamic>>> loadQuestions(String lessonId) async {
    final rows = await Supabase.instance.client
        .from('learning_exercise_questions')
        .select('id,kind,prompt,choices,position')
        .eq('lesson_id', lessonId)
        .eq('is_published', true)
        .inFilter('kind', ['vocabulary', 'listening'])
        .order('position');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Server-side grading: returns total/correct/score/passed/results.
  Future<Map<String, dynamic>> submitExercise(
    String lessonId,
    List<Map<String, dynamic>> answers,
  ) async {
    final result = await Supabase.instance.client.rpc(
      'sai_learning_submit_exercise',
      params: {'p_lesson': lessonId, 'p_answers': answers},
    );
    if (result is! Map) throw StateError('استجابة التصحيح غير صالحة.');
    return Map<String, dynamic>.from(result);
  }
}

class LiveLessonPage extends StatefulWidget {
  const LiveLessonPage({
    super.key,
    required this.lesson,
    required this.canTrack,
    this.canManageAssessments = false,
    this.canViewAssessments = false,
    this.store,
  });
  final Map<String, dynamic> lesson;
  final bool canTrack;
  final bool canManageAssessments;
  final bool canViewAssessments;
  final LessonStudyStore? store;

  @override
  State<LiveLessonPage> createState() => _LiveLessonPageState();
}

class _LiveLessonPageState extends State<LiveLessonPage> {
  late final Future<String?> mediaUrl;
  late final LessonStudyStore store;
  String? studentId;
  bool progressReady = false;
  String? progressStatus;
  String? completionBasis;
  String? progressError;
  List<Map<String, dynamic>>? words;
  String? wordsError;
  Set<String> studiedWords = {};
  final Set<String> sessionReviewed = {};
  bool readingDone = false;
  bool listeningStarted = false;
  bool listeningDone = false;
  bool saving = false;
  String? finishError;
  List<Map<String, dynamic>>? questions;
  final Map<String, int> quizAnswers = {};
  bool submittingQuiz = false;
  String? quizError;
  Map<String, dynamic>? quizResult;

  String get lessonId => '${widget.lesson['id']}';

  @override
  void initState() {
    super.initState();
    store = widget.store ?? const LessonStudyStore();
    mediaUrl = _mediaUrl();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (!widget.canTrack) {
      if (mounted) setState(() => progressReady = true);
      return;
    }
    try {
      final resolved = await store.resolveStudentId();
      if (resolved == null) {
        if (mounted) setState(() => progressReady = true);
        return;
      }
      studentId = resolved;
      final row = await store.readProgress(lessonId, resolved);
      final status = row?['status'] as String?;
      // Opening a lesson records "in progress" without downgrading completion.
      if (status == null || status == 'not_started') {
        await store.writeProgress(lessonId, resolved, 'in_progress');
      }
      final loadedWords = await store.loadWords(lessonId);
      final studied = await store.loadStudiedWords(
        resolved,
        loadedWords.map((word) => '${word['id']}').toList(),
      );
      final loadedQuestions = await store.loadQuestions(lessonId);
      if (mounted) {
        setState(() {
          progressStatus = status == null || status == 'not_started' ? 'in_progress' : status;
          completionBasis = row?['completion_basis'] as String?;
          words = loadedWords;
          studiedWords = studied;
          questions = loadedQuestions;
        });
      }
    } catch (error) {
      if (mounted) setState(() => progressError = 'تعذر تحميل بيانات الدرس: $error');
    } finally {
      if (mounted) setState(() => progressReady = true);
    }
  }

  bool get _hasReading =>
      ((widget.lesson['content_body'] as String?)?.trim().length ?? 0) >= 20;
  bool get _hasListening =>
      widget.lesson['content_kind'] == 'audio' &&
      (((widget.lesson['content_path'] as String?)?.trim().isNotEmpty ?? false) ||
          ((widget.lesson['content_url'] as String?)?.trim().isNotEmpty ?? false));
  bool get _hasVocabulary => (words?.isNotEmpty ?? false);

  bool get _vocabularyDone =>
      (words ?? const []).every((word) =>
          sessionReviewed.contains('${word['id']}') || studiedWords.contains('${word['id']}'));

  bool get _completable =>
      progressStatus != 'completed' &&
      (_hasReading || _hasListening || _hasVocabulary) &&
      (!_hasReading || readingDone) &&
      (!_hasListening || listeningDone) &&
      (!_hasVocabulary || _vocabularyDone);

  Future<void> _markWordStudied(String wordId) async {
    if (saving || sessionReviewed.contains(wordId)) return;
    final student = studentId;
    if (student == null) return;
    setState(() => saving = true);
    try {
      await store.markWordStudied(wordId, student);
      if (mounted) setState(() => sessionReviewed.add(wordId));
    } catch (error) {
      _notice('تعذر حفظ مراجعة المفردة: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _submitQuiz() async {
    final list = questions ?? const [];
    if (submittingQuiz || list.isEmpty) return;
    final answers = [
      for (final question in list)
        if (quizAnswers['${question['id']}'] != null)
          {'question': '${question['id']}', 'choice': quizAnswers['${question['id']}']},
    ];
    if (answers.isEmpty) return;
    setState(() { submittingQuiz = true; quizError = null; });
    try {
      final result = await store.submitExercise(lessonId, answers);
      if (mounted) {
        setState(() {
          quizResult = result;
          if (result['passed'] == true) {
            progressStatus = 'completed';
            completionBasis = 'assessed';
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => quizError = 'تعذر تصحيح الإجابات: $error');
    } finally {
      if (mounted) setState(() => submittingQuiz = false);
    }
  }

  Future<void> _finishLesson() async {
    if (saving || !_completable) return;
    final student = studentId;
    if (student == null) return;
    setState(() { saving = true; finishError = null; });
    try {
      await store.writeProgress(lessonId, student, 'completed', completionBasis: 'self_reported');
      if (mounted) {
        setState(() {
          progressStatus = 'completed';
          completionBasis = 'self_reported';
        });
        _notice('أُتممت تمارين هذا الدرس وسُجّل إكمالك الذاتي (غير معتمد).');
      }
    } catch (error) {
      if (mounted) setState(() => finishError = 'تعذر تسجيل الإكمال: $error');
    } finally {
      if (mounted) setState(() => saving = false);
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
          if (widget.canViewAssessments)
            SaiCard(
              child: ListTile(
                leading: const Icon(Icons.assignment_turned_in_outlined, color: gold),
                title: const Text('التقييمات والتمارين'),
                subtitle: const Text('مسودات المعلم، المحاولات المحفوظة، والنتائج المتاحة'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => LiveAssessmentsPage(
                    lessonId: lessonId,
                    courseId: '${widget.lesson['course_id']}',
                    canManage: widget.canManageAssessments,
                    canTake: widget.canTrack,
                  ),
                )),
              ),
            ),
          if (widget.canTrack && progressReady && progressError != null)
            EmptyPanel(progressError!, retry: () {
              setState(() { progressReady = false; progressError = null; words = null; });
              _loadProgress();
            }),
          if (widget.canTrack && progressReady && studentId != null && progressError == null)
            LessonProgressNotice(status: progressStatus, basis: completionBasis),
          if (widget.canTrack && progressReady && studentId != null && progressError == null)
            ..._exerciseWidgets(),
          if (widget.canTrack && progressReady && studentId == null && progressError == null)
            const EmptyPanel('لا يوجد ملف طالب مرتبط بهذا الحساب؛ لم يُسجل تقدم محلي بديل.'),
        ],
      ),
    );
  }

  List<Widget> _exerciseWidgets() {
    if (words == null || questions == null) {
      return [const SaiCard(child: Center(child: CircularProgressIndicator()))];
    }
    final widgets = <Widget>[];
    if (questions!.isNotEmpty) widgets.add(_quizCard());
    widgets.add(const SectionHeading('تمارين الدرس'));
    if (!_hasReading && !_hasListening && !_hasVocabulary) {
      widgets.add(const EmptyPanel(
        'لا توجد تمارين مرتبطة بهذا الدرس بعد؛ أكمله بعد إضافة مادة قراءة أو تسجيل صوتي أو مفردات.',
      ));
      return widgets;
    }
    if (_hasReading) {
      widgets.add(SaiCard(
        child: ListTile(
          leading: Icon(
            readingDone ? Icons.check_circle_rounded : Icons.menu_book_rounded,
            color: gold,
          ),
          title: const Text('تمرين القراءة'),
          subtitle: const Text('اقرأ مادة الدرس المعروضة أعلاه كاملة.'),
          trailing: progressStatus == 'completed'
              ? null
              : TextButton(
                  onPressed: saving || readingDone
                      ? null
                      : () => setState(() => readingDone = true),
                  child: Text(readingDone ? 'اكتملت القراءة' : 'أنهيت قراءة المادة'),
                ),
        ),
      ));
    }
    if (_hasListening) {
      widgets.add(SaiCard(
        child: ListTile(
          leading: Icon(
            listeningDone ? Icons.check_circle_rounded : Icons.headphones_rounded,
            color: gold,
          ),
          title: const Text('تمرين الاستماع'),
          subtitle: const Text('شغّل التسجيل الصوتي كاملاً ثم أكّد إتمام الاستماع.'),
          trailing: progressStatus == 'completed'
              ? null
              : TextButton(
                  onPressed: saving || listeningDone
                      ? null
                      : () async {
                          final url = await mediaUrl;
                          if (url != null) {
                            setState(() => listeningStarted = true);
                            await _openMedia(url);
                          }
                          if (listeningStarted && mounted && !listeningDone) {
                            setState(() => listeningDone = true);
                          }
                        },
                  child: Text(listeningDone ? 'اكتمل الاستماع' : 'استمعت للتسجيل'),
                ),
        ),
      ));
    }
    if (_hasVocabulary) {
      widgets.add(SaiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تمرين المفردات', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final word in words!)
              Builder(builder: (context) {
                final id = '${word['id']}';
                final done = sessionReviewed.contains(id) || studiedWords.contains(id);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${word['hanzi']}  •  ${word['pinyin'] ?? ''}'),
                  subtitle: Text('${word['meaning_ar'] ?? ''}'),
                  trailing: done
                      ? const Icon(Icons.check_circle_rounded, color: gold)
                      : TextButton(
                          onPressed: saving || progressStatus == 'completed'
                              ? null
                              : () => _markWordStudied(id),
                          child: const Text('راجعتها'),
                        ),
                );
              }),
          ],
        ),
      ));
    }
    if (finishError != null) widgets.add(EmptyPanel(finishError!));
    if (progressStatus != 'completed') {
      widgets.add(FilledButton.icon(
        onPressed: saving || !_completable ? null : _finishLesson,
        icon: const Icon(Icons.task_alt_rounded),
        label: Text(saving ? 'جارٍ الحفظ...' : 'إنهاء الدرس'),
      ));
      if (!_completable) {
        widgets.add(const Text(
          'أكمل كل تمارين الدرس لتفعيل تسجيل الإكمال.',
          textAlign: TextAlign.center,
        ));
      }
    }
    return widgets;
  }

  Widget _quizCard() {
    final list = questions!;
    final result = quizResult;
    final results = <String, bool>{
      if (result != null)
        for (final row in (result['results'] as List? ?? const []))
          '${(row as Map)['question']}': row['correct'] == true,
    };
    final answered = list.where((q) => quizAnswers['${q['id']}'] != null).length;
    return SaiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('التقييم المُصحَّح', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('يُصحَّح على الخادم · النجاح من ٧٠٪', style: TextStyle(fontSize: 11)),
          const SizedBox(height: 8),
          for (final entry in list.asMap().entries) ...[
            Text('${entry.key + 1}. ${entry.value['prompt']}'),
            RadioGroup<int>(
              groupValue: quizAnswers['${entry.value['id']}'],
              onChanged: result != null || submittingQuiz
                  ? (_) {}
                  : (value) => setState(() {
                      if (value != null) quizAnswers['${entry.value['id']}'] = value;
                    }),
              child: Column(
                children: [
                  for (final choice in (entry.value['choices'] as List).asMap().entries)
                    RadioListTile<int>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      enabled: result == null && !submittingQuiz,
                      title: Text('${choice.value}'),
                      subtitle: result != null &&
                              quizAnswers['${entry.value['id']}'] == choice.key &&
                              results.containsKey('${entry.value['id']}')
                          ? Text(
                              results['${entry.value['id']}']!
                                  ? 'إجابة صحيحة'
                                  : 'إجابة غير صحيحة${entry.value['kind'] == 'vocabulary' ? ' — أُعيدت المفردة إلى المراجعة' : ''}',
                            )
                          : null,
                      value: choice.key,
                    ),
                ],
              ),
            ),
          ],
          if (quizError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('$quizError', style: const TextStyle(color: gold)),
            ),
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'النتيجة: ${result['correct']} من ${result['total']} (${result['score']}٪).'
                '${result['passed'] == true ? ' اجتزت التقييم وسُجّل إكمال الدرس كتقييم مُصحَّح.' : ' لم تبلغ درجة النجاح؛ راجع المفردات ثم أعد المحاولة.'}',
              ),
            ),
          const SizedBox(height: 8),
          if (result == null)
            FilledButton.icon(
              onPressed: submittingQuiz || answered == 0 ? null : _submitQuiz,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(submittingQuiz ? 'جارٍ التصحيح...' : 'إرسال الإجابات ($answered / ${list.length})'),
            )
          else if (result['passed'] != true)
            OutlinedButton.icon(
              onPressed: () => setState(() { quizResult = null; quizAnswers.clear(); }),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
        ],
      ),
    );
  }
}

class LessonProgressNotice extends StatelessWidget {
  const LessonProgressNotice({super.key, required this.status, this.basis});
  final String? status;
  final String? basis;

  @override
  Widget build(BuildContext context) => SaiCard(
    child: Text(
      status == 'completed' && basis == 'assessed'
          ? 'اجتزت تقييم هذا الدرس؛ صُحِّح على الخادم وسُجّل كإكمال معتمد.'
          : status == 'completed' && basis == 'self_reported'
              ? 'أكملت تمارين هذا الدرس وسُجّل إكمالك الذاتي (غير معتمد).'
              : status == 'completed'
                  ? 'توجد حالة إكمال سابقة غير متحققة؛ أكمل تمارين الدرس لتسجيل مراجعتك الذاتية.'
                  : status == 'in_progress'
                      ? 'الحالة المسجلة: قيد الدراسة.'
                      : 'لا توجد حالة إكمال مسجلة.',
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
