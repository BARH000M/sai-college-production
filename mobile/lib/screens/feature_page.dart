import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

import '../models/roles.dart';

class FeaturePage extends StatelessWidget {
  const FeaturePage({super.key, required this.feature});

  final Feature feature;

  String get _name => switch (feature) {
        Feature.finance => 'الرسوم والمالية',
        Feature.staff => 'شؤون الموظفين',
        Feature.admissions => 'القبول والتسجيل',
        Feature.library => 'المكتبة',
        Feature.content => 'إدارة المحتوى',
        Feature.users => 'المستخدمون',
        _ => 'الخدمة',
      };

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: _name,
        children: [
          SaiCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: SaiColors.maroonTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings_outlined,
                      color: SaiColors.maroon, size: 26),
                ),
                const SizedBox(height: 14),
                Text(_name, style: SaiTextStyles.screenTitle),
                const SizedBox(height: 6),
                const Text(
                  'هذه الوحدة ليست موصولة بواجهة بيانات موثقة بعد. لن نعرض بيانات تجريبية أو ننفذ عمليات غير معتمدة.',
                  textAlign: TextAlign.center,
                  style: SaiTextStyles.body,
                ),
              ],
            ),
          ),
        ],
      );
}