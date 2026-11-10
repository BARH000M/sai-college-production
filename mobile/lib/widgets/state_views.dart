import 'package:flutter/material.dart';

import '../core/sai_theme.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: SaiColors.maroon),
          ),
        ),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState(
      {super.key,
      required this.message,
      required this.onRetry,
      this.title = 'تعذّر تحميل البيانات'});

  final String message;
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                  color: SaiColors.dangerTint, shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_outlined,
                  size: 24, color: SaiColors.danger),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: SaiColors.ink)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5, color: SaiColors.muted, height: 1.7)),
            const SizedBox(height: 16),
            SizedBox(
              width: 190,
              child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text('إعادة المحاولة')),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaiColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
                color: SaiColors.goldTint, shape: BoxShape.circle),
            child: Icon(icon, size: 23, color: SaiColors.gold),
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: SaiColors.ink)),
          const SizedBox(height: 5),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11.5, color: SaiColors.muted, height: 1.7)),
        ],
      ),
    );
  }
}

/// Info banner used for form notes and validation summaries.
class NoteBanner extends StatelessWidget {
  const NoteBanner(
      {super.key,
      required this.message,
      this.color = SaiColors.warning,
      this.tint = SaiColors.warningTint,
      this.icon = Icons.info_outline});

  final String message;
  final Color color;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.22))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 11,
                    height: 1.7,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
