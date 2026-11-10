import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/sai_repository.dart';
import '../widgets/ui.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key, required this.repo});

  final SaiRepository repo;

  @override
  Widget build(BuildContext context) => SaiPage(
        title: 'الحضور',
        children: [
          const Text('الصفوف المتاحة حسب الصلاحيات'),
          AsyncList(
            future: repo.attendanceClasses(),
            builder: (rows) => Column(
              children: [
                for (final r in rows)
                  SaiTile(
                    title: r['name']?.toString() ?? '',
                    icon: Icons.class_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceSessionsScreen(
                          repo: repo,
                          classRow: r,
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
  Widget build(BuildContext context) => SaiPage(
        title: 'جلسات الحضور',
        subtitle: classRow['name']?.toString(),
        children: [
          AsyncList(
            future: repo.attendanceSessions(classRow['id'].toString()),
            builder: (rows) => Column(
              children: [
                for (final r in rows)
                  SaiTile(
                    title: r['attendance_date']?.toString() ?? '',
                    subtitle: r['status']?.toString(),
                    icon: Icons.event_available_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceRosterScreen(
                          repo: repo,
                          session: r,
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
  late Future<List<Map<String, dynamic>>> data;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    data = widget.repo.attendanceRoster(widget.session['id'].toString());
  }

  Future<void> mark(Map<String, dynamic> r, String status) async {
    try {
      await widget.repo.markAttendance(
        sessionId: widget.session['id'].toString(),
        studentId: r['student_id'].toString(),
        status: status,
        recordId: r['record_id']?.toString(),
      );
      if (mounted) {
        setState(refresh);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SaiPage(
        title: 'سجل الحضور',
        subtitle: widget.session['attendance_date']?.toString(),
        children: [
          if (widget.session['status'] != 'open')
            const Text(
              'هذه الجلسة مغلقة للقراءة فقط',
              style: TextStyle(color: SaiColors.red),
            ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: data,
            builder: (context, s) {
              if (s.hasError) {
                return Text('لا يمكن تحميل الكشف: ${s.error}');
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: [
                  for (final r in s.data!)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['full_name']?.toString() ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                                'الحالة: ${r['attendance_status'] ?? 'لم يُسجل'}'),
                            if (widget.session['status'] == 'open')
                              Wrap(
                                spacing: 5,
                                children: [
                                  for (final option in const [
                                    ('present', 'حاضر'),
                                    ('absent', 'غائب'),
                                    ('late', 'متأخر'),
                                    ('excused', 'بعذر'),
                                  ])
                                    ActionChip(
                                      label: Text(option.$2),
                                      onPressed: () => mark(r, option.$1),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );
}
