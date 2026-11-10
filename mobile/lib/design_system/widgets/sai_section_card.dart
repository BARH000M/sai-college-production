import 'package:flutter/material.dart';
import '../theme/sai_tokens.dart';

class SaiSectionCard extends StatelessWidget {
  const SaiSectionCard({super.key, required this.title, required this.child,
    this.onTap, this.icon});
  final String title;
  final Widget child;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Card(
    color: SaiTokens.surface,
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SaiTokens.radius),
      side: const BorderSide(color: Color(0xFFE7E7E3))),
    child: InkWell(
      borderRadius: BorderRadius.circular(SaiTokens.radius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, color: SaiTokens.brand), const SizedBox(width: 8)],
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 12), child,
        ]),
      ),
    ),
  );
}
