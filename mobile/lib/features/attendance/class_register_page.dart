import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sai_theme.dart';
import '../../widgets/state_views.dart';
import '../academics/class_models.dart';

const _statuses = <String, String>{
  'present': 'حاضر',
  'absent': 'غائب',
  'late': 'متأخر',
  'excused': 'بعذر',
};

String _two(int value) => value.toString().padLeft(2, '0');
String _dateKey(DateTime value) => '${value.year}-${_two(value.month)}-${_two(value.day)}';
String _arabicDate(DateTime value) {
  const weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  return '${weekdays[value.weekday - 1]} ${value.day}/${value.month}/${value.year}';
}

class _RegisterRow {
  _RegisterRow({required this.studentId, required this.fullName, this.status, this.note});

  final String studentId;
  final String fullName;
  String? status;
  String? note;

  String get label => status == null ? 'لم يُسجَّل' : (_statuses[status] ?? status!);
}

/// Mobile attendance register: marks a whole class with one tap and saves the
/// whole roster in one action.
class ClassRegisterPage extends StatefulWidget {
  const ClassRegisterPage({super.key, required this.cls});

  final SaiClass cls;

  @override
  State<ClassRegisterPage> createState() => _ClassRegisterPageState();
}

class _ClassRegisterPageState extends State<ClassRegisterPage> {
  late DateTime _date = DateTime.now();
  late final List<DateTime> _days = List<DateTime>.generate(
    10,
    (index) => DateTime.now().subtract(Duration(days: index)),
  );

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _sessionError;
  String? _sessionId;
  String _sessionStatus = 'open';
  List<_RegisterRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _ensureSession(SupabaseClient client) async {
    if (_sessionId != null) return _sessionId;
    final key = _dateKey(_date);
    try {
      final existing = await client
          .from('attendance_sessions')
          .select('id,status')
          .eq('class_id', widget.cls.id)
          .eq('attendance_date', key)
          .maybeSingle();
      if (existing != null) {
        _sessionId = existing['id'] as String;
        _sessionStatus = (existing['status'] as String?) ?? 'open';
        return _sessionId;
      }
      final created = await client
          .from('attendance_sessions')
          .insert({
            'branch_id': widget.cls.branchId,
            'academic_session_id': widget.cls.sessionId,
            'class_id': widget.cls.id,
            'attendance_date': key,
          })
          .select('id,status')
          .single();
      _sessionId = created['id'] as String;
      _sessionStatus = (created['status'] as String?) ?? 'open';
      return _sessionId;
    } catch (error) {
      final message = error.toString();
      if (message.toLowerCase().contains('duplicate')) {
        final retry = await client
            .from('attendance_sessions')
            .select('id,status')
            .eq('class_id', widget.cls.id)
            .eq('attendance_date', key)
            .maybeSingle();
        if (retry != null) {
          _sessionId = retry['id'] as String;
          _sessionStatus = (retry['status'] as String?) ?? 'open';
          return _sessionId;
        }
      }
      rethrow;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sessionError = null;
      _sessionId = null;
      _sessionStatus = 'open';
    });

    final client = Supabase.instance.client;
    try {
      try {
        await _ensureSession(client);
      } catch (sessionFailure) {
        _sessionError = sessionFailure.toString();
      }

      final roster = _sessionId == null
          ? null
          : await client.rpc('sai_attendance_roster', params: {'wanted_session': _sessionId});
      final students = _sessionId != null
          ? const []
          : await client
              .from('students')
              .select('id,full_name')
              .eq('class_id', widget.cls.id)
              .eq('status', 'active')
              .order('full_name', ascending: true);

      final List<_RegisterRow> rows;
      if (roster != null) {
        rows = (roster as List).whereType<Map<String, dynamic>>().map((row) {
          final name = (row['full_name'] as String?)?.trim() ?? '';
          return _RegisterRow(
            studentId: row['student_id'] as String,
            fullName: name.isEmpty ? 'طالب' : name,
            status: row['attendance_status'] as String?,
            note: row['note'] as String?,
          );
        }).toList();
      } else {
        rows = (students as List).whereType<Map<String, dynamic>>().map((row) {
          final name = (row['full_name'] as String?)?.trim() ?? '';
          return _RegisterRow(
            studentId: row['id'] as String,
            fullName: name.isEmpty ? 'طالب' : name,
          );
        }).toList();
      }

      if (_sessionId != null) {
        final records = await client
            .from('attendance_records')
            .select('student_id,status,note')
            .eq('attendance_session_id', _sessionId!);
        final byStudent = <String, Map<String, dynamic>>{};
        for (final record in (records as List).whereType<Map<String, dynamic>>()) {
          byStudent[record['student_id'] as String] = record;
        }
        for (final row in rows) {
          final record = byStudent[row.studentId];
          if (record != null) {
            row.status = record['status'] as String?;
            row.note = record['note'] as String?;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل سجل الحضور. تحقق من صلاحيتك على هذا الصف.\n$error';
      });
    }
  }

