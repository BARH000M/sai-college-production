import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

import '../data/sai_repository.dart';
import '../models/roles.dart';
import '../widgets/sai_async_list.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key, required this.repo, required this.open});

  final SaiRepository repo;
  final void Function(Feature) open;

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: 'المقررات والدروس',
        subtitle: 'الصفوف والبرامج المسجلة',
        children: [
          const SaiSectionTitle(title: 'البرامج الأكاديمية'),
          SaiAsyncList(
            load: repo.classes,
            emptyIcon: Icons.menu_book_outlined,
            emptyTitle: 'لا توجد برامج مسجلة',
            emptyMessage: 'لم تُسجَّل برامج أكاديمية لهذا الحساب بعد.',
            builder: (rows) => Column(
              children: [
                for (final row in rows)
                  SaiListTile(
                    title: row['name']?.toString() ?? 'صف',
                    subtitle:
                        '${row['program'] ?? ''} · السعة ${row['capacity'] ?? '—'}',
                    icon: Icons.menu_book_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseDetailScreen(row: row, repo: repo),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.row, required this.repo});

  final Map<String, dynamic> row;
  final SaiRepository repo;

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: row['name']?.toString() ?? 'المقرر',
        subtitle: 'بيانات البرنامج',
        children: [
          SaiCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                SaiDetailRow(
                  label: 'البرنامج',
                  value: row['program']?.toString() ?? '—',
                  icon: Icons.school_outlined,
                ),
                SaiDetailRow(
                  label: 'السعة',
                  value: '${row['capacity'] ?? '—'}',
                  icon: Icons.people_outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SaiCard(
            padding: EdgeInsets.all(16),
            child: Text(
              'لم يتم العثور على جداول محتوى الدروس في مخطط 001–007 المراجع. لا يتم عرض دروس وهمية؛ اربط وحدة المحتوى عند اعتماد مخططها.',
              style: SaiTextStyles.body,
            ),
          ),
        ],
      );
}