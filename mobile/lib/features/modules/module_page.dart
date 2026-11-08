import 'package:flutter/material.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/feature_catalog.dart';
import '../../core/sai_theme.dart';
import '../students/student_records_page.dart';

class ModulePage extends StatelessWidget {
  const ModulePage({super.key, required this.module, required this.identity, required this.role});

  final FeatureModule module;
  final AppIdentity identity;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    if (module.id == 'students' && (role == AppRole.student || role == AppRole.parent)) {
      return StudentRecordsPage(identity: identity, role: role);
    }
    return Scaffold(
      appBar: AppBar(title: Text(module.label)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(radius: 26, backgroundColor: const Color(0xFFFFE9EC), foregroundColor: SaiColors.red, child: Icon(module.icon)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(module.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        Text(module.pillar, style: const TextStyle(color: SaiColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('أقسام الوحدة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...module.tabs.map((tab) => Card(
                child: ListTile(
                  leading: const Icon(Icons.article_outlined, color: SaiColors.navy),
                  title: Text(tab),
                ),
              )),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: SaiColors.border)),
            child: const Text(
              'هذه شاشة تأسيسية للوحدة. ربط القوائم والعمليات يتم مباشرةً بالخدمات الحالية، مع إبقاء صلاحيات قاعدة البيانات هي المرجع النهائي.',
              style: TextStyle(color: SaiColors.muted, height: 1.8),
            ),
          ),
        ],
      ),
    );
  }
}
