import 'package:flutter/material.dart';

import 'package:sai_college_mobile/core/sai_theme.dart';
import '../typography/sai_text_styles.dart';

/// Standard loading / error / empty switch used by every data-backed screen.
class SaiAsyncState extends StatelessWidget {
  const SaiAsyncState({
    super.key,
    required this.loading,
    required this.child,
    this.error,
    this.onRetry,
    this.isEmpty = false,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'لا توجد بيانات متاحة',
    this.emptyMessage = 'لم يتم العثور على سجلات لعرضها في الوقت الحالي.',
    this.errorTitle = 'تعذّر تحميل البيانات',
  });

  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final bool isEmpty;
  final Widget child;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String errorTitle;

  @override
  Widget build(BuildContext context) {
    if (loading) return const SaiLoadingState();
    if (error != null) {
      return SaiErrorState(title: errorTitle, message: error!, onRetry: onRetry);
    }
    if (isEmpty) {
      return SaiEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }
    return child;
  }
}

/// Spinner with the standard padding and stroke weight.
class SaiLoadingState extends StatelessWidget {
  const SaiLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: SaiColors.maroon,
            ),
          ),
        ),
      );
}

/// Failure state with an optional retry action.
class SaiErrorState extends StatelessWidget {
  const SaiErrorState({
    super.key,
    required this.message,
    this.title = 'تعذّر تحميل البيانات',
    this.onRetry,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

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
                color: SaiColors.dangerTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_outlined,
                  size: 24, color: SaiColors.danger),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: SaiTextStyles.bodyStrong.copyWith(fontSize: 15)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center, style: SaiTextStyles.caption),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 190,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 17),
                  label: const Text('إعادة المحاولة'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty result state card.
class SaiEmptyState extends StatelessWidget {
  const SaiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

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
              color: SaiColors.goldTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 23, color: SaiColors.gold),
          ),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: SaiTextStyles.cardTitle),
          const SizedBox(height: 5),
          Text(message,
              textAlign: TextAlign.center, style: SaiTextStyles.caption),
        ],
      ),
    );
  }
}