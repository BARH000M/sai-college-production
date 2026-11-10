import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/access.dart';
import '../data/module_registry.dart';
import '../data/repository.dart';
import 'components.dart';

/// Live, RLS-protected Supabase-backed module. This never writes demo data.
/// Existing operational modules stay read-only until their dedicated business
/// transactions (circulation, marking, payment, etc.) are wired to server APIs.
class LiveModuleScreen extends StatefulWidget {
  const LiveModuleScreen({super.key, required this.spec, required this.roles});
  final ModuleSpec spec;
  final Set<Role> roles;

  @override
  State<LiveModuleScreen> createState() => _LiveModuleScreenState();
}

class _LiveModuleScreenState extends State<LiveModuleScreen> {
  late Stream<List<Map<String, dynamic>>> rows;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    rows = Supabase.instance.client
        .from(widget.spec.table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100);
  }

  bool get canWrite => widget.spec.writable &&
      Access.manages(widget.roles, widget.spec.page);

  Future<void> _edit([Map<String, dynamic>? current]) async {
    if (!canWrite || busy) return;
    try {
      final branches = current != null
          ? <Map<String, dynamic>>[]
          : await Repository().branches();
      if (!mounted) return;
      if (current == null && branches.isEmpty) {
        _notice('لا توجد فروع متاحة لحسابك. اربط الحساب بفرع أولاً.');
        return;
      }
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _ModuleEditor(
          spec: widget.spec,
          existing: current,
          branches: branches,
        ),
      );
      if (data == null || !mounted) return;
      setState(() => busy = true);
      final q = Supabase.instance.client.from(widget.spec.table);
      if (current == null) {
        await q.insert(data);
      } else {
        await q.update(data).eq('id', current['id']);
      }
      if (!mounted) return;
      _notice('تم الحفظ في Supabase بنجاح.');
    } on PostgrestException catch (e) {
      if (mounted) _notice('رفضت قاعدة البيانات العملية: ${e.message}');
    } catch (_) {
      if (mounted) _notice('تعذر حفظ التعديلات. تحقق من الاتصال والصلاحيات.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> current) async {
    if (!canWrite || busy) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف «${current['title']}» من قاعدة البيانات المشتركة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => busy = true);
    try {
      await Supabase.instance.client.from(widget.spec.table).delete().eq('id', current['id']);
      if (mounted) _notice('تم تنفيذ الحذف وفق صلاحيات الخادم.');
    } on PostgrestException catch (e) {
      if (mounted) _notice('تعذر الحذف: ${e.message}');
    } catch (_) {
      if (mounted) _notice('تعذر الحذف، أعد المحاولة.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Submit real homework to the existing authoritative submissions table.
  /// Auth and RLS decide whether the current student may submit/replace it.
  Future<void> _submitHomework(Map<String, dynamic> homework) async {
    final studentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (studentUserId == null) { _notice('يرجى تسجيل الدخول أولاً.'); return; }
    try {
      final client = Supabase.instance.client;
      final student = await client.from('students').select('id')
          .eq('user_id', studentUserId).maybeSingle();
      if (student == null) { _notice('لا يوجد ملف طالب مرتبط بالحساب.'); return; }
      final existing = await client.from('learning_homework_submissions')
          .select('id,content,status').eq('homework_id', homework['id'])
          .eq('student_id', student['id']).maybeSingle();
      if (!mounted) return;
      if (existing != null && existing['status'] == 'graded') {
        _notice('تم اعتماد درجة هذا التسليم؛ راجع المعلم لأي تعديل.');
        return;
      }
      final editor = TextEditingController(text: (existing?['content'] ?? '').toString());
      try {
        final content = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تسليم الواجب'),
            content: TextField(controller: editor, minLines: 3, maxLines: 7,
              decoration: const InputDecoration(labelText: 'إجابتك')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(onPressed: () {
                if (editor.text.trim().isNotEmpty) Navigator.pop(ctx, editor.text.trim());
              }, child: const Text('تسليم')),
            ],
          ),
        );
        if (content == null || !mounted) return;
        if (existing == null) {
          await client.from('learning_homework_submissions').insert({
            'homework_id': homework['id'], 'student_id': student['id'],
            'content': content, 'status': 'submitted',
          });
        } else {
          await client.from('learning_homework_submissions').update({
            'content': content, 'status': 'submitted',
          }).eq('id', existing['id']);
        }
        if (mounted) _notice('تم تسليم الواجب إلى قاعدة البيانات المشتركة.');
      } finally {
        editor.dispose();
      }
    } on PostgrestException catch (e) {
      if (mounted) _notice('تعذر تسليم الواجب: ${e.message}');
    } catch (_) {
      if (mounted) _notice('تعذر إتمام التسليم. حاول مجدداً.');
    }
  }

  /// Use the existing atomic server RPC instead of editing loan quantities.
  Future<void> _issueLibraryItem(Map<String, dynamic> item) async {
    try {
      final client = Supabase.instance.client;
      final students = await client.from('students').select('id,full_name')
          .eq('branch_id', item['branch_id']).order('full_name').limit(250);
      if (!mounted) return;
      if (students.isEmpty) { _notice('لا توجد سجلات طلاب متاحة لهذا الفرع.'); return; }
      final studentId = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('اختر الطالب لاستعارة الكتاب'),
          children: [
            SizedBox(
              height: 360,
              width: 360,
              child: ListView(
                children: [for (final student in students)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, student['id'] as String),
                    child: Text('${student['full_name']}'),
                  )],
              ),
            ),
          ],
        ),
      );
      if (studentId == null || !mounted) return;
      await client.rpc('sai_library_issue', params: {
        'p_item': item['id'], 'p_student': studentId,
        'p_due': DateTime.now().add(const Duration(days: 14)).toIso8601String().substring(0, 10),
      });
      if (mounted) _notice('تم تسجيل الإعارة في قاعدة البيانات المشتركة.');
    } on PostgrestException catch (e) {
      if (mounted) _notice('رفضت قاعدة البيانات الإعارة: ${e.message}');
    } catch (_) {
      if (mounted) _notice('تعذر تسجيل الإعارة.');
    }
  }

  Future<void> _returnLibraryItem(Map<String, dynamic> item) async {
    try {
      final client = Supabase.instance.client;
      final loans = await client.from('library_loans')
          .select('id,student_id,due_date').eq('item_id', item['id'])
          .isFilter('returned_at', null).limit(100);
      if (!mounted) return;
      if (loans.isEmpty) { _notice('لا توجد إعارة مفتوحة لهذا الكتاب.'); return; }
      final loanId = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('اختر الإعارة للإرجاع'),
          children: [
            SizedBox(width: 360, height: 330, child: ListView(children: [
              for (final loan in loans)
                SimpleDialogOption(onPressed: () => Navigator.pop(ctx, loan['id'] as String),
                  child: Text('الطالب: ${loan['student_id']} • موعد الإرجاع: ${loan['due_date']}')),
            ])),
          ],
        ),
      );
      if (loanId == null || !mounted) return;
      await client.rpc('sai_library_return', params: {'p_loan': loanId});
      if (mounted) _notice('تم تسجيل الإرجاع في قاعدة البيانات المشتركة.');
    } on PostgrestException catch (e) {
      if (mounted) _notice('رفضت قاعدة البيانات الإرجاع: ${e.message}');
    } catch (_) {
      if (mounted) _notice('تعذر إتمام الإرجاع.');
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(
          children: [
            Expanded(child: Text(widget.spec.subtitle, style: const TextStyle(fontSize: 12))),
            IconButton(
              tooltip: 'تحديث البيانات',
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh_rounded, color: darkRed),
            ),
            if (canWrite)
              IconButton(
                tooltip: 'إضافة سجل',
                onPressed: busy ? null : () => _edit(),
                icon: const Icon(Icons.add_circle, color: darkRed),
              ),
          ],
        ),
      ),
      if (busy) const LinearProgressIndicator(),
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: rows,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: EmptyPanel('هذه الوحدة لا يمكن تحميلها من قاعدة البيانات الآن. تحقق من وجود الجدول، ونشر ترحيل قاعدة البيانات، وصلاحيات RLS. لا تُعرض بيانات تجريبية مكان البيانات الحقيقية.', retry: () => setState(_reload)),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final results = snapshot.data!;
            if (results.isEmpty) {
              return Center(child: EmptyPanel('لا توجد سجلات متاحة لحسابك في ${widget.spec.title}.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              itemCount: results.length,
              itemBuilder: (context, i) {
                final r = results[i];
                final label = (r['title'] ?? r['name'] ?? 'سجل').toString();
                final subtitle = [r['description'], r['instructions'], r['author'], r['category'], r['status']]
                    .where((v) => v != null && v.toString().trim().isNotEmpty)
                    .map((v) => v.toString()).take(2).join(' • ');
                return SaiCard(
                  padding: 7,
                  child: ListTile(
                    title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    leading: const Icon(Icons.article_outlined, color: darkRed),
                    trailing: canWrite
                        ? PopupMenuButton<String>(
                            onSelected: (choice) {
                              if (choice == 'edit') _edit(r);
                              if (choice == 'delete') _delete(r);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('تعديل')),
                              PopupMenuItem(value: 'delete', child: Text('حذف')),
                            ],
                          )
                        : const Icon(Icons.chevron_left_rounded),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(label, style: Theme.of(context).textTheme.titleLarge),
                              const Divider(),
                              if (widget.spec.page == PageId.assignments && widget.roles.contains(Role.student))
                                FilledButton.icon(onPressed: () => _submitHomework(r),
                                  icon: const Icon(Icons.upload_file), label: const Text('تسليم الواجب')),
                              if (widget.spec.page == PageId.library && Access.manages(widget.roles, PageId.library)) ...[
                                FilledButton.icon(onPressed: () => _issueLibraryItem(r),
                                  icon: const Icon(Icons.bookmark_add_outlined), label: const Text('تسجيل إعارة')),
                                OutlinedButton.icon(onPressed: () => _returnLibraryItem(r),
                                  icon: const Icon(Icons.assignment_return_outlined), label: const Text('إرجاع نسخة')),
                              ],
                              for (final item in r.entries)
                                if (!['id', 'branch_id', 'created_by', 'updated_by'].contains(item.key) && item.value != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Text('${item.key}: ${item.value}'),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class _ModuleEditor extends StatefulWidget {
  const _ModuleEditor({required this.spec, this.existing, required this.branches});
  final ModuleSpec spec;
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> branches;
  @override
  State<_ModuleEditor> createState() => _ModuleEditorState();
}

class _ModuleEditorState extends State<_ModuleEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController description;
  late final Map<String, TextEditingController> extra;
  String? branchId;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: '${widget.existing?['title'] ?? ''}');
    description = TextEditingController(text: '${widget.existing?['description'] ?? ''}');
    extra = {
      for (final field in widget.spec.fields)
        field.key: TextEditingController(text: '${widget.existing?[field.key] ?? ''}'),
    };
    if (widget.branches.length == 1) branchId = widget.branches.first['id'] as String;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    for (final c in extra.values) { c.dispose(); }
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    if (widget.existing == null && branchId == null) return;
    final payload = <String, dynamic>{
      'title': title.text.trim(),
      'description': description.text.trim(),
      if (widget.existing == null) 'branch_id': branchId,
    };
    for (final field in widget.spec.fields) {
      final value = extra[field.key]!.text.trim();
      // An empty optional field means NULL, not the string "null".
      payload[field.key] = value.isEmpty ? null : (field.numeric ? int.tryParse(value) : value);
    }
    Navigator.pop(context, payload);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'إضافة ${widget.spec.title}' : 'تعديل السجل'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.existing == null)
                DropdownButtonFormField<String>(
                  initialValue: branchId,
                  items: [
                    for (final b in widget.branches)
                      DropdownMenuItem(value: b['id'] as String, child: Text('${b['name']}')),
                  ],
                  onChanged: (value) => setState(() => branchId = value),
                  decoration: const InputDecoration(labelText: 'الفرع'),
                  validator: (value) => value == null ? 'اختر الفرع' : null,
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: 'العنوان'),
                validator: (v) => v == null || v.trim().isEmpty ? 'العنوان مطلوب' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: description,
                decoration: const InputDecoration(labelText: 'الوصف'),
                minLines: 1,
                maxLines: 3,
              ),
              for (final field in widget.spec.fields) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: extra[field.key],
                  decoration: InputDecoration(labelText: field.label),
                  keyboardType: field.numeric ? TextInputType.number : TextInputType.text,
                  validator: (value) => field.numeric && value != null && value.trim().isNotEmpty && (int.tryParse(value.trim()) == null || int.parse(value.trim()) < 0)
                      ? 'أدخل عدداً صحيحاً غير سالب' : null,
                ),
              ],
              const SizedBox(height: 9),
              const Text('العمليات تُحفظ في Supabase فوراً وتخضع لصلاحيات قاعدة البيانات.', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(onPressed: save, child: const Text('حفظ')),
    ],
  );
}

