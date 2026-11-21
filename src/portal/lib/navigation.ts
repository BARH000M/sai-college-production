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
  { id: "admissions", label: "القبول والتسجيل", icon: "ri-user-add-line", roles: ["super_admin", "admin", "receptionist"] },
  { id: "scanner", label: "ماسح إيصالات القبول", icon: "ri-qr-scan-2-line", roles: ["super_admin", "admin", "receptionist"] },
  { id: "students", label: "سجلات الطلاب", icon: "ri-group-line", roles: ["super_admin", "admin", "receptionist"] },
  { id: "classes", label: "الصفوف", icon: "ri-building-4-line", roles: ["super_admin", "admin"] },
  { id: "academics", label: "الشؤون الأكاديمية", icon: "ri-book-2-line", roles: ["super_admin", "admin", "teacher"] },
  { id: "timetable", label: "الجداول والتقويم", icon: "ri-calendar-2-line", roles: ["super_admin", "admin", "teacher", "student", "parent", "receptionist"] },
  { id: "qr", label: "الحضور بالرمز QR", icon: "ri-qr-code-line", roles: ["super_admin", "admin", "teacher", "receptionist", "student"] },
  { id: "attendance", label: "الحضور والمتابعة", icon: "ri-calendar-check-line", roles: ["super_admin", "admin", "teacher", "receptionist"] },
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
  { id: "staff", label: "شؤون الموظفين", icon: "ri-team-line", roles: ["super_admin", "admin"] },
  { id: "reception", label: "الاستقبال", icon: "ri-customer-service-2-line", roles: ["super_admin", "admin", "receptionist"] },
  { id: "library", label: "المكتبة", icon: "ri-book-shelf-line", roles: ["super_admin", "admin", "librarian", "teacher", "parent", "student"] },
  { id: "finance", label: "الرسوم والمالية", icon: "ri-money-dollar-circle-line", roles: ["super_admin", "admin", "accountant", "parent", "student"] },
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
  { id: "systemCatalog", label: "جرد النظام والوحدات", icon: "ri-list-check-2", roles: ["super_admin"] },
  { id: "backups", label: "النسخ الاحتياطي والاستعادة", icon: "ri-database-2-line", roles: ["super_admin"] },
  { id: "permissionsCenter", label: "مصفوفة الصلاحيات المتقدمة", icon: "ri-shield-keyhole-line", roles: ["super_admin"] },
  { id: "sidebarManager", label: "إدارة القائمة الجانبية", icon: "ri-layout-left-2-line", roles: ["super_admin"] },
  { id: "coverageAudit", label: "تدقيق التغطية", icon: "ri-file-list-3-line", roles: ["super_admin","admin"] },
];

/**
 * Screens that are fully wired and safe to open. Anything outside this list is
 * hidden from the sidebar, the mobile bar, the search box and the role dashboard
 * so a user can never land on a screen that pretends to be ready but is not.
 */
const availableModuleIds: readonly string[] = [
  "home", "profile", "notifications", "branches", "sessions", "classes", "students", "admissions", "scanner",
  "courses", "homework", "progress", "attendance", "exams", "roles", "reports", "cms",
  "academics", "timetable", "qr", "vocabulary", "library", "communications", "finance",
  "settings", "systemCatalog", "staff",
  "downloads", "inventory", "transport", "portfolio", "housing", "certificates", "frontCms", "alumni",
  "backups",
  "listening", "speaking", "tones", "handwriting", "reading", "review", "authoring",
  "permissionsCenter", "sidebarManager", "coverageAudit",
  "media", "approvals", "quizzes", "reception",
];

export function isAppRole(value: string): value is AppRole {
  return Object.prototype.hasOwnProperty.call(roleLabels, value);
}

/**
 * Modules that must never be switched off, so a super administrator can always
 * reach Settings to re-enable anything else.
 */
export const alwaysOnModuleIds: readonly string[] = [
  "home", "profile", "notifications", "settings", "systemCatalog", "roles", "backups",
  "permissionsCenter", "sidebarManager",
];

// Live toggle state, loaded once per session from sai_module_toggles.
let disabledModuleIds: ReadonlySet<string> = new Set();
// Per-role overrides, loaded from sai_module_role_overrides (moduleId -> role -> enabled).
let moduleRoleOverrides: ReadonlyMap<string, ReadonlyMap<string, boolean>> = new Map();

export function applyModuleToggles(
  disabledIds: readonly string[],
  overrides: Record<string, Record<string, boolean>> = {},
): void {
  const next = new Set<string>();
  for (const id of disabledIds) if (!alwaysOnModuleIds.includes(id)) next.add(id);
  disabledModuleIds = next;

  const map = new Map<string, ReadonlyMap<string, boolean>>();
  for (const [moduleId, roleMap] of Object.entries(overrides)) {
    if (alwaysOnModuleIds.includes(moduleId)) continue;
    const inner = new Map<string, boolean>();
    for (const [role, enabled] of Object.entries(roleMap ?? {})) {
      // A per-role override may only ever target one of the nine approved roles;
      // anything else is dropped so it can never widen access.
      if (!isAppRole(role)) continue;
      inner.set(role, enabled === true);
    }
    if (inner.size > 0) map.set(moduleId, inner);
  }
  moduleRoleOverrides = map;
}

