import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/sai_theme.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import '../attendance/class_register_page.dart';
import 'class_form_sheet.dart';
import 'class_models.dart';
import 'class_roster_sheet.dart';
import 'student_transfer_page.dart';
import 'teacher_directory.dart';

/// Screen 1 of the mockup: the class list with seats, occupancy and status.
class ClassesSeatsPage extends StatefulWidget {
  const ClassesSeatsPage({
    super.key,
    required this.identity,
    required this.role,
    required this.onOpenImport,
    required this.onOpenParentLink,
  });

  final AppIdentity identity;
  final AppRole role;
  final VoidCallback onOpenImport;
  final VoidCallback onOpenParentLink;

  @override
  State<ClassesSeatsPage> createState() => _ClassesSeatsPageState();
}

class _ClassesSeatsPageState extends State<ClassesSeatsPage> {
  late Future<List<SaiClass>> _future;
  String _query = '';
  String _program = 'all';
  List<String> _knownPrograms = const [];

  bool get _canManageClasses =>
      widget.identity.roles.contains(AppRole.superAdmin) ||
      widget.identity.roles.contains(AppRole.admin);

  bool get _canMarkAttendance => const {
        AppRole.superAdmin,
        AppRole.admin,
        AppRole.teacher,
        AppRole.receptionist,
      }.any(widget.identity.roles.contains);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SaiClass>> _load() async {
    final client = Supabase.instance.client;
    final classRows = await client
        .from('classes')
        .select(
            'id,name,program,capacity,is_active,teacher_id,branch_id,session_id')
        .order('name', ascending: true);
    final studentRows = await client.from('students').select('class_id,status');

    final counts = <String, int>{};
    for (final row in studentRows as List) {
      final map = row as Map<String, dynamic>;
      if (map['status'] != 'active') continue;
      final classId = map['class_id'] as String?;
      if (classId == null) continue;
      counts[classId] = (counts[classId] ?? 0) + 1;
    }

    final teacherNames = await loadTeacherNames(client);
    final branchNames = await _nameMap(client, 'branches');
    final sessionNames = await _nameMap(client, 'academic_sessions');

    final rows = (classRows as List)
        .whereType<Map<String, dynamic>>()
        .map((row) => SaiClass.fromRow(
              row,
              enrolledByClass: counts,
              teacherNames: teacherNames,
              branchNames: branchNames,
              sessionNames: sessionNames,
            ))
        .toList();

    _knownPrograms = rows
        .map((row) => row.program)
        .where((program) => program != 'غير محدد')
        .toSet()
        .toList()
      ..sort();
    return rows;
  }

  Future<Map<String, String>> _nameMap(
      SupabaseClient client, String table) async {
    try {
      final rows = await client.from(table).select('id,name');
      return {
        for (final row in (rows as List).whereType<Map<String, dynamic>>())
          row['id'] as String: (row['name'] as String?) ?? ''
      };
    } catch (_) {
      return const {};
    }
  }

  void _retry() => setState(() => _future = _load());

