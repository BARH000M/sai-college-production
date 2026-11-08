import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/sai_theme.dart';

class StudentRecordsPage extends StatefulWidget {
  const StudentRecordsPage({super.key, required this.identity, required this.role});

  final AppIdentity identity;
  final AppRole role;

  @override
  State<StudentRecordsPage> createState() => _StudentRecordsPageState();
}

class _StudentRecordsPageState extends State<StudentRecordsPage> {
  late Future<List<Map<String, dynamic>>> _records;

  @override
  void initState() {
    super.initState();
    _records = _loadRecords();
  }

  Future<List<Map<String, dynamic>>> _loadRecords() async {
    final client = Supabase.instance.client;
    if (widget.role == AppRole.student) {
      final row = await client
          .from('students')
          .select('id, admission_no, full_name, status, class_id, class:classes(name, program)')
          .eq('user_id', widget.identity.userId)
          .maybeSingle();
      return row == null ? [] : [Map<String, dynamic>.from(row)];
    }

    // Parents see only verified links belonging to their authenticated user.
    final links = await client
        .from('parent_student_links')
        .select('student_id')
        .eq('parent_user_id', widget.identity.userId)
        .not('verified_at', 'is', null);
    final studentIds = links
        .map((row) => row['student_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (studentIds.isEmpty) return [];

    final rows = await client
        .from('students')
        .select('id, admission_no, full_name, status, class_id, class:classes(name, program)')
        .inFilter('id', studentIds)
        .order('full_name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  void _retry() => setState(() => _records = _loadRecords());

  String _statusLabel(Object? status) => switch (status?.toString()) {
        'active' => 'نشط',
        'inactive' => 'غير نشط',
        'graduated' => 'متخرج',
        'withdrawn' => 'منسحب',
        _ => 'غير محدد',
      };

  Map<String, dynamic>? _classData(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.role == AppRole.parent;
    return Scaffold(
      appBar: AppBar(title: Text(isParent ? 'سجلات الأبناء' : 'سجلي الدراسي')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _records,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              title: 'تعذّر تحميل السجلات',
              message: 'تحقق من الاتصال، وإذا استمر الخطأ راجع صلاحيات الحساب في النظام.',
              action: FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
            );
          }
          final records = snapshot.data ?? const [];
          if (records.isEmpty) {
            return _MessageState(
              icon: Icons.folder_open_outlined,
              title: isParent ? 'لا توجد سجلات أبناء مرتبطة' : 'لا يوجد سجل طالب لهذا الحساب',
              message: isParent
                  ? 'ستظهر هنا السجلات المرتبطة والمؤكدة لهذا الحساب.'
                  : 'اربط إدارة الكلية حساب الدخول بسجل الطالب لإظهاره هنا.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(isParent ? 'الأبناء المرتبطون بحسابك' : 'بياناتي', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...records.map(_recordCard),
            ],
          );
        },
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> row) {
    final classInfo = _classData(row['class']);
    final className = classInfo?['name']?.toString();
    final program = classInfo?['program']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFFE9EC),
                    foregroundColor: SaiColors.red,
                    child: Icon(Icons.person_outline),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(row['full_name']?.toString() ?? 'طالب', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  _StatusChip(label: _statusLabel(row['status'])),
                ],
              ),
              const Divider(height: 24),
              _DataLine(label: 'رقم القيد', value: row['admission_no']?.toString() ?? '—'),
              if (className != null && className.isNotEmpty) _DataLine(label: 'الشعبة', value: className),
              if (program != null && program.isNotEmpty) _DataLine(label: 'البرنامج', value: program),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataLine extends StatelessWidget {
  const _DataLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(width: 88, child: Text(label, style: const TextStyle(color: SaiColors.muted, fontSize: 12))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: SaiColors.navy))),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(label, style: const TextStyle(fontSize: 11, color: SaiColors.success)),
        visualDensity: VisualDensity.compact,
        side: BorderSide.none,
        backgroundColor: const Color(0xFFEAF6F0),
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: SaiColors.muted),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: SaiColors.muted, height: 1.8)),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}
