import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'components.dart';

const _questionKinds = <String, String>{
  'multiple_choice': 'اختيار من متعدد',
  'true_false': 'صح أو خطأ',
  'matching': 'مطابقة',
  'fill_blank': 'أكمل الفراغ',
  'written': 'إجابة كتابية',
};

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
          'id,course_id,lesson_id,title,instructions,due_at,attempt_limit,status,results_released',
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
      _results = [];
    });
    await _loadDetail('${assessment['id']}');
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
    final deadline = TextEditingController();
    final attempts = TextEditingController(text: '1');
    try {
      final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => AlertDialog(
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
                  controller: deadline,
                  decoration: const InputDecoration(
                    labelText: 'موعد نهائي ISO اختياري',
                  ),
                ),
                TextField(
                  controller: attempts,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الحد الأقصى للمحاولات (١–١٠)',
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
                'deadline': deadline.text.trim(),
                'attempts': attempts.text.trim(),
              }),
              child: const Text('حفظ المسودة'),
            ),
          ],
        ),
      );
      if (values == null) return;
      final limit = int.tryParse(values['attempts'] ?? '');
      final due = values['deadline']?.isEmpty == true
          ? null
          : DateTime.tryParse(values['deadline']!)?.toUtc().toIso8601String();
      if ((values['title'] ?? '').length < 2 ||
          limit == null ||
          limit < 1 ||
          limit > 10 ||
          (values['deadline']!.isNotEmpty && due == null)) {
        throw StateError('راجع العنوان وموعد التسليم وعدد المحاولات.');
      }
      await _client.from('learning_assessments').insert({
        'course_id': widget.courseId,
        'lesson_id': widget.lessonId,
        'title': values['title'],
        'instructions': values['instructions']!.isEmpty
            ? null
            : values['instructions'],
        'due_at': due,
        'attempt_limit': limit,
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
      deadline.dispose();
      attempts.dispose();
    }
  }

  Future<void> _addQuestion(
    String assessmentId, {
    Map<String, dynamic>? current,
  }) async {
    String kind = '${current?['kind'] ?? 'multiple_choice'}';
    final prompt = TextEditingController(text: '${current?['prompt'] ?? ''}');
    final points = TextEditingController(text: '${current?['points'] ?? 1}');
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
                    if (kind == 'multiple_choice' || kind == 'true_false')
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
      if (kindValue == 'matching') {
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
          numericPoints <= 0) {
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
      if (mounted) setState(() => _notice = 'حُفظ السؤال.');
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر حفظ السؤال: $error');
    } finally {
      prompt.dispose();
      points.dispose();
      choices.dispose();
      answer.dispose();
    }
  }

  String _answerText(Map<String, dynamic> question) {
    final key = question['answer_key'];
    if (key is Map) {
      return (question['choices'] as List)
          .take((question['choices'] as List).length ~/ 2)
          .map((left) => key[left] ?? '')
          .join('\n');
    }
    if (key is List) return key.join('\n');
    return '';
  }

  Future<void> _toggleStatus(Map<String, dynamic> item) async {
    try {
      await _client
          .from('learning_assessments')
          .update({
            'status': item['status'] == 'published' ? 'draft' : 'published',
          })
          .eq('id', item['id']);
      if (mounted) {
        setState(() {
          _reload();
          _notice = item['status'] == 'published'
              ? 'أُوقف نشر التقييم.'
              : 'نُشر التقييم.';
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
    final deadline = TextEditingController(text: '${item['due_at'] ?? ''}');
    final attempts = TextEditingController(
      text: '${item['attempt_limit'] ?? 1}',
    );
    try {
      final values = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => AlertDialog(
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
                  controller: deadline,
                  decoration: const InputDecoration(
                    labelText: 'موعد نهائي ISO اختياري',
                  ),
                ),
                TextField(
                  controller: attempts,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الحد الأقصى للمحاولات (١–١٠)',
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
                'deadline': deadline.text.trim(),
                'attempts': attempts.text.trim(),
              }),
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
      if (values == null) return;
      final limit = int.tryParse(values['attempts'] ?? '');
      final due = values['deadline']?.isEmpty == true
          ? null
          : DateTime.tryParse(values['deadline']!)?.toUtc().toIso8601String();
      if ((values['title'] ?? '').length < 2 ||
          limit == null ||
          limit < 1 ||
          limit > 10 ||
          (values['deadline']!.isNotEmpty && due == null)) {
        throw StateError('راجع العنوان وموعد التسليم وعدد المحاولات.');
      }
      await _client
          .from('learning_assessments')
          .update({
            'title': values['title'],
            'instructions': values['instructions']!.isEmpty
                ? null
                : values['instructions'],
            'due_at': due,
            'attempt_limit': limit,
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
      deadline.dispose();
      attempts.dispose();
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
        });
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
      if (!await _saveAttempt()) return;
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _toggleStatus(item),
                child: Text(
                  item['status'] == 'published' ? 'إيقاف النشر' : 'نشر للطلاب',
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => _toggleResults(item),
                child: Text(
                  item['results_released'] == true
                      ? 'إخفاء النتائج'
                      : 'إتاحة النتائج',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _addQuestion(id),
                icon: const Icon(Icons.add),
                label: const Text('إضافة سؤال'),
              ),
            ],
          ),
          if (_questions.isEmpty)
            const Text('لا توجد أسئلة بعد. أضف سؤالاً قبل النشر.'),
          for (final question in _questions)
            ListTile(
              title: Text('${question['prompt']}'),
              subtitle: Text(
                '${_questionKinds[question['kind']]} · ${question['points']} درجة',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (choice) {
                  if (choice == 'edit') _addQuestion(id, current: question);
                  if (choice == 'delete') {
                    _deleteQuestion(id, '${question['id']}');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
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
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            onPressed: _busy ? null : () => _start(id),
            child: const Text('بدء أو استكمال المحاولة المحفوظة'),
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
            Text('موعد التسليم: ${_attempt!['due_at']}'),
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
              subtitle: Text(result['feedback']?.toString() ?? ''),
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
                          '${item['status'] == 'published' ? 'منشور' : 'مسودة'}'
                          ' · ${item['attempt_limit']} محاولات'
                          '${item['due_at'] == null ? '' : ' · ${item['due_at']}'}',
                        ),
                        trailing: widget.canManage
                            ? PopupMenuButton<String>(
                                onSelected: (choice) {
                                  if (choice == 'edit') _editAssessment(item);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
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
