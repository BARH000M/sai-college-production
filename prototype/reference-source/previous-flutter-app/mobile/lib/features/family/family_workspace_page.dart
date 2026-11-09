import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/profile.dart';
import '../../core/api.dart';
import '../shared/data_state.dart';

class FamilyWorkspacePage extends StatefulWidget {
  const FamilyWorkspacePage(
      {super.key, required this.api, required this.profile});
  final SchoolApi api;
  final Profile profile;
  @override
  State<FamilyWorkspacePage> createState() => _FamilyWorkspacePageState();
}

class _FamilyWorkspacePageState extends State<FamilyWorkspacePage> {
  List<StudentRecord> _students = const [];
  StudentRecord? _student;
  List<AttendanceRecord> _attendance = const [];
  List<AssignmentRecord> _assignments = const [];
  List<PublishedResult> _results = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({int? studentId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isParent = widget.profile.role == 'parent';
      final students = await widget.api.linkedStudents(
          studentId: isParent ? null : widget.profile.studentId,
          parent: isParent);
      final selectedId = studentId ??
          _student?.id ??
          (students.isEmpty ? null : students.first.id);
      final selected =
          students.where((item) => item.id == selectedId).firstOrNull;
      if (selected == null) {
        if (!mounted) return;
        setState(() {
          _students = students;
          _student = null;
          _attendance = const [];
          _assignments = const [];
          _results = const [];
          _loading = false;
        });
        return;
      }
      final values = await Future.wait<dynamic>([
        widget.api.studentAttendance(selected.id),
        widget.api.classAssignments(selected.classId),
        widget.api.publishedResults(selected.id),
      ]);
      if (!mounted) return;
      setState(() {
        _students = students;
        _student = selected;
        _attendance = values[0] as List<AttendanceRecord>;
        _assignments = values[1] as List<AssignmentRecord>;
        _results = values[2] as List<PublishedResult>;
        _loading = false;
      });
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
          _error = 'تعذّر تحميل بيانات الطالب. لم نعرض بيانات بديلة.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => DataStateView(
      loading: _loading,
      error: _error,
      onRetry: () => _load(),
      child: Builder(builder: (context) {
        if (_student == null) {
          return const EmptyState(
              icon: Icons.family_restroom_outlined,
              title: 'لا يوجد طالب مرتبط بهذا الحساب',
              message:
                  'تواصل مع إدارة المدرسة لربط ملف الطالب بحساب ولي الأمر.');
        }
        return DefaultTabController(
            length: 4,
            child: Column(children: [
              PageHeader(
                  title: _student!.fullName,
                  subtitle:
                      'القيد: ${_student!.admissionNo ?? 'غير متاح'} · البيانات المعروضة تخص الطالب المحدد فقط.',
                  icon: Icons.school_outlined),
              if (_students.length > 1)
                SizedBox(
                    height: 48,
                    child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: _students
                            .map((student) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                    label: Text(student.fullName),
                                    selected: student.id == _student!.id,
                                    onSelected: (_) =>
                                        _load(studentId: student.id))))
                            .toList())),
              const TabBar(isScrollable: true, tabs: [
                Tab(text: 'الملخص'),
                Tab(text: 'الحضور'),
                Tab(text: 'الواجبات'),
                Tab(text: 'النتائج المنشورة')
              ]),
              Expanded(
                  child: TabBarView(children: [
                _summary(),
                _attendanceTab(),
                _assignmentsTab(),
                _resultsTab()
              ])),
            ]));
      }));

  Widget _summary() => ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(_student!.fullName),
                subtitle: Text(_student!.admissionNo ?? 'لا يوجد رقم قيد'))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('سجلات الحضور المتاحة'),
                trailing: Text('${_attendance.length}'))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('واجبات الفصل'),
                trailing: Text('${_assignments.length}'))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('نتائج منشورة'),
                subtitle: const Text('لا تظهر درجات الاختبارات غير المنشورة.'),
                trailing: Text('${_results.length}'))),
      ]);

  Widget _attendanceTab() => _attendance.isEmpty
      ? const EmptyState(
          icon: Icons.fact_check_outlined, title: 'لا سجلات حضور متاحة')
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _attendance.length,
          itemBuilder: (context, index) {
            final item = _attendance[index];
            return Card(
                child: ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(item.date),
                    trailing: Text(attendanceLabel(item.status))));
          },
        );

  Widget _assignmentsTab() => _assignments.isEmpty
      ? const EmptyState(
          icon: Icons.assignment_outlined, title: 'لا واجبات منشورة لهذا الفصل')
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _assignments.length,
          itemBuilder: (context, index) {
            final item = _assignments[index];
            return Card(
                child: ListTile(
                    title: Text(item.title),
                    subtitle: Text(
                        '${item.subject}\n${item.description}\nآخر موعد: ${item.dueDate}'),
                    trailing: Text('${item.maxMarks} درجة'),
                    isThreeLine: true));
          },
        );

  Widget _resultsTab() => _results.isEmpty
      ? const EmptyState(
          icon: Icons.workspace_premium_outlined,
          title: 'لا نتائج منشورة حالياً',
          message:
              'قد توجد اختبارات لم تنشرها المدرسة بعد؛ لا يعرض التطبيق درجاتها.')
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final item = _results[index];
            return Card(
                child: ListTile(
                    title: Text(item.term == null || item.term!.isEmpty
                        ? item.subject
                        : '${item.subject} · ${item.term}'),
                    subtitle: Text('${item.subject} · ${item.examDate}'),
                    trailing: Text('${item.marks} / ${item.maxMarks}')));
          },
        );
}