  Future<void> _openForm({SaiClass? existing}) async {
    final saved = await ClassFormSheet.show(context,
        existing: existing, knownPrograms: _knownPrograms);
    if (saved == true && mounted) {
      _retry();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(existing == null
            ? 'تمت إضافة الصف بنجاح.'
            : 'تم تحديث بيانات الصف.'),
      ));
    }
  }

  void _openRegister(SaiClass row) {
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ClassRegisterPage(cls: row)));
  }

  void _openRoster(SaiClass row) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ClassRosterSheetPage(cls: row)));
  }

  Future<void> _openTransfer({SaiClass? source}) async {
    final moved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => StudentTransferPage(initialSourceId: source?.id)),
    );
    if (moved == true && mounted) _retry();
  }

  List<SaiClass> _filter(List<SaiClass> rows) {
    final query = _query.trim().toLowerCase();
    return rows.where((row) {
      final matchesProgram = _program == 'all' || row.program == _program;
      final matchesQuery = query.isEmpty ||
          row.name.toLowerCase().contains(query) ||
          row.program.toLowerCase().contains(query) ||
          (row.teacherName ?? '').toLowerCase().contains(query);
      return matchesProgram && matchesQuery;
    }).toList();
  }

  void _openSheet(SaiClass row) {
    final color = row.isFull
        ? SaiColors.danger
        : (row.isNearFull ? SaiColors.warning : SaiColors.success);
    final tint = row.isFull
        ? SaiColors.dangerTint
        : (row.isNearFull ? SaiColors.warningTint : SaiColors.successTint);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(row.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: SaiColors.ink))),
                TintChip(label: row.statusLabel, color: color, tint: tint),
              ],
            ),
            const SizedBox(height: 4),
            Text(row.program,
                style: const TextStyle(fontSize: 11.5, color: SaiColors.muted)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: SaiColors.cream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SaiColors.border),
              ),
              child: Column(
                children: [
                  _InfoLine(
                      icon: Icons.person_outline,
                      label: 'معلم الصف',
                      value: row.teacherName ?? 'غير مسند'),
                  _InfoLine(
                      icon: Icons.apartment_outlined,
                      label: 'الفرع',
                      value: row.branchName ?? '—'),
                  _InfoLine(
                      icon: Icons.calendar_month_outlined,
                      label: 'الفصل الدراسي',
                      value: row.sessionName ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: row.ratio,
                minHeight: 7,
                backgroundColor: SaiColors.creamDeep,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SheetStat(label: 'المسجلون', value: '${row.enrolled}'),
                _SheetStat(label: 'السعة', value: '${row.capacity}'),
                _SheetStat(label: 'المقاعد المتاحة', value: '${row.available}'),
                _SheetStat(label: 'نسبة الإشغال', value: '${row.percent}%'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openRoster(row);
                    },
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('كشف الصف'),
                  ),
                ),
                if (_canMarkAttendance) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _openRegister(row);
                      },
                      icon: const Icon(Icons.fact_check_outlined, size: 16),
                      label: const Text('الحضور'),
                    ),
                  ),
                ],
              ],
            ),
            if (_canManageClasses) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openTransfer(source: row);
                  },
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('نقل طلاب من هذا الصف'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openForm(existing: row);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('تعديل السعة والمعلم'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('إغلاق')),
            ),
          ],
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SaiClass>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingState();
        }
        if (snapshot.hasError) {
          return ErrorState(
            message:
                'تحقق من الاتصال وصلاحيات حسابك، ثم أعد المحاولة.\n${snapshot.error}',
            onRetry: _retry,
          );
        }
        final rows = snapshot.data ?? const <SaiClass>[];
        final programs = rows.map((row) => row.program).toSet().toList()
          ..sort();
        final filtered = _filter(rows);
        final totalSeats = rows.fold<int>(0, (sum, row) => sum + row.capacity);
        final totalEnrolled =
            rows.fold<int>(0, (sum, row) => sum + row.enrolled);

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            SectionHeader(
              icon: Icons.meeting_room_outlined,
              title: 'إدارة الصفوف والمقاعد',
              actionLabel: _canManageClasses ? 'إضافة صف' : 'استيراد',
              actionIcon:
                  _canManageClasses ? Icons.add : Icons.upload_file_outlined,
              onAction:
                  _canManageClasses ? () => _openForm() : widget.onOpenImport,
            ),
            const SizedBox(height: 10),
            _SummaryStrip(
                count: rows.length, enrolled: totalEnrolled, seats: totalSeats),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(
                      hintText: 'البحث عن صف أو برنامج...',
                      prefixIcon:
                          Icon(Icons.search, size: 18, color: SaiColors.muted),
                      prefixIconConstraints:
                          BoxConstraints(minWidth: 38, minHeight: 38),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SaiColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _program,
                      isDense: true,
                      icon: const Icon(Icons.expand_more,
                          size: 18, color: SaiColors.muted),
                      style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Cairo',
                          color: SaiColors.ink,
                          fontWeight: FontWeight.w600),
                      items: [
                        const DropdownMenuItem(
                            value: 'all', child: Text('جميع البرامج')),
                        ...programs.map((program) => DropdownMenuItem(
                              value: program,
                              child: Text(program,
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (value) =>
                          setState(() => _program = value ?? 'all'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              EmptyState(
                icon: Icons.meeting_room_outlined,
                title: 'لا توجد صفوف مسجلة',
                message: _canManageClasses
                    ? 'استخدم زر «إضافة صف» لإنشاء أول صف وتحديد السعة ومعلم الصف من الجوال.'
                    : 'لم تُسند إليك صفوف بعد. تواصل مع إدارة الكلية.',
              )
            else if (filtered.isEmpty)
              const EmptyState(
                icon: Icons.search_off,
                title: 'لا نتائج مطابقة',
                message: 'جرّب كلمة بحث أخرى أو اختر «جميع البرامج».',
              )
            else
              ...filtered.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _ClassCard(
                      row: row,
                      onTap: () => _openSheet(row),
                      onRoster: () => _openRoster(row),
                      onRegister:
                          _canMarkAttendance ? () => _openRegister(row) : null,
                      onEdit: _canManageClasses
                          ? () => _openForm(existing: row)
                          : null,
                    ),
                  )),
            const SizedBox(height: 6),
            _ToolsRow(
              onImport: widget.onOpenImport,
              onParentLink: widget.onOpenParentLink,
              onTransfer: _canManageClasses ? () => _openTransfer() : null,
            ),
          ],
        );
      },
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: SaiColors.muted),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(fontSize: 10.5, color: SaiColors.muted)),
          Expanded(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SaiColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.row,
    required this.onTap,
    required this.onRoster,
    required this.onRegister,
    required this.onEdit,
  });

  final SaiClass row;
  final VoidCallback onTap;
  final VoidCallback onRoster;
  final VoidCallback? onRegister;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final color = row.isFull
        ? SaiColors.danger
        : (row.isNearFull ? SaiColors.warning : SaiColors.success);
    final tint = row.isFull
        ? SaiColors.dangerTint
        : (row.isNearFull ? SaiColors.warningTint : SaiColors.successTint);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaiColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 11, 9, 10),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TintChip(
                          label: row.statusLabel, color: color, tint: tint),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: SaiColors.ink)),
                            const SizedBox(height: 1),
                            Text(row.program,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10, color: SaiColors.muted)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 11, color: SaiColors.muted),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(row.teacherName ?? 'بدون معلم',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 9.5,
                                          color: SaiColors.muted)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text('${row.enrolled} / ${row.capacity}',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: SaiColors.ink)),
                              const SizedBox(width: 4),
                              const Icon(Icons.people_alt_outlined,
                                  size: 15, color: SaiColors.ink),
                            ],
                          ),
                          const Text('المسجلون / السعة',
                              style: TextStyle(
                                  fontSize: 8.5, color: SaiColors.muted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text('${row.percent}%',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: row.ratio,
                            minHeight: 5,
                            backgroundColor: SaiColors.creamDeep,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: SaiColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: Row(
              children: [
                Expanded(
                    child: _CardAction(
                        icon: Icons.description_outlined,
                        label: 'كشف الصف',
                        onTap: onRoster)),
                Expanded(
                  child: _CardAction(
                    icon: Icons.fact_check_outlined,
                    label: 'الحضور',
                    onTap: onRegister,
                  ),
                ),
                Expanded(
                  child: _CardAction(
                    icon: Icons.edit_outlined,
                    label: 'تعديل',
                    onTap: onEdit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: SaiColors.maroon),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: SaiColors.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip(
      {required this.count, required this.enrolled, required this.seats});

  final int count;
  final int enrolled;
  final int seats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SaiColors.goldTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaiColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          _MiniStat(label: 'الصفوف', value: '$count'),
          _divider(),
          _MiniStat(label: 'الطلاب النشطون', value: '$enrolled'),
          _divider(),
          _MiniStat(label: 'إجمالي المقاعد', value: '$seats'),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 22, color: SaiColors.gold.withValues(alpha: 0.3));
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SaiColors.ink)),
          Text(label,
              style: const TextStyle(fontSize: 9, color: SaiColors.muted)),
        ],
      ),
    );
  }
}

class _ToolsRow extends StatelessWidget {
  const _ToolsRow({required this.onImport, required this.onParentLink, this.onTransfer});

  final VoidCallback onImport;
  final VoidCallback onParentLink;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ToolButton(
                icon: Icons.upload_file_outlined,
                label: 'استيراد الطلاب',
                onTap: onImport,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _ToolButton(icon: Icons.link, label: 'ربط ولي الأمر', onTap: onParentLink)),
          ],
        ),
        if (onTransfer != null) ...[
          const SizedBox(height: 8),
          _ToolButton(icon: Icons.swap_horiz, label: 'نقل طلاب بين الصفوف', onTap: onTransfer!),
        ],
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SaiColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: SaiColors.maroon),
            const SizedBox(width: 7),
            Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SaiColors.ink))),
          ],
        ),
      ),
    );
  }
}

class _SheetStat extends StatelessWidget {
  const _SheetStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SaiColors.ink)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: SaiColors.muted)),
        ],
      ),
    );
  }
}
