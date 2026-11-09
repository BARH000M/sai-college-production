import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sai_theme.dart';
import '../../widgets/sai_app_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';

enum _RowState { ready, duplicate, error }

class _ImportRow {
  _ImportRow({required this.line, required this.name, required this.admissionNo, required this.className, required this.state, required this.note});

  final int line;
  final String name;
  final String admissionNo;
  final String className;
  final _RowState state;
  final String note;
}

class _ImportSource {
  const _ImportSource({required this.classIds, required this.existingNumbers});

  final Map<String, String> classIds;
  final Set<String> existingNumbers;
}

/// Screen 3 of the mockup: bulk student import with a validation preview
/// before anything is written to the database.
class StudentImportPage extends StatefulWidget {
  const StudentImportPage({super.key});

  @override
  State<StudentImportPage> createState() => _StudentImportPageState();
}

class _StudentImportPageState extends State<StudentImportPage> {
  static const _sample = 'أحمد محمد عبدالله | STU000125 | HSK 1\nسارة علي حسين | STU000126 | HSK 2';

  final _controller = TextEditingController();
  late Future<_ImportSource> _source;
  List<_ImportRow> _rows = const [];
  int _step = 0;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _source = _loadSource();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<_ImportSource> _loadSource() async {
    final client = Supabase.instance.client;
    final classRows = await client.from('classes').select('id,name');
    final classIds = <String, String>{};
    for (final row in classRows as List) {
      final map = row as Map<String, dynamic>;
      final name = (map['name'] as String?)?.trim().toLowerCase();
      if (name != null && name.isNotEmpty) classIds[name] = map['id'] as String;
    }
    final studentRows = await client.from('students').select('admission_no');
    final existing = <String>{};
    for (final row in studentRows as List) {
      final value = (row as Map<String, dynamic>)['admission_no'];
      if (value is String && value.trim().isNotEmpty) existing.add(value.trim().toLowerCase());
    }
    return _ImportSource(classIds: classIds, existingNumbers: existing);
  }

  int get _readyCount => _rows.where((row) => row.state == _RowState.ready).length;
  int get _duplicateCount => _rows.where((row) => row.state == _RowState.duplicate).length;
  int get _errorCount => _rows.where((row) => row.state == _RowState.error).length;

