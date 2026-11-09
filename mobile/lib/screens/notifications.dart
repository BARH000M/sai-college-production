import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const SaiPageScaffold(
        title: 'الإشعارات',
        subtitle: 'آخر التحديثات الأكاديمية',
        children: [
          SaiEmptyState(
            icon: Icons.notifications_none,
            title: 'لا توجد إشعارات معروضة',
            message: 'يتطلب عرض الإشعارات جدولاً معتمداً وصلاحيات RLS.',
          ),
        ],
      );
}