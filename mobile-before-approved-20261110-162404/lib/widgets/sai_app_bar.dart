import 'package:flutter/material.dart';

import '../core/sai_theme.dart';

/// Header used by every screen in the mockup: official crest, bilingual brand
/// title, notification bell and the hamburger that opens the side menu.
AppBar saiAppBar(
  BuildContext context, {
  required VoidCallback onMenu,
  VoidCallback? onNotifications,
  bool showBack = false,
  bool showBell = true,
  String? title,
}) {
  return AppBar(
    toolbarHeight: 64,
    automaticallyImplyLeading: false,
    backgroundColor: SaiColors.cream,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    titleSpacing: 14,
    title: Row(
      children: [
        if (showBack)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.arrow_forward, size: 20, color: SaiColors.ink),
              ),
            ),
          ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SaiColors.border),
          ),
          padding: const EdgeInsets.all(3),
          child: Image.asset('assets/images/sai-logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title ?? 'كلية ساي التعليمية اليمنية الصينية',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: SaiColors.ink, height: 1.35),
              ),
              const SizedBox(height: 1),
              const Text(
                '世门赛艾教育学院',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: SaiColors.gold, height: 1.3),
              ),
            ],
          ),
        ),
        if (showBell)
          IconButton(
            onPressed: onNotifications,
            visualDensity: VisualDensity.compact,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, size: 22, color: SaiColors.ink),
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: SaiColors.maroon,
                      shape: BoxShape.circle,
                      border: Border.all(color: SaiColors.cream, width: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        IconButton(
          onPressed: onMenu,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.menu, size: 23, color: SaiColors.ink),
        ),
        const SizedBox(width: 2),
      ],
    ),
  );
}