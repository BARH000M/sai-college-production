import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/assessment_settings.dart';
import 'components.dart';

const _questionKinds = <String, String>{
  'multiple_choice': 'اختيار من متعدد',
  'multiple_select': 'اختر جميع الإجابات الصحيحة',
  'true_false': 'صح أو خطأ',
  'matching': 'مطابقة',
  'fill_blank': 'أكمل الفراغ',
  'written': 'إجابة كتابية',
};

String _assessmentStatusLabel(Object? status) => switch (status) {
  'draft' => 'مسودة',
  'published' => 'منشور',
  'closed' => 'مغلق',
  'archived' => 'مؤرشف',
  _ => 'غير معروف',
};

bool _assessmentIsOpen(Map<String, dynamic> item) {
  if (item['status'] != 'published') return false;
  final now = DateTime.now().toUtc();
  final startsAt = DateTime.tryParse('${item['starts_at'] ?? ''}');
  final dueAt = DateTime.tryParse('${item['due_at'] ?? ''}');
  return (startsAt == null || !now.isBefore(startsAt)) &&
      (dueAt == null || !now.isAfter(dueAt));
}

class LiveAssessmentsPage extends StatefulWidget {
  const LiveAssessmentsPage({
    super.key,
    required this.lessonId,
    required this.courseId,
    required this.canManage,
    required this.canTake,
  });

  final String lessonId;
  final String courseId;
  final bool canManage;
  final bool canTake;

  @override
  State<LiveAssessmentsPage> createState() => _LiveAssessmentsPageState();
}

