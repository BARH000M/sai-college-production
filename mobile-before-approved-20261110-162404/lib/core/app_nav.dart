import 'package:flutter/material.dart';

import 'app_role.dart';

/// One entry of the bottom navigator. The mockup uses four role-specific
/// destinations plus a permanent "المزيد" tab.
class NavSlot {
  const NavSlot({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _home = NavSlot(id: 'home', label: 'الرئيسية', icon: Icons.home_outlined, activeIcon: Icons.home);
const _classes = NavSlot(id: 'classes', label: 'الصفوف', icon: Icons.meeting_room_outlined, activeIcon: Icons.meeting_room);
const _students = NavSlot(id: 'students', label: 'الطلاب', icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt);
const _users = NavSlot(id: 'users', label: 'المستخدمين', icon: Icons.manage_accounts_outlined, activeIcon: Icons.manage_accounts);
const _children = NavSlot(id: 'children', label: 'أبنائي', icon: Icons.family_restroom_outlined, activeIcon: Icons.family_restroom);
const _myRecord = NavSlot(id: 'myprofile', label: 'بياناتي', icon: Icons.badge_outlined, activeIcon: Icons.badge);
const _attendance = NavSlot(id: 'attendance', label: 'الحضور', icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check);
const _homework = NavSlot(id: 'homework', label: 'الواجبات', icon: Icons.assignment_outlined, activeIcon: Icons.assignment);
const _courses = NavSlot(id: 'courses', label: 'المقررات', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book);
const _finance = NavSlot(id: 'finance', label: 'الرسوم', icon: Icons.payments_outlined, activeIcon: Icons.payments);
const _library = NavSlot(id: 'library', label: 'المكتبة', icon: Icons.local_library_outlined, activeIcon: Icons.local_library);
const _more = NavSlot(id: 'more', label: 'المزيد', icon: Icons.menu, activeIcon: Icons.menu_open);

List<NavSlot> navSlotsFor(AppRole role) => switch (role) {
      AppRole.superAdmin || AppRole.admin => const [_home, _classes, _students, _users, _more],
      AppRole.teacher => const [_home, _classes, _students, _attendance, _more],
      AppRole.receptionist => const [_home, _students, _classes, _attendance, _more],
      AppRole.accountant => const [_home, _finance, _students, _attendance, _more],
      AppRole.librarian => const [_home, _library, _students, _attendance, _more],
      AppRole.contentEditor => const [_home, _courses, _students, _attendance, _more],
      AppRole.student => const [_home, _myRecord, _courses, _homework, _more],
      AppRole.parent => const [_home, _children, _courses, _attendance, _more],
    };

/// Short label used in the drawer subtitle for each role.
String navSlotHint(String id) => switch (id) {
      'home' => 'لوحة الوصول السريع',
      'classes' => 'الصفوف والمقاعد',
      'students' => 'سجلات الطلاب',
      'users' => 'الأدوار والصلاحيات',
      'children' => 'بيانات الأبناء',
      'myprofile' => 'بياناتي الدراسية',
      'timetable' => 'جدول الحصص',
      'progress' => 'الدرجات والتقدم',
      'attendance' => 'الحضور والغياب',
      'homework' => 'الواجبات والتسليم',
      'courses' => 'المقررات والدروس',
      'finance' => 'الرسوم والمالية',
      'library' => 'المكتبة والإعارة',
      'more' => 'كل الخدمات',
      _ => '',
    };