export const roleLabels = {
  super_admin: "الإدارة العامة",
  admin: "مدير الأكاديمية",
  teacher: "المعلم",
  accountant: "المحاسب",
  receptionist: "الاستقبال",
  librarian: "أمين المكتبة",
  student: "الطالب",
  parent: "ولي الأمر",
  content_editor: "محرر المحتوى",
} as const;

export type AppRole = keyof typeof roleLabels;
export type NavigationItem = {
  id: string;
  label: string;
  icon: string;
  roles: readonly AppRole[];
};

const allRoles = Object.keys(roleLabels) as AppRole[];

// Navigation follows the approved role/module map; the database enforces access.
export const navigation: readonly NavigationItem[] = [
  { id: "home", label: "الرئيسية", icon: "ri-home-5-line", roles: allRoles },
  { id: "profile", label: "ملفي الشخصي", icon: "ri-user-3-line", roles: allRoles },
  { id: "notifications", label: "مركز الإشعارات", icon: "ri-notification-3-line", roles: allRoles },
  { id: "admissions", label: "القبول والتسجيل", icon: "ri-user-add-line", roles: ["super_admin", "admin", "receptionist", "teacher"] },
  { id: "scanner", label: "ماسح إيصالات القبول", icon: "ri-qr-scan-2-line", roles: ["super_admin", "admin", "receptionist"] },
  { id: "students", label: "سجلات الطلاب", icon: "ri-group-line", roles: ["super_admin", "admin", "teacher", "receptionist", "parent", "student"] },
  { id: "classes", label: "الصفوف", icon: "ri-building-4-line", roles: ["super_admin", "admin", "teacher", "student", "parent"] },
  { id: "academics", label: "الشؤون الأكاديمية", icon: "ri-book-2-line", roles: ["super_admin", "admin", "teacher"] },
  { id: "timetable", label: "الجداول والتقويم", icon: "ri-calendar-2-line", roles: ["super_admin", "admin", "teacher", "student", "parent", "receptionist"] },
  { id: "qr", label: "الحضور بالرمز QR", icon: "ri-qr-code-line", roles: ["super_admin", "admin", "teacher", "receptionist", "student"] },
  { id: "attendance", label: "الحضور والمتابعة", icon: "ri-calendar-check-line", roles: ["super_admin", "admin", "teacher", "receptionist", "student", "parent"] },
  { id: "courses", label: "المقررات والدروس", icon: "ri-file-list-3-line", roles: ["super_admin", "admin", "teacher", "student", "parent", "content_editor"] },
  { id: "listening", label: "الاستماع", icon: "ri-headphone-line", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "speaking", label: "التحدث والنطق", icon: "ri-mic-line", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "tones", label: "النغمات الصينية", icon: "ri-music-2-line", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "vocabulary", label: "المفردات", icon: "ri-translate-2", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "handwriting", label: "الكتابة اليدوية", icon: "ri-quill-pen-line", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "reading", label: "القراءة", icon: "ri-book-open-line", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "review", label: "المراجعة المتباعدة", icon: "ri-time-line", roles: ["super_admin", "admin", "teacher", "student"] },
  { id: "homework", label: "الواجبات", icon: "ri-task-line", roles: ["super_admin", "admin", "teacher", "student", "parent"] },
  { id: "quizzes", label: "الاختبارات القصيرة", icon: "ri-question-line", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "exams", label: "الامتحانات", icon: "ri-file-paper-2-line", roles: ["super_admin", "admin", "teacher", "student", "parent", "content_editor"] },
  { id: "progress", label: "التقدم التعليمي", icon: "ri-line-chart-line", roles: ["super_admin", "admin", "teacher", "student", "parent"] },
  { id: "authoring", label: "تأليف الدروس", icon: "ri-edit-2-line", roles: ["super_admin", "admin", "content_editor", "teacher"] },
  { id: "media", label: "مكتبة الوسائط", icon: "ri-image-line", roles: ["super_admin", "admin", "content_editor", "teacher"] },
  { id: "approvals", label: "المراجعة والنشر", icon: "ri-checkbox-circle-line", roles: ["super_admin", "admin", "content_editor", "teacher"] },
  { id: "staff", label: "شؤون الموظفين", icon: "ri-team-line", roles: ["super_admin", "admin", "teacher", "accountant", "receptionist", "librarian", "content_editor"] },
  { id: "reception", label: "الاستقبال", icon: "ri-customer-service-2-line", roles: ["super_admin", "admin", "receptionist"] },
  { id: "library", label: "المكتبة", icon: "ri-book-shelf-line", roles: ["super_admin", "admin", "librarian", "teacher", "parent", "student"] },
  { id: "finance", label: "الرسوم والمالية", icon: "ri-money-dollar-circle-line", roles: ["super_admin", "admin", "accountant", "receptionist", "parent", "student"] },
  { id: "communications", label: "التواصل والإعلانات", icon: "ri-mail-line", roles: allRoles },
  { id: "branches", label: "الفروع والجلسات", icon: "ri-map-pin-2-line", roles: ["super_admin", "admin"] },
  { id: "sessions", label: "الجلسات الأكاديمية", icon: "ri-calendar-todo-line", roles: ["super_admin", "admin"] },
  { id: "reports", label: "التقارير والطباعة", icon: "ri-printer-line", roles: ["super_admin", "admin", "teacher", "accountant", "receptionist", "librarian", "content_editor"] },
  { id: "cms", label: "الموقع التعريفي CMS", icon: "ri-layout-4-line", roles: ["super_admin", "admin", "content_editor"] },
  { id: "roles", label: "إدارة الأدوار والصلاحيات", icon: "ri-shield-user-line", roles: ["super_admin"] },
  { id: "downloads", label: "مركز التحميل", icon: "ri-download-cloud-line", roles: ["super_admin","admin","teacher","student","parent","librarian","content_editor"] },
  { id: "inventory", label: "المخزون", icon: "ri-archive-line", roles: ["super_admin","admin","accountant"] },
  { id: "transport", label: "النقل", icon: "ri-bus-line", roles: ["super_admin","admin","receptionist","student","parent"] },
  { id: "portfolio", label: "ملف الإنجاز", icon: "ri-file-user-line", roles: ["super_admin","admin","teacher","student","parent"] },
  { id: "housing", label: "السكن الطلابي", icon: "ri-hotel-bed-line", roles: ["super_admin","admin","receptionist","student","parent"] },
  { id: "certificates", label: "الشهادات", icon: "ri-award-line", roles: ["super_admin","admin","receptionist","student","parent"] },
  { id: "frontCms", label: "صفحات Front CMS", icon: "ri-pages-line", roles: ["super_admin","admin","content_editor"] },
  { id: "alumni", label: "الخريجون", icon: "ri-graduation-cap-line", roles: ["super_admin","admin","receptionist"] },
  { id: "settings", label: "إعدادات النظام", icon: "ri-settings-3-line", roles: ["super_admin","admin"] },
];

