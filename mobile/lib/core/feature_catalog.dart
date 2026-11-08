import 'package:flutter/material.dart';
import 'app_role.dart';

class FeatureModule {
  const FeatureModule({required this.id, required this.label, required this.pillar, required this.roles, required this.tabs});
  final String id;
  final String label;
  final String pillar;
  final Set<AppRole> roles;
  final List<String> tabs;

  IconData get icon => switch (id) {
    'home' => Icons.home_outlined,
    'admissions' => Icons.how_to_reg_outlined,
    'students' => Icons.people_alt_outlined,
    'academics' => Icons.school_outlined,
    'timetable' => Icons.calendar_month_outlined,
    'attendance' => Icons.fact_check_outlined,
    'qr' => Icons.qr_code_2_outlined,
    'courses' => Icons.menu_book_outlined,
    'listening' => Icons.headphones_outlined,
    'speaking' => Icons.record_voice_over_outlined,
    'tones' => Icons.graphic_eq_outlined,
    'vocabulary' => Icons.translate_outlined,
    'handwriting' => Icons.draw_outlined,
    'reading' => Icons.auto_stories_outlined,
    'review' => Icons.replay_outlined,
    'homework' => Icons.assignment_outlined,
    'quizzes' || 'exams' => Icons.quiz_outlined,
    'certificates' => Icons.workspace_premium_outlined,
    'progress' => Icons.trending_up_outlined,
    'authoring' => Icons.edit_note_outlined,
    'media' => Icons.perm_media_outlined,
    'approvals' => Icons.fact_check_outlined,
    'finance' => Icons.payments_outlined,
    'staff' => Icons.badge_outlined,
    'reception' => Icons.support_agent_outlined,
    'library' => Icons.local_library_outlined,
    'communications' => Icons.campaign_outlined,
    'branches' => Icons.account_tree_outlined,
    'reports' => Icons.bar_chart_outlined,
    'cms' => Icons.language_outlined,
    'settings' => Icons.settings_outlined,
    _ => Icons.grid_view_outlined,
  };
}