/// Metrics are RLS scoped. Never show local demo totals as production facts.
class LiveReportsScreen extends StatefulWidget {
  const LiveReportsScreen({super.key});
  @override
  State<LiveReportsScreen> createState() => _LiveReportsScreenState();
}

class _LiveReportsScreenState extends State<LiveReportsScreen> {
  late Future<List<(String, int?)>> future = _load();
  Future<List<(String, int?)>> _load() async {
    final client = Supabase.instance.client;
    final result = <(String, int?)>[];
    for (final entry in [('students', 'الطلاب'), ('classes', 'الصفوف'), ('learning_homework', 'الواجبات'), ('library_items', 'كتب المكتبة')]) {
      try {
        final response = await client.from(entry.$1).select('id').count(CountOption.exact);
        result.add((entry.$2, response.count));
      } catch (_) {
        result.add((entry.$2, null));
      }
    }
    return result;
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<(String, int?)>>(
    future: future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeading('إحصاءات البيانات المتاحة لحسابك'),
          const Text('تعرض الأعداد التي تسمح بها سياسات RLS، ولا تعتبر ميزاناً مالياً أو تقريراً إدارياً معتمداً.'),
          const SizedBox(height: 12),
          for (final item in snapshot.data!)
            SaiCard(child: ListTile(
              title: Text(item.$1),
              trailing: Text(item.$2?.toString() ?? 'غير متاح', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkRed)),
            )),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => future = _load()),
            icon: const Icon(Icons.refresh), label: const Text('تحديث التقرير'),
          ),
        ],
      );
    },
  );
}

