import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

import '../models/roles.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key, required this.open});

  final void Function(Feature) open;

  @override
  Widget build(BuildContext context) {
    const modules = <({String title, String subtitle, IconData icon})>[
      (title: 'الاستماع', subtitle: 'استمع وميّز النغمات', icon: Icons.headphones),
      (title: 'التحدث', subtitle: 'تدريب النطق', icon: Icons.mic_none),
      (title: 'القراءة', subtitle: 'فهم النصوص', icon: Icons.auto_stories_outlined),
      (title: 'الكتابة', subtitle: 'تدريب الحروف', icon: Icons.draw_outlined),
      (title: 'المفردات', subtitle: 'مراجعة الكلمات', icon: Icons.translate),
      (title: 'المراجعة', subtitle: 'مراجعة متباعدة', icon: Icons.replay_outlined),
    ];

    return SaiPageBody(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
      children: [
        const SaiScreenHeader(
          title: 'تعلم اللغة الصينية',
          subtitle: 'استمع · تحدث · اقرأ · اكتب',
        ),
        SaiCard(
          backgroundColor: SaiColors.maroon,
          borderColor: SaiColors.maroonDeep,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '中文学习',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'تعلّم بخطوات صغيرة كل يوم',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: SaiColors.maroon,
                  minimumSize: const Size(150, 42),
                ),
                onPressed: () => open(Feature.courses),
                child: const Text('استكشف المقررات'),
              ),
            ],
          ),
        ),
        const SaiSectionTitle(
          title: 'مهارات اللغة',
          padding: EdgeInsetsDirectional.only(start: 2, top: 16, bottom: 8),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 650;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wide ? 3 : 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                return SaiCard(
                  onTap: () => open(Feature.courses),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(module.icon, color: SaiColors.maroon, size: 22),
                      const Spacer(),
                      Text(
                        module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SaiTextStyles.bodyStrong,
                      ),
                      Text(
                        module.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SaiTextStyles.caption,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}