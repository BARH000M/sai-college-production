import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

import '../data/sai_repository.dart';
import '../widgets/sai_async_list.dart';

class RosterScreen extends StatelessWidget {
  const RosterScreen({super.key, required this.repo, required this.classRow});

  final SaiRepository repo;
  final Map<String, dynamic> classRow;

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: 'كشف طلاب الصف',
        subtitle: classRow['name']?.toString(),
        children: [
          SaiCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('كلية ساي التعليمية اليمنية الصينية',
                    style: SaiTextStyles.bodyStrong),
                const Text('也门赛艾教育学院',
                    style: TextStyle(color: SaiColors.gold, fontSize: 11)),
                const Divider(height: 18),
                SaiDetailRow(label: 'الصف', value: '${classRow['name'] ?? '—'}'),
                SaiDetailRow(
                    label: 'البرنامج', value: '${classRow['program'] ?? '—'}'),
                SaiDetailRow(
                    label: 'السعة', value: '${classRow['capacity'] ?? '—'}'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SaiSectionTitle(title: 'الطلاب المسجلون'),
          SaiAsyncList(
            load: () => repo.students(classId: classRow['id']?.toString()),
            emptyIcon: Icons.people_outline,
            emptyTitle: 'لا يوجد طلاب ظاهرون',
            emptyMessage: 'لا يظهر أي طالب في هذا الصف وفق سياسات الوصول الحالية.',
            builder: (rows) => Column(
              children: [
                for (final row in rows)
                  SaiListTile(
                    title: row['full_name']?.toString() ?? '',
                    subtitle:
                        'رقم القيد: ${row['admission_no'] ?? ''} · ${row['status'] ?? ''}',
                    icon: Icons.person_outline,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'الحضور الفعلي متاح من شاشة الحضور عند نشر migration 006 وتفعيل صلاحياته.',
            style: SaiTextStyles.caption,
          ),
        ],
      );
}