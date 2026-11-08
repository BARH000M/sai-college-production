import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sai_theme.dart';
import '../../widgets/metric_tile.dart';

/// Real study metrics for one student, assembled from the same tables the web
/// portal reads. Each block is isolated so one restricted query cannot hide the
/// others.
class StudentStats {
  const StudentStats({
    required this.attendancePresent,
    required this.attendanceTotal,
    required this.averageScore,
    required this.gradedCount,
    required this.completedLessons,
    required this.totalLessons,
    required this.announcements,
  });

  final int attendancePresent;
  final int attendanceTotal;
  final int? averageScore;
  final int gradedCount;
  final int completedLessons;
  final int totalLessons;
  final int announcements;

  static const empty = StudentStats(
    attendancePresent: 0,
    attendanceTotal: 0,
    averageScore: null,
    gradedCount: 0,
    completedLessons: 0,
    totalLessons: 0,
    announcements: 0,
  );

  int? get attendancePercent =>
      attendanceTotal == 0 ? null : ((attendancePresent / attendanceTotal) * 100).round();
}

Future<StudentStats> loadStudentStats(SupabaseClient client, String studentId) async {
  var present = 0;
  var attendanceTotal = 0;
  int? average;
  var graded = 0;
  var completed = 0;
  var totalLessons = 0;
  var announcements = 0;

  try {
    final rows = await client.from('attendance_records').select('status').eq('student_id', studentId);
    for (final row in rows as List) {
      final status = (row as Map<String, dynamic>)['status'];
      attendanceTotal++;
      if (status == 'present' || status == 'late') present++;
    }
  } catch (_) {
    // Restricted or empty — keep zeroes.
  }

  try {
    final rows = await client.from('learning_homework_submissions').select('score').eq('student_id', studentId);
    var sum = 0;
    var count = 0;
    for (final row in rows as List) {
      final score = (row as Map<String, dynamic>)['score'];
      if (score is num) {
        sum += score.toInt();
        count++;
      }
    }
    if (count > 0) {
      average = (sum / count).round();
      graded = count;
    }
  } catch (_) {
    // Ignore.
  }

  try {
    final rows = await client
        .from('learning_lesson_progress')
        .select('lesson_id,status')
        .eq('student_id', studentId)
        .eq('status', 'completed');
    completed = (rows as List).length;
  } catch (_) {
    // Ignore.
  }

  try {
    final rows = await client.from('learning_lessons').select('id');
    totalLessons = (rows as List).length;
  } catch (_) {
    // Ignore.
  }

  try {
    final rows = await client.from('cms_news').select('id').eq('is_published', true);
    announcements = (rows as List).length;
  } catch (_) {
    // Ignore.
  }

  return StudentStats(
    attendancePresent: present,
    attendanceTotal: attendanceTotal,
    averageScore: average,
    gradedCount: graded,
    completedLessons: completed,
    totalLessons: totalLessons,
    announcements: announcements,
  );
}

/// The four metric squares that appear under a student card in the mockup.
class StudentMetricRow extends StatelessWidget {
  const StudentMetricRow({super.key, required this.stats, this.compact = false});

  final StudentStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final percent = stats.attendancePercent;
    return MetricRow(
      tiles: [
        MetricTile(
          icon: Icons.event_available_outlined,
          label: 'الحضور',
          value: '${stats.attendancePresent}/${stats.attendanceTotal}',
          sub: percent == null ? 'لا سجلات' : '$percent%',
          color: SaiColors.success,
          tint: SaiColors.successTint,
        ),
        MetricTile(
          icon: Icons.grade_outlined,
          label: 'الدرجات',
          value: stats.averageScore == null ? '—' : '${stats.averageScore}%',
          sub: '${stats.gradedCount} مُصحّح',
          color: SaiColors.warning,
          tint: SaiColors.warningTint,
        ),
        MetricTile(
          icon: Icons.menu_book_outlined,
          label: 'الدروس',
          value: '${stats.completedLessons}/${stats.totalLessons}',
          sub: 'مكتملة',
          color: SaiColors.maroon,
          tint: SaiColors.maroonTint,
        ),
        MetricTile(
          icon: Icons.campaign_outlined,
          label: 'الإعلانات',
          value: '${stats.announcements}',
          sub: 'إعلان منشور',
          color: SaiColors.gold,
          tint: SaiColors.goldTint,
        ),
      ],
    );
  }
}