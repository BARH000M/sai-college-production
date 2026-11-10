import 'package:flutter/material.dart';
import '../models/roles.dart';
import '../data/sai_repository.dart';
import 'dashboard.dart';
import 'modules.dart';
import 'learning.dart';
import 'courses.dart';
import 'classes.dart';
import 'lesson.dart';
import 'student.dart';
import 'notifications.dart';
import 'profile.dart';
import 'attendance.dart';
import 'feature_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.roles, required this.repo});
  final Set<AppRole> roles;
  final SaiRepository repo;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Feature selected = Feature.home;
  late final Set<Feature> allowed = allowedFeatures(widget.roles);
  void open(Feature f) {
    if (!allowed.contains(f)) return;
    if ([
      Feature.home,
      Feature.modules,
      Feature.learning,
      Feature.courses,
      Feature.classes,
      Feature.notifications,
      Feature.profile
    ].contains(f)) {
      setState(() => selected = f);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page(f)));
  }

  Widget page(Feature f) => switch (f) {
        Feature.home =>
          DashboardScreen(roles: widget.roles, repo: widget.repo, open: open),
        Feature.modules => ModulesScreen(roles: widget.roles, open: open),
        Feature.learning => LearningScreen(open: open),
        Feature.courses => CoursesScreen(repo: widget.repo, open: open),
        Feature.classes => ClassesScreen(repo: widget.repo),
        Feature.roster => ClassesScreen(repo: widget.repo),
        Feature.lesson => const LessonScreen(),
        Feature.student => StudentScreen(repo: widget.repo),
        Feature.notifications => const NotificationsScreen(),
        Feature.profile =>
          ProfileScreen(roles: widget.roles, repo: widget.repo),
        Feature.attendance => AttendanceScreen(repo: widget.repo),
        _ => FeaturePage(feature: f)
      };
  static const nav = <({Feature feature, String title, IconData icon})>[
    (feature: Feature.home, title: 'الرئيسية', icon: Icons.home_outlined),
    (feature: Feature.classes, title: 'الصفوف', icon: Icons.class_outlined),
    (feature: Feature.courses, title: 'الدروس', icon: Icons.menu_book_outlined),
    (feature: Feature.learning, title: 'التعلم', icon: Icons.translate),
    (feature: Feature.modules, title: 'المزيد', icon: Icons.grid_view_outlined)
  ];
  @override
  Widget build(BuildContext context) {
    final tabs = nav.where((n) => allowed.contains(n.feature)).toList();
    final active =
        tabs.any((n) => n.feature == selected) ? selected : tabs.first.feature;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
        appBar: AppBar(
            title: const Text('كلية ساي التعليمية اليمنية الصينية',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            actions: [
              if (allowed.contains(Feature.notifications))
                IconButton(
                    tooltip: 'الإشعارات',
                    onPressed: () => open(Feature.notifications),
                    icon: const Icon(Icons.notifications_none)),
              IconButton(
                  tooltip: 'حسابي',
                  onPressed: () => open(Feature.profile),
                  icon: const Icon(Icons.account_circle_outlined))
            ]),
        body: Row(children: [
          if (wide)
            NavigationRail(
                selectedIndex: tabs.indexWhere((e) => e.feature == active),
                onDestinationSelected: (i) => open(tabs[i].feature),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final t in tabs)
                    NavigationRailDestination(
                        icon: Icon(t.icon), label: Text(t.title))
                ]),
          Expanded(child: page(active))
        ]),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: tabs.indexWhere((e) => e.feature == active),
                onDestinationSelected: (i) => open(tabs[i].feature),
                destinations: [
                    for (final t in tabs)
                      NavigationDestination(icon: Icon(t.icon), label: t.title)
                  ]));
  }
}
