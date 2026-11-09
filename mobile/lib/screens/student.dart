import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

import '../data/sai_repository.dart';
import '../widgets/sai_async_list.dart';

class StudentScreen extends StatelessWidget {
  const StudentScreen({super.key, required this.repo});

  final SaiRepository repo;

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: 'ملفات الطلاب',
        subtitle: 'سجلات الطلاب المسجلة',
        children: [
          SaiAsyncList(
            load: () => repo.students(),
            emptyIcon: Icons.people_outline,
            emptyTitle: 'لا توجد ملفات طلاب',
            emptyMessage: 'لم يتم العثور على سجلات طلاب مرتبطة بصلاحيات هذا الحساب.',
            builder: (rows) => Column(
              children: [
                for (final row in rows)
                  SaiListTile(
                    title: row['full_name']?.toString() ?? '',
                    subtitle:
                        '${row['admission_no'] ?? ''} · ${row['status'] ?? ''}',
                    icon: Icons.person_outline,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentDetailScreen(row: row),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}

class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: 'ملف الطالب',
        subtitle: row['full_name']?.toString(),
        children: [
          SaiCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                SaiDetailRow(
                  label: 'الاسم',
                  value: row['full_name']?.toString() ?? '—',
                  icon: Icons.person_outline,
                ),
                SaiDetailRow(
                  label: 'رقم القيد',
                  value: row['admission_no']?.toString() ?? '—',
                  icon: Icons.badge_outlined,
                ),
                SaiDetailRow(
                  label: 'الحالة',
                  value: row['status']?.toString() ?? '—',
                  icon: Icons.info_outline,
                ),
              ],
            ),
          ),
        ],
      );
}