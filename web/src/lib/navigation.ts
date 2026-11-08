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
  { id: "home", label: "الرئيسية", icon: "⌂", roles: allRoles },
  { id: "admissions", label: "القبول والتسجيل", icon: "▤", roles: ["super_admin", "admin", "receptionist", "teacher"] },
  { id: "students", label: "سجلات الطلاب", icon: "♙", roles: ["super_admin", "admin", "teacher", "receptionist", "parent", "student"] },
  { id: "classes", label: "الصفوف", icon: "▦", roles: ["super_admin", "admin", "teacher", "student", "parent"] },
  { id: "academics", label: "الشؤون الأكاديمية", icon: "▦", roles: ["super_admin", "admin", "teacher"] },
  { id: "timetable", label: "الجداول والتقويم", icon: "▤", roles: ["super_admin", "admin", "teacher", "student", "parent", "receptionist"] },
  { id: "attendance", label: "الحضور والغياب", icon: "▣", roles: ["super_admin", "admin", "teacher", "accountant", "receptionist", "student", "parent"] },
  { id: "qr", label: "الحضور بالرمز QR", icon: "▦", roles: ["super_admin", "admin", "teacher", "receptionist", "student"] },
  { id: "courses", label: "المقررات والدروس", icon: "▤", roles: ["super_admin", "admin", "teacher", "student", "parent", "content_editor"] },
  { id: "listening", label: "الاستماع", icon: "◉", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "speaking", label: "التحدث والنطق", icon: "◉", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "tones", label: "النغمات الصينية", icon: "♪", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "vocabulary", label: "المفردات", icon: "▤", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "handwriting", label: "الكتابة اليدوية", icon: "✎", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "reading", label: "القراءة", icon: "▤", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "review", label: "المراجعة المتباعدة", icon: "◷", roles: ["super_admin", "admin", "teacher", "student"] },
  { id: "homework", label: "الواجبات", icon: "✎", roles: ["super_admin", "admin", "teacher", "student", "parent"] },
  { id: "quizzes", label: "الاختبارات القصيرة", icon: "☷", roles: ["super_admin", "admin", "teacher", "student", "content_editor"] },
  { id: "exams", label: "الامتحانات", icon: "☷", roles: ["super_admin", "admin", "teacher", "student", "parent", "content_editor"] },
  { id: "certificates", label: "الشهادات والبطاقات", icon: "▤", roles: ["super_admin", "admin", "teacher", "student", "parent", "receptionist"] },
  { id: "progress", label: "التقدم التعليمي", icon: "▥", roles: ["super_admin", "admin", "teacher", "student", "parent"] },
  { id: "authoring", label: "تأليف الدروس", icon: "✎", roles: ["super_admin", "admin", "content_editor", "teacher"] },
  { id: "media", label: "مكتبة الوسائط", icon: "▤", roles: ["super_admin", "admin", "content_editor", "teacher"] },
  { id: "approvals", label: "المراجعة والنشر", icon: "✓", roles: ["super_admin", "admin", "content_editor", "teacher"] },
  { id: "finance", label: "الرسوم والمالية", icon: "◈", roles: ["super_admin", "admin", "accountant", "parent", "student"] },
  { id: "staff", label: "شؤون الموظفين", icon: "♙", roles: ["super_admin", "admin", "teacher", "accountant", "receptionist", "librarian", "content_editor"] },
  { id: "reception", label: "الاستقبال", icon: "♙", roles: ["super_admin", "admin", "receptionist"] },
  { id: "library", label: "المكتبة", icon: "▤", roles: ["super_admin", "admin", "librarian", "teacher", "parent", "student"] },
  { id: "communications", label: "التواصل والإعلانات", icon: "✉", roles: allRoles },
  { id: "branches", label: "الفروع والجلسات", icon: "▦", roles: ["super_admin", "admin"] },
  { id: "sessions", label: "الجلسات الأكاديمية", icon: "◷", roles: ["super_admin", "admin"] },
  { id: "reports", label: "التقارير والطباعة", icon: "▥", roles: allRoles },
  { id: "cms", label: "الموقع التعريفي CMS", icon: "▤", roles: ["super_admin", "admin", "content_editor"] },
  { id: "settings", label: "النظام والصلاحيات", icon: "⚙", roles: allRoles },
];

export function isAppRole(value: string): value is AppRole {
  return Object.prototype.hasOwnProperty.call(roleLabels, value);
}

export function visibleNavigation(roles: readonly string[]): NavigationItem[] {
  return navigation.filter((item) => item.roles.some((role) => roles.includes(role)));
}

export function modulePath(item: NavigationItem): string {
  return item.id === "home" ? "/dashboard" : `/modules/${item.id}`;
}

export function isModuleAvailable(id: string): boolean {
  return ["home", "branches", "sessions", "classes", "students", "admissions", "attendance"].includes(id);
}
