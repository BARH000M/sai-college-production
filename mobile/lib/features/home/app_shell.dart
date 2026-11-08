import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_identity.dart';
import '../../core/app_nav.dart';
import '../../core/app_role.dart';
import '../../core/auth_repository.dart';
import '../../core/feature_catalog.dart';
import '../../core/sai_theme.dart';
import '../../widgets/sai_app_bar.dart';
import '../../widgets/sai_drawer.dart';
import '../academics/classes_seats_page.dart';
import '../modules/module_page.dart';
import '../modules/modules_page.dart';
import '../modules/status_page.dart';
import '../notifications/notifications_page.dart';
import '../roles/roles_permissions_page.dart';
import '../students/my_children_page.dart';
import '../students/my_profile_page.dart';
import '../students/parent_link_page.dart';
import '../students/student_import_page.dart';
import 'home_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.identity});

  final AppIdentity identity;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late AppRole _activeRole = widget.identity.roles.first;
  int _index = 0;

  List<NavSlot> get _slots => navSlotsFor(_activeRole);

  bool get _canManageStudents =>
      const {AppRole.superAdmin, AppRole.admin, AppRole.receptionist}.contains(_activeRole);

  void _selectSlot(String id) {
    final index = _slots.indexWhere((slot) => slot.id == id);
    if (index >= 0 && index != _index) setState(() => _index = index);
  }

  void _openFeature(FeatureModule module) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ModulePage(module: module, identity: widget.identity, role: _activeRole),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openNotifications() {
    _push(NotificationsPage(identity: widget.identity, role: _activeRole));
  }

  void _openImport() => _push(const StudentImportPage());

  void _openParentLink() => _push(ParentLinkPage(identity: widget.identity));

  void _switchRole(AppRole role) {
    if (!widget.identity.roles.contains(role)) return;
    setState(() {
      _activeRole = role;
      _index = 0;
    });
  }

  Future<void> _signOut() async {
    await AuthRepository(Supabase.instance.client).signOut();
  }

  FeatureModule? _moduleOrNull(String id) {
    for (final module in modulesForRole(_activeRole)) {
      if (module.id == id) return module;
    }
    return null;
  }

  Widget _moduleSlot(NavSlot slot) {
    final module = _moduleOrNull(slot.id);
    if (module == null) {
      return StatusPage(
        icon: slot.icon,
        title: slot.label,
        message: 'لا يتضمن دورك الحالي صلاحية الوصول إلى هذه الوحدة. تواصل مع إدارة الكلية.',
      );
    }
    return ModulePage(
      module: module,
      identity: widget.identity,
      role: _activeRole,
      embedded: true,
    );
  }

  Widget _pageForSlot(NavSlot slot) {
    switch (slot.id) {
      case 'home':
        return HomePage(
          identity: widget.identity,
          role: _activeRole,
          onOpenModules: () => _selectSlot('more'),
          onOpenFeature: _openFeature,
        );
      case 'classes':
        return ClassesSeatsPage(
          identity: widget.identity,
          role: _activeRole,
          onOpenImport: _openImport,
          onOpenParentLink: _openParentLink,
        );
      case 'users':
        return const RolesPermissionsPage();
      case 'children':
        return MyChildrenPage(identity: widget.identity);
      case 'myprofile':
        return MyProfilePage(identity: widget.identity);
      case 'more':
        return ModulesPage(role: _activeRole, onOpenFeature: _openFeature);
      default:
        return _moduleSlot(slot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    final safeIndex = _index < slots.length ? _index : 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: SaiColors.cream,
      drawer: SaiDrawer(
        identity: widget.identity,
        activeRole: _activeRole,
        slots: slots,
        selectedIndex: safeIndex,
        onSelect: (index) => setState(() => _index = index),
        onSignOut: _signOut,
        onRoleSelected: widget.identity.roles.length > 1 ? _switchRole : null,
        onClasses: slots.any((slot) => slot.id == 'classes') ? () => _selectSlot('classes') : null,
        onRoles: slots.any((slot) => slot.id == 'users') ? () => _selectSlot('users') : null,
        onImportStudents: _canManageStudents ? _openImport : null,
        onParentLink: _canManageStudents ? _openParentLink : null,
      ),
      appBar: saiAppBar(
        context,
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        onNotifications: _openNotifications,
      ),
      body: IndexedStack(
        index: safeIndex,
        children: slots.map(_pageForSlot).toList(growable: false),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: SaiColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: slots
              .map((slot) => NavigationDestination(
                    icon: Icon(slot.icon),
                    selectedIcon: Icon(slot.activeIcon),
                    label: slot.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}