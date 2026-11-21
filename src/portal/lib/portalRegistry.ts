/**
 * Hierarchical navigation registry for the unified SAI College portal.
 *
 * The specification defines one portal architecture for nine roles with the
 * hierarchy: zone → main module → submenu → page → authorized actions.
 *
 * This file is the single source of truth for that hierarchy. Leaf pages point at
 * a stable module id from `navigation.ts`, so every destination is already wired
 * to a real screen and to that module's approved role mapping. Modules that are
 * not verified yet are still registered here (so the control centre can report
 * them) but they resolve to no navigation item and therefore never render as a
 * dead link.
 */
export type PortalZoneId = "daily" | "academics" | "administration";

export type PortalPage = {
  /** Navigation module id this page opens. */
  moduleId: string;
};

export type PortalSubmenu = {
  /** Stable submenu id; also the translation key in `sectionLabels`. */
  id: string;
  /** Arabic source label. */
  label: string;
  pages: readonly PortalPage[];
};

export type PortalModule = {
  /** Stable main-menu id; also the translation key in `moduleLabels`. */
  id: string;
  /** Arabic source label. */
  label: string;
  icon: string;
  zone: PortalZoneId;
  submenus: readonly PortalSubmenu[];
};

/** Zone order and labels for the sidebar. */
export const portalZones: readonly { id: PortalZoneId; label: string; icon: string }[] = [
  { id: "daily", label: "العمل اليومي", icon: "ri-sun-line" },
  { id: "academics", label: "التعليم والتعلم", icon: "ri-book-open-line" },
  { id: "administration", label: "الإدارة والنظام", icon: "ri-shield-user-line" },
];

const page = (moduleId: string): PortalPage => ({ moduleId });

/**
 * Main menu registry. Every navigation module id must appear exactly once as a
 * page below; `portalPageIds()` is asserted in the test suite.
 */
