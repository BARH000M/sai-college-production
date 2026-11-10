import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sai_theme.dart';
import '../../widgets/state_views.dart';
import 'class_models.dart';
import 'class_roster_export.dart';

String _two(int value) => value.toString().padLeft(2, '0');
String _printed(DateTime value) =>
    '${value.year}/${_two(value.month)}/${_two(value.day)}';

/// Official class roster sheet — the printable document that leaves the phone
/// as text (WhatsApp / e-mail / print) with the college letterhead.
class ClassRosterSheetPage extends StatefulWidget {
  const ClassRosterSheetPage({super.key, required this.cls});

  final SaiClass cls;

  @override
  State<ClassRosterSheetPage> createState() => _ClassRosterSheetPageState();
}

class _ClassRosterSheetPageState extends State<ClassRosterSheetPage> {
  late Future<List<RosterStudent>> _future;
  final DateTime _issuedAt = DateTime.now();
  bool _attendanceUnavailable = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RosterStudent>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('students')
        .select('id,admission_no,full_name')
        .eq('class_id', widget.cls.id)
        .eq('status', 'active')
        .order('full_name', ascending: true);

    // Real totals for the current month, read from attendance_records through
    // the sessions of this class only.
    final now = DateTime.now();
    final monthStart = '${now.year}-${_two(now.month)}-01';
    final monthEnd =
        '${now.year}-${_two(now.month)}-${_two(DateTime(now.year, now.month + 1, 0).day)}';
    final stats = <String, Map<String, int>>{};
    _attendanceUnavailable = false;

    try {
      final sessions = await client
          .from('attendance_sessions')
          .select('id')
          .eq('class_id', widget.cls.id)
          .gte('attendance_date', monthStart)
          .lte('attendance_date', monthEnd);
      final sessionIds = (sessions as List)
          .whereType<Map<String, dynamic>>()
          .map((row) => row['id'] as String?)
          .whereType<String>()
          .toList();

      if (sessionIds.isNotEmpty) {
        final records = await client
            .from('attendance_records')
            .select('student_id,status')
            .inFilter('attendance_session_id', sessionIds);
        for (final record in (records as List).whereType<Map<String, dynamic>>()) {
          final studentId = record['student_id'] as String?;
          final status = record['status'] as String?;
          if (studentId == null || status == null) continue;
          final bucket = stats.putIfAbsent(studentId, () => <String, int>{});
          bucket[status] = (bucket[status] ?? 0) + 1;
        }
      }
    } catch (_) {
      _attendanceUnavailable = true;
    }

