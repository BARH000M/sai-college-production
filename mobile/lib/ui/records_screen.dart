import 'package:flutter/material.dart';

import '../core/access.dart';
import '../data/demo_school.dart';
import '../data/demo_workspace.dart';
import 'components.dart';
import 'printing.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({
    super.key,
    required this.page,
    required this.title,
    required this.icon,
    required this.roles,
    required this.demo,
  });
  final PageId page;
  final String title;
  final IconData icon;
  final Set<Role> roles;
  final DemoWorkspace demo;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String query = '';
  String? filter;

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final demo = widget.demo;
    final all = DemoSchool.records(page, widget.roles, demo);
    final statuses = all
        .map((row) => DemoSchool.status(demo, page, row))
        .toSet();
    final chosen = statuses.contains(filter) ? filter : null;
    final filtered = all
        .where(
          (row) =>
              (chosen == null ||
                  DemoSchool.status(demo, page, row) == chosen) &&
              '${row.id} ${row.title} ${row.summary}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        SectionHeading(
          '${widget.title} (${filtered.length})',
          action: filtered.isEmpty
              ? null
              : PrintAction(
                  CollegeReport(
                    title: widget.title,
                    preview: true,
                    signature: [
                      PageId.finance,
                      PageId.admissions,
                      PageId.exams,
                    ].contains(page),
                    columns: const [
                      PrintColumn('السجل', flex: 2),
                      PrintColumn('التفاصيل', flex: 4),
                      PrintColumn('الحالة', flex: 1.6),
                    ],
                    rows: [
                      for (final row in filtered)
                        [
                          row.title,
                          '${row.summary}\n${row.fields.map((item) => '${item.label}  ${item.value}').join('\n')}',
                          DemoSchool.status(demo, page, row),
                        ],
                    ],
                  ),
                ),
        ),
        TextField(
          onChanged: (value) => setState(() => query = value.trim()),
          decoration: const InputDecoration(
            hintText: 'ابحث في السجلات',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        if (statuses.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: const Text('الكل'),
                selected: chosen == null,
                onSelected: (_) => setState(() => filter = null),
              ),
              for (final status in statuses)
                ChoiceChip(
                  label: Text(status),
                  selected: chosen == status,
                  onSelected: (_) => setState(() => filter = status),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (filtered.isEmpty) const EmptyPanel('لا توجد نتائج مطابقة.'),
        for (final row in filtered)
          Tile(
            row.title,
            widget.icon,
            subtitle: '${row.summary}\n${DemoSchool.status(demo, page, row)}',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _RecordDetail(
                  row: row,
                  page: page,
                  heading: widget.title,
                  roles: widget.roles,
                  demo: demo,
                  icon: widget.icon,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordDetail extends StatefulWidget {
  const _RecordDetail({
    required this.row,
    required this.page,
    required this.heading,
    required this.roles,
    required this.demo,
    required this.icon,
  });
  final CollegeEntry row;
  final PageId page;
  final String heading;
  final Set<Role> roles;
  final DemoWorkspace demo;
  final IconData icon;

  @override
  State<_RecordDetail> createState() => _RecordDetailState();
}

class _RecordDetailState extends State<_RecordDetail> {
  bool saving = false;

  Future<void> apply(DemoAction action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (_) =>
            _ActionDialog(action: action, grade: widget.page == PageId.exams),
      );
      if (result == null || !mounted) return;
      final status = widget.page == PageId.exams
          ? '${int.parse(result)} / 100'
          : action.status;
      await DemoSchool.update(
        widget.demo,
        widget.page,
        widget.row,
        status,
        note: widget.page == PageId.assignments && action.input != null
            ? result
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حُفظ التغيير التجريبي على هذا الجهاز.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ التغيير. أعد المحاولة.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.demo,
    builder: (context, _) {
      final row = widget.row;
      final status = DemoSchool.status(widget.demo, widget.page, row);
      final answer = DemoSchool.detail(widget.demo, widget.page, row);
      final action = DemoSchool.action(widget.page, widget.roles, status);
      final fields = [
        field('السجل', row.title),
        field('الوصف', row.summary),
        ...row.fields,
        field('الحالة', status),
        if (answer.isNotEmpty) field('إجابة الطالب', answer),
      ];
      final title = widget.page == PageId.finance && status == DemoSchool.paid
          ? 'إيصال سداد'
          : widget.heading;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: darkRed,
          foregroundColor: Colors.white,
          title: Text(widget.heading),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionHeading(
              row.title,
              action: PrintAction(
                CollegeReport(
                  title: title,
                  subtitle: row.id,
                  preview: true,
                  columns: const [
                    PrintColumn('البيان', flex: 1.4),
                    PrintColumn('التفاصيل', flex: 3),
                  ],
                  rows: [
                    for (final item in fields) [item.label, item.value],
                  ],
                  signature: widget.page == PageId.finance,
                ),
              ),
            ),
            Tile(status, widget.icon, subtitle: 'بيانات توضيحية'),
            SaiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in fields.skip(1)) ...[
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: gold,
                      ),
                    ),
                    Text(
                      item.value,
                      style: const TextStyle(fontFamilyFallback: ['NotoSC']),
                    ),
                    const Divider(),
                  ],
                ],
              ),
            ),
            if (action != null)
              RedButton(
                action.label,
                icon: Icons.check,
                onPressed: saving ? null : () => apply(action),
              ),
          ],
        ),
      );
    },
  );
}

class _ActionDialog extends StatefulWidget {
  const _ActionDialog({required this.action, required this.grade});
  final DemoAction action;
  final bool grade;

  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.action.label),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('سيُحفظ هذا الإجراء في بيانات المعاينة على جهازك.'),
            if (widget.action.input != null) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                maxLines: widget.grade ? 1 : 4,
                maxLength: widget.grade ? 3 : 220,
                keyboardType: widget.grade
                    ? TextInputType.number
                    : TextInputType.multiline,
                decoration: InputDecoration(labelText: widget.action.input),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'هذا الحقل مطلوب.';
                  }
                  if (widget.grade) {
                    final normalized = _normalizeDigits(value.trim());
                    final number = int.tryParse(normalized);
                    if (number == null || number < 0 || number > 100) {
                      return 'أدخل درجة بين 0 و100.';
                    }
                  }
                  return null;
                },
              ),
            ],
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
        onPressed: () {
          if (!form.currentState!.validate()) return;
          final value = controller.text.trim();
          Navigator.pop(
            context,
            widget.grade ? _normalizeDigits(value) : value,
          );
        },
        child: const Text('تأكيد'),
      ),
    ],
  );
}

String _normalizeDigits(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  return value;
}
