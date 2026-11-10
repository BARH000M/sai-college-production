import 'package:flutter/material.dart';

class SaiAsyncState extends StatelessWidget {
  const SaiAsyncState(
      {super.key,
      required this.loading,
      required this.child,
      this.error,
      this.onRetry,
      this.isEmpty = false});
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final bool isEmpty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error!, textAlign: TextAlign.center),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ));
    }
    if (isEmpty) return const Center(child: Text('لا توجد بيانات متاحة'));
    return child;
  }
}
