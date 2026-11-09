import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_identity.dart';
import '../../core/sai_theme.dart';
import '../../widgets/sai_app_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';

class _StudentOption {
  const _StudentOption({required this.id, required this.name, required this.admissionNo, required this.className});

  final String id;
  final String name;
  final String admissionNo;
  final String className;

  String get subtitle => [admissionNo, className].where((part) => part.trim().isNotEmpty).join(' · ');
}

class _GuardianOption {
  const _GuardianOption({required this.userId, required this.name, required this.email, required this.phone});

  final String userId;
  final String name;
  final String email;
  final String phone;

  String get subtitle => [phone.trim(), email.trim()].where((part) => part.isNotEmpty).join(' · ');
}

class _LinkOptions {
  const _LinkOptions({required this.students, required this.guardians});

  final List<_StudentOption> students;
  final List<_GuardianOption> guardians;
}

/// Screen 2 of the mockup: attach a guardian account to a student record.
class ParentLinkPage extends StatefulWidget {
  const ParentLinkPage({super.key, required this.identity});

  final AppIdentity identity;

  @override
  State<ParentLinkPage> createState() => _ParentLinkPageState();
}

class _ParentLinkPageState extends State<ParentLinkPage> {
  late Future<_LinkOptions> _future;
  _StudentOption? _student;
  _GuardianOption? _guardian;
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LinkOptions> _load() async {
    final client = Supabase.instance.client;
    final classRows = await client.from('classes').select('id,name');
    final classNames = <String, String>{};
    for (final row in classRows as List) {
      final map = row as Map<String, dynamic>;
      final id = map['id'];
      if (id is String) classNames[id] = (map['name'] as String?) ?? '';
    }

    final studentRows = await client.from('students').select('id,full_name,admission_no,class_id').order('full_name', ascending: true);
    final students = (studentRows as List).map((row) {
      final map = row as Map<String, dynamic>;
      final classId = map['class_id'] as String?;
      return _StudentOption(
        id: map['id'] as String,
        name: (map['full_name'] as String?)?.trim().isNotEmpty == true ? (map['full_name'] as String).trim() : 'طالب',
        admissionNo: (map['admission_no'] as String?) ?? '',
        className: classId == null ? '' : (classNames[classId] ?? ''),
      );
    }).toList();

    final roleRows = await client.from('user_roles').select('user_id,role').eq('role', 'parent');
    final guardianIds = <String>[];
    for (final row in roleRows as List) {
      final id = (row as Map<String, dynamic>)['user_id'];
      if (id is String && !guardianIds.contains(id)) guardianIds.add(id);
    }

    final guardians = <_GuardianOption>[];
    if (guardianIds.isNotEmpty) {
      final profileRows = await client.from('profiles').select('id,full_name,email,phone').inFilter('id', guardianIds);
      for (final row in profileRows as List) {
        final map = row as Map<String, dynamic>;
        guardians.add(_GuardianOption(
          userId: map['id'] as String,
          name: (map['full_name'] as String?)?.trim().isNotEmpty == true ? (map['full_name'] as String).trim() : 'ولي أمر',
          email: (map['email'] as String?) ?? '',
          phone: (map['phone'] as String?) ?? '',
        ));
      }
      guardians.sort((a, b) => a.name.compareTo(b.name));
    }

    return _LinkOptions(students: students, guardians: guardians);
  }

  void _retry() => setState(() => _future = _load());

