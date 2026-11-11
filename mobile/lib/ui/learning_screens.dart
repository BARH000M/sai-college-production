import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/curriculum.dart';
import '../data/demo_workspace.dart';
import 'components.dart';
import 'printing.dart';

typedef LearningContext = ({DemoWorkspace? demo, String learnerId});

class LevelBadge extends StatelessWidget {
  const LevelBadge(this.code, {super.key});
  final String code;

  @override
  Widget build(BuildContext context) {
    final (symbol, character, base, _) = switch (code) {
      'P0' => (
        Icons.graphic_eq_rounded,
        '声',
        const Color(0xFF892311),
        const Color(0xFFFFD7A0),
      ),
      'A0' => (
        Icons.auto_stories_rounded,
        '字',
        const Color(0xFF006C63),
        const Color(0xFFC9EDE5),
      ),
      'SAI1' => (
        Icons.forum_rounded,
        '话',
        const Color(0xFF784267),
        const Color(0xFFF4D9EE),
      ),
      _ => (
        Icons.account_tree_rounded,
        '学',
        const Color(0xFF2D4C87),
        const Color(0xFFD8E4FB),
      ),
    };
    return SizedBox.square(
      dimension: 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [base, darkRed],
          ),
          border: Border.all(color: base.withValues(alpha: .14)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              top: 8,
              start: 8,
              child: Icon(symbol, size: 28, color: base),
            ),
            PositionedDirectional(
              bottom: 5,
              end: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  child: Text(
                    character,
                    style: const TextStyle(
                      fontFamily: 'NotoSC',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CourseCatalog extends StatelessWidget {
  const CourseCatalog({super.key, required this.learning});
  final LearningContext learning;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
    children: [
      const SectionHeading('المقررات المتاحة'),
      for (final course in courses)
        SaiCard(
          padding: 11,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CourseScreen(course: course, learning: learning),
            ),
          ),
          child: Row(
            children: [
              LevelBadge(course.code),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(course.subtitle, style: const TextStyle(fontSize: 12)),
                    Text(
                      '${course.lessons.length} دروس',
                      style: const TextStyle(fontSize: 11, color: gold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                course.code,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: gold,
                ),
              ),
              const Icon(Icons.chevron_left, size: 18),
            ],
          ),
        ),
    ],
  );
}

class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key, required this.course, required this.learning});
  final Course course;
  final LearningContext learning;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: darkRed,
      foregroundColor: Colors.white,
      title: Text(course.title),
    ),
    body: ListenableBuilder(
      listenable: learning.demo ?? const _NoChanges(),
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SaiCard(
            child: Row(
              children: [
                LevelBadge(course.code),
                const SizedBox(width: 12),
                Expanded(child: Text(course.subtitle)),
                PrintAction(
                  CollegeReport(
                    title: 'خطة ${course.title}',
                    subtitle: course.code,
                    preview: learning.demo != null,
                    columns: const [
                      PrintColumn('الرمز', flex: 1, ltr: true),
                      PrintColumn('الدرس', flex: 2),
                      PrintColumn('هدف الدرس', flex: 4),
                    ],
                    rows: [
                      for (final lesson in course.lessons)
                        [lesson.id, lesson.title, lesson.tip],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeading('الدروس'),
          for (final lesson in course.lessons)
            Tile(
              lesson.title,
              learning.demo?.completed(learning.learnerId, lesson.id) == true
                  ? Icons.check_circle_outline
                  : Icons.play_lesson_outlined,
              subtitle: '${lesson.id}  •  ${lesson.meaning}',
              onTap: () => openLesson(context, lesson, learning),
            ),
        ],
      ),
    ),
  );
}

class _NoChanges implements Listenable {
  const _NoChanges();
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

void openLesson(
  BuildContext context,
  Lesson lesson,
  LearningContext learning, {
  int initialTab = 0,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LessonScreen(
        lesson: lesson,
        learning: learning,
        initialTab: initialTab,
      ),
    ),
  );
}

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.lesson,
    required this.learning,
    this.initialTab = 0,
  });
  final Lesson lesson;
  final LearningContext learning;
  final int initialTab;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final FlutterTts _tts = FlutterTts();
  bool audioStarted = false;
  bool speaking = false;

  Future<void> speak(String text) async {
    if (speaking) return;
    setState(() => speaking = true);
    audioStarted = true;
    try {
      final supported = await _tts.isLanguageAvailable('zh-CN');
      if (supported != true && supported != 1) {
        throw StateError('Chinese voice unavailable');
      }
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(.38);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'فعّل صوت الماندرين في إعدادات تحويل النص إلى كلام على الجهاز، ثم أعد المحاولة.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => speaking = false);
    }
  }

  Future<void> _stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      /* Voice service may be unavailable. */
    }
  }

  @override
  void dispose() {
    if (audioStarted) unawaited(_stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: darkRed,
          foregroundColor: Colors.white,
          title: Text(lesson.title),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFFFD9D5),
            indicatorColor: gold,
            tabs: [
              Tab(text: 'الدرس'),
              Tab(text: 'النطق'),
              Tab(text: 'الكتابة'),
              Tab(text: 'التقييم'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionHeading(
                  lesson.title,
                  action: PrintAction(
                    CollegeReport(
                      title: 'بطاقة درس: ${lesson.title}',
                      subtitle: lesson.id,
                      preview: widget.learning.demo != null,
                      columns: const [
                        PrintColumn('الصينية', flex: 2, ltr: true),
                        PrintColumn('النطق', flex: 2, ltr: true),
                        PrintColumn('المعنى', flex: 3),
                      ],
                      rows: [
                        for (final word in lesson.words)
                          [word.hanzi, word.pinyin, word.arabic],
                        [lesson.example, lesson.pinyin, lesson.meaning],
                        ['', '', lesson.tip],
                      ],
                    ),
                  ),
                ),
                SaiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        lesson.example,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'NotoSC',
                          fontSize: 24,
                          color: gold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lesson.pinyin,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                      ),
                      Text(lesson.meaning, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(lesson.tip),
                    ],
                  ),
                ),
                const SectionHeading('المفردات'),
                for (final word in lesson.words)
                  SaiCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                word.hanzi,
                                style: const TextStyle(
                                  fontFamily: 'NotoSC',
                                  fontSize: 20,
                                  color: gold,
                                ),
                              ),
                              Text(
                                word.pinyin,
                                textDirection: TextDirection.ltr,
                              ),
                              Text(word.arabic),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: speaking ? null : () => speak(word.hanzi),
                          tooltip: 'استمع إلى الكلمة',
                          icon: const Icon(Icons.volume_up_outlined),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SectionHeading('استمع ثم كرّر'),
                SaiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        lesson.example,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontFamily: 'NotoSC',
                          fontSize: 25,
                        ),
                      ),
                      Text(
                        lesson.pinyin,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                      ),
                      Text(lesson.meaning, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      RedButton(
                        speaking ? 'جارٍ التشغيل…' : 'استمع إلى المثال',
                        icon: Icons.headphones_outlined,
                        onPressed: speaking
                            ? null
                            : () => speak(lesson.example),
                      ),
                    ],
                  ),
                ),
                const Tile(
                  'تدريب التحدث',
                  Icons.record_voice_over_outlined,
                  subtitle:
                      'كرّر المثال ببطء، ثم قل جملة مشابهة. استمع مرة ثانية وقارن النغمات.',
                ),
                Text(lesson.tip),
              ],
            ),
            _WritingTab(character: lesson.words.first.hanzi.characters.first),
            _Quiz(lesson: lesson, learning: widget.learning),
          ],
        ),
      ),
    );
  }
}

