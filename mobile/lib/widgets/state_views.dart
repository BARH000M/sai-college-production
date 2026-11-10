import 'package:flutter/material.dart';

import '../design_system/design_system.dart';

/// Feature-screen aliases of the shared design-system states.
///
/// Keeping the names in one place means the loading, error and empty visuals
/// are defined once (`SaiAsyncState` family) and cannot drift per module.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) => const SaiLoadingState();
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'تعذّر تحميل البيانات',
  });

  final String message;
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      SaiErrorState(title: title, message: message, onRetry: onRetry);
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) =>
      SaiEmptyState(icon: icon, title: title, message: message);
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
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 11,
                  height: 1.7,
                  color: color,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
