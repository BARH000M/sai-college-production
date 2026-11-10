import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import '../data/sai_repository.dart';

class StudentScreen extends StatelessWidget {
  const StudentScreen({super.key, required this.repo});
  final SaiRepository repo;

  @override
  Widget build(BuildContext context) => SaiPage(
        title: 'ملفات الطلاب',
        children: [
          AsyncList(
            future: repo.students(),
            builder: (rows) => Column(
              children: [
                for (final r in rows)
                  SaiTile(
                    title: r['full_name']?.toString() ?? '',
                    subtitle:
                        '${r['admission_no'] ?? ''} · ${r['status'] ?? ''}',
                    icon: Icons.person_outline,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SaiPage(
                          title: 'ملف الطالب',
                          children: [
                            SaiTile(
                                title: 'الاسم',
                                subtitle: r['full_name']?.toString(),
                                icon: Icons.person_outline),
                            SaiTile(
                                title: 'رقم القيد',
                                subtitle: r['admission_no']?.toString(),
                                icon: Icons.badge_outlined),
                            SaiTile(
                                title: 'الحالة',
                                subtitle: r['status']?.toString(),
                                icon: Icons.info_outline),
                          ],
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
