import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/sai_theme.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';

const _staffRoles = {'super_admin', 'admin', 'teacher', 'accountant', 'receptionist', 'librarian', 'content_editor'};
const _learnerRoles = {'student', 'parent'};

String roleLabel(String role) => switch (role) {
      'super_admin' => 'مشرف عام',
      'admin' => 'مدير',
      'teacher' => 'معلم',
      'accountant' => 'محاسب',
      'receptionist' => 'استقبال',
      'librarian' => 'أمين مكتبة',
      'content_editor' => 'محرر محتوى',
      'student' => 'طالب',
      'parent' => 'ولي أمر',
      _ => role,
    };

class _UserRow {
  _UserRow({required this.id, required this.name, required this.email, required this.roles});

  final String id;
  final String name;
  final String email;
  final List<String> roles;

  bool get hasConflict =>
      roles.any(_staffRoles.contains) && roles.any(_learnerRoles.contains);
}

class RolesPermissionsPage extends StatefulWidget {
  const RolesPermissionsPage({super.key});

  @override
  State<RolesPermissionsPage> createState() => _RolesPermissionsPageState();
}

class _RolesPermissionsPageState extends State<RolesPermissionsPage> {
  late Future<List<_UserRow>> _future;
  String _filter = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_UserRow>> _load() async {
    final client = Supabase.instance.client;
    final roleRows = await client.from('user_roles').select('user_id,role');
    final rolesByUser = <String, List<String>>{};
    for (final row in roleRows as List) {
      final map = row as Map<String, dynamic>;
      final userId = map['user_id'];
      final role = map['role'];
      if (userId is! String || role == null) continue;
      rolesByUser.putIfAbsent(userId, () => <String>[]).add(role.toString());
    }

    final profileRows = await client.from('profiles').select('id,full_name,email');
    final users = <_UserRow>[];
    final seen = <String>{};
    for (final row in profileRows as List) {
      final map = row as Map<String, dynamic>;
      final id = map['id'] as String;
      seen.add(id);
      users.add(_UserRow(
        id: id,
        name: (map['full_name'] as String?)?.trim().isNotEmpty == true ? (map['full_name'] as String).trim() : 'مستخدم ساي',
        email: (map['email'] as String?) ?? '',
        roles: List<String>.from(rolesByUser[id] ?? const <String>[])..sort(),
      ));
    }
    for (final entry in rolesByUser.entries) {
      if (seen.contains(entry.key)) continue;
      users.add(_UserRow(id: entry.key, name: 'مستخدم ساي', email: 'معرّف غير ظاهر', roles: List<String>.from(entry.value)..sort()));
    }
    users.sort((a, b) => a.name.compareTo(b.name));
    return users;
  }

  void _retry() => setState(() => _future = _load());

  List<_UserRow> _applyFilters(List<_UserRow> users) {
    final query = _query.trim().toLowerCase();
    return users.where((user) {
      final matchesQuery = query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
      if (!matchesQuery) return false;
      return switch (_filter) {
        'noRole' => user.roles.isEmpty,
        'multiple' => user.roles.length > 1,
        'conflict' => user.hasConflict,
        _ => true,
      };
    }).toList();
  }

