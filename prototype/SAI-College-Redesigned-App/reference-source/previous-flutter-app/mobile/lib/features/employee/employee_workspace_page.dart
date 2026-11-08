import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../shared/data_state.dart';

class EmployeeWorkspacePage extends StatefulWidget {
  const EmployeeWorkspacePage({super.key, required this.api});
  final SchoolApi api;
  @override
  State<EmployeeWorkspacePage> createState() => _EmployeeWorkspacePageState();
}

class _EmployeeWorkspacePageState extends State<EmployeeWorkspacePage> {
  EmployeeWorkspace? _data;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.employeeWorkspace();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحميل ملف الموظف.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => DataStateView(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: Builder(builder: (context) {
        final data = _data!;
        return DefaultTabController(
            length: 3,
            child: Column(children: [
              PageHeader(
                  title: data.employee.fullName,
                  subtitle:
                      '${data.employee.employmentType} · ${data.employee.employeeNo}\nالحالة: ${data.employee.status} · الالتحاق: ${data.employee.hireDate}',
                  icon: Icons.badge_outlined),
              const TabBar(tabs: [
                Tab(text: 'الملخص'),
                Tab(text: 'دوامي'),
                Tab(text: 'إجازاتي')
              ]),
              Expanded(
                  child: TabBarView(children: [
                _summary(data),
                _attendance(data),
                _leaves(data)
              ])),
            ]));
      }));
  Widget _summary(EmployeeWorkspace data) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Card(
            color: Color(0xFFE8F2ED),
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'هذه صفحة قراءة لبياناتك المرتبطة. طلبات الإجازة الجديدة تسجّلها الإدارة وفق صلاحيات النظام الحالية؛ لا يعرض التطبيق إجراءً غير مصرح به.'))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.access_time_outlined),
                title: const Text('سجلات الدوام'),
                trailing: Text('${data.attendance.length}'))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('طلبات الإجازة'),
                trailing: Text('${data.leaves.length}'))),
      ]);
  Widget _attendance(EmployeeWorkspace data) => data.attendance.isEmpty
      ? const EmptyState(
          icon: Icons.access_time_outlined, title: 'لا سجلات دوام متاحة')
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: data.attendance.length,
          itemBuilder: (context, index) {
            final item = data.attendance[index];
            return Card(
                child: ListTile(
                    title: Text(item.date),
                    subtitle: Text(
                        'الدخول: ${item.checkIn ?? '—'} · الانصراف: ${item.checkOut ?? '—'}'),
                    trailing: Text(item.status)));
          });
  Widget _leaves(EmployeeWorkspace data) => data.leaves.isEmpty
      ? const EmptyState(
          icon: Icons.event_busy_outlined, title: 'لا طلبات إجازة متاحة')
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: data.leaves.length,
          itemBuilder: (context, index) {
            final item = data.leaves[index];
            return Card(
                child: ListTile(
                    title: Text(leaveKindLabel(item.kind)),
                    subtitle: Text(
                        '${item.startDate} إلى ${item.endDate}\n${item.reason}'),
                    trailing: Text(leaveStatusLabel(item.status)),
                    isThreeLine: true));
          });
}
