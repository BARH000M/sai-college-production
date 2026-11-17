import 'package:flutter/material.dart';

import '../core/access.dart';
import '../data/exam_repository.dart';
import 'components.dart';
import 'printing.dart';

/// Live examinations and results screen (Phase 4A).
/// Staff manage scheduling, marks and publication; students and parents see
/// published results only. The database remains the authorization authority.
class LiveExamsScreen extends StatefulWidget {
  const LiveExamsScreen({super.key, required this.roles, this.repository});

  final Set<Role> roles;
  final ExamRepository? repository;

  @override
  State<LiveExamsScreen> createState() => _LiveExamsScreenState();
}

class _LiveExamsScreenState extends State<LiveExamsScreen> {
  late final ExamRepository repository =
      widget.repository ?? ExamRepository();
  late Future<List<Map<String, dynamic>>> _future;
  bool get manages => Access.manages(widget.roles, PageId.exams);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = manages ? repository.classes() : repository.familyResults();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyPanel(
            'تعذر تحميل بيانات الاختبارات. تحقق من الاتصال وصلاحية الحساب.',
            retry: () => setState(_reload),
          );
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return manages ? _staffHome(rows) : _familyHome(rows);
      },
    ),
  );

  Widget _staffHome(List<Map<String, dynamic>> classes) {
    if (classes.isEmpty) {
      return EmptyPanel(
        'لا توجد صفوف مسندة لحسابك لإدارة اختباراتها.',
        retry: () => setState(_reload),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeading('الاختبارات والنتائج')),
            IconButton(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh, color: gold),
            ),
          ],
        ),
        const Text(
          'تُنشأ الاختبارات كمسودة ثم تُفتح لرصد الدرجات، وتُنشر بعد مراجعة الشؤون الأكاديمية.',
        ),
        const SizedBox(height: 12),
        for (final classRow in classes)
          SaiCard(
            child: ListTile(
              leading: const Icon(Icons.assessment_outlined, color: gold),
              title: Text('${classRow['name']}'),
              subtitle: const Text('اختبارات الصف ورصد الدرجات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ExamClassPage(classRow: classRow, repository: repository),
                  ),
                );
                if (mounted) setState(_reload);
              },
            ),
          ),
      ],
    );
  }

  Widget _familyHome(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return EmptyPanel(
        'لا توجد نتائج منشورة حتى الآن. تظهر النتائج هنا بعد اعتمادها.',
        retry: () => setState(_reload),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeading('النتائج المنشورة')),
            IconButton(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh, color: gold),
            ),
          ],
        ),
        for (final row in results)
          SaiCard(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined, color: gold),
              title: Text('${row['exam']?['title'] ?? 'اختبار'}'),
              subtitle: Text(
                '${row['student_name']} · ${row['exam']?['subject'] ?? ''}\n'
                '${row['exam']?['exam_date'] ?? ''} · '
                '${row['score'] == null ? '—' : '${row['score']} / ${row['exam']?['max_score'] ?? '—'}'}'
                ' · ${gradeLabels[row['grade']] ?? '—'}',
              ),
              trailing: PrintAction(
                CollegeReport(
                  title: 'إشعار نتيجة اختبار',
                  subtitle: '${row['exam']?['exam_date'] ?? ''}',
                  preview: false,
                  signature: true,
                  columns: const [
                    PrintColumn('البيان', flex: 2),
                    PrintColumn('القيمة', flex: 3),
                  ],
                  rows: [
                    ['الطالب', '${row['student_name']}'],
                    ['الاختبار', '${row['exam']?['title'] ?? '—'}'],
                    ['المادة', '${row['exam']?['subject'] ?? '—'}'],
                    ['التاريخ', '${row['exam']?['exam_date'] ?? '—'}'],
                    [
                      'الدرجة',
                      row['score'] == null
                          ? '—'
                          : '${row['score']} / ${row['exam']?['max_score'] ?? '—'}',
                    ],
                    ['التقدير', gradeLabels[row['grade']] ?? '—'],
                    if (row['note'] != null && '${row['note']}'.isNotEmpty)
                      ['ملاحظة', '${row['note']}'],
                  ],
                ),
              ),
            ),
          ),
        const Text(
          'تُعرض النتائج المنشورة والمعتمدة فقط.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Exams of one class: scheduling, state transitions and marks entry.
class ExamClassPage extends StatefulWidget {
  const ExamClassPage({super.key, required this.classRow, this.repository});

  final Map<String, dynamic> classRow;
  final ExamRepository? repository;

  @override
  State<ExamClassPage> createState() => _ExamClassPageState();
}

class _ExamClassPageState extends State<ExamClassPage> {
  late final ExamRepository repository =
      widget.repository ?? ExamRepository();
  late Future<List<Map<String, dynamic>>> _exams;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _exams = repository.exams(classId: widget.classRow['id'] as String);
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (failure) {
      if (mounted) {
        setState(() => error = failure is FormatException
            ? failure.message
            : 'تعذر تنفيذ الطلب. تحقق من الصلاحية وحالة الاختبار.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _createExam() async {
    final created = await showDialog<ExamDraftInput>(
      context: context,
      builder: (_) => ExamComposerDialog(classRow: widget.classRow),
    );
    if (created == null || !mounted) return;
    await _run(() => repository.createExam(created), 'تم إنشاء الاختبار كمسودة.');
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: Text('اختبارات ${widget.classRow['name']}'),
        backgroundColor: darkRed,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _exams,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyPanel(
              'تعذر تحميل اختبارات الصف.',
              retry: () => setState(_reload),
            );
          }
          final exams = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RedButton('إنشاء اختبار', onPressed: busy ? null : _createExam),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
              if (exams.isEmpty)
                const EmptyPanel('لا توجد اختبارات لهذا الصف بعد. أنشئ أول مسودة.'),
              for (final exam in exams)
                SaiCard(
                  child: ListTile(
                    leading: const Icon(Icons.event_note_outlined, color: gold),
                    title: Text('${exam['title']}'),
                    subtitle: Text(
                      '${exam['subject']} · ${exam['exam_date']}'
                      '${exam['room'] == null ? '' : ' · ${exam['room']}'}'
                      '\n${examStatuses[exam['status']] ?? exam['status']}',
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ExamDetailPage(exam: exam, repository: repository),
                        ),
                      );
                      if (mounted) setState(_reload);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

/// One exam: roster, marks entry, transitions and the printable report.
class ExamDetailPage extends StatefulWidget {
  const ExamDetailPage({super.key, required this.exam, this.repository});

  final Map<String, dynamic> exam;
  final ExamRepository? repository;

  @override
  State<ExamDetailPage> createState() => _ExamDetailPageState();
}

class _ExamDetailPageState extends State<ExamDetailPage> {
  late final ExamRepository repository =
      widget.repository ?? ExamRepository();
  late Map<String, dynamic> exam = widget.exam;
  late Future<List<Map<String, dynamic>>> _roster;
  final _scores = <String, TextEditingController>{};
  final _notes = <String, TextEditingController>{};
  String? error;
  bool busy = false;

  num get maxScore => exam['max_score'] as num? ?? 100;
  String get status => exam['status'] as String? ?? 'draft';
  bool get editable => status == 'marks_entry';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    for (final controller in [..._scores.values, ..._notes.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reload() {
    _roster = repository.roster(exam['id'] as String).then((rows) {
      for (final row in rows) {
        final id = row['student_id'] as String;
        _scores.putIfAbsent(id, TextEditingController.new).text =
            row['score'] == null ? '' : '${row['score']}';
        _notes.putIfAbsent(id, TextEditingController.new).text =
            row['note'] == null ? '' : '${row['note']}';
      }
      return rows;
    });
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } on FormatException catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر تنفيذ الطلب. تحقق من الصلاحية وحالة الاختبار.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _transition(String to) => _run(() async {
    await repository.transition(exam['id'] as String, status, to);
    exam = {...exam, 'status': to};
  }, 'انتقل الاختبار إلى «${examStatuses[to]}».');

  static const _actions = <String, List<(String, String)>>{
    'draft': [('marks_entry', 'فتح رصد الدرجات'), ('cancelled', 'إلغاء الاختبار')],
    'marks_entry': [('review', 'إرسال للمراجعة'), ('cancelled', 'إلغاء الاختبار')],
    'review': [('marks_entry', 'إعادة لرصد الدرجات'), ('published', 'نشر النتائج')],
    'published': [('review', 'إلغاء النشر')],
  };

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: Text('${exam['title']}'),
        backgroundColor: darkRed,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _roster,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyPanel(
              'تعذر تحميل كشف الدرجات.',
              retry: () => setState(_reload),
            );
          }
          final roster = snapshot.data ?? const <Map<String, dynamic>>[];
          final recorded = roster.where((row) => row['score'] != null).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${exam['subject']} · ${exam['exam_date']}'
                '${exam['room'] == null ? '' : ' · ${exam['room']}'}'
                '\nالحالة: ${examStatuses[status] ?? status} · الدرجة العظمى: $maxScore',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final action in _actions[status] ?? const <(String, String)>[])
                    OutlinedButton(
                      onPressed: busy ? null : () => _transition(action.$1),
                      child: Text(action.$2),
                    ),
                  if (roster.isNotEmpty)
                    PrintAction(
                      CollegeReport(
                        title: 'كشف نتائج اختبار',
                        subtitle:
                            '${exam['title']} · ${exam['exam_date']} · ${examStatuses[status]}',
                        preview: status != 'published',
                        signature: true,
                        columns: const [
                          PrintColumn('الطالب', flex: 2),
                          PrintColumn('الرقم الأكاديمي', ltr: true),
                          PrintColumn('الدرجة', ltr: true),
                          PrintColumn('التقدير'),
                          PrintColumn('ملاحظة'),
                        ],
                        rows: [
                          for (final row in roster)
                            [
                              '${row['full_name']}',
                              '${row['admission_no']}',
                              row['score'] == null
                                  ? '—'
                                  : '${row['score']} / $maxScore',
                              gradeLabels[row['grade']] ?? '—',
                              '${row['note'] ?? '—'}',
                            ],
                        ],
                      ),
                    ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
              if (roster.isEmpty)
                const EmptyPanel('لا يوجد طلاب نشطون في هذا الصف.'),
              if (roster.isNotEmpty)
                Text('رُصدت درجات $recorded من ${roster.length} طالباً.'),
              for (final row in roster) _markRow(row),
            ],
          );
        },
      ),
    ),
  );

  Widget _markRow(Map<String, dynamic> row) {
    final id = row['student_id'] as String;
    final score = _scores[id]!;
    final note = _notes[id]!;
    final markError = validateMark(score.text, maxScore);
    final grade = score.text.trim().isEmpty
        ? null
        : gradeForScore(num.tryParse(score.text.trim()), maxScore);
    final savedScore = row['score'] == null ? '' : '${row['score']}';
    final changed =
        score.text.trim() != savedScore || note.text != '${row['note'] ?? ''}';
    return SaiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${row['full_name']} · ${row['admission_no']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: score,
                  enabled: editable && !busy,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'الدرجة من $maxScore',
                    errorText: markError,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Text(grade == null ? '—' : gradeLabels[grade]!),
            ],
          ),
          TextField(
            controller: note,
            enabled: editable && !busy,
            maxLength: 240,
            decoration: const InputDecoration(labelText: 'ملاحظة'),
            onChanged: (_) => setState(() {}),
          ),
          if (editable)
            RedButton(
              busy ? 'جارٍ الحفظ...' : 'حفظ الدرجة',
              onPressed: !changed || markError != null || busy
                  ? null
                  : () => _run(
                      () => repository.saveMark(
                        exam['id'] as String,
                        row,
                        score.text,
                        note.text,
                        maxScore,
                      ),
                      'تم حفظ الدرجة.',
                    ),
            ),
        ],
      ),
    );
  }
}

