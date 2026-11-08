import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/sai_theme.dart';
import '../../widgets/state_views.dart';
import 'student_records_page.dart';
import 'student_stats.dart';

class _MyRecord {
  const _MyRecord({
    required this.id,
    required this.name,
    required this.admissionNo,
    required this.className,
    required this.status,
    required this.stats,
  });

  final String id;
  final String name;
  final String admissionNo;
  final String className;
  final String status;
  final StudentStats stats;
}

/// Screen 6 of the mockup: the student's own record and study metrics.
class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key, required this.identity});

  final AppIdentity identity;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  late Future<_MyRecord?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MyRecord?> _load() async {
    final client = Supabase.instance.client;
    final row = await client
        .from('students')
        .select('id,full_name,admission_no,class_id,status')
        .eq('user_id', widget.identity.userId)
        .maybeSingle();
    if (row == null) return null;

    final classId = row['class_id'] as String?;
    var className = 'غير مسجل في صف';
    if (classId != null) {
      final classRow = await client.from('classes').select('name').eq('id', classId).maybeSingle();
      final name = (classRow?['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) className = name;
    }

    final id = row['id'] as String;
    final stats = await loadStudentStats(client, id);
    return _MyRecord(
      id: id,
      name: (row['full_name'] as String?)?.trim().isNotEmpty == true ? (row['full_name'] as String).trim() : widget.identity.fullName,
      admissionNo: (row['admission_no'] as String?) ?? '—',
      className: className,
      status: (row['status'] as String?) ?? 'active',
      stats: stats,
    );
  }

  void _retry() => setState(() => _future = _load());

  void _openAcademicRecord() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentRecordsPage(identity: widget.identity, role: AppRole.student),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.identity.fullName.trim().split(RegExp(r'\s+')).first;
    return FutureBuilder<_MyRecord?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingState();
        if (snapshot.hasError) {
          return ErrorState(message: '${snapshot.error}', onRetry: _retry);
        }
        final record = snapshot.data;
        if (record == null) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
            children: [
              Text('مرحبًا، $firstName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SaiColors.ink)),
              const SizedBox(height: 3),
              const Text('بياناتك الشخصية فقط', style: TextStyle(fontSize: 10.5, color: SaiColors.muted)),
              const SizedBox(height: 14),
              const EmptyState(
                icon: Icons.badge_outlined,
                title: 'لا يوجد سجل طالب مرتبط بحسابك',
                message: 'اطلب من إدارة الكلية ربط حساب الدخول بسجل الطالب ليظهر هنا.',
              ),
            ],
          );
        }
        final initial = record.name.trim().isEmpty ? 'ط' : record.name.trim().substring(0, 1);
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
          children: [
            Text('مرحبًا، $firstName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SaiColors.ink)),
            const SizedBox(height: 3),
            const Text('بياناتك الشخصية فقط', style: TextStyle(fontSize: 10.5, color: SaiColors.muted)),
            const SizedBox(height: 14),
            InkWell(
              onTap: _openAcademicRecord,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SaiColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: SaiColors.creamDeep,
                      child: Text(initial, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(record.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                          const SizedBox(height: 1),
                          Text(record.admissionNo, style: const TextStyle(fontSize: 10, color: SaiColors.muted)),
                          const SizedBox(height: 1),
                          Text(record.className, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: SaiColors.gold, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left, size: 18, color: SaiColors.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SaiColors.border),
              ),
              child: StudentMetricRow(stats: record.stats),
            ),
            const SizedBox(height: 11),
            FilledButton.icon(
              onPressed: _openAcademicRecord,
              icon: const Icon(Icons.menu_book_outlined, size: 17),
              label: const Text('سجلي الأكاديمي'),
            ),
            const SizedBox(height: 12),
            const NoteBanner(
              icon: Icons.lock_outline,
              color: SaiColors.warning,
              tint: SaiColors.warningTint,
              message: 'تظهر فقط بيانات سجلك الدراسي، وأي سجل آخر يبقى محجوبًا بسياسات الحماية في قاعدة البيانات.',
            ),
          ],
        );
      },
    );
  }
}