class _WritingTab extends StatefulWidget {
  const _WritingTab({required this.character});
  final String character;
  @override
  State<_WritingTab> createState() => _WritingTabState();
}

class _WritingTabState extends State<_WritingTab> {
  final points = <Offset?>[];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const SectionHeading('تدرّب على كتابة الحرف'),
      const Text(
        'اتبع شكل الحرف بإصبعك. امسح اللوحة وأعد المحاولة من الذاكرة.',
      ),
      const SizedBox(height: 12),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: gold),
                borderRadius: BorderRadius.circular(16),
              ),
              child: GestureDetector(
                onPanStart: (event) =>
                    setState(() => points.add(event.localPosition)),
                onPanUpdate: (event) =>
                    setState(() => points.add(event.localPosition)),
                onPanEnd: (_) => setState(() => points.add(null)),
                onPanCancel: () => setState(() => points.add(null)),
                child: CustomPaint(
                  foregroundPainter: _TracePainter(List.of(points)),
                  child: Center(
                    child: Text(
                      widget.character,
                      style: const TextStyle(
                        fontFamily: 'NotoSC',
                        fontSize: 112,
                        color: Color(0xFFEBD9D3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => setState(points.clear),
        icon: const Icon(Icons.restart_alt),
        label: const Text('مسح اللوحة'),
      ),
    ],
  );
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.points);
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final grid = Paint()..color = const Color(0x22B6000B);
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      grid,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      grid,
    );
    final pen = Paint()
      ..color = gold
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < points.length; i++) {
      if (points[i - 1] != null && points[i] != null) {
        canvas.drawLine(points[i - 1]!, points[i]!, pen);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) =>
      oldDelegate.points.length != points.length;
}