/** Explicit per-role override, or null when the role inherits the global state. */
export function moduleRoleOverride(moduleId: string, role: string): boolean | null {
  const inner = moduleRoleOverrides.get(moduleId);
  if (!inner) return null;
  const value = inner.get(role);
  return value === undefined ? null : value;
}

export function isModuleDisabled(id: string): boolean {
  return disabledModuleIds.has(id);
}

/**
 * Effective state for a set of roles.
 *
 * Precedence is strict: an always-on module is always visible, a global OFF hides
 * the module for every role, and only then do per-role overrides apply. A per-role
 * "enabled" row can therefore never bypass a global disable — it only restores the
 * global state for one role, or switches it off for one role. Multi-role accounts
 * get the union: the module is visible when at least one of their roles is enabled.
 */
export function isModuleEnabledFor(moduleId: string, roles: readonly string[]): boolean {
  if (alwaysOnModuleIds.includes(moduleId)) return true;
  // Global OFF wins over every per-role override.
  if (disabledModuleIds.has(moduleId)) return false;
  const inner = moduleRoleOverrides.get(moduleId);
  if (!inner || inner.size === 0) return true;
  if (roles.length === 0) return true;
  for (const role of roles) {
    const override = inner.get(role);
    // An explicit "off" hides the module for that role only; unknown/inherit keeps it.
    if (override === undefined || override === true) return true;
  }
  return false;
}

/**
 * Snapshot shape loaded from sai_module_toggles and sai_module_role_overrides.
 * `null` means that particular read failed, which is different from an empty list.
 */
export type ModuleToggleSnapshot = {
  toggles: readonly { module_id: string; enabled: boolean }[] | null;
  overrides: readonly { module_id: string; role: string; enabled: boolean }[] | null;
};

/**
 * Applies a loaded snapshot.
 *
 * Failure behaviour is deliberate: when the global toggle list could not be read,
 * the last successfully applied state is kept untouched instead of being cleared.
 * A transient error therefore never resurrects a module an administrator disabled,
 * and a first-load failure still fails open (no module is hidden) so the portal
 * remains reachable — navigation is a UI hint, row level security still enforces data
 * access. If only the override read failed, the global state still applies and every
 * role inherits it.
 */
export function applyModuleToggleSnapshot(snapshot: ModuleToggleSnapshot): void {
  if (snapshot.toggles === null) return;
  const disabled = snapshot.toggles
    .filter((row) => row.enabled === false)
    .map((row) => row.module_id);
  const overrides: Record<string, Record<string, boolean>> = {};
  for (const row of snapshot.overrides ?? []) {
    // Reject a role value that is not one of the nine approved roles.
    if (!isAppRole(row.role)) continue;
    overrides[row.module_id] = { ...(overrides[row.module_id] ?? {}), [row.role]: row.enabled === true };
  }
  applyModuleToggles(disabled, overrides);
}

/** Modules a super administrator may toggle in Settings (available and not always-on). */
export function toggleableModules(): NavigationItem[] {
  return navigation.filter((item) => availableModuleIds.includes(item.id) && !alwaysOnModuleIds.includes(item.id));
}

export function isModuleAvailable(id: string, roles?: readonly string[]): boolean {
  if (!availableModuleIds.includes(id)) return false;
  if (roles) return isModuleEnabledFor(id, roles);
  return !disabledModuleIds.has(id);
}

export function canAccessModule(id: string, roles: readonly string[]): boolean {
  const item = navigation.find((entry) => entry.id === id);
  return !!item && item.roles.some((role) => roles.includes(role));
}

export function modulePath(item: NavigationItem): string {
  if (item.id === "home") return "/portal/dashboard";
  if (item.id === "profile") return "/portal/profile";
  return `/portal/modules/${item.id}`;
}

export function visibleNavigation(roles: readonly string[]): NavigationItem[] {
  return navigation.filter((item) => isModuleAvailable(item.id, roles) && canAccessModule(item.id, roles));
}

/**
 * Modules whose screens exist in the catalogue but whose data foundation or
 * sign-off is not ready. They never appear as links; the dashboard lists them so
 * staff can see what is still being prepared instead of clicking a dead button.
 *
 * V4.0 completed the four remaining modules (media, approvals, quizzes,
 * reception). They are now wired and reachable, so the pending list is empty;
 * the export is kept so the dashboard and tests keep a stable contract.
 */
export const pendingModules: readonly { id: string; label: string; reason: string }[] = [] as const;

export function isModulePending(id: string): boolean {
  return pendingModules.some((item) => item.id === id);
}