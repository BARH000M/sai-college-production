import 'package:flutter/material.dart';

import '../typography/sai_text_styles.dart';
import 'sai_page_body.dart';

/// Full page shell: compact app bar plus a centred, max-width scroll body.
///
/// Replaces the hand-written `Scaffold + AppBar + ListView` blocks so every
/// pushed screen shares the same header rhythm, safe-area handling and gutter.
class SaiPageScaffold extends StatelessWidget {
  const SaiPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions,
    this.maxWidth = 920,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 26),
    this.bottomBar,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  /// Optional pinned bar rendered below the scroll area (see
  /// `SaiBottomActionBar`).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SaiTextStyles.screenTitle,
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SaiTextStyles.caption,
              ),
          ],
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SaiPageBody(padding: padding, children: children),
          ),
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}