import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/sai_theme.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';

class _ClassRow {
  const _ClassRow({
    required this.id,
    required this.name,
    required this.program,
    required this.capacity,
    required this.enrolled,
    required this.isActive,
  });

  final String id;
  final String name;
  final String program;
  final int capacity;
  final int enrolled;
  final bool isActive;

  double get ratio => capacity <= 0 ? 0 : (enrolled / capacity).clamp(0, 1).toDouble();
  int get percent => (ratio * 100).round();
  bool get isFull => capacity > 0 && enrolled >= capacity;
  bool get isNearFull => !isFull && capacity > 0 && ratio >= 0.8;
  int get available => capacity - enrolled > 0 ? capacity - enrolled : 0;
}

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
  late Future<List<_ClassRow>> _future;
  String _query = '';
  String _program = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_ClassRow>> _load() async {
    final client = Supabase.instance.client;
    final classRows = await client
        .from('classes')
        .select('id,name,program,capacity,is_active')
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

    return (classRows as List).map((row) {
      final map = row as Map<String, dynamic>;
      final id = map['id'] as String;
      return _ClassRow(
        id: id,
        name: (map['name'] as String?)?.trim().isNotEmpty == true ? (map['name'] as String).trim() : 'صف بدون اسم',
        program: (map['program'] as String?)?.trim().isNotEmpty == true ? (map['program'] as String).trim() : 'غير محدد',
        capacity: (map['capacity'] as num?)?.toInt() ?? 0,
        enrolled: counts[id] ?? 0,
        isActive: map['is_active'] != false,
      );
    }).toList();
  }

  void _retry() => setState(() => _future = _load());

  List<_ClassRow> _filter(List<_ClassRow> rows) {
    final query = _query.trim().toLowerCase();
    return rows.where((row) {
      final matchesProgram = _program == 'all' || row.program == _program;
      final matchesQuery = query.isEmpty ||
          row.name.toLowerCase().contains(query) ||
          row.program.toLowerCase().contains(query);
      return matchesProgram && matchesQuery;
    }).toList();
  }

  void _openSheet(_ClassRow row) {
    final color = row.isFull ? SaiColors.danger : (row.isNearFull ? SaiColors.warning : SaiColors.success);
    final tint = row.isFull ? SaiColors.dangerTint : (row.isNearFull ? SaiColors.warningTint : SaiColors.successTint);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(row.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SaiColors.ink))),
                TintChip(
                  label: row.isFull ? 'ممتلئ' : (row.isNearFull ? 'قريب من الامتلاء' : 'متاح'),
                  color: color,
                  tint: tint,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(row.program, style: const TextStyle(fontSize: 11.5, color: SaiColors.muted)),
            const SizedBox(height: 16),
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
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('إغلاق')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_ClassRow>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingState();
        if (snapshot.hasError) {
          return ErrorState(
            message: 'تحقق من الاتصال وصلاحيات حسابك، ثم أعد المحاولة.\n${snapshot.error}',
            onRetry: _retry,
          );
        }
        final rows = snapshot.data ?? const <_ClassRow>[];
        final programs = rows.map((row) => row.program).toSet().toList()..sort();
        final filtered = _filter(rows);
        final totalSeats = rows.fold<int>(0, (sum, row) => sum + row.capacity);
        final totalEnrolled = rows.fold<int>(0, (sum, row) => sum + row.enrolled);

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            SectionHeader(
              icon: Icons.meeting_room_outlined,
              title: 'إدارة الصفوف والمقاعد',
              actionLabel: 'استيراد',
              actionIcon: Icons.upload_file_outlined,
              onAction: widget.onOpenImport,
            ),
            const SizedBox(height: 10),
            _SummaryStrip(count: rows.length, enrolled: totalEnrolled, seats: totalSeats),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: const InputDecoration(
                      hintText: 'البحث عن صف أو برنامج...',
                      prefixIcon: Icon(Icons.search, size: 18, color: SaiColors.muted),
                      prefixIconConstraints: BoxConstraints(minWidth: 38, minHeight: 38),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 42,
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
                      icon: const Icon(Icons.expand_more, size: 18, color: SaiColors.muted),
                      style: const TextStyle(fontSize: 11, fontFamily: 'Cairo', color: SaiColors.ink, fontWeight: FontWeight.w600),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('جميع البرامج')),
                        ...programs.map((program) => DropdownMenuItem(
                              value: program,
                              child: Text(program, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (value) => setState(() => _program = value ?? 'all'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const EmptyState(
                icon: Icons.meeting_room_outlined,
                title: 'لا توجد صفوف مسجلة',
                message: 'أنشئ الصفوف من بوابة الويب أو استورد الطلاب لبدء تشكيل الصفوف والمقاعد.',
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
                    child: _ClassCard(row: row, onTap: () => _openSheet(row)),
                  )),
            const SizedBox(height: 6),
            _ToolsRow(onImport: widget.onOpenImport, onParentLink: widget.onOpenParentLink),
          ],
        );
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.row, required this.onTap});

  final _ClassRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = row.isFull ? SaiColors.danger : (row.isNearFull ? SaiColors.warning : SaiColors.success);
    final tint = row.isFull ? SaiColors.dangerTint : (row.isNearFull ? SaiColors.warningTint : SaiColors.successTint);
    final label = row.isFull ? 'ممتلئ' : (row.isNearFull ? 'قريب من الامتلاء' : 'متاح');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SaiColors.border),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TintChip(label: label, color: color, tint: tint),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                      const SizedBox(height: 1),
                      Text(row.program, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: SaiColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text('${row.enrolled} / ${row.capacity}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                        const SizedBox(width: 4),
                        const Icon(Icons.people_alt_outlined, size: 15, color: SaiColors.ink),
                      ],
                    ),
                    const Text('المسجلون / السعة', style: TextStyle(fontSize: 8.5, color: SaiColors.muted)),
                  ],
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_left, size: 18, color: SaiColors.muted),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text('${row.percent}%', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
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
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.count, required this.enrolled, required this.seats});

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
        border: Border.all(color: SaiColors.gold.withOpacity(0.28)),
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

  Widget _divider() => Container(width: 1, height: 22, color: SaiColors.gold.withOpacity(0.3));
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
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SaiColors.ink)),
          Text(label, style: const TextStyle(fontSize: 9, color: SaiColors.muted)),
        ],
      ),
    );
  }
}

class _ToolsRow extends StatelessWidget {
  const _ToolsRow({required this.onImport, required this.onParentLink});

  final VoidCallback onImport;
  final VoidCallback onParentLink;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ToolButton(icon: Icons.upload_file_outlined, label: 'استيراد الطلاب', onTap: onImport)),
        const SizedBox(width: 8),
        Expanded(child: _ToolButton(icon: Icons.link, label: 'ربط ولي الأمر', onTap: onParentLink)),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onTap});

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
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SaiColors.ink))),
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
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SaiColors.ink)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: SaiColors.muted)),
        ],
      ),
    );
  }
}