import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import '../core/theme.dart';

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key});

  @override
  Widget build(BuildContext context) => SaiPage(
        title: 'تفاصيل الدرس',
        subtitle: 'المحتوى التعليمي',
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.play_circle_outline,
                      color: SaiColors.red, size: 54),
                  const SizedBox(height: 12),
                  const Text('مشغل الدروس',
                      style:
                          TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                  const Text(
                      'ستظهر المواد والفيديوهات والتدريبات بعد ربط مصدر المحتوى المعتمد.',
                      style: TextStyle(color: SaiColors.muted)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in [
                        'الدرس',
                        'المفردات',
                        'التدريبات',
                        'المصادر'
                      ])
                        Chip(label: Text(s)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}