export const portalModules: readonly PortalModule[] = [
  // ---------------------------------------------------------------- daily
  {
    id: "dashboard",
    label: "لوحة التحكم",
    icon: "ri-dashboard-2-line",
    zone: "daily",
    submenus: [
      { id: "overview", label: "نظرة عامة", pages: [page("home")] },
      { id: "account", label: "الملف الشخصي", pages: [page("profile")] },
      { id: "inbox", label: "مركز الإشعارات", pages: [page("notifications")] },
    ],
  },
  {
    id: "front-office",
    label: "الاستقبال والقبول",
    icon: "ri-customer-service-2-line",
    zone: "daily",
    submenus: [
      { id: "enquiries", label: "استفسارات القبول", pages: [page("admissions")] },
      { id: "reception", label: "سجل الزوار", pages: [page("reception")] },
      { id: "scanner", label: "ماسح الإيصالات", pages: [page("scanner")] },
    ],
  },
  {
    id: "student-information",
    label: "شؤون الطلاب",
    icon: "ri-group-line",
    zone: "daily",
    submenus: [
      { id: "records", label: "سجلات الطلاب", pages: [page("students")] },
      { id: "classes", label: "الصفوف والشعب", pages: [page("classes")] },
      { id: "portfolio", label: "ملف الإنجاز", pages: [page("portfolio")] },
    ],
  },
  {
    id: "fees",
    label: "تحصيل الرسوم",
    icon: "ri-money-dollar-circle-line",
    zone: "daily",
    submenus: [{ id: "collection", label: "تحصيل الرسوم", pages: [page("finance")] }],
  },
  {
    id: "attendance",
    label: "الحضور والانصراف",
    icon: "ri-calendar-check-line",
    zone: "daily",
    submenus: [
      { id: "tracking", label: "الحضور والمتابعة", pages: [page("attendance")] },
      { id: "qr", label: "الحضور بالرمز QR", pages: [page("qr")] },
    ],
  },
  {
    id: "communications",
    label: "التواصل والإعلانات",
    icon: "ri-mail-send-line",
    zone: "daily",
    submenus: [{ id: "announcements", label: "الإعلانات والرسائل", pages: [page("communications")] }],
  },
  {
    id: "organisation",
    label: "الفروع والجلسات",
    icon: "ri-map-pin-2-line",
    zone: "daily",
    submenus: [
      { id: "branches", label: "دليل الفروع", pages: [page("branches")] },
      { id: "sessions", label: "الجلسات الأكاديمية", pages: [page("sessions")] },
    ],
  },

  // ------------------------------------------------------------ academics
  {
    id: "courses",
    label: "المقررات الإلكترونية",
    icon: "ri-book-2-line",
    zone: "academics",
    submenus: [{ id: "catalogue", label: "المقررات والدروس", pages: [page("courses")] }],
  },
  {
    id: "languages",
    label: "اللغة الصينية",
    icon: "ri-translate-2",
    zone: "academics",
    submenus: [{ id: "vocabulary", label: "المفردات", pages: [page("vocabulary")] }],
  },
  {
    id: "language-labs",
    label: "مختبرات المهارات",
    icon: "ri-headphone-line",
    zone: "academics",
    submenus: [
      { id: "listening", label: "الاستماع", pages: [page("listening")] },
      { id: "speaking", label: "التحدث والنطق", pages: [page("speaking")] },
      { id: "tones", label: "النغمات الصينية", pages: [page("tones")] },
      { id: "handwriting", label: "الكتابة اليدوية", pages: [page("handwriting")] },
      { id: "reading", label: "القراءة", pages: [page("reading")] },
      { id: "review", label: "المراجعة المتباعدة", pages: [page("review")] },
    ],
  },
  {
    id: "homework",
    label: "الواجبات والتقييم",
    icon: "ri-task-line",
    zone: "academics",
    submenus: [
      { id: "homework", label: "الواجبات", pages: [page("homework")] },
      { id: "quizzes", label: "الاختبارات القصيرة", pages: [page("quizzes")] },
    ],
  },
  {
    id: "examinations",
    label: "الاختبارات والامتحانات",
    icon: "ri-file-paper-2-line",
    zone: "academics",
    submenus: [{ id: "exams", label: "الامتحانات", pages: [page("exams")] }],
  },
  {
    id: "progress",
    label: "التقدم التعليمي",
    icon: "ri-line-chart-line",
    zone: "academics",
    submenus: [{ id: "progress", label: "التقدم التعليمي", pages: [page("progress")] }],
  },
  {
    id: "content-studio",
    label: "استوديو المحتوى",
    icon: "ri-edit-2-line",
    zone: "academics",
    submenus: [
      { id: "authoring", label: "تأليف الدروس", pages: [page("authoring")] },
      { id: "media", label: "مكتبة الوسائط", pages: [page("media")] },
      { id: "approvals", label: "المراجعة والنشر", pages: [page("approvals")] },
    ],
  },
  {
    id: "academic-affairs",
    label: "الشؤون الأكاديمية",
    icon: "ri-school-line",
    zone: "academics",
    submenus: [
      { id: "affairs", label: "الشؤون الأكاديمية", pages: [page("academics")] },
      { id: "timetable", label: "الجداول والتقويم", pages: [page("timetable")] },
    ],
  },
  {
    id: "library",
    label: "المكتبة",
    icon: "ri-book-shelf-line",
    zone: "academics",
    submenus: [{ id: "library", label: "المكتبة", pages: [page("library")] }],
  },
  {
    id: "downloads",
    label: "مركز التحميل",
    icon: "ri-download-cloud-line",
    zone: "academics",
    submenus: [{ id: "downloads", label: "مركز التحميل", pages: [page("downloads")] }],
  },

  // ------------------------------------------------------- administration
  {
    id: "hr",
    label: "الموارد البشرية",
    icon: "ri-team-line",
    zone: "administration",
    submenus: [{ id: "staff", label: "شؤون الموظفين", pages: [page("staff")] }],
  },
  {
    id: "reports",
    label: "التقارير",
    icon: "ri-bar-chart-2-line",
    zone: "administration",
    submenus: [{ id: "reports", label: "التقارير والطباعة", pages: [page("reports")] }],
  },
  {
    id: "website-cms",
    label: "الموقع التعريفي",
    icon: "ri-layout-4-line",
    zone: "administration",
    submenus: [
      { id: "cms", label: "الموقع التعريفي CMS", pages: [page("cms")] },
      { id: "frontCms", label: "صفحات Front CMS", pages: [page("frontCms")] },
    ],
  },
  {
    id: "services",
    label: "الخدمات الطلابية",
    icon: "ri-bus-line",
    zone: "administration",
    submenus: [
      { id: "transport", label: "النقل", pages: [page("transport")] },
      { id: "housing", label: "السكن الطلابي", pages: [page("housing")] },
      { id: "certificates", label: "الشهادات", pages: [page("certificates")] },
      { id: "alumni", label: "الخريجون", pages: [page("alumni")] },
    ],
  },
  {
    id: "inventory",
    label: "المخزون",
    icon: "ri-archive-line",
    zone: "administration",
    submenus: [{ id: "inventory", label: "المخزون", pages: [page("inventory")] }],
  },
  {
    id: "access-control",
    label: "الأدوار والصلاحيات",
    icon: "ri-shield-user-line",
    zone: "administration",
    submenus: [
      { id: "roles", label: "إدارة الأدوار", pages: [page("roles")] },
      { id: "permissions", label: "مصفوفة الصلاحيات", pages: [page("permissionsCenter")] },
    ],
  },
  {
    id: "system",
    label: "النظام والنسخ الاحتياطي",
    icon: "ri-settings-3-line",
    zone: "administration",
    submenus: [
      { id: "settings", label: "إعدادات النظام", pages: [page("settings")] },
      { id: "catalog", label: "جرد النظام", pages: [page("systemCatalog")] },
      { id: "backups", label: "النسخ الاحتياطي", pages: [page("backups")] },
      { id: "sidebar", label: "إدارة القائمة الجانبية", pages: [page("sidebarManager")] },
      { id: "coverage", label: "تدقيق التغطية", pages: [page("coverageAudit")] },
    ],
  },
];

/** Every module id referenced by a page in the registry. */
export function portalPageIds(): string[] {
  return portalModules.flatMap((module) => module.submenus.flatMap((submenu) => submenu.pages.map((p) => p.moduleId)));
}

/** The main module that owns a page, if any. */
export function portalModuleForPage(moduleId: string): PortalModule | null {
  return portalModules.find((module) => module.submenus.some((submenu) => submenu.pages.some((p) => p.moduleId === moduleId))) ?? null;
}

/** The submenu that owns a page, if any. */
export function portalSubmenuForPage(moduleId: string): PortalSubmenu | null {
  for (const module of portalModules) {
    const submenu = module.submenus.find((entry) => entry.pages.some((p) => p.moduleId === moduleId));
    if (submenu) return submenu;
  }
  return null;
}

/** Ordered page ids of one module, used for counts and quick navigation. */
export function portalModulePageIds(moduleId: string): string[] {
  const module = portalModules.find((entry) => entry.id === moduleId);
  return module ? module.submenus.flatMap((submenu) => submenu.pages.map((p) => p.moduleId)) : [];
}