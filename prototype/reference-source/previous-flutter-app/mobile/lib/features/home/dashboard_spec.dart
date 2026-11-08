import 'package:flutter/material.dart';
import '../../auth/profile.dart';
import '../../core/api.dart';
import '../../routing/app_role.dart';

class StatSpec {
  const StatSpec(
      {required this.label,
      required this.icon,
      required this.load,
      this.hint,
      this.alertWhenPositive = false});
  final String label;
  final IconData icon;
  final Future<String> Function() load;
  final String? hint;
  final bool alertWhenPositive;
}

String _num(num value) {
  final rounded = value.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

List<StatSpec> specsFor(
    {required AppRole role, required SchoolApi api, required Profile profile}) {
  switch (role) {
    case AppRole.owner:
      return [
        StatSpec(
            label: 'المؤسسات',
            icon: Icons.apartment_outlined,
            hint: 'عبر كل المدارس',
            load: () async => _num((await api.ownerOverview()).schools)),
        StatSpec(
            label: 'حسابات الدخول',
            icon: Icons.group_outlined,
            load: () async => _num((await api.ownerOverview()).users)),
        StatSpec(
            label: 'الطلاب',
            icon: Icons.school_outlined,
            load: () async => _num((await api.ownerOverview()).students)),
        StatSpec(
            label: 'المعلمون',
            icon: Icons.badge_outlined,
            load: () async => _num((await api.ownerOverview()).teachers)),
      ];
    case AppRole.admin:
      return [
        StatSpec(
            label: 'الطلاب',
            icon: Icons.school_outlined,
            load: () async => _num(await api.countRows('school_students'))),
        StatSpec(
            label: 'الفصول',
            icon: Icons.meeting_room_outlined,
            load: () async => _num(await api.countRows('school_classes'))),
        StatSpec(
            label: 'تحصيل بلا قيد',
            icon: Icons.compare_arrows_outlined,
            hint: 'وصولات لم تُرحّل بعد',
            alertWhenPositive: true,
            load: () async => _num(await api.unpostedFeeCount())),
        StatSpec(
            label: 'اعتمادات مالية معلّقة',
            icon: Icons.pending_actions_outlined,
            hint: 'تحتاج مديراً ثانياً',
            alertWhenPositive: true,
            load: () async => _num(await api.pendingFinanceApprovals())),
        StatSpec(
            label: 'صافي الدفتر',
            icon: Icons.account_balance_wallet_outlined,
            load: () async => _num(await api.ledgerNet())),
      ];
    case AppRole.accountant:
      return [
        StatSpec(
            label: 'تحصيل بلا قيد',
            icon: Icons.compare_arrows_outlined,
            alertWhenPositive: true,
            load: () async => _num(await api.unpostedFeeCount())),
        StatSpec(
            label: 'قيمة التحصيل المعلّق',
            icon: Icons.payments_outlined,
            load: () async => _num(await api.unpostedFeeValue())),
        StatSpec(
            label: 'قيود بانتظار اعتماد',
            icon: Icons.pending_actions_outlined,
            alertWhenPositive: true,
            load: () async => _num(await api.pendingFinanceApprovals())),
        StatSpec(
            label: 'صافي الدفتر',
            icon: Icons.account_balance_wallet_outlined,
            load: () async => _num(await api.ledgerNet())),
      ];
    case AppRole.teacher:
      return [
        StatSpec(
            label: 'الفصول',
            icon: Icons.meeting_room_outlined,
            load: () async => _num(await api.countRows('school_classes'))),
        StatSpec(
            label: 'المقررات',
            icon: Icons.menu_book_outlined,
            load: () async => _num((await api.courses()).length)),
        StatSpec(
            label: 'الواجبات',
            icon: Icons.assignment_outlined,
            load: () async => _num(await api.countRows('school_assignments'))),
        StatSpec(
            label: 'الحصص المباشرة',
            icon: Icons.videocam_outlined,
            load: () async =>
                _num(await api.countRows('school_live_sessions'))),
      ];
    case AppRole.employee:
      return [
        StatSpec(
            label: 'ملفي الوظيفي',
            icon: Icons.badge_outlined,
            hint: 'سجلك أنت',
            load: () async => _num(await api.countRows('school_employees'))),
        StatSpec(
            label: 'طلبات الإجازة',
            icon: Icons.beach_access_outlined,
            load: () async => _num(await api.countRows('school_hr_leaves'))),
        StatSpec(
            label: 'مهامي',
            icon: Icons.task_alt_outlined,
            load: () async => _num(await api.countRows('school_tasks'))),
      ];
    case AppRole.parent:
      return [
        StatSpec(
            label: 'أبنائي',
            icon: Icons.family_restroom_outlined,
            hint: 'مرتبطون بحسابك',
            load: () async => _num((await api.childIds()).length)),
        StatSpec(
            label: 'نتائج منشورة',
            icon: Icons.verified_outlined,
            load: () async =>
                _num(await api.countRows('school_exam_publications'))),
        StatSpec(
            label: 'إعلانات',
            icon: Icons.campaign_outlined,
            load: () async =>
                _num(await api.countRows('school_announcements'))),
        StatSpec(
            label: 'الواجبات',
            icon: Icons.assignment_outlined,
            load: () async => _num(await api.countRows('school_assignments'))),
      ];
    case AppRole.student:
      return [
        StatSpec(
            label: 'المقررات',
            icon: Icons.menu_book_outlined,
            load: () async => _num(await api.enrolledCourseCount())),
        StatSpec(
            label: 'الواجبات',
            icon: Icons.assignment_outlined,
            load: () async => _num(await api.countRows('school_assignments'))),
        StatSpec(
            label: 'شهاداتي',
            icon: Icons.workspace_premium_outlined,
            load: () async => _num(await api.countRows('school_certificates'))),
        StatSpec(
            label: 'حضور مسجّل',
            icon: Icons.fact_check_outlined,
            load: () async => _num(await api.countRows('school_attendance'))),
      ];
  }
}

String roleNote(AppRole role, Profile profile) {
  switch (role) {
    case AppRole.owner:
      return 'مالك المنصة: تظهر المؤسسات والحسابات عبر كل المدارس.';
    case AppRole.admin:
      return 'بيانات مؤسستك فقط. كل رقم مقروء الآن من الخادم.';
    case AppRole.accountant:
      return 'الشاشات المالية فقط — لا وصول إلى درجات الطلاب.';
    case AppRole.teacher:
      return 'الفصول المسندة إليك فقط، والقيد مفروض في قاعدة البيانات.';
    case AppRole.employee:
      return 'خدماتك الوظيفية: الإجازات والمهام.';
    case AppRole.parent:
      return 'أبناؤك المرتبطون بحسابك فقط.';
    case AppRole.student:
      return 'بياناتك الدراسية الخاصة.';
  }
}
