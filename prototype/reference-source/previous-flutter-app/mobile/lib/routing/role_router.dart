import 'package:flutter/material.dart';
import '../auth/profile.dart';
import '../core/api.dart';
import '../features/account/account_page.dart';
import '../features/employee/employee_workspace_page.dart';
import '../features/family/family_workspace_page.dart';
import '../features/fees/posting_page.dart';
import '../features/home/role_home_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/teacher/teacher_workspace_page.dart';
import '../features/tutor/tutor_search_page.dart';
import 'app_role.dart';

class RoleDestination {
  RoleDestination(
      {required this.label, required this.icon, required this.builder});
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

List<RoleDestination> destinationsFor({
  required AppRole role,
  required SchoolApi api,
  required Profile profile,
  required Future<void> Function() onSignOut,
}) {
  final home = RoleDestination(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      builder: (_) => RoleHomePage(api: api, profile: profile, role: role));
  final notifications = RoleDestination(
      label: 'الرسائل',
      icon: Icons.notifications_outlined,
      builder: (_) => NotificationsPage(api: api, profile: profile));
  final account = RoleDestination(
      label: 'الحساب',
      icon: Icons.person_outline,
      builder: (_) => AccountPage(profile: profile, onSignOut: onSignOut));
  switch (role) {
    case AppRole.owner:
      return [home, notifications, account];
    case AppRole.admin:
      return [
        home,
        RoleDestination(
            label: 'ترحيل الرسوم',
            icon: Icons.payments_outlined,
            builder: (_) => PostingPage(api: api)),
        RoleDestination(
            label: 'الدروس',
            icon: Icons.menu_book_outlined,
            builder: (_) => TutorSearchPage(api: api)),
        notifications,
        account,
      ];
    case AppRole.accountant:
      return [home, notifications, account];
    case AppRole.teacher:
      return [
        home,
        RoleDestination(
            label: 'فصولي',
            icon: Icons.co_present_outlined,
            builder: (_) => TeacherWorkspacePage(api: api, profile: profile)),
        RoleDestination(
            label: 'الدروس',
            icon: Icons.menu_book_outlined,
            builder: (_) => TutorSearchPage(api: api)),
        notifications,
        account,
      ];
    case AppRole.employee:
      return [
        home,
        RoleDestination(
            label: 'ملفي الوظيفي',
            icon: Icons.badge_outlined,
            builder: (_) => EmployeeWorkspacePage(api: api)),
        notifications,
        account,
      ];
    case AppRole.parent:
    case AppRole.student:
      return [
        home,
        RoleDestination(
            label: role == AppRole.parent ? 'أبنائي' : 'دراستي',
            icon: Icons.school_outlined,
            builder: (_) => FamilyWorkspacePage(api: api, profile: profile)),
        RoleDestination(
            label: 'الدروس',
            icon: Icons.menu_book_outlined,
            builder: (_) => TutorSearchPage(api: api)),
        notifications,
        account,
      ];
  }
}
