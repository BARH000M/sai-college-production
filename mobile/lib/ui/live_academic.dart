import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'components.dart';
import '../core/access.dart';
import '../data/finance_repository.dart';
import 'finance_detail.dart';
import 'finance_setup.dart';
import 'printing.dart';

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
  const LiveFinanceScreen({super.key, this.loader, this.roles = const {}});

  final Future<List<Map<String, dynamic>>> Function()? loader;
  final Set<Role> roles;

  @override
  State<LiveFinanceScreen> createState() => _LiveFinanceScreenState();
}

class _LiveFinanceScreenState extends State<LiveFinanceScreen> {
  late Future<List<Map<String, dynamic>>> _assignments;
  String _search = '', _status = '', _classId = '';
  DateTime? _from, _to;

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
    final repository = FinanceRepository(client);

    final results = await Future.wait([
      repository.rows('sai_finance_assignments'),
      repository.rows('sai_finance_students'),
      repository.rows('sai_finance_group_labels'),
    ]);
    final students = {for (final row in results[1]) row['id']: row};
    final groups = {for (final row in results[2]) row['id']: row['name']};
    return results[0].map((row) {
      final student = students[row['student_id']];
      final group = groups[row['fee_group_id']];
      if (student == null || group is! String || row['balance'] is! num) {
        throw StateError('تعذر قراءة بيانات الرسوم أو الرصيد.');
      }
      return {
        ...row,
        'student_name': student['full_name'],
        'admission_no': student['admission_no'],
        'group_name': group,
      };
    }).toList();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _assignments,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return EmptyPanel(
          'تعذر تحميل الرسوم المسموح بها لهذا الحساب.',
          retry: () => setState(_reload),
        );
      }
      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
      if (rows.isEmpty) {
        return ListView(
          children: [
            EmptyPanel(
              'لا توجد استحقاقات رسوم مسجلة أو مرئية لهذا الحساب.',
              retry: () => setState(_reload),
            ),
            if (Access.manages(widget.roles, PageId.finance)) _setupButton(),
          ],
        );
      }
      const statuses = {
        'unpaid': 'غير مدفوع',
        'partial': 'مدفوع جزئياً',
        'paid': 'مدفوع',
        'waived': 'معفى',
        'cancelled': 'ملغى',
      };
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      bool overdue(Map<String, dynamic> row) =>
          row['status'] != 'cancelled' &&
          (row['balance'] as num) > 0 &&
          DateTime.parse('${row['due_date']}').isBefore(today);
      final visible = rows.where((row) {
        final due = DateTime.parse('${row['due_date']}');
        return '${row['student_name']} ${row['admission_no'] ?? ''}'
                .toLowerCase()
                .contains(_search.trim().toLowerCase()) &&
            (_status.isEmpty ||
                (_status == 'overdue'
                    ? overdue(row)
                    : row['status'] == _status)) &&
            (_classId.isEmpty || row['class_id'] == _classId) &&
            (_from == null || !due.isBefore(_from!)) &&
            (_to == null || !due.isAfter(_to!));
      }).toList();
      BigInt cents(num value) =>
          BigInt.parse(financeAmount('$value').replaceAll('.', ''));
      final outstanding = visible
          .where((r) => r['status'] != 'cancelled')
          .fold(BigInt.zero, (total, r) => total + cents(r['balance'] as num));
      final late = visible
          .where(overdue)
          .fold(BigInt.zero, (total, r) => total + cents(r['balance'] as num));
      String money(BigInt value) =>
          '${value ~/ BigInt.from(100)}.${(value % BigInt.from(100)).toString().padLeft(2, '0')}';
      final classes = rows
          .map((r) => r['class_id'])
          .whereType<String>()
          .toSet();
      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeading('الاستحقاقات المالية')),
              IconButton(
                onPressed: () => setState(_reload),
                icon: const Icon(Icons.refresh, color: gold),
              ),
            ],
          ),
          if (Access.manages(widget.roles, PageId.finance)) _setupButton(),
          TextField(
            decoration: const InputDecoration(
              labelText: 'بحث بالاسم أو الرقم الأكاديمي',
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          DropdownButtonFormField<String>(
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'حالة السداد'),
            items: [
              const DropdownMenuItem(value: '', child: Text('كل الحالات')),
              const DropdownMenuItem(value: 'overdue', child: Text('متأخر')),
              for (final entry in statuses.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _status = value ?? ''),
          ),
          DropdownButtonFormField<String>(
            initialValue: classes.contains(_classId) ? _classId : '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'معرّف الصف'),
            items: [
              const DropdownMenuItem(value: '', child: Text('كل الصفوف')),
              for (final id in classes)
                DropdownMenuItem(
                  value: id,
                  child: Text(id, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _classId = value ?? ''),
          ),
          Wrap(
            children: [
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _from ?? today,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (mounted && date != null) setState(() => _from = date);
                },
                child: Text(
                  'الاستحقاق من: ${_from?.toIso8601String().split('T').first ?? 'الكل'}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _to ?? today,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (mounted && date != null) setState(() => _to = date);
                },
                child: Text(
                  'إلى: ${_to?.toIso8601String().split('T').first ?? 'الكل'}',
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _from = null;
                  _to = null;
                }),
                child: const Text('مسح التواريخ'),
              ),
            ],
          ),
          Text(
            'المستحق: ${money(outstanding)} ر.ي · المتأخر: ${money(late)} ر.ي',
          ),
          PrintAction(
            CollegeReport(
              title: 'كشف فواتير الرسوم والأرصدة',
              subtitle:
                  'المستحق: ${money(outstanding)} ر.ي · المتأخر: ${money(late)} ر.ي',
              preview: false,
              columns: const [
                PrintColumn('الطالب'),
                PrintColumn('الرسوم'),
                PrintColumn('الاستحقاق'),
                PrintColumn('الرصيد'),
              ],
              rows: [
                for (final row in visible)
                  [
                    '${row['student_name']}',
                    '${row['group_name']}',
                    '${row['due_date']}',
                    '${row['balance']} ر.ي',
                  ],
              ],
            ),
          ),
          if (visible.isEmpty) const Text('لا توجد نتائج تطابق البحث.'),
          for (final row in visible)
            SaiCard(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: gold),
                title: Text('${row['group_name']} · ${row['student_name']}'),
                subtitle: Text(
                  'موعد الاستحقاق: ${row['due_date']} · ${statuses[row['status']] ?? row['status']}\nالمتبقي: ${row['balance']} ر.ي${overdue(row) ? ' · متأخر' : ''}',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: row['id'] == null
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FinanceDetail(
                              assignment: row,
                              roles: widget.roles,
                            ),
                          ),
                        );
                        if (mounted) setState(_reload);
                      },
              ),
            ),
          const Text(
            'اختر الفاتورة لعرض سجل الدفعات والإيصالات. تخضع العمليات لصلاحيات الحساب والفرع.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    },
  );

  Widget _setupButton() => TextButton(
    onPressed: () async {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const FinanceSetup()));
      if (mounted) setState(_reload);
    },
    child: const Text('إدارة مجموعات الرسوم وإسنادها'),
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