/// Dialog for creating and scheduling a draft exam.
class ExamComposerDialog extends StatefulWidget {
  const ExamComposerDialog({super.key, required this.classRow});

  final Map<String, dynamic> classRow;

  @override
  State<ExamComposerDialog> createState() => _ExamComposerDialogState();
}

class _ExamComposerDialogState extends State<ExamComposerDialog> {
  final subject = TextEditingController();
  final title = TextEditingController();
  final room = TextEditingController();
  final maxScore = TextEditingController(text: '100');
  String date = '';
  String? error;

  @override
  void dispose() {
    for (final controller in [subject, title, room, maxScore]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      title: Text('اختبار جديد · ${widget.classRow['name']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subject,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'المادة'),
            ),
            TextField(
              controller: title,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'عنوان الاختبار'),
            ),
            TextField(
              controller: room,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'القاعة (اختياري)'),
            ),
            TextField(
              controller: maxScore,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الدرجة العظمى'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => date = picked.toIso8601String().split('T').first);
                }
              },
              child: Text(date.isEmpty ? 'اختر تاريخ الاختبار' : 'التاريخ: $date'),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () {
            final draft = ExamDraftInput(
              classRow: widget.classRow,
              subject: subject.text,
              title: title.text,
              date: date,
              room: room.text,
              maxScore: num.tryParse(maxScore.text.trim()) ?? 0,
            );
            final problem = validateExamDraft(draft);
            if (problem != null) {
              setState(() => error = problem);
              return;
            }
            Navigator.pop(context, draft);
          },
          child: const Text('إنشاء المسودة'),
        ),
      ],
    ),
  );
}
