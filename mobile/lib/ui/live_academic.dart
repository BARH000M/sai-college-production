import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'components.dart';

class LiveAttendanceScreen extends StatefulWidget {
  const LiveAttendanceScreen({super.key, this.loader, this.personalOnly = false});

  final Future<List<Map<String, dynamic>>> Function()? loader;
  final bool personalOnly;

  @override
  State<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen> {
  late Future<List<Map<String, dynamic>>> _records;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _records = (widget.loader ?? _loadRecords)();
  }

  Future<List<Map<String, dynamic>>> _loadRecords() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('تعذر التحقق من هوية الحساب.');
    var query = client.from('attendance_records')
        .select('id,student_id,attendance_session_id,status,note,marked_at');
    if (widget.personalOnly) {
      final own = await client.from('students').select('id').eq('user_id', user.id);
      final links = await client.from('parent_student_links').select('student_id')
          .eq('parent_user_id', user.id).not('verified_at', 'is', null);
      final ids = {
        ...own.map((row) => row['id'] as String),
        ...links.map((row) => row['student_id'] as String),
      }.toList();
      if (ids.isEmpty) return [];
      query = query.inFilter('student_id', ids);
    }
    final records = await query.order('marked_at', ascending: false).limit(100);
    if (records.isEmpty) return [];
    final sessionIds = records.map((r) => r['attendance_session_id'] as String).toSet().toList();
    final studentIds = records.map((r) => r['student_id'] as String).toSet().toList();
    final sessions = await client.from('attendance_sessions')
        .select('id,attendance_date').inFilter('id', sessionIds);
    final students = await client.from('students')
        .select('id,full_name').inFilter('id', studentIds);
    final dates = {for (final row in sessions) row['id']: row['attendance_date']};
    final names = {for (final row in students) row['id']: row['full_name']};
    return records.map((row) {
      final date = dates[row['attendance_session_id']];
      final name = names[row['student_id']];
      if (date is! String || name is! String) {
        throw StateError('تعذر قراءة بيانات الطالب أو تاريخ الحضور.');
      }
      return {...row, 'attendance_date': date, 'student_name': name};
    }).toList();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _records,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return EmptyPanel('تعذر تحميل سجلات الحضور. تحقق من اتصال الحساب وصلاحياته.', retry: () => setState(_reload));
      }
      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
      if (rows.isEmpty) {
        return EmptyPanel('لا توجد سجلات حضور مرئية لهذا الحساب حتى الآن.', retry: () => setState(_reload));
      }
      const statuses = {'present': 'حاضر', 'absent': 'غائب', 'late': 'متأخر', 'excused': 'بعذر'};
      return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Row(children: [const Expanded(child: SectionHeading('سجلات الحضور')), IconButton(onPressed: () => setState(_reload), icon: const Icon(Icons.refresh, color: gold))]),
              for (final row in rows)
                SaiCard(
                  child: ListTile(
                    leading: const Icon(Icons.fact_check_outlined, color: gold),
                    title: Text('${row['student_name']}'),
                    subtitle: Text('${row['attendance_date']}  •  ${statuses[row['status']] ?? row['status']}${row['note'] == null || row['note'] == '' ? '' : '\n${row['note']}'}'),
                    trailing: const Icon(Icons.verified_outlined, color: gold),
                  ),
                ),
              const Text('تظهر أحدث 100 سجل مسموح لهذا الحساب؛ تُطبق صلاحيات قاعدة البيانات.', textAlign: TextAlign.center),
            ],
      );
    },
  );
}

class LiveFinanceScreen extends StatefulWidget {
  const LiveFinanceScreen({super.key, this.loader});

  final Future<List<Map<String, dynamic>>> Function()? loader;

  @override
  State<LiveFinanceScreen> createState() => _LiveFinanceScreenState();
}

class _LiveFinanceScreenState extends State<LiveFinanceScreen> {
  late Future<List<Map<String, dynamic>>> _assignments;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _assignments = (widget.loader ?? _loadAssignments)();
  }

  Future<List<Map<String, dynamic>>> _loadAssignments() async {
    final client = Supabase.instance.client;
    Future<List<Map<String, dynamic>>> loadPages(String name) async {
      final result = <Map<String, dynamic>>[];
      while (true) {
        final page = await client.rpc(name).range(result.length, result.length + 999);
        final rows = List<Map<String, dynamic>>.from(page);
        result.addAll(rows);
        if (rows.length < 1000) return result;
      }
    }

    final results = await Future.wait([
      loadPages('sai_finance_assignments'),
      loadPages('sai_finance_students'),
      loadPages('sai_finance_group_labels'),
    ]);
    final students = {for (final row in results[1]) row['id']: row['full_name']};
    final groups = {for (final row in results[2]) row['id']: row['name']};
    return results[0].map((row) {
      final student = students[row['student_id']];
      final group = groups[row['fee_group_id']];
      if (student is! String || group is! String || row['balance'] is! num) {
        throw StateError('تعذر قراءة بيانات الرسوم أو الرصيد.');
      }
      return {...row, 'student_name': student, 'group_name': group};
    }).toList();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _assignments,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return EmptyPanel('تعذر تحميل الرسوم المسموح بها لهذا الحساب.', retry: () => setState(_reload));
      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
      if (rows.isEmpty) {
        return EmptyPanel('الاتصال المالي يعمل، لكن لا توجد استحقاقات رسوم مسجلة أو مرئية لهذا الحساب. لا نعرض مبالغ تجريبية.', retry: () => setState(_reload));
      }
      const statuses = {'unpaid': 'غير مدفوع', 'partial': 'مدفوع جزئياً', 'paid': 'مدفوع', 'waived': 'معفى', 'cancelled': 'ملغى'};
      return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Row(children: [const Expanded(child: SectionHeading('الاستحقاقات المالية')), IconButton(onPressed: () => setState(_reload), icon: const Icon(Icons.refresh, color: gold))]),
              for (final row in rows)
                SaiCard(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, color: gold),
                    title: Text('${row['group_name']} · ${row['student_name']}'),
                    subtitle: Text('موعد الاستحقاق: ${row['due_date']} · ${statuses[row['status']] ?? row['status']}'),
                    trailing: Text('المتبقي: ${row['balance']} ر.ي', style: const TextStyle(color: ink, fontWeight: FontWeight.bold)),
                  ),
                ),
              const Text('هذه الشاشة للعرض فقط. تسجيل الدفعات أو الإعفاءات يجب أن يتم عبر إجراءات المالية المعتمدة ذات التدقيق والصلاحيات.', textAlign: TextAlign.center),
            ],
      );
    },
  );
}

class LiveUnavailableModule extends StatelessWidget {
  const LiveUnavailableModule({super.key, required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [SaiCard(child: Column(children: [const Icon(Icons.info_outline_rounded, size: 38, color: gold), const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center)]))],
  );
}
