import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import '../models/roles.dart';
import '../core/theme.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key, required this.open});
  final void Function(Feature) open;

  @override
  Widget build(BuildContext context) {
    const modules = [
      ('الاستماع', 'استمع وميّز النغمات', Icons.headphones),
      ('التحدث', 'تدريب النطق', Icons.mic_none),
      ('القراءة', 'فهم النصوص', Icons.auto_stories_outlined),
      ('الكتابة', 'تدريب الحروف', Icons.draw_outlined),
      ('المفردات', 'مراجعة الكلمات', Icons.translate),
      ('المراجعة', 'مراجعة متباعدة', Icons.replay_outlined),
    ];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SaiHeader(
            title: 'تعلم اللغة الصينية',
            subtitle: 'استمع · تحدث · اقرأ · اكتب'),
        Card(
          color: SaiColors.red,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('中文学习',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold)),
                const Text('تعلّم بخطوات صغيرة كل يوم',
                    style: TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: SaiColors.red),
                  onPressed: () => open(Feature.courses),
                  child: const Text('استكشف المقررات'),
                ),
              ],
            ),
          ),
        ),
        const SaiSection(title: 'مهارات اللغة'),
        LayoutBuilder(
          builder: (context, c) => GridView.count(
            crossAxisCount: c.maxWidth > 650 ? 3 : 2,
            childAspectRatio: 1.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              for (final m in modules)
                Card(
                  child: InkWell(
                    onTap: () => open(Feature.courses),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(m.$3, color: SaiColors.red),
                          const Spacer(),
                          Text(m.$1,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(m.$2,
                              style: const TextStyle(
                                  fontSize: 11, color: SaiColors.muted)),
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
}
