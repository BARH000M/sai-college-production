import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/profile.dart';
import '../core/api.dart';
import '../routing/app_role.dart';
import '../routing/role_router.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.profile});
  final Profile profile;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final SchoolApi _api = SchoolApi();
  late final AppRole _role = resolveRole(widget.profile);
  int _index = 0;
  SchoolBranding? _branding;
  bool _brandingFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBranding());
  }

  Future<void> _loadBranding() async {
    try {
      final branding = await _api.branding();
      if (!mounted) return;
      setState(() {
        _branding = branding;
        _brandingFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _brandingFailed = true);
    }
  }

  Future<void> _signOut() async {
    try {
      await _api.signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تسجيل الخروج. تحقق من الاتصال وأعد المحاولة.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(
        role: _role, api: _api, profile: widget.profile, onSignOut: _signOut);
    final safeIndex = _index >= destinations.length ? 0 : _index;
    final primary = _branding?.primaryColor != null
        ? Color(_branding!.primaryColor!)
        : Theme.of(context).colorScheme.primary;
    final schoolName = _branding?.name ??
        (_brandingFailed ? 'تعذّر تحميل اسم المؤسسة' : 'المؤسسة التعليمية');
    final subtitle = [
      schoolName,
      if (_branding?.academicYear != null &&
          _branding!.academicYear!.isNotEmpty)
        _branding!.academicYear!
    ].join(' · ');

    return Theme(
      data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
              seedColor: primary, brightness: Brightness.light)),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primary,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(destinations[safeIndex].label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Text('$subtitle · ${widget.profile.fullName}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.normal),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
          centerTitle: false,
          actions: [
            if (_branding?.logoUrl != null && _branding!.logoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    backgroundImage: NetworkImage(_branding!.logoUrl!),
                    onBackgroundImageError: (_, __) {}),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: primary.withAlpha(18),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(_role.label,
                      style:
                          TextStyle(fontSize: 10, color: primary)),
                ),
              ),
            ),
          ],
        ),
        body: IndexedStack(
            index: safeIndex,
            children:
                destinations.map((d) => Builder(builder: d.builder)).toList()),
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          indicatorColor: primary.withAlpha(41),
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: destinations
              .map((d) =>
                  NavigationDestination(icon: Icon(d.icon), label: d.label))
              .toList(),
        ),
      ),
    );
  }
}