  Future<void> _confirm() async {
    if (_student == null || _guardian == null) {
      setState(() => _error = 'اختر الطالب وولي الأمر أولًا.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final client = Supabase.instance.client;
      final existing = await client
          .from('parent_student_links')
          .select('id')
          .eq('parent_user_id', _guardian!.userId)
          .eq('student_id', _student!.id)
          .maybeSingle();
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'هذا الربط موجود بالفعل بين الطالب وولي الأمر المحدد.';
        });
        return;
      }
      await client.from('parent_student_links').insert({
        'parent_user_id': _guardian!.userId,
        'student_id': _student!.id,
        'verified_at': DateTime.now().toUtc().toIso8601String(),
        'verified_by': widget.identity.userId,
      });
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = 'تم ربط ${_student!.name} بحساب ${_guardian!.name}.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّر حفظ الربط: ${_errorText(error)}';
      });
    }
  }

  String _errorText(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _pickStudent(List<_StudentOption> options) async {
    final selected = await _showPicker<_StudentOption>(
      title: 'اختر الطالب',
      hint: 'ابحث بالاسم أو رقم القيد',
      options: options,
      labelOf: (item) => item.name,
      subtitleOf: (item) => item.subtitle,
      matches: (item, query) =>
          item.name.toLowerCase().contains(query) ||
          item.admissionNo.toLowerCase().contains(query) ||
          item.className.toLowerCase().contains(query),
    );
    if (selected != null) setState(() => _student = selected);
  }

  Future<void> _pickGuardian(List<_GuardianOption> options) async {
    final selected = await _showPicker<_GuardianOption>(
      title: 'اختر ولي الأمر',
      hint: 'ابحث بالاسم أو الهاتف أو البريد',
      options: options,
      labelOf: (item) => item.name,
      subtitleOf: (item) => item.subtitle,
      matches: (item, query) =>
          item.name.toLowerCase().contains(query) ||
          item.email.toLowerCase().contains(query) ||
          item.phone.contains(query),
    );
    if (selected != null) setState(() => _guardian = selected);
  }

  Future<T?> _showPicker<T>({
    required String title,
    required String hint,
    required List<T> options,
    required String Function(T item) labelOf,
    required String Function(T item) subtitleOf,
    required bool Function(T item, String query) matches,
  }) {
    var query = '';
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = options.where((item) => query.isEmpty || matches(item, query)).toList();
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.62,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(width: 38, height: 4, decoration: BoxDecoration(color: SaiColors.border, borderRadius: BorderRadius.circular(4))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SaiColors.ink))),
                          IconButton(onPressed: () => Navigator.of(sheetContext).pop(), icon: const Icon(Icons.close, size: 18)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        autofocus: false,
                        onChanged: (value) => setSheetState(() => query = value.trim().toLowerCase()),
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: hint,
                          prefixIcon: const Icon(Icons.search, size: 18, color: SaiColors.muted),
                          prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('لا نتائج مطابقة', style: TextStyle(fontSize: 12, color: SaiColors.muted)))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  onTap: () => Navigator.of(sheetContext).pop(item),
                                  dense: true,
                                  title: Text(labelOf(item), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                                  subtitle: Text(subtitleOf(item), style: const TextStyle(fontSize: 10.5, color: SaiColors.muted)),
                                  trailing: const Icon(Icons.chevron_left, size: 17, color: SaiColors.muted),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: saiAppBar(
        context,
        showBack: true,
        onMenu: () {},
        showBell: false,
        title: 'ربط ولي الأمر بالطلاب',
      ),
      body: FutureBuilder<_LinkOptions>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const LoadingState();
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}', onRetry: _retry);
          }
          final options = snapshot.data ?? const _LinkOptions(students: [], guardians: []);
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
            children: [
              const SectionHeader(icon: Icons.link, title: 'ربط حساب ولي الأمر بحساب الطالب'),
              const SizedBox(height: 12),
              _FieldCard(
                label: 'اختر الطالب',
                isRequired: true,
                value: _student == null ? null : '${_student!.name} — ${_student!.subtitle}',
                onTap: options.students.isEmpty ? null : () => _pickStudent(options.students),
                emptyHint: options.students.isEmpty ? 'لا توجد سجلات طلاب متاحة' : 'اضغط للاختيار من سجلات الطلاب',
                icon: Icons.person_search_outlined,
              ),
              const SizedBox(height: 10),
              _FieldCard(
                label: 'اختر ولي الأمر',
                isRequired: true,
                value: _guardian == null ? null : '${_guardian!.name} — ${_guardian!.subtitle}',
                onTap: options.guardians.isEmpty ? null : () => _pickGuardian(options.guardians),
                emptyHint: options.guardians.isEmpty ? 'لا توجد حسابات بأدوار ولي أمر بعد' : 'اضغط للاختيار من حسابات أولياء الأمور',
                icon: Icons.family_restroom_outlined,
              ),
              if (_student != null && _guardian != null) ...[
                const SizedBox(height: 10),
                _SelectedPreview(student: _student!, guardian: _guardian!),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SaiColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 16, color: SaiColors.maroon),
                        const SizedBox(width: 6),
                        const Text('الصلاحيات الممنوحة لولي الأمر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const _PermissionRow(label: 'الاطلاع على الحضور والغياب'),
                    const _PermissionRow(label: 'الاطلاع على الدرجات والتقييم'),
                    const _PermissionRow(label: 'الاطلاع على الرسوم والإيصالات'),
                    const _PermissionRow(label: 'الاطلاع على الإعلانات والرسائل'),
                    const NoteBanner(
                      icon: Icons.lock_outline,
                      color: SaiColors.warning,
                      tint: SaiColors.warningTint,
                      message: 'تُطبّق هذه الصلاحيات من سياسات الحماية في قاعدة البيانات، ولا يمكن تجاوزها من التطبيق.',
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                NoteBanner(icon: Icons.error_outline, color: SaiColors.danger, tint: SaiColors.dangerTint, message: _error!),
              ],
              if (_success != null) ...[
                const SizedBox(height: 10),
                NoteBanner(icon: Icons.check_circle_outline, color: SaiColors.success, tint: SaiColors.successTint, message: _success!),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _confirm,
                      icon: _busy
                          ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.link, size: 17),
                      label: Text(_busy ? 'جارٍ الحفظ...' : 'تأكيد الربط'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.isRequired,
    required this.value,
    required this.onTap,
    required this.emptyHint,
    required this.icon,
  });

  final String label;
  final bool isRequired;
  final String? value;
  final VoidCallback? onTap;
  final String emptyHint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? SaiColors.maroon.withOpacity(0.4) : SaiColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: filled ? SaiColors.maroon : SaiColors.muted),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SaiColors.muted)),
                      if (isRequired) const Text(' *', style: TextStyle(fontSize: 10, color: SaiColors.danger, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    filled ? value! : emptyHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: filled ? FontWeight.w700 : FontWeight.w400, color: filled ? SaiColors.ink : SaiColors.muted, height: 1.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: SaiColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SelectedPreview extends StatelessWidget {
  const _SelectedPreview({required this.student, required this.guardian});

  final _StudentOption student;
  final _GuardianOption guardian;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: SaiColors.goldTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaiColors.gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(child: _PreviewPerson(name: student.name, meta: student.subtitle, icon: Icons.school_outlined)),
          Container(width: 1, height: 34, color: SaiColors.gold.withOpacity(0.35)),
          Expanded(child: _PreviewPerson(name: guardian.name, meta: guardian.subtitle, icon: Icons.person_outline)),
        ],
      ),
    );
  }
}

class _PreviewPerson extends StatelessWidget {
  const _PreviewPerson({required this.name, required this.meta, required this.icon});

  final String name;
  final String meta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: SaiColors.gold),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: SaiColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(color: SaiColors.successTint, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 12, color: SaiColors.success),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11.5, color: SaiColors.ink))),
        ],
      ),
    );
  }
}