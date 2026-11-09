import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key});

  @override
  Widget build(BuildContext context) => SaiPageScaffold(
        title: 'تفاصيل الدرس',
        subtitle: 'المحتوى التعليمي',
        children: [
          SaiCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.play_circle_outline,
                    color: SaiColors.maroon, size: 48),
                const SizedBox(height: 10),
                Text('مشغل الدروس', style: SaiTextStyles.screenTitle),
                const SizedBox(height: 4),
                const Text(
                  'ستظهر المواد والفيديوهات والتدريبات بعد ربط مصدر المحتوى المعتمد.',
                  style: SaiTextStyles.body,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final section in const [
                      'الدرس',
                      'المفردات',
                      'التدريبات',
                      'المصادر',
                    ])
                      Chip(label: Text(section)),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}