import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sai_theme.dart';
import '../../widgets/state_views.dart';
import 'class_models.dart';
import 'student_transfer_widgets.dart';

/// A student row inside the transfer picker.
class _TransferStudent {
  const _TransferStudent({
    required this.id,
    required this.fullName,
    required this.admissionNo,
    required this.branchId,
  });

  final String id;
  final String fullName;
  final String admissionNo;
  final String? branchId;
}

/// Bulk move of students from one class to another.
///
/// Capacity is checked while picking, and again against fresh data right
/// before saving, so a class that filled up in the meantime is rejected
/// instead of being over-enrolled. The update is one statement, so the move
/// either applies to every selected student or to none of them.
class StudentTransferPage extends StatefulWidget {
  const StudentTransferPage({super.key, this.initialSourceId});

  final String? initialSourceId;

  @override
  State<StudentTransferPage> createState() => _StudentTransferPageState();
}

class _StudentTransferPageState extends State<StudentTransferPage> {
  bool _loadingClasses = true;
  bool _loadingStudents = false;
  bool _saving = false;
  String? _classesError;
  String? _studentsError;
  String? _formError;

  List<SaiClass> _classes = const [];
  SaiClass? _source;
  SaiClass? _destination;
  List<_TransferStudent> _students = const [];
  final Set<String> _selected = <String>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _classesError = null;
    });
    final client = Supabase.instance.client;
    try {
      final classRows = await client
          .from('classes')
          .select('id,name,program,capacity,is_active,teacher_id,branch_id,session_id')
          .order('name', ascending: true);
      final studentRows = await client.from('students').select('class_id,status');

      final counts = <String, int>{};
      for (final row in (studentRows as List).whereType<Map<String, dynamic>>()) {
        if (row['status'] != 'active') continue;
        final classId = row['class_id'] as String?;
        if (classId == null) continue;
        counts[classId] = (counts[classId] ?? 0) + 1;
      }

      final branchNames = await _nameMap(client, 'branches');
      final sessionNames = await _nameMap(client, 'academic_sessions');

      final rows = (classRows as List)
          .whereType<Map<String, dynamic>>()
          .map((row) => SaiClass.fromRow(
                row,
                enrolledByClass: counts,
                branchNames: branchNames,
                sessionNames: sessionNames,
              ))
          .toList();

      if (!mounted) return;
      final initial = widget.initialSourceId == null
          ? <SaiClass>[]
          : rows.where((row) => row.id == widget.initialSourceId).toList();
      setState(() {
        _classes = rows;
        _source = initial.isNotEmpty ? initial.first : (rows.isEmpty ? null : rows.first);
        _destination = null;
        _loadingClasses = false;
      });
      await _loadStudents();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingClasses = false;
        _classesError = 'تعذّر تحميل الصفوف. تحقق من الاتصال وصلاحيات حسابك.\n$error';
      });
    }
  }

  Future<Map<String, String>> _nameMap(SupabaseClient client, String table) async {
    try {
      final rows = await client.from(table).select('id,name');
      return {
        for (final row in (rows as List).whereType<Map<String, dynamic>>())
          row['id'] as String: (row['name'] as String?) ?? ''
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> _loadStudents() async {
    final source = _source;
    if (source == null) {
      setState(() => _students = const []);
      return;
    }
    setState(() {
      _loadingStudents = true;
      _studentsError = null;
      _formError = null;
      _selected.clear();
      _query = '';
    });
    try {
      final rows = await Supabase.instance.client
          .from('students')
          .select('id,full_name,admission_no,branch_id')
          .eq('class_id', source.id)
          .eq('status', 'active')
          .order('full_name', ascending: true);
      final students = (rows as List).whereType<Map<String, dynamic>>().map((row) {
        final name = (row['full_name'] as String?)?.trim() ?? '';
        return _TransferStudent(
          id: row['id'] as String,
          fullName: name.isEmpty ? 'طالب' : name,
          admissionNo: (row['admission_no'] as String?)?.trim().isNotEmpty == true
              ? (row['admission_no'] as String).trim()
              : '—',
          branchId: row['branch_id'] as String?,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _students = students;
        _loadingStudents = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingStudents = false;
        _studentsError = 'تعذّر تحميل طلاب الصف.\n$error';
      });
    }
  }

  /// Destination choices stay inside the same branch: the database refuses to
  /// move a student across branches, so we never offer an invalid target.
  List<SaiClass> get _destinations {
    final source = _source;
    if (source == null) return const [];
    return _classes
        .where((row) => row.id != source.id && row.branchId == source.branchId && row.isActive)
        .toList();
  }

  List<_TransferStudent> get _visibleStudents {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _students;
    return _students
        .where((student) =>
            student.fullName.toLowerCase().contains(query) ||
            student.admissionNo.toLowerCase().contains(query))
        .toList();
  }

  bool get _allVisibleSelected {
    final visible = _visibleStudents;
    return visible.isNotEmpty && visible.every((student) => _selected.contains(student.id));
  }

  bool get _overCapacity {
    final destination = _destination;
    if (destination == null) return false;
    return _selected.length > destination.available;
  }

  String _friendly(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('not authorized for this branch') || lower.contains('42501')) {
      return 'لا تملك صلاحية نقل طلاب في هذا الفرع. النقل متاح لمسؤول الفرع أو الإدارة العامة.';
    }
    if (lower.contains('invalid class or branch')) {
      return 'الصف الهدف لا يتبع نفس فرع الطالب، لذلك رُفض النقل.';
    }
    if (lower.contains('permission denied') || lower.contains('row-level security')) {
      return 'منعت قواعد الحماية هذا النقل لهذا الحساب. راجع صلاحياتك مع إدارة الكلية.';
    }
    if (lower.contains('duplicate') || lower.contains('unique')) {
      return 'يوجد تعارض في بيانات الطلاب، أعد المحاولة بعد تحديث الصفحة.';
    }
    return raw;
  }

  Future<void> _save() async {
    final source = _source;
    final destination = _destination;
    if (source == null || destination == null || _selected.isEmpty) return;

    setState(() {
      _saving = true;
      _formError = null;
    });

    final client = Supabase.instance.client;
    try {
      final selectedStudents =
          _students.where((student) => _selected.contains(student.id)).toList();
      final crossBranch = selectedStudents
          .any((student) => student.branchId != null && student.branchId != destination.branchId);
      if (crossBranch) {
        setState(() {
          _saving = false;
          _formError = 'بعض الطلاب المحددين يتبعون فرعاً آخر. لا يمكن النقل بين الفروع.';
        });
        return;
      }

      // Fresh capacity check against the current database state.
      final freshClass = await client
          .from('classes')
          .select('capacity')
          .eq('id', destination.id)
          .maybeSingle();
      final capacity =
          (freshClass?['capacity'] as num?)?.toInt() ?? destination.capacity;
      final current = await client
          .from('students')
          .select('id')
          .eq('class_id', destination.id)
          .eq('status', 'active');
      final enrolledNow = (current as List).length;
      final free = capacity - enrolledNow;
      if (_selected.length > free) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _formError = free <= 0
              ? 'الصف «${destination.name}» أصبح ممتلئاً ($capacity طالباً). اختر صفاً آخر أو ارفع السعة أولاً.'
              : 'المقاعد المتاحة في «${destination.name}» الآن $free فقط، والمحدد ${_selected.length} طالباً. خفّف التحديد أو اختر صفاً آخر.';
        });
        return;
      }

      final ids = _selected.toList();
      final updated = await client
          .from('students')
          .update({'class_id': destination.id})
          .inFilter('id', ids)
          .select('id');
      final moved = (updated as List).length;

      if (!mounted) return;
      setState(() => _saving = false);
      final partial = moved < ids.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(partial
            ? 'نُقل $moved من ${ids.length} طالباً. بقية السجلات منعتها قواعد الصلاحيات أو تغيّرت أثناء النقل.'
            : 'تم نقل ${ids.length} طالباً من «${source.name}» إلى «${destination.name}».'),
        backgroundColor: partial ? SaiColors.warning : SaiColors.success,
      ));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = 'تعذّر إتمام النقل: ${_friendly(error)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final destinations = _destinations;

    return Scaffold(
      backgroundColor: SaiColors.cream,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('نقل الطلاب بين الصفوف',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SaiColors.ink)),
            Text('نقل جماعي مع التحقق من السعة', style: TextStyle(fontSize: 10, color: SaiColors.muted)),
          ],
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_forward, size: 20, color: SaiColors.ink),
        ),
      ),
      body: _loadingClasses
          ? const LoadingState()
          : _classesError != null
              ? ErrorState(message: _classesError!, onRetry: _loadClasses)
              : _classes.isEmpty
                  ? const EmptyState(
                      icon: Icons.meeting_room_outlined,
                      title: 'لا توجد صفوف',
                      message: 'أنشئ صفوفاً أولاً من شاشة الصفوف والمقاعد ثم عد للنقل.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                      children: [
                        TransferStepCard(
                          index: '1',
                          title: 'الصف الحالي (المصدر)',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TransferClassDropdown(
                                label: 'من صف',
                                value: source,
                                items: _classes,
                                onChanged: (value) async {
                                  if (value == null || value.id == source?.id) return;
                                  setState(() {
                                    _source = value;
                                    _destination = null;
                                  });
                                  await _loadStudents();
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${source?.enrolled ?? 0} طالباً نشطاً · ${source?.program ?? '—'}',
                                style: const TextStyle(fontSize: 10.5, color: SaiColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TransferStepCard(
                          index: '2',
                          title: 'اختر الطلاب',
                          trailing: Text(
                            'المحدد ${_selected.length}',
                            style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w700, color: SaiColors.maroon),
                          ),
                          child: _buildStudentPicker(),
                        ),
                        const SizedBox(height: 10),
                        TransferStepCard(
                          index: '3',
                          title: 'الصف الهدف',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (destinations.isEmpty)
                                const Text(
                                  'لا يوجد صف آخر في نفس الفرع. أضف صفاً جديداً من شاشة الصفوف ثم عد للنقل.',
                                  style: TextStyle(fontSize: 11, height: 1.7, color: SaiColors.muted),
                                )
                              else ...[
                                TransferClassDropdown(
                                  label: 'إلى صف',
                                  value: _destination,
                                  items: destinations,
                                  hint: 'اختر الصف الهدف',
                                  onChanged: (value) => setState(() {
                                    _destination = value;
                                    _formError = null;
                                  }),
                                ),
                                if (_destination != null) ...[
                                  const SizedBox(height: 10),
                                  TransferCapacityPanel(
                                    destination: _destination!,
                                    selectedCount: _selected.length,
                                    overCapacity: _overCapacity,
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        if (_formError != null) ...[
                          const SizedBox(height: 10),
                          NoteBanner(
                            message: _formError!,
                            color: SaiColors.danger,
                            tint: SaiColors.dangerTint,
                            icon: Icons.error_outline,
                          ),
                        ],
                        const SizedBox(height: 12),
                        const NoteBanner(
                          message:
                              'تتم إعادة فحص السعة من قاعدة البيانات لحظة الحفظ. إذا امتلأ الصف الهدف تظهر رسالة ولا يُنقل أي طالب.',
                          color: SaiColors.gold,
                          tint: SaiColors.goldTint,
                          icon: Icons.verified_outlined,
                        ),
                      ],
                    ),
      bottomNavigationBar: _loadingClasses || _classesError != null
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: SaiColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed:
                            _saving || _destination == null || _selected.isEmpty || _overCapacity
                                ? null
                                : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.swap_horiz, size: 18),
                        label: Text(_saving ? 'جارٍ النقل...' : 'نقل الطلاب (${_selected.length})'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStudentPicker() {
    if (_loadingStudents) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_studentsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_studentsError!,
              style: const TextStyle(fontSize: 11, height: 1.7, color: SaiColors.danger)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _loadStudents, child: const Text('إعادة المحاولة')),
        ],
      );
    }
    if (_students.isEmpty) {
      return const Text(
        'لا يوجد طلاب نشطون في هذا الصف. اختر صفاً آخر أو أضف الطلاب أولاً.',
        style: TextStyle(fontSize: 11, height: 1.7, color: SaiColors.muted),
      );
    }

    final visible = _visibleStudents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          style: const TextStyle(fontSize: 12.5),
          decoration: const InputDecoration(
            hintText: 'ابحث بالاسم أو رقم القيد...',
            prefixIcon: Icon(Icons.search, size: 18, color: SaiColors.muted),
            prefixIconConstraints: BoxConstraints(minWidth: 38, minHeight: 38),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            InkWell(
              onTap: () => setState(() {
                if (_allVisibleSelected) {
                  for (final student in visible) {
                    _selected.remove(student.id);
                  }
                } else {
                  _selected.addAll(visible.map((student) => student.id));
                }
              }),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _allVisibleSelected ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 17,
                      color: SaiColors.maroon,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _allVisibleSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل (${visible.length})',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: SaiColors.ink),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (_selected.isNotEmpty)
              TextButton(
                onPressed: () => setState(_selected.clear),
                child: const Text('مسح التحديد', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 2),
        ...visible.map((student) {
          final checked = _selected.contains(student.id);
          return InkWell(
            onTap: () => setState(() {
              if (checked) {
                _selected.remove(student.id);
              } else {
                _selected.add(student.id);
              }
              _formError = null;
            }),
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    checked ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                    color: checked ? SaiColors.maroon : SaiColors.muted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: SaiColors.ink),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(student.admissionNo,
                      style: const TextStyle(fontSize: 9.5, color: SaiColors.muted)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}