import 'package:flutter/material.dart';

import '../core/app_identity.dart';
import '../core/app_nav.dart';
import '../core/app_role.dart';
import '../core/sai_theme.dart';

/// The hamburger menu shown on every screen.
class SaiDrawer extends StatelessWidget {
  const SaiDrawer({
    super.key,
    required this.identity,
    required this.activeRole,
    required this.slots,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSignOut,
    this.onImportStudents,
    this.onParentLink,
    this.onRoles,
    this.onClasses,
    this.onRoleSelected,
  });

  final AppIdentity identity;
  final AppRole activeRole;
  final List<NavSlot> slots;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function() onSignOut;
  final VoidCallback? onImportStudents;
  final VoidCallback? onParentLink;
  final VoidCallback? onRoles;
  final VoidCallback? onClasses;
  final ValueChanged<AppRole>? onRoleSelected;

  @override
  Widget build(BuildContext context) {
    final trimmedName = identity.fullName.trim();
    final initials = trimmedName.isEmpty ? 'س' : trimmedName.substring(0, 1);
    return Drawer(
      backgroundColor: SaiColors.cream,
      width: MediaQuery.of(context).size.width * 0.84,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [SaiColors.maroon, SaiColors.maroonDeep],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Image.asset('assets/images/sai-logo.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('كلية ساي التعليمية اليمنية الصينية', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.4)),
                            SizedBox(height: 2),
                            Text('世门赛艾教育学院', style: TextStyle(color: Color(0xFFEBC98A), fontSize: 9, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.18),
                        child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(identity.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(activeRole.label, style: const TextStyle(color: Color(0xFFEBC98A), fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (identity.roles.length > 1) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: identity.roles.map((role) {
                        final selected = role == activeRole;
                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onRoleSelected == null
                              ? null
                              : () {
                                  Navigator.of(context).maybePop();
                                  onRoleSelected!(role);
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              role.label,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: selected ? SaiColors.maroon : Colors.white,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 6, bottom: 8),
                    child: Text('التنقل', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: SaiColors.muted)),
                  ),
                  ...List.generate(slots.length, (index) {
                    final slot = slots[index];
                    final selected = index == selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(11),
                        onTap: () {
                          Navigator.of(context).maybePop();
                          onSelect(index);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? SaiColors.maroonTint : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: [
                              Icon(selected ? slot.activeIcon : slot.icon, size: 19, color: selected ? SaiColors.maroon : SaiColors.muted),
                              const SizedBox(width: 10),
                              Expanded(child: Text(slot.label, style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: selected ? SaiColors.maroon : SaiColors.ink))),
                              Text(navSlotHint(slot.id), style: const TextStyle(fontSize: 9, color: SaiColors.muted)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (onClasses != null || onImportStudents != null || onParentLink != null || onRoles != null) ...[
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsetsDirectional.only(start: 6, bottom: 8),
                      child: Text('أدوات الإدارة', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: SaiColors.muted)),
                    ),
                    if (onClasses != null) _DrawerTool(icon: Icons.meeting_room_outlined, label: 'الصفوف والمقاعد', onTap: () { Navigator.of(context).maybePop(); onClasses!(); }),
                    if (onImportStudents != null) _DrawerTool(icon: Icons.upload_file_outlined, label: 'استيراد الطلاب', onTap: () { Navigator.of(context).maybePop(); onImportStudents!(); }),
                    if (onParentLink != null) _DrawerTool(icon: Icons.link, label: 'ربط ولي الأمر بالطلاب', onTap: () { Navigator.of(context).maybePop(); onParentLink!(); }),
                    if (onRoles != null) _DrawerTool(icon: Icons.admin_panel_settings_outlined, label: 'الأدوار والصلاحيات', onTap: () { Navigator.of(context).maybePop(); onRoles!(); }),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () {
                  Navigator.of(context).maybePop();
                  onSignOut();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 19, color: SaiColors.maroon),
                      SizedBox(width: 10),
                      Text('تسجيل الخروج', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SaiColors.maroon)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTool extends StatelessWidget {
  const _DrawerTool({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: SaiColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: SaiColors.gold),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SaiColors.ink))),
              const Icon(Icons.chevron_left, size: 17, color: SaiColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}