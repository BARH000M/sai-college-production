import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/finance_repository.dart';

/// Uses the existing fee-group and assignment RPCs; no direct ledger writes.
class FinanceSetup extends StatefulWidget {
  const FinanceSetup({super.key});
  @override
  State<FinanceSetup> createState() => _FinanceSetupState();
}

class _FinanceSetupState extends State<FinanceSetup> {
  final client = Supabase.instance.client;
  late final repository = FinanceRepository(client);
  List<Map<String, dynamic>> groups = [],
      students = [],
      sessions = [],
      branches = [];
  final name = TextEditingController(),
      description = TextEditingController(),
      amount = TextEditingController();
  final due = TextEditingController(),
      discount = TextEditingController(text: '0'),
      assignmentDue = TextEditingController();
  String? editId, branch, session, groupId, studentId, error, success;
  bool busy = false, ready = false, active = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      description,
      amount,
      due,
      discount,
      assignmentDue,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        repository.rows('sai_finance_groups'),
        repository.rows('sai_finance_students'),
        repository.rows('sai_finance_sessions'),
      ]);
      // Branch options are covered by the existing branch RLS policies.
      final options = <Map<String, dynamic>>[];
      while (true) {
        final page = await client
            .from('branches')
            .select('id,name')
            .eq('is_active', true)
            .order('id')
            .range(options.length, options.length + 999);
        options.addAll(page);
        if (page.length < 1000) break;
      }
      if (mounted) {
        setState(() {
          groups = results[0];
          students = results[1];
          sessions = results[2];
          branches = options;
          ready = true;
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = '$failure';
          ready = false;
        });
      }
    }
  }

  Future<void> _save(bool assignment) async {
    if (busy || !ready) return;
    setState(() {
      busy = true;
      error = null;
      success = null;
    });
    try {
      final params = assignment
          ? <String, dynamic>{
              'wanted_group': groupId,
              'wanted_student': studentId,
              'wanted_discount': financeAmount(discount.text),
              'wanted_due': assignmentDue.text.trim().isEmpty
                  ? null
                  : assignmentDue.text.trim(),
            }
          : <String, dynamic>{
              'wanted_id': editId,
              'wanted_branch': branch,
              'wanted_session': session,
              'wanted_name': name.text.trim(),
              'wanted_description': description.text.trim().isEmpty
                  ? null
                  : description.text.trim(),
              'wanted_amount': financeAmount(amount.text),
              'wanted_due': due.text.trim(),
              'wanted_active': active,
            };
      if (assignment && (groupId == null || studentId == null)) {
        throw StateError('اختر المجموعة والطالب');
      }
      if (!assignment &&
          (branch == null ||
              session == null ||
              name.text.trim().isEmpty ||
              due.text.trim().isEmpty)) {
        throw StateError('أكمل بيانات المجموعة');
      }
      final result = await client.rpc(
        assignment ? 'sai_finance_assign' : 'sai_finance_save_group',
        params: params,
      );
      if (result is! String || result.isEmpty) {
        throw StateError('تعذر تأكيد العملية؛ راجع السجل');
      }
      if (mounted) {
        setState(
          () => success = assignment
              ? 'تم إسناد الرسوم'
              : 'تم حفظ المجموعة؛ لم تتغير الفواتير السابقة',
        );
        await _load();
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _select(
    String label,
    String? value,
    List<Map<String, dynamic>> options,
    ValueChanged<String?>? change,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final row in options)
        DropdownMenuItem(
          value: '${row['id']}',
          child: Text('${row['name']}', overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: busy || !ready ? null : change,
  );

  Widget _text(String label, TextEditingController controller) => TextField(
    controller: controller,
    enabled: !busy && ready,
    decoration: InputDecoration(labelText: label),
  );

  void _edit(Map<String, dynamic>? row) {
    setState(() {
      editId = row?['id'] as String?;
      branch = row?['branch_id'] as String?;
      session = row?['academic_session_id'] as String?;
      name.text = '${row?['name'] ?? ''}';
      description.text = '${row?['description'] ?? ''}';
      amount.text = '${row?['amount'] ?? ''}';
      due.text = '${row?['due_date'] ?? ''}';
      active = row?['is_active'] as bool? ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chosen = groups.where((g) => g['id'] == groupId).firstOrNull;
    final eligible = students
        .where(
          (s) =>
              chosen != null &&
              s['status'] == 'active' &&
              s['branch_id'] == chosen['branch_id'] &&
              (s['class_id'] == null ||
                  s['session_id'] == chosen['academic_session_id']),
        )
        .map((s) => {...s, 'name': '${s['full_name']} · ${s['admission_no']}'})
        .toList();
    final sessionOptions = [...sessions];
    if (session != null && !sessionOptions.any((s) => s['id'] == session)) {
      sessionOptions.add({'id': session, 'name': 'الجلسة الحالية (غير نشطة)'});
    }
    final branchOptions = [...branches];
    if (branch != null && !branchOptions.any((b) => b['id'] == branch)) {
      branchOptions.add({'id': branch, 'name': 'الفرع الحالي (غير نشط)'});
    }
    return Scaffold(
      appBar: AppBar(title: const Text('مجموعات الرسوم والإسناد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (success != null) Text(success!),
          if (!ready)
            TextButton(
              onPressed: _load,
              child: const Text('تحميل البيانات / إعادة المحاولة'),
            ),
          const Text('مجموعة رسوم جديدة أو تعديل مجموعة'),
          _select(
            'تعديل مجموعة موجودة',
            editId,
            groups,
            (id) => _edit(groups.firstWhere((g) => g['id'] == id)),
          ),
          TextButton(
            onPressed: busy ? null : () => _edit(null),
            child: const Text('مجموعة جديدة'),
          ),
          _select(
            'الفرع',
            branch,
            branchOptions,
            editId != null ? null : (value) => setState(() => branch = value),
          ),
          _select(
            'الجلسة الأكاديمية',
            session,
            sessionOptions,
            editId != null ? null : (value) => setState(() => session = value),
          ),
          _text('اسم المجموعة', name),
          _text('الوصف', description),
          _text('المبلغ بالريال اليمني', amount),
          _text('الاستحقاق YYYY-MM-DD', due),
          SwitchListTile(
            value: active,
            onChanged: busy ? null : (value) => setState(() => active = value),
            title: const Text('مجموعة نشطة'),
          ),
          FilledButton(
            onPressed: busy || !ready ? null : () => _save(false),
            child: const Text('حفظ المجموعة'),
          ),
          const Divider(),
          const Text('إسناد رسوم لطالب'),
          _select(
            'مجموعة الرسوم',
            groupId,
            groups.where((g) => g['is_active'] == true).toList(),
            (value) => setState(() {
              groupId = value;
              studentId = null;
            }),
          ),
          _select(
            'الطالب',
            studentId,
            eligible,
            (value) => setState(() => studentId = value),
          ),
          _text('الخصم الثابت', discount),
          _text('استحقاق خاص YYYY-MM-DD (اختياري)', assignmentDue),
          FilledButton(
            onPressed: busy || !ready ? null : () => _save(true),
            child: const Text('إسناد الرسوم'),
          ),
        ],
      ),
    );
  }
}
