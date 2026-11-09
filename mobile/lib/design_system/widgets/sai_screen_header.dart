import 'package:flutter/material.dart';

import '../typography/sai_text_styles.dart';
import 'sai_logo.dart';

/// Header for screens embedded inside the tab shell: crest, title, subtitle and
/// optional trailing actions.
class SaiScreenHeader extends StatelessWidget {
  const SaiScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.logoSize = 46,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        children: [
          SaiLogo(size: logoSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SaiTextStyles.screenTitle),
                if (subtitle != null)
                  Text(subtitle!, style: SaiTextStyles.caption),
              ],
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}