class _LiveAssessmentsPageState extends State<LiveAssessmentsPage> {
  late Future<List<Map<String, dynamic>>> _assessments;
  String? _openId;
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _bankQuestions = [];
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _attempt;
  Map<String, dynamic> _answers = {};
  bool _submitted = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _assessments = _client
        .from('learning_assessments')
        .select(
          'id,course_id,lesson_id,title,instructions,starts_at,due_at,time_limit_minutes,attempt_limit,passing_score,randomize_questions,status,results_released',
        )
        .eq('lesson_id', widget.lessonId)
        .order('created_at', ascending: false);
  }

  Future<void> _open(Map<String, dynamic> assessment) async {
    if (_openId == assessment['id']) {
      setState(() => _openId = null);
      return;
    }
    setState(() {
      _openId = '${assessment['id']}';
      _attempt = null;
      _answers = {};
      _submitted = false;
      _error = null;
      _notice = null;
      _questions = [];
      _bankQuestions = [];
      _results = [];
    });
    await _loadDetail('${assessment['id']}');
    if (widget.canManage) {
      await _loadBank('${assessment['course_id']}');
    }
  }

  Future<void> _loadBank(String courseId) async {
    try {
      final result = await _client.rpc(
        'sai_learning_assessment_question_bank',
        params: {'p_course': courseId, 'p_category': null},
      );
      if (result is! List) throw StateError('استجابة بنك الأسئلة غير صالحة.');
      if (mounted) {
        setState(
          () => _bankQuestions = List<Map<String, dynamic>>.from(result),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تحميل بنك الأسئلة: $error');
    }
  }

  Future<void> _loadDetail(String id) async {
    try {
      if (widget.canManage) {
        final questions = await _client.rpc(
          'sai_learning_assessment_questions_admin',
          params: {'p_assessment': id},
        );
        if (questions is! List) throw StateError('استجابة الأسئلة غير صالحة.');
        _questions = List<Map<String, dynamic>>.from(questions);
      }
      final results = await _client.rpc(
        'sai_learning_assessment_results',
        params: {'p_assessment': id},
      );
      if (results is! List) throw StateError('استجابة النتائج غير صالحة.');
      if (mounted) {
        setState(() => _results = List<Map<String, dynamic>>.from(results));
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تحميل التقييم: $error');
    }
  }

  Future<void> _createAssessment() async {
    final title = TextEditingController();
    final instructions = TextEditingController();
    final starts = TextEditingController();
    final deadline = TextEditingController();
    final timeLimit = TextEditingController();
    final attempts = TextEditingController(text: '1');
    final passingScore = TextEditingController(text: '70');
    var randomizeQuestions = false;
    try {
      final values = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('إنشاء تقييم — مسودة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  TextField(
                    controller: instructions,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'التعليمات'),
                  ),
                  TextField(
                    controller: starts,
                    decoration: const InputDecoration(
                      labelText: 'موعد البدء ISO اختياري',
                    ),
                  ),
                  TextField(
                    controller: deadline,
                    decoration: const InputDecoration(
                      labelText: 'موعد الإغلاق ISO اختياري',
                    ),
                  ),
                  TextField(
                    controller: timeLimit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مدة المحاولة بالدقائق (١–٣٠٠، اختياري)',
                    ),
                  ),
                  TextField(
                    controller: attempts,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الحد الأقصى للمحاولات (١–١٠)',
                    ),
                  ),
                  TextField(
                    controller: passingScore,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'درجة الاجتياز (٠–١٠٠٪)',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ترتيب عشوائي ثابت لكل محاولة'),
                    value: randomizeQuestions,
                    onChanged: (value) => setDialogState(
                      () => randomizeQuestions = value ?? false,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'title': title.text.trim(),
                  'instructions': instructions.text.trim(),
                  'starts': starts.text.trim(),
                  'deadline': deadline.text.trim(),
                  'timeLimit': timeLimit.text.trim(),
                  'attempts': attempts.text.trim(),
                  'passingScore': passingScore.text.trim(),
                  'randomizeQuestions': randomizeQuestions,
                }),
                child: const Text('حفظ المسودة'),
              ),
            ],
          ),
        ),
      );
      if (values == null) return;
      if ((values['title'] as String).length < 2 ||
          (values['title'] as String).length > 200) {
        throw const FormatException(
          'عنوان التقييم يجب أن يكون بين حرفين و٢٠٠ حرف.',
        );
      }
      final settings = AssessmentSettings.fromInput(
        startsAt: values['starts'] as String,
        dueAt: values['deadline'] as String,
        timeLimitMinutes: values['timeLimit'] as String,
        attemptLimit: values['attempts'] as String,
        passingScore: values['passingScore'] as String,
        randomizeQuestions: values['randomizeQuestions'] as bool,
      );
      await _client.from('learning_assessments').insert({
        'course_id': widget.courseId,
        'lesson_id': widget.lessonId,
        'title': values['title'],
        'instructions': values['instructions']!.isEmpty
            ? null
            : values['instructions'],
        ...settings.toJson(),
      });
      if (mounted) {
        setState(() {
          _reload();
          _notice = 'أُنشئت مسودة التقييم.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر إنشاء التقييم: $error');
    } finally {
      title.dispose();
      instructions.dispose();
      starts.dispose();
      deadline.dispose();
      timeLimit.dispose();
      attempts.dispose();
      passingScore.dispose();
    }
  }

  Future<void> _addQuestion(
    String assessmentId, {
    Map<String, dynamic>? current,
  }) async {
    String kind = '${current?['kind'] ?? 'multiple_choice'}';
    final prompt = TextEditingController(text: '${current?['prompt'] ?? ''}');
    final points = TextEditingController(text: '${current?['points'] ?? 1}');
    final category = TextEditingController(
      text: '${current?['bank_category'] ?? ''}',
    );
    final choices = TextEditingController(
      text: current == null
          ? ''
          : (current['kind'] == 'matching'
                ? (current['choices'] as List)
                      .take((current['choices'] as List).length ~/ 2)
                      .join('\n')
                : (current['choices'] as List).join('\n')),
    );
    final answer = TextEditingController(
      text: current == null ? '' : _answerText(current),
    );
    int correct = (current?['correct_choice'] as num?)?.toInt() ?? 0;
    try {
      final values = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(current == null ? 'إضافة سؤال' : 'تعديل السؤال'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: kind,
                      decoration: const InputDecoration(
                        labelText: 'نوع السؤال',
                      ),
                      items: _questionKinds.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => kind = value ?? kind),
                    ),
                    TextField(
                      controller: prompt,
                      decoration: const InputDecoration(labelText: 'نص السؤال'),
                    ),
                    TextField(
                      controller: points,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'الدرجة'),
                    ),
                    TextField(
                      controller: category,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'تصنيف بنك الأسئلة (اختياري)',
                      ),
                    ),
                    if (kind == 'multiple_choice' ||
                        kind == 'multiple_select' ||
                        kind == 'true_false')
                      TextField(
                        controller: choices,
                        minLines: 2,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'الخيارات — كل خيار في سطر',
                        ),
                      ),
                    if (kind == 'matching')
                      TextField(
                        controller: choices,
                        minLines: 2,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'العناصر المطلوب مطابقتها',
                        ),
                      ),
                    if (kind == 'fill_blank')
                      TextField(
                        controller: answer,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'الإجابات المقبولة — كل إجابة في سطر',
                        ),
                      ),
                    if (kind == 'multiple_select')
                      TextField(
                        controller: answer,
                        decoration: const InputDecoration(
                          labelText: 'أرقام الإجابات الصحيحة مفصولة بفواصل',
                        ),
                      ),
                    if (kind == 'matching')
                      TextField(
                        controller: answer,
                        minLines: 2,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'الإجابات المطابقة بالترتيب نفسه',
                        ),
                      ),
                    if (kind == 'multiple_choice' || kind == 'true_false')
                      TextFormField(
                        initialValue: '$correct',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'رقم الإجابة الصحيحة، بدءاً من صفر',
                        ),
                        onChanged: (value) =>
                            correct = int.tryParse(value) ?? correct,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'kind': kind,
                  'prompt': prompt.text.trim(),
                  'points': double.tryParse(points.text),
                  'category': category.text.trim(),
                  'choices': choices.text,
                  'answer': answer.text,
                  'correct': correct,
                }),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );
      if (values == null) return;
      final kindValue = values['kind'] as String;
      final left = (values['choices'] as String)
          .split(RegExp(r'\r?\n'))
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
      final other = (values['answer'] as String)
          .split(RegExp(r'\r?\n'))
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
      List<String> options = left;
      dynamic key;
      if (kindValue == 'multiple_select') {
        options = left;
        key =
            other
                .expand((value) => value.split(','))
                .map((value) => int.tryParse(value.trim()))
                .whereType<int>()
                .toList()
              ..sort();
      } else if (kindValue == 'matching') {
        options = [...left, ...other];
        key = {
          for (var index = 0; index < left.length; index++)
            left[index]: index < other.length ? other[index] : '',
        };
      } else if (kindValue == 'fill_blank') {
        options = [];
        key = other;
      } else if (kindValue == 'written') {
        options = [];
      }
      final numericPoints = values['points'] as double?;
      if ((values['prompt'] as String).length < 2 ||
          numericPoints == null ||
          numericPoints <= 0 ||
          (values['category'] as String).length > 80) {
        throw StateError('أدخل نص السؤال ودرجة صحيحة أكبر من صفر.');
      }
      final payload = {
        'lesson_id': widget.lessonId,
        'assessment_id': assessmentId,
        'kind': kindValue,
        'prompt': values['prompt'],
        'choices': options,
        'correct_choice':
            kindValue == 'multiple_choice' || kindValue == 'true_false'
            ? values['correct']
            : null,
        'answer_key': key,
        'points': numericPoints,
        'bank_category': (values['category'] as String).isEmpty
            ? null
            : values['category'],
        'is_published': false,
      };
      if (current == null) {
        final last = await _client
            .from('learning_exercise_questions')
            .select('position')
            .eq('assessment_id', assessmentId)
            .order('position', ascending: false)
            .limit(1);
        final position =
            ((last as List).isEmpty
                ? 0
                : (last[0]['position'] as num).toInt()) +
            1;
        await _client.from('learning_exercise_questions').insert({
          ...payload,
          'position': position,
        });
      } else {
        await _client
            .from('learning_exercise_questions')
            .update(payload)
            .eq('id', current['id'])
            .eq('assessment_id', assessmentId);
      }
      await _loadDetail(assessmentId);
      await _loadBank(widget.courseId);
      if (mounted) setState(() => _notice = 'حُفظ السؤال.');
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ السؤال: $error');
    } finally {
      prompt.dispose();
      points.dispose();
      category.dispose();
      choices.dispose();
      answer.dispose();
    }
  }

  String _answerText(Map<String, dynamic> question) {
    final key = question['answer_key'];
    if (question['kind'] == 'multiple_select' && key is List) {
      return key.join(',');
    }
    if (key is Map) {
      return (question['choices'] as List)
          .take((question['choices'] as List).length ~/ 2)
          .map((left) => key[left] ?? '')
          .join('\n');
    }
    if (key is List) return key.join('\n');
    return '';
  }

  Future<void> _changeStatus(Map<String, dynamic> item, String status) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(switch (status) {
            'published' => 'نشر التقييم؟',
            'closed' => 'إغلاق التقييم؟',
            'archived' => 'أرشفة التقييم؟',
            _ => 'إعادة التقييم إلى المسودات؟',
          }),
          content: const Text(
            'سيُطبّق التغيير على الطلاب المعيّنين وفق صلاحياتهم.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _client
          .from('learning_assessments')
          .update({'status': status})
          .eq('id', item['id']);
      if (mounted) {
        setState(() {
          _reload();
          _notice = switch (status) {
            'published' => 'نُشر التقييم.',
            'closed' => 'أُغلق التقييم ومنع بدء محاولات جديدة.',
            'archived' => 'أُرشف التقييم.',
            _ => 'أُعيد التقييم إلى المسودات.',
          };
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تغيير حالة النشر: $error');
    }
  }

  Future<void> _editAssessment(Map<String, dynamic> item) async {
    final title = TextEditingController(text: '${item['title'] ?? ''}');
    final instructions = TextEditingController(
      text: '${item['instructions'] ?? ''}',
    );
    final starts = TextEditingController(text: '${item['starts_at'] ?? ''}');
    final deadline = TextEditingController(text: '${item['due_at'] ?? ''}');
    final timeLimit = TextEditingController(
      text: '${item['time_limit_minutes'] ?? ''}',
    );
    final attempts = TextEditingController(
      text: '${item['attempt_limit'] ?? 1}',
    );
    final passingScore = TextEditingController(
      text: '${item['passing_score'] ?? 70}',
    );
    var randomizeQuestions = item['randomize_questions'] == true;
    try {
      final values = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('تعديل التقييم'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  TextField(
                    controller: instructions,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'التعليمات'),
                  ),
                  TextField(
                    controller: starts,
                    decoration: const InputDecoration(
                      labelText: 'موعد البدء ISO اختياري',
                    ),
                  ),
                  TextField(
                    controller: deadline,
                    decoration: const InputDecoration(
                      labelText: 'موعد الإغلاق ISO اختياري',
                    ),
                  ),
                  TextField(
                    controller: timeLimit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مدة المحاولة بالدقائق (١–٣٠٠، اختياري)',
                    ),
                  ),
                  TextField(
                    controller: attempts,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الحد الأقصى للمحاولات (١–١٠)',
                    ),
                  ),
                  TextField(
                    controller: passingScore,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'درجة الاجتياز (٠–١٠٠٪)',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('ترتيب عشوائي ثابت لكل محاولة'),
                    value: randomizeQuestions,
                    onChanged: (value) => setDialogState(
                      () => randomizeQuestions = value ?? false,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'title': title.text.trim(),
                  'instructions': instructions.text.trim(),
                  'starts': starts.text.trim(),
                  'deadline': deadline.text.trim(),
                  'timeLimit': timeLimit.text.trim(),
                  'attempts': attempts.text.trim(),
                  'passingScore': passingScore.text.trim(),
                  'randomizeQuestions': randomizeQuestions,
                }),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );
      if (values == null) return;
      final titleValue = values['title'] as String;
      if (titleValue.length < 2 || titleValue.length > 200) {
        throw const FormatException(
          'عنوان التقييم يجب أن يكون بين حرفين و٢٠٠ حرف.',
        );
      }
      final settings = AssessmentSettings.fromInput(
        startsAt: values['starts'] as String,
        dueAt: values['deadline'] as String,
        timeLimitMinutes: values['timeLimit'] as String,
        attemptLimit: values['attempts'] as String,
        passingScore: values['passingScore'] as String,
        randomizeQuestions: values['randomizeQuestions'] as bool,
      );
      await _client
          .from('learning_assessments')
          .update({
            'title': titleValue,
            'instructions': (values['instructions'] as String).isEmpty
                ? null
                : values['instructions'],
            ...settings.toJson(),
          })
          .eq('id', item['id'])
          .select('id');
      if (mounted) {
        setState(() {
          _reload();
          _notice = 'حُفظ تعديل التقييم.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تعديل التقييم: $error');
    } finally {
      title.dispose();
      instructions.dispose();
      starts.dispose();
      deadline.dispose();
      timeLimit.dispose();
      attempts.dispose();
      passingScore.dispose();
    }
  }

  Future<void> _duplicateAssessment(String assessmentId) async {
    try {
      await _client.rpc(
        'sai_learning_assessment_duplicate',
        params: {'p_assessment': assessmentId, 'p_title': null},
      );
      if (mounted) {
        setState(() {
          _reload();
          _notice = 'أُنشئت نسخة مسودة دون نسخ المحاولات أو الطلاب المعيّنين.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر نسخ التقييم: $error');
    }
  }

  Future<void> _manageAssignments(String assessmentId) async {
    try {
      final response = await _client.rpc(
        'sai_learning_assessment_roster',
        params: {'p_assessment': assessmentId},
      );
      if (response is! List) {
        throw StateError('استجابة قائمة الطلاب غير صالحة.');
      }
      final roster = List<Map<String, dynamic>>.from(response);
      final selected = roster
          .where((student) => student['assigned'] == true)
          .map((student) => '${student['student_id']}')
          .toSet();
      if (!mounted) return;
      final values = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('تعيين الطلاب'),
            content: SizedBox(
              width: 440,
              child: roster.isEmpty
                  ? const Text('لا يوجد طلاب نشطون في الصف.')
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final student in roster)
                          CheckboxListTile(
                            title: Text('${student['full_name']}'),
                            subtitle: Text('${student['admission_no']}'),
                            value: selected.contains(
                              '${student['student_id']}',
                            ),
                            onChanged: (checked) => setDialogState(() {
                              final id = '${student['student_id']}';
                              if (checked == true) {
                                selected.add(id);
                              } else {
                                selected.remove(id);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: roster.isEmpty
                    ? null
                    : () => Navigator.pop(context, {'classWide': true}),
                child: const Text('الصف بالكامل'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, {
                        'classWide': false,
                        'studentIds': selected.toList(),
                      }),
                child: const Text('حفظ التعيين'),
              ),
            ],
          ),
        ),
      );
      if (values == null) return;
      await _client.rpc(
        'sai_learning_assessment_assign',
        params: {
          'p_assessment': assessmentId,
          'p_student_ids': values['classWide'] == true
              ? <String>[]
              : values['studentIds'],
        },
      );
      if (mounted) {
        setState(() {
          _notice = values['classWide'] == true
              ? 'أُسند التقييم إلى الصف بالكامل.'
              : 'حُفظ تعيين الطلاب.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ تعيين الطلاب: $error');
    }
  }

  Future<void> _toggleResults(Map<String, dynamic> item) async {
    try {
      await _client
          .from('learning_assessments')
          .update({'results_released': item['results_released'] != true})
          .eq('id', item['id']);
      await _loadDetail('${item['id']}');
      if (mounted) {
        setState(() {
          _reload();
          _notice = item['results_released'] == true
              ? 'أُخفيت النتائج.'
              : 'أُتيحت النتائج للطالب وولي الأمر.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تغيير إتاحة النتائج: $error');
    }
  }

  Future<void> _deleteQuestion(String assessmentId, String questionId) async {
    try {
      await _client
          .from('learning_exercise_questions')
          .delete()
          .eq('id', questionId)
          .eq('assessment_id', assessmentId);
      await _loadDetail(assessmentId);
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حذف السؤال: $error');
    }
  }

  Future<void> _addFromBank(String assessmentId, String questionId) async {
    try {
      await _client.rpc(
        'sai_learning_assessment_add_from_bank',
        params: {'p_assessment': assessmentId, 'p_question': questionId},
      );
      await _loadDetail(assessmentId);
      if (mounted) setState(() => _notice = 'أُضيف سؤال البنك إلى المسودة.');
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر إضافة سؤال البنك: $error');
    }
  }

  Future<void> _previewQuestions() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة عرض الطالب'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < _questions.length; index++)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${_questions[index]['prompt']} · '
                            '${_questions[index]['points']} درجة',
                          ),
                          if (_questions[index]['kind'] == 'multiple_choice' ||
                              _questions[index]['kind'] == 'true_false')
                            for (final choice
                                in _questions[index]['choices'] as List)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.radio_button_off),
                                title: Text('$choice'),
                              ),
                          if (_questions[index]['kind'] == 'multiple_select')
                            for (final choice
                                in _questions[index]['choices'] as List)
                              ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.check_box_outline_blank,
                                ),
                                title: Text('$choice'),
                              ),
                          if (_questions[index]['kind'] == 'fill_blank')
                            const TextField(
                              enabled: false,
                              decoration: InputDecoration(
                                hintText: 'إجابة الطالب',
                              ),
                            ),
                          if (_questions[index]['kind'] == 'written')
                            const TextField(
                              enabled: false,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'إجابة الطالب',
                              ),
                            ),
                          if (_questions[index]['kind'] == 'matching')
                            const Text('يختار الطالب مطابقة لكل عنصر.'),
                        ],
                      ),
                    ),
                  ),
                if (_questions.isEmpty) const Text('أضف أسئلة لعرض المعاينة.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _start(String assessmentId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await _client.rpc(
        'sai_learning_assessment_start',
        params: {'p_assessment': assessmentId},
      );
      if (value is! Map) throw StateError('استجابة بدء التقييم غير صالحة.');
      final started = Map<String, dynamic>.from(value);
      final saved = started['saved_answers'];
      if (mounted) {
        setState(() {
          _attempt = started;
          _answers = saved is Map ? Map<String, dynamic>.from(saved) : {};
          _submitted = started['status'] != 'in_progress';
          _notice = started['timed_out'] == true
              ? 'انتهى الوقت وأُرسلت الإجابات المحفوظة تلقائياً.'
              : 'ستظهر النتيجة بعد إتاحتها من المعلم.';
        });
      }
      if (started['timed_out'] == true) {
        await _loadDetail(assessmentId);
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر بدء التقييم: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _saveAttempt() async {
    final attemptId = _attempt?['attempt_id'] as String?;
    if (attemptId == null) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      for (final entry in _answers.entries) {
        await _client.rpc(
          'sai_learning_assessment_save',
          params: {
            'p_attempt': attemptId,
            'p_question': entry.key,
            'p_answer': entry.value,
          },
        );
      }
      if (mounted) {
        setState(() => _notice = 'حُفظ التقدم، ويمكن استكمال المحاولة لاحقاً.');
      }
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ التقدم: $error');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitAttempt(String assessmentId) async {
    final attemptId = _attempt?['attempt_id'] as String?;
    if (attemptId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final expiresAt = DateTime.tryParse('${_attempt?['expires_at'] ?? ''}');
      final expiredByClock =
          expiresAt != null && !DateTime.now().toUtc().isBefore(expiresAt);
      if (!await _saveAttempt() &&
          !expiredByClock &&
          !(_error?.contains('Assessment time limit has passed') ?? false)) {
        return;
      }
      final outcome = await _client.rpc(
        'sai_learning_assessment_submit',
        params: {'p_attempt': attemptId},
      );
      if (outcome is! Map) throw StateError('استجابة التسليم غير صالحة.');
      if (mounted) {
        setState(() {
          _submitted = true;
          _notice =
              '${outcome['message'] ?? 'تم تسليم الإجابات.'} ستظهر النتيجة بعد إتاحتها.';
        });
      }
      await _loadDetail(assessmentId);
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر تسليم التقييم: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grade(Map<String, dynamic> row) async {
    final answerId = row['answer_id'] as String?;
    if (answerId == null) return;
    final points = TextEditingController(text: '${row['points_awarded'] ?? 0}');
    final feedback = TextEditingController(text: '${row['feedback'] ?? ''}');
    try {
      final value = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تصحيح الإجابة الكتابية'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${row['answer'] ?? ''}'),
              TextField(
                controller: points,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'الدرجة'),
              ),
              TextField(
                controller: feedback,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات المعلم'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ التصحيح'),
            ),
          ],
        ),
      );
      if (value != true) return;
      final score = double.tryParse(points.text);
      final matchingQuestion = _questions.where(
        (q) => q['id'] == row['question_id'],
      );
      final max = matchingQuestion.isEmpty
          ? null
          : (matchingQuestion.first['points'] as num?)?.toDouble();
      if (score == null || max == null || score < 0 || score > max) {
        throw StateError('أدخل درجة لا تتجاوز الدرجة القصوى للسؤال ($max).');
      }
      await _client.rpc(
        'sai_learning_assessment_grade',
        params: {
          'p_answer': answerId,
          'p_points': score,
          'p_feedback': feedback.text.trim().isEmpty
              ? null
              : feedback.text.trim(),
        },
      );
      await _loadDetail(_openId!);
      if (mounted) setState(() => _notice = 'حُفظ تصحيح الإجابة.');
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ التصحيح: $error');
    } finally {
      points.dispose();
      feedback.dispose();
    }
  }

  Widget _questionInput(Map<String, dynamic> question) {
    final id = '${question['id']}';
    final kind = '${question['kind']}';
    final options = List<String>.from(question['choices'] as List? ?? const []);
    final value = _answers[id];
    if (kind == 'multiple_choice' || kind == 'true_false') {
      return RadioGroup<int>(
        groupValue: value is num ? value.toInt() : null,
        onChanged: (answer) {
          if (!_submitted) setState(() => _answers[id] = answer);
        },
        child: Column(
          children: [
            for (var index = 0; index < options.length; index++)
              RadioListTile<int>(
                value: index,
                title: Text(options[index]),
                enabled: !_submitted,
              ),
          ],
        ),
      );
    }
    if (kind == 'multiple_select') {
      final selected = value is List
          ? value.whereType<num>().map((item) => item.toInt()).toSet()
          : <int>{};
      return Column(
        children: [
          for (var index = 0; index < options.length; index++)
            CheckboxListTile(
              value: selected.contains(index),
              title: Text(options[index]),
              enabled: !_submitted,
              onChanged: (checked) {
                final next = {...selected};
                if (checked == true) {
                  next.add(index);
                } else {
                  next.remove(index);
                }
                setState(() => _answers[id] = next.toList()..sort());
              },
            ),
        ],
      );
    }
    if (kind == 'matching') {
      final half = options.length ~/ 2;
      final left = options.take(half).toList();
      final right = options.skip(half).toList();
      final answers = value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
      return Column(
        children: [
          for (final item in left)
            DropdownButtonFormField<String>(
              initialValue: right.contains(answers[item])
                  ? answers[item] as String
                  : null,
              decoration: InputDecoration(labelText: item),
              items: right
                  .map(
                    (choice) =>
                        DropdownMenuItem(value: choice, child: Text(choice)),
                  )
                  .toList(),
              onChanged: _submitted
                  ? null
                  : (choice) => setState(
                      () => _answers[id] = {...answers, item: choice},
                    ),
            ),
        ],
      );
    }
    return TextFormField(
      minLines: kind == 'written' ? 3 : 1,
      maxLines: kind == 'written' ? 6 : 1,
      maxLength: 5000,
      readOnly: _submitted,
      initialValue: value is String ? value : '',
      decoration: InputDecoration(
        labelText: kind == 'written' ? 'إجابتك الكتابية' : 'الإجابة',
      ),
      onChanged: (answer) => _answers[id] = answer,
    );
  }

  Widget _detail(Map<String, dynamic> item) {
    final id = '${item['id']}';
    if (widget.canManage) {
      final status = '${item['status']}';
      final canEditQuestions = status == 'draft' || status == 'published';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              if (status == 'draft')
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _changeStatus(item, 'published'),
                  child: const Text('نشر للطلاب'),
                ),
              if (status == 'published')
                TextButton(
                  onPressed: _busy ? null : () => _changeStatus(item, 'closed'),
                  child: const Text('إغلاق التقييم'),
                ),
              if (status == 'closed')
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _changeStatus(item, 'archived'),
                  child: const Text('أرشفة التقييم'),
                ),
              if (status != 'archived')
                TextButton(
                  onPressed: _busy ? null : () => _duplicateAssessment(id),
                  child: const Text('نسخ التقييم'),
                ),
              if (status != 'closed' && status != 'archived')
                TextButton(
                  onPressed: _busy ? null : () => _manageAssignments(id),
                  child: const Text('تعيين الطلاب'),
                ),
              TextButton(
                onPressed: _busy || status == 'draft' || status == 'archived'
                    ? null
                    : () => _toggleResults(item),
                child: Text(
                  item['results_released'] == true
                      ? 'إخفاء النتائج'
                      : 'إتاحة النتائج',
                ),
              ),
              if (canEditQuestions)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _previewQuestions,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('معاينة الطالب'),
                ),
              if (canEditQuestions)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _addQuestion(id),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة سؤال'),
                ),
            ],
          ),
          if (status == 'draft' && _bankQuestions.isNotEmpty) ...[
            const Text('أسئلة مصنفة قابلة لإعادة الاستخدام'),
            for (final question in _bankQuestions)
              ListTile(
                title: Text('${question['prompt']}'),
                subtitle: Text('${question['bank_category']}'),
                trailing: canEditQuestions
                    ? TextButton(
                        onPressed: _busy
                            ? null
                            : () => _addFromBank(id, '${question['id']}'),
                        child: const Text('إضافة'),
                      )
                    : null,
              ),
          ],
          if (_questions.isEmpty)
            const Text('لا توجد أسئلة بعد. أضف سؤالاً قبل النشر.'),
          for (final question in _questions)
            ListTile(
              title: Text('${question['prompt']}'),
              subtitle: Text(
                '${_questionKinds[question['kind']]} · ${question['points']} درجة',
              ),
              trailing: canEditQuestions
                  ? PopupMenuButton<String>(
                      onSelected: (choice) {
                        if (choice == 'edit') {
                          _addQuestion(id, current: question);
                        }
                        if (choice == 'delete') {
                          _deleteQuestion(id, '${question['id']}');
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    )
                  : null,
            ),
          const Divider(),
          const Text('المحاولات والتصحيح'),
          if (_results.isEmpty) const Text('لا توجد محاولات.'),
          for (final result in _results)
            if (result['answer_id'] != null)
              Card(
                child: ListTile(
                  title: Text('${result['prompt'] ?? 'سؤال'}'),
                  subtitle: Text(
                    '${result['answer'] ?? 'لم تُسجل إجابة'}'
                    '${result['feedback'] == null ? '' : '\n${result['feedback']}'}',
                  ),
                  trailing:
                      result['kind'] == 'written' &&
                          result['status'] != 'graded'
                      ? IconButton(
                          onPressed: () => _grade(result),
                          icon: const Icon(Icons.rate_review_outlined),
                        )
                      : Text('${result['points_awarded'] ?? ''}'),
                ),
              ),
        ],
      );
    }

    if (widget.canTake) {
      if (_attempt == null) {
        final startsAt = DateTime.tryParse('${item['starts_at'] ?? ''}');
        final waitingForStart =
            startsAt != null && DateTime.now().toUtc().isBefore(startsAt);
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            onPressed: _busy || !_assessmentIsOpen(item)
                ? null
                : () => _start(id),
            child: Text(
              waitingForStart
                  ? 'يفتح في ${item['starts_at']}'
                  : 'بدء أو استكمال المحاولة المحفوظة',
            ),
          ),
        );
      }
      final questions = List<Map<String, dynamic>>.from(
        _attempt!['questions'] as List? ?? const [],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_attempt!['due_at'] != null)
            Text('موعد الإغلاق: ${_attempt!['due_at']}'),
          if (_attempt!['expires_at'] != null && !_submitted)
            Text('تنتهي المحاولة: ${_attempt!['expires_at']}'),
          for (var index = 0; index < questions.length; index++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${questions[index]['prompt']} (${questions[index]['points']} درجة)',
                    ),
                    _questionInput(questions[index]),
                  ],
                ),
              ),
            ),
          if (_submitted)
            Text(
              _notice ??
                  'تم تسليم إجاباتك. تظهر النتيجة بعد إتاحتها من المعلم.',
            )
          else
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _saveAttempt();
                        },
                  child: const Text('حفظ التقدم'),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _submitAttempt(id),
                  child: const Text('تسليم الإجابات'),
                ),
              ],
            ),
        ],
      );
    }

    if (_results.isEmpty) {
      return const Text('تظهر النتيجة بعد تصحيحها وإتاحتها من المعلم.');
    }
    return Column(
      children: [
        for (final result in _results)
          if (result['score'] != null)
            ListTile(
              title: Text(
                'النتيجة: ${result['score']} من ${result['max_score']}',
              ),
              subtitle: Text(
                '${result['passed'] == null
                    ? ''
                    : result['passed'] == true
                    ? 'مجتاز'
                    : 'لم يجتز'}'
                '${result['feedback'] == null ? '' : ' · ${result['feedback']}'}',
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('التقييمات والتمارين'),
        actions: [
          IconButton(
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
          ),
          if (widget.canManage)
            IconButton(
              onPressed: _createAssessment,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _assessments,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyPanel(
              'تعذر تحميل التقييمات: ${snapshot.error}',
              retry: () => setState(_reload),
            );
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return Center(
              child: EmptyPanel(
                widget.canManage
                    ? 'لا توجد تقييمات لهذا الدرس. أضف مسودة باستخدام زر الإضافة.'
                    : 'لا توجد تقييمات منشورة لهذا الدرس.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_notice != null)
                Text(_notice!, style: const TextStyle(color: Colors.green)),
              for (final item in items)
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('${item['title']}'),
                        subtitle: Text(
                          '${_assessmentStatusLabel(item['status'])}'
                          '${item['starts_at'] == null ? '' : ' · يبدأ ${item['starts_at']}'}'
                          ' · ${item['attempt_limit']} محاولات'
                          '${item['time_limit_minutes'] == null ? '' : ' · ${item['time_limit_minutes']} دقيقة'}'
                          ' · الاجتياز ${item['passing_score'] ?? 70}%'
                          '${item['due_at'] == null ? '' : ' · ${item['due_at']}'}',
                        ),
                        trailing: widget.canManage
                            ? PopupMenuButton<String>(
                                onSelected: (choice) {
                                  if (choice == 'edit') _editAssessment(item);
                                },
                                itemBuilder: (_) => [
                                  if (item['status'] == 'draft' ||
                                      item['status'] == 'published')
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('تعديل الإعدادات'),
                                    ),
                                ],
                              )
                            : const Icon(Icons.chevron_left),
                        onTap: () => _open(item),
                      ),
                      if (_openId == item['id'])
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if ((item['instructions'] as String?)
                                      ?.isNotEmpty ==
                                  true)
                                Text('${item['instructions']}'),
                              _detail(item),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