  void _preview(_ImportSource source) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _message = 'الصق أسطر الطلاب أولًا (الاسم | رقم القيد | الصف).';
        _messageIsError = true;
        _rows = const [];
        _step = 0;
      });
      return;
    }

    final parsed = <_ImportRow>[];
    final seen = <String>{};
    final lines = text.split(RegExp(r'\r?\n'));
    var lineNumber = 0;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      lineNumber++;
      final parts = line.split(RegExp(r'[|\t;,]+')).map((part) => part.trim()).toList();
      final name = parts.isNotEmpty ? parts[0] : '';
      final admissionNo = parts.length > 1 ? parts[1] : '';
      final className = parts.length > 2 ? parts[2] : '';

      if (name.isEmpty) {
        parsed.add(_ImportRow(line: lineNumber, name: '—', admissionNo: admissionNo, className: className, state: _RowState.error, note: 'اسم الطالب مفقود'));
        continue;
      }
      if (admissionNo.isEmpty) {
        parsed.add(_ImportRow(line: lineNumber, name: name, admissionNo: '—', className: className, state: _RowState.error, note: 'رقم القيد مفقود'));
        continue;
      }
      if (className.isEmpty || !source.classIds.containsKey(className.toLowerCase())) {
        parsed.add(_ImportRow(line: lineNumber, name: name, admissionNo: admissionNo, className: className.isEmpty ? '—' : className, state: _RowState.error, note: 'الصف غير معروف في النظام'));
        continue;
      }
      final key = admissionNo.toLowerCase();
      if (source.existingNumbers.contains(key) || seen.contains(key)) {
        seen.add(key);
        parsed.add(_ImportRow(line: lineNumber, name: name, admissionNo: admissionNo, className: className, state: _RowState.duplicate, note: 'موجود مسبقًا — سيُستبعد'));
        continue;
      }
      seen.add(key);
      parsed.add(_ImportRow(line: lineNumber, name: name, admissionNo: admissionNo, className: className, state: _RowState.ready, note: 'جاهز للاستيراد'));
    }

    setState(() {
      _rows = parsed;
      _step = parsed.isEmpty ? 0 : 1;
      _message = parsed.isEmpty ? 'لم يتم العثور على أسطر صالحة للمعاينة.' : null;
      _messageIsError = parsed.isEmpty;
    });
  }

  Future<void> _confirm() async {
    final ready = _rows.where((row) => row.state == _RowState.ready).toList();
    if (ready.isEmpty) {
      setState(() {
        _message = 'لا توجد أسطر جاهزة للاستيراد. راجع الأخطاء والمكرار أولًا.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final source = await _source;
      final client = Supabase.instance.client;
      final payload = ready
          .map((row) => {
                'full_name': row.name,
                'admission_no': row.admissionNo,
                'class_id': source.classIds[row.className.toLowerCase()],
                'status': 'active',
              })
          .toList();
      await client.from('students').insert(payload);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = 2;
        _rows = const [];
        _controller.clear();
        _message = 'تم استيراد ${payload.length} طالبًا بنجاح.';
        _messageIsError = false;
      });
      _source = _loadSource();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'تعذّر الاستيراد: ${error is PostgrestException ? error.message : error}';
        _messageIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: saiAppBar(
        context,
        showBack: true,
        onMenu: () {},
        showBell: false,
        title: 'استيراد الطلاب',
      ),
      body: FutureBuilder<_ImportSource>(
        future: _source,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const LoadingState();
          if (snapshot.hasError) {
            return ErrorState(
              message: '${snapshot.error}',
              onRetry: () => setState(() => _source = _loadSource()),
            );
          }
          final source = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
            children: [
              const SectionHeader(icon: Icons.upload_file_outlined, title: 'استيراد الطلاب ومعالجة البيانات'),
              const SizedBox(height: 12),
              _StepBar(step: _step),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SaiColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بيانات الطلاب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                    const SizedBox(height: 2),
                    const Text('كل سطر: الاسم | رقم القيد | الصف', style: TextStyle(fontSize: 10, color: SaiColors.muted)),
                    const SizedBox(height: 9),
                    TextField(
                      controller: _controller,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 12, height: 1.8),
                      decoration: const InputDecoration(
                        hintText: _sample,
                        hintStyle: TextStyle(fontSize: 11.5, color: SaiColors.muted, height: 1.8),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _controller.text = _sample,
                            icon: const Icon(Icons.content_paste_outlined, size: 16),
                            label: const Text('نموذج'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: () => _preview(source),
                            icon: const Icon(Icons.manage_search, size: 17),
                            label: const Text('معاينة البيانات'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _CountTile(label: 'أخطاء', value: '$_errorCount', color: SaiColors.danger, tint: SaiColors.dangerTint, icon: Icons.error_outline)),
                    const SizedBox(width: 7),
                    Expanded(child: _CountTile(label: 'مكررة', value: '$_duplicateCount', color: SaiColors.warning, tint: SaiColors.warningTint, icon: Icons.copy_all_outlined)),
                    const SizedBox(width: 7),
                    Expanded(child: _CountTile(label: 'جاهزة', value: '$_readyCount', color: SaiColors.success, tint: SaiColors.successTint, icon: Icons.check_circle_outline)),
                    const SizedBox(width: 7),
                    Expanded(child: _CountTile(label: 'الإجمالي', value: '${_rows.length}', color: SaiColors.maroon, tint: SaiColors.maroonTint, icon: Icons.list_alt_outlined)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SaiColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: const BoxDecoration(
                          color: SaiColors.creamDeep,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 24, child: Text('#', style: _headStyle)),
                            Expanded(flex: 4, child: Text('اسم الطالب', style: _headStyle)),
                            Expanded(flex: 3, child: Text('الصف', style: _headStyle)),
                            Expanded(flex: 3, child: Text('الحالة', style: _headStyle)),
                          ],
                        ),
                      ),
                      ..._rows.take(40).map((row) => _PreviewRow(row: row)),
                      if (_rows.length > 40)
                        Padding(
                          padding: const EdgeInsets.all(9),
                          child: Text('+ ${_rows.length - 40} سطرًا إضافيًا في المعاينة', style: const TextStyle(fontSize: 10, color: SaiColors.muted)),
                        ),
                    ],
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                NoteBanner(
                  message: _message!,
                  icon: _messageIsError ? Icons.error_outline : Icons.check_circle_outline,
                  color: _messageIsError ? SaiColors.danger : SaiColors.success,
                  tint: _messageIsError ? SaiColors.dangerTint : SaiColors.successTint,
                ),
              ],
              const SizedBox(height: 12),
              const NoteBanner(
                icon: Icons.info_outline,
                color: SaiColors.warning,
                tint: SaiColors.warningTint,
                message: 'تُستبعد الأسطر المكررة والأسطر التي تحتوي أخطاء تلقائيًا، ولا يتم تعديل أي سجل موجود.',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy || _readyCount == 0 ? null : _confirm,
                icon: _busy
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_alt, size: 17),
                label: Text(_busy ? 'جارٍ الاستيراد...' : 'تأكيد الاستيراد ($_readyCount)'),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _headStyle = TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: SaiColors.ink);

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final int step;

  static const _labels = ['رفع البيانات', 'معاينة', 'تأكيد الاستيراد'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (index) {
        final active = index <= step;
        final done = index < step;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? SaiColors.maroon : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? SaiColors.maroon : SaiColors.border, width: 1.5),
                ),
                child: done
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : Text('${index + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? Colors.white : SaiColors.muted)),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  _labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: active ? SaiColors.ink : SaiColors.muted),
                ),
              ),
              if (index < _labels.length - 1)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(height: 1.5, color: index < step ? SaiColors.maroon : SaiColors.border),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.value, required this.color, required this.tint, required this.icon});

  final String label;
  final String value;
  final Color color;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.row});

  final _ImportRow row;

  @override
  Widget build(BuildContext context) {
    final (color, tint, label) = switch (row.state) {
      _RowState.ready => (SaiColors.success, SaiColors.successTint, 'جاهز'),
      _RowState.duplicate => (SaiColors.warning, SaiColors.warningTint, 'مكرر'),
      _RowState.error => (SaiColors.danger, SaiColors.dangerTint, 'خطأ'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SaiColors.border, width: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Text('${row.line}', style: const TextStyle(fontSize: 9.5, color: SaiColors.muted))),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                Text(row.admissionNo, style: const TextStyle(fontSize: 8.5, color: SaiColors.muted)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(row.className, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: SaiColors.ink)),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TintChip(label: label, color: color, tint: tint),
                ),
                const SizedBox(height: 2),
                Text(row.note, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: SaiColors.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}