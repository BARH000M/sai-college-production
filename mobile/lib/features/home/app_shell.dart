import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_identity.dart';
import '../../core/app_role.dart';
import '../../core/auth_repository.dart';
import '../../core/feature_catalog.dart';
import '../../core/sai_theme.dart';
import '../account/account_page.dart';
import '../modules/modules_page.dart';
import '../modules/module_page.dart';
import '../modules/status_page.dart';
import 'home_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.identity});

  final AppIdentity identity;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppRole _activeRole = widget.identity.roles.first;
  int _selectedIndex = 0;

  void _openFeature(FeatureModule module) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ModulePage(module: module, identity: widget.identity, role: _activeRole),
      ),
    );
  }

  void _switchRole(AppRole role) {
    if (!widget.identity.roles.contains(role)) return;
    setState(() {
      _activeRole = role;
      _selectedIndex = 0;
    });
  }

  Future<void> _signOut() async {
    await AuthRepository(Supabase.instance.client).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleMatches = featureModules.where((m) => m.id == 'timetable' && m.roles.contains(_activeRole)).toList();
    final FeatureModule? schedule = scheduleMatches.isEmpty ? null : scheduleMatches.first;
    final pages = <Widget>[
      HomePage(
        identity: widget.identity,
        role: _activeRole,
        onOpenModules: () => setState(() => _selectedIndex = 1),
        onOpenFeature: _openFeature,
      ),
      ModulesPage(role: _activeRole, onOpenFeature: _openFeature),
      schedule == null
          ? const StatusPage(
              icon: Icons.calendar_month_outlined,
              title: 'الجدول والتقويم',
              message: 'لا يتضمن دورك صلاحية عرض هذه الوحدة.',
            )
          : ModulePage(module: schedule, identity: widget.identity, role: _activeRole),
      const StatusPage(
        icon: Icons.notifications_none_rounded,
        title: 'التنبيهات',
        message: 'ستظهر التنبيهات هنا بعد ربط خدمة الإشعارات المعتمدة في النظام.',
      ),
      AccountPage(
        identity: widget.identity,
        activeRole: _activeRole,
        onSignOut: _signOut,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset('assets/images/sai-logo.png', width: 40, height: 40, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('كلية ساي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            ),
          ],
        ),
        actions: [
          if (widget.identity.roles.length > 1)
            PopupMenuButton<AppRole>(
              tooltip: 'تغيير الدور النشط',
              initialValue: _activeRole,
              onSelected: _switchRole,
              itemBuilder: (context) => widget.identity.roles
                  .map((role) => PopupMenuItem(value: role, child: Text(role.label)))
                  .toList(),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 6, end: 12),
                child: Row(
                  children: [
                    Text(_activeRole.label, style: const TextStyle(fontSize: 12, color: SaiColors.red)),
                    const Icon(Icons.expand_more, color: SaiColors.red),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6, end: 16),
              child: Center(child: Text(_activeRole.label, style: const TextStyle(fontSize: 12, color: SaiColors.red))),
            ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'الخدمات'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'الجدول'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'التنبيهات'),
          NavigationDestination(icon: Icon(Icons.account_circle_outlined), selectedIcon: Icon(Icons.account_circle), label: 'حسابي'),
        ],
      ),
    );
  }
}