const featureModules = <FeatureModule>[
  FeatureModule(
    id: "home", label: "الرئيسية", pillar: "المؤسسة",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.accountant, AppRole.receptionist, AppRole.librarian, AppRole.student, AppRole.parent, AppRole.contentEditor}, tabs: ["نظرة عامة"],
  ),
  FeatureModule(
    id: "admissions", label: "القبول والتسجيل", pillar: "الإدارة",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.receptionist}, tabs: ["استفسارات القبول", "الطلبات", "التسجيل"],
  ),
  FeatureModule(
    id: "students", label: "سجلات الطلاب", pillar: "الإدارة",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.receptionist, AppRole.parent, AppRole.student}, tabs: ["ملفات الطلاب", "أولياء الأمور", "استيراد تجريبي"],
  ),
  FeatureModule(
    id: "academics", label: "الشؤون الأكاديمية", pillar: "الإدارة",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher}, tabs: ["البرامج والمستويات", "الصفوف والشعب", "الخطة الدراسية"],
  ),
  FeatureModule(
    id: "timetable", label: "الجداول والتقويم", pillar: "الإدارة",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.parent, AppRole.receptionist}, tabs: ["جدول الحصص", "الاختبارات المجدولة", "التقويم السنوي"],
  ),
  FeatureModule(
    id: "attendance", label: "الحضور والغياب", pillar: "الإدارة",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.accountant, AppRole.receptionist, AppRole.student, AppRole.parent}, tabs: ["حضور الطلاب", "حضور الموظفين", "التقارير"],
  ),
  FeatureModule(
    id: "qr", label: "الحضور بالرمز QR", pillar: "الإدارة",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.receptionist, AppRole.student}, tabs: ["بطاقة الحضور", "محاكاة التحقق"],
  ),
  FeatureModule(
    id: "courses", label: "المقررات والدروس", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.parent, AppRole.contentEditor}, tabs: ["كتالوج المقررات", "الدروس", "الموارد والتنزيلات", "الحصص المباشرة"],
  ),
  FeatureModule(
    id: "listening", label: "الاستماع", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.contentEditor}, tabs: ["مختبر الاستماع"],
  ),
  FeatureModule(
    id: "speaking", label: "التحدث والنطق", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.contentEditor}, tabs: ["التدريب الشفهي"],
  ),
  FeatureModule(
    id: "tones", label: "النغمات الصينية", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.contentEditor}, tabs: ["تمييز النغمات"],
  ),
  FeatureModule(
    id: "vocabulary", label: "المفردات", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.contentEditor}, tabs: ["البطاقات", "المحفوظات"],
  ),
  FeatureModule(
    id: "handwriting", label: "الكتابة اليدوية", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.contentEditor}, tabs: ["لوحة الكتابة"],
  ),
  FeatureModule(
    id: "reading", label: "القراءة", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.contentEditor}, tabs: ["نصوص وفهم"],
  ),
  FeatureModule(
    id: "review", label: "المراجعة المتباعدة", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student}, tabs: ["مستحق اليوم", "سجل المراجعات"],
  ),
  FeatureModule(
    id: "homework", label: "الواجبات", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.parent}, tabs: ["واجبات قائمة", "التسليم والتقييم"],
  ),
  FeatureModule(
    id: "quizzes", label: "الاختبارات القصيرة", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.contentEditor}, tabs: ["تدريب قصير", "النتيجة"],
  ),
  FeatureModule(
    id: "exams", label: "الامتحانات", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.parent, AppRole.contentEditor}, tabs: ["الجدول والنتائج", "بنك الأسئلة", "التقييم"],
  ),
  FeatureModule(
    id: "certificates", label: "الشهادات والبطاقات", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.parent, AppRole.receptionist}, tabs: ["شهادات الإنجاز", "بطاقات الطلاب", "السيرة الدراسية"],
  ),
  FeatureModule(
    id: "progress", label: "التقدم التعليمي", pillar: "التعلم",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.student, AppRole.parent}, tabs: ["الأبعاد التعليمية", "تقارير الطالب"],
  ),
  FeatureModule(
    id: "authoring", label: "تأليف الدروس", pillar: "المحتوى",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.contentEditor, AppRole.teacher}, tabs: ["تحرير الدرس", "المحتوى متعدد اللغات", "الإصدارات"],
  ),
  FeatureModule(
    id: "media", label: "مكتبة الوسائط", pillar: "المحتوى",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.contentEditor, AppRole.teacher}, tabs: ["صور", "صوت", "فيديو", "ملفات"],
  ),
  FeatureModule(
    id: "approvals", label: "المراجعة والنشر", pillar: "المحتوى",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.contentEditor, AppRole.teacher}, tabs: ["قائمة المراجعة", "منشور", "السجل"],
  ),
  FeatureModule(
    id: "finance", label: "الرسوم والمالية", pillar: "العمليات",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.accountant, AppRole.parent, AppRole.student}, tabs: ["الفواتير", "المجموعات والخصومات", "الإيصالات", "الدخل والمصروفات"],
  ),
  FeatureModule(
    id: "staff", label: "شؤون الموظفين", pillar: "العمليات",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.accountant, AppRole.receptionist, AppRole.librarian, AppRole.contentEditor}, tabs: ["دليل الموظفين", "الإجازات", "الحضور"],
  ),
  FeatureModule(
    id: "reception", label: "الاستقبال", pillar: "العمليات",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.receptionist}, tabs: ["الزوار", "المكالمات", "مواعيد ومراسلات"],
  ),
  FeatureModule(
    id: "library", label: "المكتبة", pillar: "العمليات",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.librarian, AppRole.teacher, AppRole.parent, AppRole.student}, tabs: ["الفهرس", "الإعارة والإرجاع", "الحجوزات"],
  ),
  FeatureModule(
    id: "communications", label: "التواصل والإعلانات", pillar: "العمليات",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.accountant, AppRole.receptionist, AppRole.librarian, AppRole.student, AppRole.parent, AppRole.contentEditor}, tabs: ["الإعلانات", "الرسائل", "قوالب التواصل"],
  ),
  FeatureModule(
    id: "branches", label: "الفروع والجلسات", pillar: "المؤسسة",
    roles: {AppRole.superAdmin, AppRole.admin}, tabs: ["الفروع", "الجلسات الأكاديمية", "الفعاليات"],
  ),
  FeatureModule(
    id: "reports", label: "التقارير والطباعة", pillar: "المؤسسة",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.accountant, AppRole.receptionist, AppRole.librarian, AppRole.parent, AppRole.student, AppRole.contentEditor}, tabs: ["تقارير نطاقي", "السلوك والمتابعة", "الطباعة"],
  ),
  FeatureModule(
    id: "cms", label: "الموقع التعريفي CMS", pillar: "المحتوى",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.contentEditor}, tabs: ["الصفحات", "القوائم", "البنرات والمعرض"],
  ),
  FeatureModule(
    id: "settings", label: "النظام والصلاحيات", pillar: "المؤسسة",
    roles: {AppRole.superAdmin, AppRole.admin, AppRole.teacher, AppRole.accountant, AppRole.receptionist, AppRole.librarian, AppRole.student, AppRole.parent, AppRole.contentEditor}, tabs: ["حسابي", "دليل الصلاحيات", "سجل التدقيق", "التكاملات", "نطاق النسخة"],
  ),
];

List<FeatureModule> modulesForRole(AppRole role) =>
    featureModules.where((module) => module.roles.contains(role)).toList(growable: false);
