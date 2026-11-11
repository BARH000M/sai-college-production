import 'package:flutter/material.dart';

import 'package:sai_college_mobile/design_system/design_system.dart';

/// Loads a list of rows and renders it through [SaiAsyncState], so every screen
/// shares the same spinner, retry and empty treatment.
///
/// Presentation stays in the design system; this widget only handles the
/// future lifecycle and the retry trigger.
class SaiAsyncList extends StatefulWidget {
  const SaiAsyncList({
    super.key,
    required this.load,
    required this.builder,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'لا توجد بيانات متاحة',
    this.emptyMessage = 'لم يتم العثور على سجلات لعرضها في الوقت الحالي.',
    this.errorMessage =
        'تعذّر تحميل البيانات. تحقق من صلاحيات الحساب أو اتصال قاعدة البيانات.',
  });

  final Future<List<Map<String, dynamic>>> Function() load;
  final Widget Function(List<Map<String, dynamic>> rows) builder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String errorMessage;

  @override
  State<SaiAsyncList> createState() => _SaiAsyncListState();
}

class _SaiAsyncListState extends State<SaiAsyncList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return SaiAsyncState(
          loading: loading,
          error: snapshot.hasError
              ? '${widget.errorMessage}\n${snapshot.error}'
              : null,
          isEmpty: !loading && !snapshot.hasError && rows.isEmpty,
          onRetry: _reload,
          emptyIcon: widget.emptyIcon,
          emptyTitle: widget.emptyTitle,
          emptyMessage: widget.emptyMessage,
          child: widget.builder(rows),
        );
      },
    );
  }
}