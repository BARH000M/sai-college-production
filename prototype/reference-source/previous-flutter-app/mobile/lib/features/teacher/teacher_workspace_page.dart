import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/profile.dart';
import '../../core/api.dart';
import '../shared/data_state.dart';

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class TeacherWorkspacePage extends StatefulWidget {
  const TeacherWorkspacePage(
      {super.key, required this.api, required this.profile});
  final SchoolApi api;
  final Profile profile;
  @override
  State<TeacherWorkspacePage> createState() => _TeacherWorkspacePageState();
}

class _TeacherWorkspacePageState extends State<TeacherWorkspacePage> {
  TeacherWorkspace? _data;
  String? _error;
  bool _loading = true;
  int? _classId;
  late String _date = _isoDate(DateTime.now());
  final Set<int> _saving = {};

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
      final data = await widget.api.teacherWorkspace(widget.profile.teacherId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _classId = data.classes.any((item) => item.id == _classId)
            ? _classId
            : (data.classes.isEmpty ? null : data.classes.first.id);
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
          _error = 'تعذّر تحميل بوابة المعلم.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(_date),
        firstDate: DateTime(2020),
        lastDate: now);
    if (selected != null && mounted) setState(() => _date = _isoDate(selected));
  }

  String? _attendanceStatus(int studentId) {
    for (final row in _data?.attendance ?? const <AttendanceRecord>[]) {
      if (row.studentId == studentId && row.date == _date) return row.status;
    }
    return null;
  }

  Future<void> _saveAttendance(StudentRecord student, String status) async {
    if (_saving.contains(student.id)) return;
    setState(() => _saving.add(student.id));
    try {
      await widget.api.markStudentAttendance(
          studentId: student.id, date: _date, status: status);
      if (!mounted) return;
      final current = _data!;
      final attendance = current.attendance
          .where((row) => !(row.studentId == student.id && row.date == _date))
          .toList()
        ..add(AttendanceRecord(
            id: 0, studentId: student.id, date: _date, status: status));
      setState(() => _data = TeacherWorkspace(
          classes: current.classes,
          slots: current.slots,
          students: current.students,
          attendance: attendance,
          assignments: current.assignments));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ حضور ${student.fullName}.')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يُحفظ الحضور. أعد المحاولة.')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(student.id));
    }
  }

  Future<void> _newAssignment() async {
    final data = _data;
    if (data == null ||
        data.classes.isEmpty ||
        widget.profile.teacherId == null) return;
    final title = TextEditingController();
    final subject = TextEditingController();
    final description = TextEditingController();
    final marks = TextEditingController(text: '10');
    var classId = _classId ?? data.classes.first.id;
    var dueDate = _isoDate(DateTime.now().add(const Duration(days: 7)));
    var saving = false;
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) =>
            StatefulBuilder(builder: (context, setDialogState) {
              Future<void> save() async {
                if (saving) return;
                setDialogState(() => saving = true);
                try {
                  await widget.api.createAssignment(
                    classId: classId,
                    teacherId: widget.profile.teacherId!,
                    title: title.text,
                    subject: subject.text,
                    description: description.text,
                    dueDate: dueDate,
                    maxMarks: int.tryParse(marks.text) ?? 0,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } on ApiException catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext)
                        .showSnackBar(SnackBar(content: Text(e.message)));
                  }
                  setDialogState(() => saving = false);
                } catch (_) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('لم يُحفظ الواجب.')));
                  }
                  setDialogState(() => saving = false);
                }
              }

              return AlertDialog(
                title: const Text('واجب جديد'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<int>(
                      value: classId,
                      decoration: const InputDecoration(labelText: 'الفصل'),
                      items: data.classes
                          .map((item) => DropdownMenuItem(
                              value: item.id, child: Text(item.label)))
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) =>
                              setDialogState(() => classId = value ?? classId)),
                  TextField(
                      controller: title,
                      enabled: !saving,
                      decoration:
                          const InputDecoration(labelText: 'عنوان الواجب')),
                  TextField(
                      controller: subject,
                      enabled: !saving,
                      decoration: const InputDecoration(labelText: 'المادة')),
                  TextField(
                      controller: description,
                      enabled: !saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'التعليمات (اختياري)')),
                  TextField(
                      controller: marks,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'الدرجة العظمى')),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('آخر موعد: $dueDate'),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: saving
                          ? null
                          : () async {
                              final selected = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: DateTime.parse(dueDate),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 366)));
                              if (selected != null) {
                                setDialogState(
                                    () => dueDate = _isoDate(selected));
                              }
                            }),
                ])),
                actions: [
                  TextButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? 'جارٍ الحفظ…' : 'حفظ الواجب'))
                ],
              );
            }));
    title.dispose();
    subject.dispose();
    description.dispose();
    marks.dispose();
    if (saved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم إنشاء الواجب.')));
      }
      await _load();
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
                    title: 'بوابة المعلم',
                    subtitle:
                        'الفصول المسندة فعلياً، والحضور والواجبات من سجلات المدرسة نفسها.',
                    icon: Icons.co_present_outlined),
                const TabBar(tabs: [
                  Tab(text: 'الفصول'),
                  Tab(text: 'الحضور'),
                  Tab(text: 'الواجبات')
                ]),
                Expanded(
                    child: TabBarView(children: [
                  _classesTab(data),
                  _attendanceTab(data),
                  _assignmentsTab(data)
                ])),
              ]));
        }),
      );

  Widget _classesTab(TeacherWorkspace data) {
    if (data.classes.isEmpty) {
      return const EmptyState(
          icon: Icons.meeting_room_outlined,
          title: 'لا فصول مسندة إلى حسابك',
          message: 'تُقرأ الإسنادات من الجدول الأسبوعي ومن معلم الفصل.');
    }
    final today = DateTime.now().weekday % 7;
    return ListView(padding: const EdgeInsets.all(16), children: [
      ...data.classes.map((item) => Card(
              child: ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: Text(item.label),
            subtitle: Text(
                '${data.studentsOf(item.id).length} طالب${item.room == null ? '' : ' · قاعة ${item.room}'}'),
            trailing: Text(item.academicYear ?? ''),
          ))),
      const SizedBox(height: 12),
      const Text('حصص اليوم', style: TextStyle(fontWeight: FontWeight.bold)),
      ...data.slots
          .where((slot) => slot.dayOfWeek == today)
          .map((slot) => ListTile(
                dense: true,
                leading: CircleAvatar(child: Text('${slot.periodNo}')),
                title: Text(slot.subject ?? 'حصة'),
                subtitle: Text(data.classes
                    .where((item) => item.id == slot.classId)
                    .map((item) => item.label)
                    .join()),
              )),
    ]);
  }

  Widget _attendanceTab(TeacherWorkspace data) {
    if (data.classes.isEmpty) {
      return const EmptyState(
          icon: Icons.fact_check_outlined, title: 'لا يوجد فصل لتسجيل الحضور');
    }
    final roster = data.studentsOf(_classId ?? data.classes.first.id);
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
                child: DropdownButtonFormField<int>(
                    value: _classId,
                    decoration: const InputDecoration(labelText: 'الفصل'),
                    items: data.classes
                        .map((item) => DropdownMenuItem(
                            value: item.id, child: Text(item.label)))
                        .toList(),
                    onChanged: (value) => setState(() => _classId = value))),
            const SizedBox(width: 8),
            OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_date)),
          ])),
      Expanded(
          child: roster.isEmpty
              ? const EmptyState(
                  icon: Icons.group_outlined, title: 'لا طلاب في هذا الفصل')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: roster.length,
                  itemBuilder: (context, index) {
                    final student = roster[index];
                    final status = _attendanceStatus(student.id);
                    return Card(
                        child: ListTile(
                      title: Text(student.fullName),
                      subtitle: Text(student.admissionNo ?? 'بلا رقم قيد'),
                      trailing: _saving.contains(student.id)
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : DropdownButton<String?>(
                              value: status,
                              hint: const Text('لم يُسجَّل'),
                              underline: const SizedBox.shrink(),
                              items: const [
                                DropdownMenuItem(
                                    value: 'present', child: Text('حاضر')),
                                DropdownMenuItem(
                                    value: 'late', child: Text('متأخر')),
                                DropdownMenuItem(
                                    value: 'absent', child: Text('غائب')),
                                DropdownMenuItem(
                                    value: 'excused', child: Text('بعذر'))
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  unawaited(_saveAttendance(student, value));
                                }
                              },
                            ),
                    ));
                  },
                )),
    ]);
  }

  Widget _assignmentsTab(TeacherWorkspace data) {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
              onPressed: data.classes.isEmpty ? null : _newAssignment,
              icon: const Icon(Icons.add),
              label: const Text('إنشاء واجب'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)))),
      Expanded(
          child: data.assignments.isEmpty
              ? const EmptyState(
                  icon: Icons.assignment_outlined, title: 'لا واجبات في فصولك')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: data.assignments.length,
                  itemBuilder: (context, index) {
                    final item = data.assignments[index];
                    final className = data.classes
                        .where((c) => c.id == item.classId)
                        .map((c) => c.label)
                        .join();
                    return Card(
                        child: ListTile(
                            title: Text(item.title),
                            subtitle: Text(
                                '${item.subject} · $className\nآخر موعد: ${item.dueDate}'),
                            trailing: Text('${item.maxMarks} درجة'),
                            isThreeLine: true));
                  },
                )),
    ]);
  }
}