  void _markAll(String? status) {
    if (_sessionStatus != 'open') return;
    setState(() {
      for (final row in _rows) {
        row.status = status;
        if (status == null) row.note = null;
      }
    });
  }

  int get _markedCount => _rows.where((row) => row.status != null).length;
  int _count(String status) => _rows.where((row) => row.status == status).length;

  Future<void> _saveAll() async {
    if (_rows.isEmpty) return;
    if (_markedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم تحدد حالة أي طالب بعد.')));
      return;
    }
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    var saved = 0;
    final failures = <String>[];

    try {
      final sessionId = await _ensureSession(client);
      if (sessionId == null) throw Exception('تعذّر فتح جلسة حضور لهذا اليوم.');

      for (final row in _rows.where((row) => row.status != null)) {
        try {
          await client.from('attendance_records').upsert({
            'attendance_session_id': sessionId,
            'student_id': row.studentId,
            'status': row.status,
            'note': (row.note ?? '').trim().isEmpty ? null : row.note!.trim(),
          }, onConflict: 'attendance_session_id,student_id');
          saved += 1;
        } catch (error) {
          failures.add('${row.fullName}: $error');
        }
      }

      if (!mounted) return;
      setState(() => _saving = false);
      final message = failures.isEmpty
          ? 'تم حفظ $saved سجلاً لصف ${widget.cls.name}.'
          : 'حُفظ $saved سجلاً، وتعذّر حفظ ${failures.length}. أول سبب: ${failures.first}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: failures.isEmpty ? SaiColors.success : SaiColors.danger,
      ));
      if (failures.isEmpty) await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تعذّر حفظ السجل: $error'),
        backgroundColor: SaiColors.danger,
      ));
    }
  }

  Future<void> _closeSession() async {
    final id = _sessionId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إغلاق جلسة الحضور', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: const Text('بعد الإغلاق يصبح سجل اليوم للقراءة فقط ولا يمكن تعديله من التطبيق.',
            style: TextStyle(fontSize: 12, height: 1.7)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('إغلاق الجلسة')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.from('attendance_sessions').update({'status': 'closed'}).eq('id', id);
      if (!mounted) return;
      setState(() => _sessionStatus = 'closed');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إغلاق جلسة الحضور.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر إغلاق الجلسة: $error'), backgroundColor: SaiColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _sessionStatus != 'open' || _sessionId == null;
    return Scaffold(
      backgroundColor: SaiColors.cream,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.cls.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SaiColors.ink)),
            Text(_arabicDate(_date), style: const TextStyle(fontSize: 10, color: SaiColors.muted)),
          ],
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_forward, size: 20, color: SaiColors.ink),
        ),
      ),
      body: Column(
        children: [
          _DateStrip(
            days: _days,
            selected: _date,
            onSelect: (day) {
              setState(() => _date = day);
              _load();
            },
          ),
          if (_sessionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: NoteBanner(
                message: 'تعذّر فتح جلسة حضور لهذا اليوم: $_sessionError\nيمكنك الاطلاع على القائمة فقط. يفتح الجلسة معلم الصف أو الإدارة.',
                color: SaiColors.danger,
                tint: SaiColors.dangerTint,
                icon: Icons.info_outline,
              ),
            )
          else if (locked)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: NoteBanner(
                message: 'جلسة هذا اليوم مغلقة. يمكنك الاطلاع على السجل فقط؛ لتصحيح الحضور راجع إدارة الكلية.',
                color: SaiColors.warning,
                tint: SaiColors.warningTint,
                icon: Icons.lock_outline,
              ),
            ),
          Expanded(
            child: _loading
                ? const LoadingState()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _rows.isEmpty
                        ? const EmptyState(
                            icon: Icons.people_outline,
                            title: 'لا يوجد طلاب في هذا الصف',
                            message: 'أضف الطلاب إلى الصف من شاشة الاستيراد أو من سجل الطالب ثم عد لتسجيل الحضور.',
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                            children: [
                              _SummaryBar(
                                total: _rows.length,
                                present: _count('present'),
                                absent: _count('absent'),
                                late: _count('late'),
                                excused: _count('excused'),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _BulkButton(
                                      label: 'الكل حاضر',
                                      icon: Icons.done_all,
                                      enabled: !locked,
                                      onTap: () => _markAll('present'),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: _BulkButton(
                                      label: 'الكل غائب',
                                      icon: Icons.person_off_outlined,
                                      enabled: !locked,
                                      danger: true,
                                      onTap: () => _markAll('absent'),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: _BulkButton(
                                      label: 'مسح',
                                      icon: Icons.layers_clear_outlined,
                                      enabled: !locked,
                                      onTap: () => _markAll(null),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._rows.map((row) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _StudentRow(
                                      row: row,
                                      locked: locked,
                                      onChanged: (status) => setState(() => row.status = status),
                                      onNote: () => _editNote(row),
                                    ),
                                  )),
                              const SizedBox(height: 4),
                              if (!locked)
                                TextButton.icon(
                                  onPressed: _closeSession,
                                  icon: const Icon(Icons.lock_outline, size: 16),
                                  label: const Text('إغلاق جلسة اليوم'),
                                ),
                            ],
                          ),
          ),
        ],
      ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: SaiColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: FilledButton.icon(
                  onPressed: _saving || locked || _rows.isEmpty ? null : _saveAll,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الكل ($_markedCount)'),
                ),
              ),
            ),
    );
  }

  Future<void> _editNote(_RegisterRow row) async {
    final controller = TextEditingController(text: row.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ملاحظة — ${row.fullName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 200,
          style: const TextStyle(fontSize: 12.5),
          decoration: const InputDecoration(hintText: 'سبب الغياب أو ملاحظة المعلم (اختياري)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (result != null) setState(() => row.note = result);
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.days, required this.selected, required this.onSelect});

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final day = days[index];
          final active = _dateKey(day) == _dateKey(selected);
          return InkWell(
            onTap: () => onSelect(day),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active ? SaiColors.maroon : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? SaiColors.maroon : SaiColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(index == 0 ? 'اليوم' : (index == 1 ? 'أمس' : _two(day.day)),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : SaiColors.ink)),
                  const SizedBox(height: 2),
                  Text('${_two(day.day)}/${_two(day.month)}',
                      style: TextStyle(fontSize: 9, color: active ? Colors.white70 : SaiColors.muted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
  });

  final int total;
  final int present;
  final int absent;
  final int late;
  final int excused;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: SaiColors.goldTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaiColors.gold.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          _cell('$total', 'الطلاب', SaiColors.ink),
          _cell('$present', 'حاضر', SaiColors.success),
          _cell('$absent', 'غائب', SaiColors.danger),
          _cell('$late', 'متأخر', SaiColors.warning),
          _cell('$excused', 'بعذر', SaiColors.muted),
        ],
      ),
    );
  }

  Widget _cell(String value, String label, Color color) => Expanded(
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: const TextStyle(fontSize: 9, color: SaiColors.muted)),
          ],
        ),
      );
}

