import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/sai_theme.dart';
import '../../widgets/sai_app_bar.dart';
import '../../widgets/section_header.dart';

class _Notice {
  const _Notice({
    required this.id,
    required this.title,
    required this.detail,
    required this.at,
    required this.icon,
    required this.tint,
  });

  final String id;
  final String title;
  final String detail;
  final DateTime at;
  final IconData icon;
  final Color tint;
}

class _NoticeGroup {
  const _NoticeGroup(
      {required this.label, required this.hint, required this.items});
  final String label;
  final String hint;
  final List<_Notice> items;
}

/// Mobile notifications centre, grouped by day exactly like the web centre so a
/// teacher can scan yesterday's items without reading the whole list.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage(
      {super.key, required this.identity, required this.role});

  final AppIdentity identity;
  final AppRole role;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<_Notice>> _future;

  bool get _isStaff => const {
        AppRole.superAdmin,
        AppRole.admin,
        AppRole.teacher,
        AppRole.receptionist,
      }.contains(widget.role);

  bool get _isLearner =>
      widget.role == AppRole.student || widget.role == AppRole.parent;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_Notice>> _load() async {
    final client = Supabase.instance.client;
    final items = <_Notice>[];

    if (_isStaff) {
      final enquiries = await client
          .from('admissions_enquiries')
          .select('id,applicant_full_name,preferred_program,created_at')
          .eq('status', 'new')
          .order('created_at', ascending: false)
          .limit(20);
      for (final row in enquiries as List) {
        final map = row as Map<String, dynamic>;
        items.add(_Notice(
          id: 'admissions-${map['id']}',
          title:
              'طلب قبول جديد: ${(map['applicant_full_name'] as String?) ?? 'متقدم'}',
          detail:
              (map['preferred_program'] as String?)?.trim().isNotEmpty == true
                  ? 'البرنامج: ${map['preferred_program']}'
                  : 'بانتظار أول تواصل من فريق القبول',
          at: _parseDate(map['created_at']),
          icon: Icons.person_add_alt_1_outlined,
          tint: SaiColors.red,
        ));
      }
    }

    final submissions = await client
        .from('learning_homework_submissions')
        .select('id,homework_id,status,score,submitted_at,graded_at')
        .eq('status', _isStaff ? 'submitted' : 'graded')
        .order(_isStaff ? 'submitted_at' : 'graded_at', ascending: false)
        .limit(20);

    final homeworkIds = <String>{};
    final submissionRows = <Map<String, dynamic>>[];
    for (final row in submissions as List) {
      final map = row as Map<String, dynamic>;
      submissionRows.add(map);
      final homeworkId = map['homework_id'];
      if (homeworkId is String) homeworkIds.add(homeworkId);
    }

    final titles = <String, String>{};
    if (homeworkIds.isNotEmpty) {
      final homework = await client
          .from('learning_homework')
          .select('id,title')
          .inFilter('id', homeworkIds.toList());
      for (final row in homework as List) {
        final map = row as Map<String, dynamic>;
        titles[(map['id'] as String)] = (map['title'] as String?) ?? 'واجب';
      }
    }

    for (final map in submissionRows) {
      final homeworkTitle = titles[(map['homework_id'] as String?)] ?? 'واجب';
      if (_isStaff) {
        items.add(_Notice(
          id: 'homework-${map['id']}',
          title: 'تسليم بانتظار التصحيح: $homeworkTitle',
          detail: 'بانتظار مراجعة المعلم',
          at: _parseDate(map['submitted_at']),
          icon: Icons.assignment_turned_in_outlined,
          tint: SaiColors.navy,
        ));
      } else if (_isLearner) {
        final score = map['score'];
        items.add(_Notice(
          id: 'grade-${map['id']}',
          title: 'صُحّح واجب: $homeworkTitle',
          detail: score == null
              ? 'صدرت ملاحظات المعلم على تسليمك.'
              : 'الدرجة $score',
          at: _parseDate(map['graded_at']),
          icon: Icons.rate_review_outlined,
          tint: SaiColors.success,
        ));
      }
    }

    if (_isStaff) {
      final records = await client
          .from('attendance_records')
          .select('id,status,marked_at,student_id')
          .inFilter('status', ['absent', 'late'])
          .order('marked_at', ascending: false)
          .limit(20);
      for (final row in records as List) {
        final map = row as Map<String, dynamic>;
        final late = map['status'] == 'late';
        items.add(_Notice(
          id: 'attendance-${map['id']}',
          title: late ? 'تأخر مسجل' : 'غياب مسجل',
          detail: late
              ? 'سُجّل تأخر طالب في إحدى الحصص.'
              : 'سُجّل غياب طالب في إحدى الحصص.',
          at: _parseDate(map['marked_at']),
          icon: Icons.event_busy_outlined,
          tint: SaiColors.warning,
        ));
      }
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }

  DateTime _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }

  List<_NoticeGroup> _group(List<_Notice> items) {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final startYesterday = startToday.subtract(const Duration(days: 1));
    final startWeek = startToday.subtract(const Duration(days: 6));

    final today = <_Notice>[];
    final yesterday = <_Notice>[];
    final week = <_Notice>[];
    final older = <_Notice>[];

    for (final item in items) {
      if (!item.at.isBefore(startToday)) {
        today.add(item);
      } else if (!item.at.isBefore(startYesterday)) {
        yesterday.add(item);
      } else if (!item.at.isBefore(startWeek)) {
        week.add(item);
      } else {
        older.add(item);
      }
    }

    return [
      if (today.isNotEmpty)
        _NoticeGroup(label: 'اليوم', hint: 'أحدث التحديثات', items: today),
      if (yesterday.isNotEmpty)
        _NoticeGroup(label: 'أمس', hint: 'خلال آخر ٢٤ ساعة', items: yesterday),
      if (week.isNotEmpty)
        _NoticeGroup(label: 'هذا الأسبوع', hint: 'آخر ٧ أيام', items: week),
      if (older.isNotEmpty)
        _NoticeGroup(
            label: 'أقدم من ذلك', hint: 'أرشيف الإشعارات', items: older),
    ];
  }

  String _timeLabel(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
    return '${at.year}/${at.month}/${at.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: saiAppBar(
        context,
        showBack: true,
        onMenu: () {},
        showBell: false,
        title: 'مركز التنبيهات',
      ),
      body: FutureBuilder<List<_Notice>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('تعذر تحميل الإشعارات\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: SaiColors.muted, height: 1.7)),
              ),
            );
          }
          final items = snapshot.data ?? const <_Notice>[];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(26),
                child: Text('لا توجد إشعارات حالياً.',
                    style: TextStyle(color: SaiColors.muted)),
              ),
            );
          }
          final groups = _group(items);
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
            children: [
              SectionHeader(
                icon: Icons.notifications_none,
                title: 'مركز التنبيهات',
                actionLabel: 'تحديث',
                actionIcon: Icons.refresh,
                onAction: () => setState(() => _future = _load()),
              ),
              const SizedBox(height: 12),
              ...groups.map((group) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(group.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: SaiColors.navy,
                                    fontSize: 13)),
                            const SizedBox(width: 8),
                            const Expanded(
                                child: Divider(
                                    color: SaiColors.border, height: 1)),
                            const SizedBox(width: 8),
                            Text('${group.items.length} · ${group.hint}',
                                style: const TextStyle(
                                    fontSize: 10.5, color: SaiColors.muted)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...group.items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 19,
                                        backgroundColor:
                                            item.tint.withValues(alpha: 0.12),
                                        foregroundColor: item.tint,
                                        child: Icon(item.icon, size: 19),
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item.title,
                                                style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: SaiColors.navy)),
                                            const SizedBox(height: 2),
                                            Text(item.detail,
                                                style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: SaiColors.muted,
                                                    height: 1.6)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_timeLabel(item.at),
                                          style: const TextStyle(
                                              fontSize: 10.5,
                                              color: SaiColors.muted)),
                                    ],
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
