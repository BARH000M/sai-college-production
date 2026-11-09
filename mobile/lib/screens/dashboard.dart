import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

import '../data/sai_repository.dart';
import '../models/roles.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.roles,
    required this.repo,
    required this.open,
  });

  final Set<AppRole> roles;
  final SaiRepository repo;
  final void Function(Feature) open;

  @override
  Widget build(BuildContext context) {
    final allowed = allowedFeatures(roles);
    final items = <({Feature feature, String title, IconData icon})>[
      (feature: Feature.classes, title: 'الصفوف', icon: Icons.meeting_room_outlined),
      (feature: Feature.courses, title: 'المقررات', icon: Icons.menu_book_outlined),
      (feature: Feature.learning, title: 'تعلم الصينية', icon: Icons.translate),
      (feature: Feature.student, title: 'الطلاب', icon: Icons.people_outline),
      (feature: Feature.finance, title: 'الرسوم', icon: Icons.payments_outlined),
      (feature: Feature.attendance, title: 'الحضور', icon: Icons.fact_check_outlined),
      (feature: Feature.content, title: 'المحتوى', icon: Icons.edit_note),
      (feature: Feature.library, title: 'المكتبة', icon: Icons.local_library_outlined),
    ];
    final visible = items.where((item) => allowed.contains(item.feature)).toList();

    return SaiPageBody(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
      children: [
        const SaiScreenHeader(
          title: 'مرحباً بك في كلية ساي',
          subtitle: 'لوحتك الأكاديمية والإدارية',
        ),
        const SaiSectionTitle(
          title: 'نظرة عامة',
          padding: EdgeInsetsDirectional.only(start: 2, top: 12, bottom: 8),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: repo.classes(),
          builder: (context, snapshot) {
            final value = snapshot.hasData ? '${snapshot.data!.length}' : '—';
            return Row(
              children: [
                Expanded(
                  child: SaiMetricCard(
                    value: value,
                    label: 'الصفوف المتاحة',
                    icon: Icons.school_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SaiMetricCard(
                    value: '${roles.length}',
                    label: 'الأدوار المعتمدة',
                    icon: Icons.verified_user_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SaiSectionTitle(
          title: 'الوصول السريع',
          padding: EdgeInsetsDirectional.only(start: 2, top: 16, bottom: 8),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 650;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wide ? 4 : 2,
                childAspectRatio: wide ? 2.1 : 1.55,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final item = visible[index];
                return SaiCard(
                  onTap: () => open(item.feature),
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(item.icon, color: SaiColors.maroon, size: 26),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SaiTextStyles.bodyStrong,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 14),
        SaiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الأدوار النشطة', style: SaiTextStyles.cardTitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final role in roles) Chip(label: Text(role.arabic)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}