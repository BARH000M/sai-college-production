import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

import '../data/sai_repository.dart';
import '../widgets/sai_async_list.dart';
import '../widgets/state_views.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key, required this.repo});

  final SaiRepository repo;

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: 'الحضور',
        subtitle: 'الصفوف المتاحة حسب الصلاحيات',
        children: [
          SaiAsyncList(
            load: repo.attendanceClasses,
            emptyIcon: Icons.fact_check_outlined,
            emptyTitle: 'لا توجد صفوف للحضور',
            emptyMessage: 'لم يتم العثور على صفوف يمكنك تسجيل الحضور لها.',
            builder: (rows) => Column(
              children: [
                for (final row in rows)
                  SaiListTile(
                    title: row['name']?.toString() ?? '',
                    icon: Icons.class_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceSessionsScreen(
                          repo: repo,
                          classRow: row,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}

class AttendanceSessionsScreen extends StatelessWidget {
  const AttendanceSessionsScreen({
    super.key,
    required this.repo,
    required this.classRow,
  });

  final SaiRepository repo;
  final Map<String, dynamic> classRow;

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: 'جلسات الحضور',
        subtitle: classRow['name']?.toString(),
        children: [
          SaiAsyncList(
            load: () => repo.attendanceSessions(classRow['id'].toString()),
            emptyIcon: Icons.event_busy_outlined,
            emptyTitle: 'لا توجد جلسات',
            emptyMessage: 'لم تُنشأ جلسات حضور لهذا الصف بعد.',
            builder: (rows) => Column(
              children: [
                for (final row in rows)
                  SaiListTile(
                    title: row['attendance_date']?.toString() ?? '',
                    subtitle: row['status']?.toString(),
                    icon: Icons.event_available_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceRosterScreen(
                          repo: repo,
                          session: row,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}

class AttendanceRosterScreen extends StatefulWidget {
  const AttendanceRosterScreen({
    super.key,
    required this.repo,
    required this.session,
  });

  final SaiRepository repo;
  final Map<String, dynamic> session;

  @override
  State<AttendanceRosterScreen> createState() => _AttendanceRosterScreenState();
}

class _AttendanceRosterScreenState extends State<AttendanceRosterScreen> {
  int _refreshKey = 0;

  bool get _isOpen => widget.session['status'] == 'open';

  Future<void> mark(Map<String, dynamic> row, String status) async {
    try {
      await widget.repo.markAttendance(
        sessionId: widget.session['id'].toString(),
        studentId: row['student_id'].toString(),
        status: status,
        recordId: row['record_id']?.toString(),
      );
      if (!mounted) return;
      setState(() => _refreshKey += 1);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحفظ: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: 'سجل الحضور',
        subtitle: widget.session['attendance_date']?.toString(),
        children: [
          if (!_isOpen) ...[
            const NoteBanner(message: 'هذه الجلسة مغلقة للقراءة فقط'),
            const SizedBox(height: 12),
          ],
          SaiAsyncList(
            key: ValueKey(_refreshKey),
            load: () =>
                widget.repo.attendanceRoster(widget.session['id'].toString()),
            emptyIcon: Icons.people_outline,
            emptyTitle: 'لا يوجد طلاب في هذا الكشف',
            emptyMessage: 'لم يُسجَّل أي طالب في هذه الجلسة بعد.',
            builder: (rows) => Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SaiCard(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['full_name']?.toString() ?? '',
                            style: SaiTextStyles.bodyStrong,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'الحالة: ${row['attendance_status'] ?? 'لم يُسجل'}',
                            style: SaiTextStyles.caption,
                          ),
                          if (_isOpen) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final option in const [
                                  ('present', 'حاضر'),
                                  ('absent', 'غائب'),
                                  ('late', 'متأخر'),
                                  ('excused', 'بعذر'),
                                ])
                                  ActionChip(
                                    label: Text(option.$2),
                                    onPressed: () => mark(row, option.$1),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}