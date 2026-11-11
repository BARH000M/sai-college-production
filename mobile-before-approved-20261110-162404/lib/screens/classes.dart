import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

import '../data/sai_repository.dart';
import '../widgets/sai_async_list.dart';
import 'roster.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key, required this.repo});

  final SaiRepository repo;

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: 'الصفوف',
        subtitle: 'الصفوف المتاحة لحسابك',
        children: [
          SaiAsyncList(
            load: repo.classes,
            emptyIcon: Icons.class_outlined,
            emptyTitle: 'لا توجد صفوف متاحة',
            emptyMessage: 'لم يتم العثور على صفوف مرتبطة بصلاحيات هذا الحساب.',
            builder: (rows) => Column(
              children: [
                for (final row in rows)
                  SaiListTile(
                    title: row['name']?.toString() ?? 'صف',
                    subtitle:
                        '${row['program'] ?? ''} · السعة ${row['capacity'] ?? '—'}',
                    icon: Icons.class_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RosterScreen(repo: repo, classRow: row),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}