class _Quiz extends StatefulWidget {
  const _Quiz({required this.lesson, required this.learning});
  final Lesson lesson;
  final LearningContext learning;

  @override
  State<_Quiz> createState() => _QuizState();
}

class _QuizState extends State<_Quiz> {
  final answers = <int?>[null, null];
  int? score;
  bool saving = false;
  String? error;

  Future<void> check(int first, int second) async {
    final result =
        (answers[0] == first ? 1 : 0) + (answers[1] == second ? 1 : 0);
    setState(() {
      score = result;
      saving = true;
      error = null;
    });
    try {
      if (result == 2) {
        await widget.learning.demo?.complete(
          widget.learning.learnerId,
          widget.lesson.id,
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر حفظ التقدم على الجهاز.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.lesson.words;
    final offset = int.parse(widget.lesson.id.split('-').last) % words.length;
    final order = [
      for (var i = 0; i < words.length; i++) (i + offset) % words.length,
    ];
    final first = order.indexOf(0);
    final second = order.reversed.toList().indexOf(1);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeading('تحقق من فهمك'),
        question('ما معنى ${words.first.hanzi}؟', 0, [
          for (final index in order) words[index].arabic,
        ]),
        question('ما الكلمة التي تعني ${words[1].arabic}؟', 1, [
          for (final index in order.reversed) words[index].hanzi,
        ]),
        RedButton(
          'تحقق من الإجابات',
          icon: Icons.task_alt,
          onPressed: saving || answers.contains(null)
              ? null
              : () => check(first, second),
        ),
        if (score != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error ??
                  (score == 2
                      ? (widget.learning.demo == null
                            ? 'أحسنت، إجابتان صحيحتان.'
                            : 'أحسنت، حُفظ إكمال الدرس على الجهاز.')
                      : 'أجبت عن $score من 2. راجع المفردات وحاول مجدداً.'),
            ),
          ),
      ],
    );
  }

  Widget question(String title, int number, List<String> options) => SaiCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamilyFallback: ['NotoSC'],
          ),
        ),
        RadioGroup<int>(
          groupValue: answers[number],
          onChanged: (value) {
            if (saving) return;
            setState(() {
              answers[number] = value;
              score = null;
            });
          },
          child: Column(
            children: [
              for (var i = 0; i < options.length; i++)
                RadioListTile<int>(
                  value: i,
                  dense: true,
                  title: Text(
                    options[i],
                    style: const TextStyle(fontFamilyFallback: ['NotoSC']),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