/**
 * Screens that are fully wired and safe to open. Anything outside this list is
 * hidden from the sidebar, the mobile bar, the search box and the role dashboard
 * so a user can never land on a screen that pretends to be ready but is not.
 */
const availableModuleIds: readonly string[] = [
  "home", "profile", "notifications", "branches", "sessions", "classes", "students", "admissions", "scanner",
  "courses", "homework", "progress", "attendance", "roles", "reports", "cms",
  "academics", "timetable", "qr", "listening", "speaking", "tones", "vocabulary",
  "handwriting", "reading", "review", "library", "communications", "finance",
  "downloads", "inventory", "transport", "portfolio", "housing", "certificates", "frontCms", "alumni", "settings",
];

export function isAppRole(value: string): value is AppRole {
  return Object.prototype.hasOwnProperty.call(roleLabels, value);
}

export function isModuleAvailable(id: string): boolean {
  return availableModuleIds.includes(id);
}

export function modulePath(item: NavigationItem): string {
  if (item.id === "home") return "/portal/dashboard";
  if (item.id === "profile") return "/portal/profile";
  return `/portal/modules/${item.id}`;
}

export function visibleNavigation(roles: readonly string[]): NavigationItem[] {
  return navigation.filter((item) => isModuleAvailable(item.id) && item.roles.some((role) => roles.includes(role)));
}

/**
 * Modules whose screens exist in the catalogue but whose data foundation or
 * sign-off is not ready. They never appear as links; the dashboard lists them so
 * staff can see what is still being prepared instead of clicking a dead button.
 */
export const pendingModules: readonly { id: string; label: string; reason: string }[] = [
  { id: "quizzes", label: "الاختبارات القصيرة", reason: "تحتاج جداول أسئلة ومحاولات وحساب درجات." },
  { id: "exams", label: "الامتحانات", reason: "تحتاج جدولة امتحانات وربطها بالجلسات الأكاديمية." },
  { id: "authoring", label: "تأليف الدروس", reason: "المحرر الكامل للمحتوى غير مبني بعد؛ تُدار الدروس حالياً من المقررات." },
  { id: "media", label: "مكتبة الوسائط", reason: "تحتاج تخزين ملفات وربطه بمساحة Supabase Storage." },
  { id: "approvals", label: "المراجعة والنشر", reason: "تحتاج حالات مراجعة واعتماد للمحتوى." },
  { id: "staff", label: "شؤون الموظفين", reason: "تحتاج سجلات موظفين وعقوداً وحضوراً إدارياً." },
  { id: "reception", label: "الاستقبال", reason: "تحتاج مسار زوار ومواعيد مستقل عن القبول." },
] as const;

export function isModulePending(id: string): boolean {
  return pendingModules.some((item) => item.id === id);
}