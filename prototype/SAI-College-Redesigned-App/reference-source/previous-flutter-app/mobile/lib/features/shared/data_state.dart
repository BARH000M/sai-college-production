import 'package:flutter/material.dart';

class DataStateView extends StatelessWidget {
  const DataStateView(
      {super.key,
      required this.loading,
      required this.error,
      required this.onRetry,
      required this.child});
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 60),
        const Icon(Icons.cloud_off_outlined,
            size: 42, color: Color(0xFF9A3412)),
        const SizedBox(height: 12),
        const Text('تعذّر تحميل البيانات',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.6)),
        const SizedBox(height: 8),
        const Text(
            'لم تُعرض قيمة فارغة أو صفرية بدلاً من البيانات التي تعذّر الوصول إليها.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة')),
      ]);
    }
    return child;
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.icon, required this.title, this.message});
  final IconData icon;
  final String title;
  final String? message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
        child: Column(children: [
          Icon(icon, size: 36, color: Colors.black38),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54, height: 1.5))
          ],
        ]),
      );
}

class PageHeader extends StatelessWidget {
  const PageHeader(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black54, height: 1.4)),
              ])),
        ]),
      );
}

String attendanceLabel(String status) => switch (status) {
      'present' => 'حاضر',
      'late' => 'متأخر',
      'absent' => 'غائب',
      'excused' => 'بعذر',
      'leave' => 'إجازة',
      'holiday' => 'عطلة',
      'remote' => 'عن بعد',
      _ => status,
    };

String leaveStatusLabel(String status) => switch (status) {
      'pending' => 'بانتظار البت',
      'approved' => 'معتمدة',
      'rejected' => 'مرفوضة',
      'cancelled' => 'ملغاة',
      _ => status,
    };

String leaveKindLabel(String kind) => switch (kind) {
      'annual' => 'سنوية',
      'sick' => 'مرضية',
      'unpaid' => 'بدون راتب',
      'maternity' => 'وضع',
      'emergency' => 'طارئة',
      'hajj' => 'حج',
      _ => 'أخرى',
    };
