import 'package:flutter/material.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/feature_catalog.dart';
import '../../core/sai_theme.dart';
import '../../widgets/sai_app_bar.dart';
import '../../widgets/section_header.dart';
import '../learning/vocabulary_bank_page.dart';
import '../students/student_records_page.dart';

class ModulePage extends StatelessWidget {
  const ModulePage({
    super.key,
    required this.module,
    required this.identity,
    required this.role,
    this.embedded = false,
  });

  final FeatureModule module;
  final AppIdentity identity;
  final AppRole role;

  /// When true the module is a bottom-navigator destination and must not add
  /// its own scaffold or header.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    if (module.id == 'students' && (role == AppRole.student || role == AppRole.parent)) {
      return StudentRecordsPage(identity: identity, role: role);
    }
    if (module.id == 'vocabulary') {
      return VocabularyBankPage(identity: identity, role: role);
    }

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
      children: [
        SectionHeader(icon: module.icon, title: module.label),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SaiColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: SaiColors.maroonTint, borderRadius: BorderRadius.circular(12)),
                child: Icon(module.icon, size: 21, color: SaiColors.maroon),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                    const SizedBox(height: 1),
                    Text(module.pillar, style: const TextStyle(fontSize: 10.5, color: SaiColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsetsDirectional.only(start: 4, bottom: 7),
          child: Text('أقسام الوحدة', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: SaiColors.muted)),
        ),
        ...module.tabs.map((tab) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SaiColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.article_outlined, size: 17, color: SaiColors.gold),
                    const SizedBox(width: 9),
                    Expanded(child: Text(tab, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SaiColors.ink))),
                    const Icon(Icons.chevron_left, size: 17, color: SaiColors.muted),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SaiColors.goldTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SaiColors.gold.withOpacity(0.28)),
          ),
          child: const Text(
            'هذه شاشة تأسيسية للوحدة داخل التطبيق. العمليات الكاملة متاحة في بوابة الويب، وتبقى صلاحيات قاعدة البيانات هي المرجع النهائي.',
            style: TextStyle(fontSize: 11, height: 1.8, color: SaiColors.warning, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    if (embedded) return content;

    return Scaffold(
      appBar: saiAppBar(context, showBack: true, onMenu: () {}, showBell: false, title: module.label),
      body: content,
    );
  }
}