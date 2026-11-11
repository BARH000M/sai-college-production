import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'components.dart';

class LiveAttendanceScreen extends StatefulWidget {
  const LiveAttendanceScreen({super.key});

  @override
  State<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen> {
  late Future<List<Map<String, dynamic>>> _sessions;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _sessions = Supabase.instance.client
        .from('attendance_sessions')
        .select('id,class_id,attendance_date,status')
        .order('attendance_date', ascending: false)
        .limit(100);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _sessions,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return EmptyPanel('تعذر تحميل سجلات الحضور. تحقق من اتصال الحساب وصلاحياته.', retry: () => setState(_reload));
      }
      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
      if (rows.isEmpty) {
        return EmptyPanel('لا توجد جلسات حضور مرئية لهذا الحساب حتى الآن.', retry: () => setState(_reload));
      }
      final classIds = rows.map((r) => r['class_id']).whereType<String>().toSet().toList();
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: Supabase.instance.client.from('classes').select('id,name').inFilter('id', classIds),
        builder: (context, classSnapshot) {
          final names = <String, String>{
            for (final row in classSnapshot.data ?? const <Map<String, dynamic>>[])
              '${row['id']}': '${row['name'] ?? 'الشعبة'}',
          };
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Row(children: [const Expanded(child: SectionHeading('سجلات الحضور من قاعدة البيانات')), IconButton(onPressed: () => setState(_reload), icon: const Icon(Icons.refresh, color: gold))]),
              for (final row in rows)
                SaiCard(
                  child: ListTile(
                    leading: const Icon(Icons.fact_check_outlined, color: gold),
                    title: Text(names['${row['class_id']}'] ?? 'الشعبة'),
                    subtitle: Text('${row['attendance_date'] ?? ''}  •  ${row['status'] ?? ''}'),
                    trailing: const Icon(Icons.verified_outlined, color: gold),
                  ),
                ),
              const Text('تُطبق صلاحيات Supabase على السجلات المعروضة. تعديل الحضور متاح عبر بوابة الإدارة وفق صلاحية الدور.', textAlign: TextAlign.center),
            ],
          );
        },
      );
    },
  );
}

class LiveFinanceScreen extends StatefulWidget {
  const LiveFinanceScreen({super.key});

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
    _assignments = Supabase.instance.client
        .from('fee_assignments')
        .select('id,fee_group_id,student_id,original_amount,discount_amount,final_amount,due_date,cancelled_at')
        .isFilter('cancelled_at', null)
        .order('due_date', ascending: true)
        .limit(200);
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
      final ids = rows.map((r) => r['fee_group_id']).whereType<String>().toSet().toList();
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: Supabase.instance.client.from('fee_groups').select('id,name,currency').inFilter('id', ids),
        builder: (context, groupsSnapshot) {
          final groups = <String, Map<String, dynamic>>{
            for (final row in groupsSnapshot.data ?? const <Map<String, dynamic>>[]) '${row['id']}': row,
          };
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Row(children: [const Expanded(child: SectionHeading('الاستحقاقات المالية')), IconButton(onPressed: () => setState(_reload), icon: const Icon(Icons.refresh, color: gold))]),
              for (final row in rows)
                SaiCard(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, color: gold),
                    title: Text('${groups['${row['fee_group_id']}']?['name'] ?? 'استحقاق رسوم'}'),
                    subtitle: Text('موعد الاستحقاق: ${row['due_date'] ?? 'غير محدد'}'),
                    trailing: Text('${row['final_amount'] ?? 0} ${groups['${row['fee_group_id']}']?['currency'] ?? ''}', style: const TextStyle(color: ink, fontWeight: FontWeight.bold)),
                  ),
                ),
              const Text('هذه الشاشة للعرض فقط. تسجيل الدفعات أو الإعفاءات يجب أن يتم عبر إجراءات المالية المعتمدة ذات التدقيق والصلاحيات.', textAlign: TextAlign.center),
            ],
          );
        },
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