  void _openSheet(_UserRow user) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SaiColors.ink)),
            Text(user.email, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: SaiColors.muted)),
            const SizedBox(height: 14),
            const Text('الأدوار المسندة', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: SaiColors.ink)),
            const SizedBox(height: 8),
            if (user.roles.isEmpty)
              const Text('لا يوجد أي دور مسند لهذا الحساب.', style: TextStyle(fontSize: 11.5, color: SaiColors.muted))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: user.roles
                    .map((role) => TintChip(
                          label: roleLabel(role),
                          color: SaiColors.maroon,
                          tint: SaiColors.maroonTint,
                        ))
                    .toList(),
              ),
            if (user.hasConflict) ...[
              const SizedBox(height: 12),
              const NoteBanner(
                icon: Icons.warning_amber_outlined,
                color: SaiColors.danger,
                tint: SaiColors.dangerTint,
                message: 'هذا الحساب يجمع دور موظف مع دور طالب/ولي أمر. يُنصح بفصل الأدوار لتفادي تعارض الصلاحيات.',
              ),
            ],
            const SizedBox(height: 12),
            const NoteBanner(
              icon: Icons.settings_outlined,
              color: SaiColors.warning,
              tint: SaiColors.warningTint,
              message: 'تعديل الأدوار يتم من بوابة الويب (الأدوار والصلاحيات) لضمان تسجيل العملية في سجل التدقيق.',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('إغلاق')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_UserRow>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingState();
        if (snapshot.hasError) {
          return ErrorState(message: '${snapshot.error}', onRetry: _retry);
        }
        final users = snapshot.data ?? const <_UserRow>[];
        final filtered = _applyFilters(users);
        final counts = {
          'all': users.length,
          'noRole': users.where((u) => u.roles.isEmpty).length,
          'multiple': users.where((u) => u.roles.length > 1).length,
          'conflict': users.where((u) => u.hasConflict).length,
        };

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
          children: [
            const SectionHeader(icon: Icons.admin_panel_settings_outlined, title: 'الأدوار والصلاحيات'),
            const SizedBox(height: 11),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو البريد الإلكتروني...',
                prefixIcon: Icon(Icons.search, size: 18, color: SaiColors.muted),
                prefixIconConstraints: BoxConstraints(minWidth: 38, minHeight: 38),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'الكل', count: counts['all']!, value: 'all', selected: _filter == 'all', onTap: _select),
                  _FilterChip(label: 'بدون دور', count: counts['noRole']!, value: 'noRole', selected: _filter == 'noRole', onTap: _select),
                  _FilterChip(label: 'أدوار متعددة', count: counts['multiple']!, value: 'multiple', selected: _filter == 'multiple', onTap: _select),
                  _FilterChip(label: 'تعارض في الأدوار', count: counts['conflict']!, value: 'conflict', selected: _filter == 'conflict', onTap: _select),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const EmptyState(
                icon: Icons.group_off_outlined,
                title: 'لا مستخدمين مطابقين',
                message: 'غيّر الفلتر أو كلمة البحث لعرض مستخدمين آخرين.',
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SaiColors.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
                      _UserTile(user: filtered[i], onTap: () => _openSheet(filtered[i])),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const NoteBanner(
              icon: Icons.verified_user_outlined,
              color: SaiColors.warning,
              tint: SaiColors.warningTint,
              message: 'تُقرأ الأدوار من جدول صلاحيات الحساب مباشرة، وأي تعديل هنا يجب أن يمر بسياسات الحماية في قاعدة البيانات.',
            ),
          ],
        );
      },
    );
  }

  void _select(String value) => setState(() => _filter = value);
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 7),
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? SaiColors.maroon : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? SaiColors.maroon : SaiColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : SaiColors.ink)),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.22) : SaiColors.creamDeep,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('$count', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: selected ? Colors.white : SaiColors.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});

  final _UserRow user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isEmpty ? 'م' : user.name.trim().substring(0, 1);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: SaiColors.creamDeep,
              child: Text(initial, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SaiColors.ink)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SaiColors.ink)),
                      ),
                      if (user.hasConflict) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.warning_amber_rounded, size: 14, color: SaiColors.warning),
                      ],
                    ],
                  ),
                  Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 9.5, color: SaiColors.muted)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (user.roles.isEmpty)
                        const TintChip(label: 'بدون دور', color: SaiColors.muted, tint: SaiColors.creamDeep)
                      else
                        ...user.roles.take(3).map((role) => TintChip(
                              label: roleLabel(role),
                              color: _learnerRoles.contains(role) ? SaiColors.success : SaiColors.maroon,
                              tint: _learnerRoles.contains(role) ? SaiColors.successTint : SaiColors.maroonTint,
                            )),
                      if (user.roles.length > 3)
                        TintChip(label: '+${user.roles.length - 3}', color: SaiColors.muted, tint: SaiColors.creamDeep),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_left, size: 18, color: SaiColors.muted),
          ],
        ),
      ),
    );
  }
}