const systemSettingCategories = <String>[
  'الإعداد العام', 'إعداد الجلسة', 'الإشعارات', 'الرسائل القصيرة',
  'واتساب', 'البريد الإلكتروني', 'طرق الدفع', 'الطباعة',
  'إعداد CMS', 'صلاحيات الأدوار', 'استرجاع البيانات', 'اللغات',
  'العملات', 'المستخدمون', 'الإضافات', 'الوحدات',
  'الحقول المخصصة', 'التحقق', 'التحديثات', 'قائمة العناوين المحظورة',
];

class CollegeSettingsScreen extends StatelessWidget {
  const CollegeSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const SectionHeading('إعدادات نظام Yemen SAI'),
      const Text('هذه قائمة إعدادات الإدارة. لا تُحفظ أسرار خدمات الدفع والبريد داخل تطبيق الهاتف. عمليات التهيئة الحساسة تتم من لوحة الويب الآمنة بعد اكتمال تكامل الخادم.'),
      const SizedBox(height: 14),
      for (final entry in systemSettingCategories)
        SaiCard(
          padding: 6,
          child: ListTile(
            leading: const Icon(Icons.settings_outlined, color: darkRed),
            title: Text(entry),
            subtitle: const Text('يلزم ربط إعدادات الخادم المخصصة لهذه الوظيفة'),
          ),
        ),
    ],
  );
}