    return (rows as List).whereType<Map<String, dynamic>>().map((row) {
      final name = (row['full_name'] as String?)?.trim() ?? '';
      final bucket = stats[row['id'] as String? ?? ''] ?? const <String, int>{};
      return RosterStudent(
        admissionNo: (row['admission_no'] as String?)?.trim().isNotEmpty == true
            ? (row['admission_no'] as String).trim()
            : '—',
        fullName: name.isEmpty ? 'طالب' : name,
        presentDays: bucket['present'] ?? 0,
        absentDays: bucket['absent'] ?? 0,
        lateDays: bucket['late'] ?? 0,
        excusedDays: bucket['excused'] ?? 0,
      );
    }).toList();
  }

  Future<void> _share(List<RosterStudent> students) async {
    try {
      await copyClassRoster(
          cls: widget.cls, students: students, issuedAt: _issuedAt);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'تم نسخ كشف الصف — الصقه في واتساب أو البريد، أو أرسله للطباعة.'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تعذّر نسخ الكشف: $error'),
        backgroundColor: SaiColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RosterStudent>>(
      future: _future,
      builder: (context, snapshot) {
        final students = snapshot.data ?? const <RosterStudent>[];
        final busy = snapshot.connectionState == ConnectionState.waiting;
        return Scaffold(
          backgroundColor: SaiColors.creamDeep,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('كشف طلاب الصف',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SaiColors.ink)),
                Text(widget.cls.name,
                    style:
                        const TextStyle(fontSize: 10, color: SaiColors.muted)),
              ],
            ),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_forward,
                  size: 20, color: SaiColors.ink),
            ),
            actions: [
              IconButton(
                tooltip: 'مشاركة الكشف',
                onPressed: busy ? null : () => _share(students),
                icon:
                    const Icon(Icons.ios_share, size: 19, color: SaiColors.ink),
              ),
            ],
          ),
          body: snapshot.hasError
              ? ErrorState(
                  message: 'تعذّر تحميل طلاب الصف.\n${snapshot.error}',
                  onRetry: () => setState(() => _future = _load()),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  children: [
                    if (busy) const LoadingState(),
                    if (!busy)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: SaiColors.border),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _Letterhead(),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: SaiColors.maroon,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'كشف طلاب الصف — يُعتمد مرجعاً للحضور والتقييم',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _MetaGrid(
                                cls: widget.cls,
                                issuedAt: _issuedAt,
                                count: students.length),
                            const SizedBox(height: 14),
                            if (_attendanceUnavailable)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: NoteBanner(
                                  message:
                                      'تعذّر قراءة سجلات الحضور لهذا الشهر بحسابك، لذلك يظهر عمود الحضور فارغاً. أعد المحاولة بحساب معلم الصف أو الإدارة.',
                                  color: SaiColors.warning,
                                  tint: SaiColors.warningTint,
                                  icon: Icons.info_outline,
                                ),
                              ),
                            _RosterTable(students: students),
                            const SizedBox(height: 6),
                            Text(
                              'حضور الشهر = أيام الحضور (حاضر + متأخر) من إجمالي الأيام المسجّلة في ${monthLabel(_issuedAt)}.',
                              style: const TextStyle(fontSize: 8.5, height: 1.6, color: SaiColors.muted),
                            ),
                            const SizedBox(height: 12),
                            _Tally(students: students, cls: widget.cls),
                            const SizedBox(height: 14),
                            const Text(
                              'يوثّق هذا الكشف الطلاب المسجلين في الصف عند تاريخ الإصدار. أي تغيير في القيد أو النقل يُسجَّل من سجل الطالب، وتُعاد طباعة الكشف بعد التحديث.',
                              style: TextStyle(
                                  fontSize: 9.5,
                                  height: 1.8,
                                  color: SaiColors.muted),
                            ),
                            const SizedBox(height: 22),
                            const Row(
                              children: [
                                Expanded(
                                    child: _SignatureLine(
                                        label: 'توقيع معلم الصف')),
                                SizedBox(width: 18),
                                Expanded(
                                    child: _SignatureLine(
                                        label: 'توقيع إدارة الكلية')),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(height: 1, color: SaiColors.border),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'كلية ساي التعليمية اليمنية الصينية · ${widget.cls.branchName ?? 'الفرع الرئيسي'}',
                                    style: const TextStyle(
                                        fontSize: 8.5, color: SaiColors.muted),
                                  ),
                                ),
                                Text('صفحة 1 من 1 · ${students.length} طالباً',
                                    style: const TextStyle(
                                        fontSize: 8.5, color: SaiColors.muted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SaiColors.border),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 15, color: SaiColors.gold),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'يعرض عمود «حضور الشهر» أيام الحضور مقابل الأيام المسجّلة فعلياً من سجل الحضور، وزر المشاركة ينسخ الكشف كاملاً بترويسة الكلية وأعمدة التوقيع، جاهزاً للصق في واتساب أو البريد أو برنامج الطباعة.',
                              style: TextStyle(fontSize: 10, height: 1.7, color: SaiColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: SaiColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إغلاق'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: busy || snapshot.hasError
                          ? null
                          : () => _share(students),
                      icon: const Icon(Icons.ios_share, size: 17),
                      label: const Text('مشاركة / طباعة الكشف'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Letterhead extends StatelessWidget {
  const _Letterhead();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: SaiColors.border),
          ),
          padding: const EdgeInsets.all(3),
          child: ClipOval(
              child: Image.asset('assets/images/sai-logo.png',
                  fit: BoxFit.contain)),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'كلية ساي التعليمية اليمنية الصينية',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: SaiColors.ink,
                    height: 1.5),
              ),
              SizedBox(height: 1),
              Text(
                '世门赛艾教育学院',
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: SaiColors.gold),
              ),
              SizedBox(height: 3),
              Text(
                'إدارة الشؤون الأكاديمية — سجل الصفوف',
                style: TextStyle(fontSize: 8.5, color: SaiColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: SaiColors.goldTint,
            shape: BoxShape.circle,
            border: Border.all(color: SaiColors.gold.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.verified_outlined,
              size: 20, color: SaiColors.gold),
        ),
      ],
    );
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid(
      {required this.cls, required this.issuedAt, required this.count});

  final SaiClass cls;
  final DateTime issuedAt;
  final int count;

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<String, String>>[
      MapEntry('الصف', cls.name),
      MapEntry('البرنامج', cls.program),
      MapEntry('معلم الصف', cls.teacherName ?? 'غير مسند'),
      MapEntry('الفرع', cls.branchName ?? '—'),
      MapEntry('عدد الطلاب', '$count'),
      MapEntry('السعة / المتاح', '${cls.capacity} / ${cls.available}'),
      MapEntry('الفصل الدراسي', cls.sessionName ?? '—'),
      MapEntry('تاريخ الإصدار', _printed(issuedAt)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: SaiColors.cream,
        border: Border.all(color: SaiColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < items.length ? 6 : 0),
              child: Row(
                children: [
                  _metaCell(items[i].key, items[i].value),
                  const SizedBox(width: 8),
                  if (i + 1 < items.length)
                    _metaCell(items[i + 1].key, items[i + 1].value)
                  else
                    const Spacer(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _metaCell(String label, String value) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(fontSize: 9, color: SaiColors.muted)),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: SaiColors.ink,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterTable extends StatelessWidget {
  const _RosterTable({required this.students});

  final List<RosterStudent> students;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: SaiColors.border)),
      child: Column(
        children: [
          Container(
            color: SaiColors.creamDeep,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: const Row(
              children: [
                SizedBox(
                    width: 22,
                    child: Text('م',
                        style: _headStyle, textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text('اسم الطالب', style: _headStyle)),
                Expanded(flex: 2, child: Text('رقم القيد', style: _headStyle)),
                Expanded(
                  flex: 2,
                  child: Text('حضور الشهر', style: _headStyle, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('لا يوجد طلاب مسجلون في هذا الصف.',
                  style: TextStyle(fontSize: 10, color: SaiColors.muted)),
            )
          else
            ...List<Widget>.generate(students.length, (index) {
              final student = students[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                decoration: BoxDecoration(
                  color: index.isEven
                      ? Colors.white
                      : SaiColors.cream.withValues(alpha: 0.55),
                  border:
                      const Border(top: BorderSide(color: SaiColors.border)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${index + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 9, color: SaiColors.muted)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        student.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: SaiColors.ink),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(student.admissionNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 9, color: SaiColors.muted)),
                    ),
                    Expanded(
                      flex: 2,
                      child: _AttendanceCell(student: student),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

const _headStyle = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: SaiColors.ink,
    height: 1.4);

/// Compact monthly attendance figure printed in the roster table.
class _AttendanceCell extends StatelessWidget {
  const _AttendanceCell({required this.student});

  final RosterStudent student;

  @override
  Widget build(BuildContext context) {
    if (student.recordedDays == 0) {
      return const Text('—',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, color: SaiColors.muted));
    }
    final percent = student.attendancePercent;
    final color = percent >= 85
        ? SaiColors.success
        : (percent >= 70 ? SaiColors.warning : SaiColors.danger);
    return Column(
      children: [
        Text(
          student.attendanceShort,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: SaiColors.ink),
        ),
        Text(
          '$percent%',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.students, required this.cls});

  final List<RosterStudent> students;
  final SaiClass cls;

  @override
  Widget build(BuildContext context) {
    final items = [
      'المسجلون: ${students.length}',
      'السعة: ${cls.capacity}',
      'المقاعد المتاحة: ${cls.available}',
      'نسبة الإشغال: ${cls.percent}%',
      'حضور الشهر: ${classAttendancePercent(students) == null ? 'لا سجلات' : '${classAttendancePercent(students)}%'}',
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SaiColors.goldTint,
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: SaiColors.gold.withValues(alpha: 0.3)),
                ),
                child: Text(item,
                    style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: SaiColors.ink)),
              ))
          .toList(),
    );
  }
}

class _SignatureLine extends StatelessWidget {
  const _SignatureLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 1, color: SaiColors.border),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 8.5, color: SaiColors.muted)),
      ],
    );
  }
}