class _BulkButton extends StatelessWidget {
  const _BulkButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? SaiColors.danger : SaiColors.maroon;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(11),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          decoration: BoxDecoration(
            color: danger ? SaiColors.dangerTint : SaiColors.maroonTint,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.row,
    required this.locked,
    required this.onChanged,
    required this.onNote,
  });

  final _RegisterRow row;
  final bool locked;
  final ValueChanged<String?> onChanged;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: SaiColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: SaiColors.creamDeep, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.person_outline, size: 16, color: SaiColors.maroon),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                    Text(
                      row.note == null || row.note!.isEmpty ? row.label : '${row.label} · ${row.note}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9.5, color: SaiColors.muted),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: locked ? null : onNote,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(Icons.sticky_note_2_outlined, size: 16, color: SaiColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: _statuses.entries
                .map((entry) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _StatusPill(
                          label: entry.value,
                          active: row.status == entry.key,
                          locked: locked,
                          color: switch (entry.key) {
                            'present' => SaiColors.success,
                            'absent' => SaiColors.danger,
                            'late' => SaiColors.warning,
                            _ => SaiColors.muted,
                          },
                          onTap: () => onChanged(row.status == entry.key ? null : entry.key),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.active,
    required this.locked,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool locked;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? color : SaiColors.border),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? Colors.white : SaiColors.muted),
        ),
      ),
    );
  }
}