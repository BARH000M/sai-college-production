import 'package:flutter/material.dart';

import '../core/access.dart';
import '../data/demo_school.dart';
import '../data/demo_workspace.dart';
import '../data/repository.dart';
import 'components.dart';
import 'printing.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({
    super.key,
    required this.roles,
    this.demo,
    this.attendance = false,
  });
  final Set<Role> roles;
  final DemoWorkspace? demo;
  final bool attendance;

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late Future<List<Map<String, dynamic>>> rows = load();
  Future<List<Map<String, dynamic>>> load() async => widget.demo == null
      ? await Repository().classes()
      : DemoSchool.visibleClasses(widget.roles);

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: rows,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EmptyPanel(
                  'تعذر تحميل الصفوف. تحقق من الاتصال وأعد المحاولة.',
                  retry: () => setState(() => rows = load()),
                ),
              ],
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionHeading(
                widget.attendance ? 'اختر الصف لعرض الحضور' : 'الصفوف المتاحة',
                action: data.isEmpty
                    ? null
                    : PrintAction(
                        CollegeReport(
                          title: 'قائمة الصفوف',
                          preview: widget.demo != null,
                          columns: const [
                            PrintColumn('الصف', flex: 2),
                            PrintColumn('البرنامج', flex: 3),
                            PrintColumn('السعة'),
                          ],
                          rows: [
                            for (final row in data)
                              [
                                '${row['name']}',
                                '${row['program']}',
                                '${row['capacity']}',
                              ],
                          ],
                        ),
                      ),
              ),
              if (data.isEmpty) const EmptyPanel('لا توجد صفوف متاحة لحسابك.'),
              for (final row in data)
                Tile(
                  '${row['name']}',
                  widget.attendance
                      ? Icons.fact_check_outlined
                      : Icons.groups_outlined,
                  subtitle: '${row['program']}  •  السعة ${row['capacity']}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RosterScreen(
                        row: row,
                        roles: widget.roles,
                        demo: widget.demo,
                        attendance: widget.attendance,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class RosterScreen extends StatefulWidget {
  const RosterScreen({
    super.key,
    required this.row,
    required this.roles,
    this.demo,
    this.attendance = false,
  });
  final Map<String, dynamic> row;
  final Set<Role> roles;
  final DemoWorkspace? demo;
  final bool attendance;

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  late Future<List<Map<String, dynamic>>> rows = load();
  DateTime date = DateTime.now();
  String query = '';
  bool saving = false;

  Future<List<Map<String, dynamic>>> load() async {
    final id = widget.row['id'] as String;
    return widget.demo == null
        ? await Repository().students(id)
        : DemoSchool.visibleStudents(id, widget.roles);
  }

  Future<void> selectDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (mounted && value != null) setState(() => date = value);
  }

  Future<void> mark(String id, String status) async {
    final demo = widget.demo;
    if (demo == null ||
        saving ||
        !Access.manages(widget.roles, PageId.attendance)) {
      return;
    }
    setState(() => saving = true);
    try {
      await demo.save(
        DemoSchool.attendanceKey(DemoSchool.dateLabel(date), id),
        status,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ الحضور على الجهاز.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = widget.demo;
    final withAttendance =
        demo != null && Access.allows(widget.roles, PageId.attendance);
    final canMark =
        withAttendance && Access.manages(widget.roles, PageId.attendance);
    final title = widget.attendance ? 'كشف الحضور' : 'كشف طلاب الصف';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkRed,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: rows,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EmptyPanel(
                  'تعذر تحميل طلاب الصف.',
                  retry: () => setState(() => rows = load()),
                ),
              ],
            );
          }
          final students = snapshot.data!
              .where(
                (row) => '${row['full_name']} ${row['admission_no']}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
              )
              .toList();
          final report = CollegeReport(
            title: title,
            subtitle: '${widget.row['name']}  •  ${DemoSchool.dateLabel(date)}',
            preview: demo != null,
            signature: true,
            columns: [
              const PrintColumn('اسم الطالب', flex: 2),
              const PrintColumn('رقم القيد', ltr: true),
              if (withAttendance) const PrintColumn('الحضور'),
            ],
            rows: [
              for (final row in students)
                [
                  '${row['full_name']}',
                  '${row['admission_no']}',
                  if (withAttendance)
                    DemoSchool.attendance(demo, date, row['id'] as String),
                ],
            ],
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionHeading(
                '${widget.row['name']}',
                action: students.isEmpty ? null : PrintAction(report),
              ),
              Tile(
                '${widget.row['program']}',
                Icons.school_outlined,
                subtitle: 'السعة ${widget.row['capacity']}',
              ),
              TextField(
                onChanged: (value) => setState(() => query = value.trim()),
                decoration: const InputDecoration(
                  hintText: 'الاسم أو رقم القيد',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              if (withAttendance) ...[
                OutlinedButton.icon(
                  onPressed: saving ? null : selectDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('الحضور ليوم ${DemoSchool.dateLabel(date)}'),
                ),
                const SizedBox(height: 8),
              ],
              if (students.isEmpty)
                const EmptyPanel('لا توجد سجلات طلاب مطابقة.'),
              for (final row in students)
                SaiCard(
                  padding: 12,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: gold,
                        size: 26,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['full_name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${row['admission_no']}',
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (withAttendance)
                        PopupMenuButton<String>(
                          enabled: canMark && !saving,
                          tooltip: 'تسجيل حالة الحضور',
                          itemBuilder: (_) => [
                            for (final status in [
                              DemoSchool.present,
                              DemoSchool.late,
                              DemoSchool.absent,
                              DemoSchool.unmarked,
                            ])
                              PopupMenuItem(value: status, child: Text(status)),
                          ],
                          onSelected: (status) =>
                              mark(row['id'] as String, status),
                          child: Chip(
                            label: Text(
                              DemoSchool.attendance(
                                demo,
                                date,
                                row['id'] as String,
                              ),
                            ),
                            avatar: canMark
                                ? const Icon(Icons.expand_more, size: 16)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
