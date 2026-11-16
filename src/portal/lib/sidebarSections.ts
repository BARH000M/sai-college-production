import {
  modulePath,
  visibleNavigation,
  type NavigationItem,
} from "./navigation";

/**
 * Smart School screenshots are an information-architecture reference, not a
 * replacement for SAI branding, screens, authorization, or implemented routes.
 * A section is omitted when none of its children are authorized and ready.
 */
export type SidebarSection = {
  id: string;
  label: string;
  icon: string;
  direct?: boolean;
  items: NavigationItem[];
};

type SectionSpec = Omit<SidebarSection, "items"> & { moduleIds: readonly string[] };

const sections: readonly SectionSpec[] = [
  { id: "dashboard", label: "لوحة التحكم", icon: "ri-dashboard-2-line", direct: true, moduleIds: ["home"] },
  { id: "my-profile", label: "ملفي الشخصي", icon: "ri-user-3-line", direct: true, moduleIds: ["profile"] },
  { id: "front-office", label: "الاستقبال والقبول", icon: "ri-customer-service-2-line", moduleIds: ["admissions", "scanner", "reception"] },
  { id: "student-records", label: "شؤون الطلاب", icon: "ri-group-line", moduleIds: ["students", "classes", "portfolio"] },
  { id: "fees", label: "الرسوم والمالية", icon: "ri-money-dollar-circle-line", moduleIds: ["finance"] },
  { id: "online-courses", label: "الدورات والتعلم", icon: "ri-book-open-line", moduleIds: ["courses", "vocabulary"] },
  { id: "assessment", label: "الواجبات والتقييم", icon: "ri-task-line", moduleIds: ["homework", "progress", "quizzes", "exams"] },
  { id: "attendance", label: "الحضور والانصراف", icon: "ri-calendar-check-line", moduleIds: ["attendance", "qr"] },
  { id: "academics", label: "الشؤون الأكاديمية", icon: "ri-school-line", moduleIds: ["academics", "timetable"] },
  { id: "human-resources", label: "الموارد البشرية", icon: "ri-team-line", moduleIds: ["staff"] },
  { id: "communications", label: "التواصل والإعلانات", icon: "ri-mail-send-line", moduleIds: ["communications", "notifications"] },
  { id: "library", label: "المكتبة والتحميلات", icon: "ri-book-shelf-line", moduleIds: ["library", "downloads"] },
  { id: "services", label: "الخدمات الطلابية", icon: "ri-bus-line", moduleIds: ["transport", "housing", "certificates", "alumni"] },
  { id: "inventory", label: "المخزون", icon: "ri-archive-line", moduleIds: ["inventory"] },
  { id: "content", label: "إدارة المحتوى والموقع", icon: "ri-layout-4-line", moduleIds: ["authoring", "media", "approvals", "cms", "frontCms"] },
  { id: "organization", label: "الفروع والجلسات", icon: "ri-map-pin-2-line", moduleIds: ["branches", "sessions"] },
  { id: "reports", label: "التقارير", icon: "ri-bar-chart-2-line", moduleIds: ["reports"] },
  { id: "administration", label: "النظام والصلاحيات", icon: "ri-shield-user-line", moduleIds: ["roles", "settings", "systemCatalog"] },
];

export function visibleSidebarSections(roles: readonly string[]): SidebarSection[] {
  const allowed = new Map(visibleNavigation(roles).map((item) => [item.id, item]));
  return sections
    .map(({ moduleIds, ...section }) => ({
      ...section,
      items: moduleIds.flatMap((id) => {
        const item = allowed.get(id);
        return item ? [item] : [];
      }),
    }))
    .filter((section) => section.items.length > 0);
}

/**
 * The bottom bar uses useful shortcuts for the signed-in role, never the
 * first five items of the administrative menu. Multi-role accounts get the
 * union of routes they can actually open.
 */
export function mobileTabs(roles: readonly string[]): NavigationItem[] {
  const preferred: readonly string[] = roles.includes("super_admin") || roles.includes("admin")
    ? ["home", "admissions", "students", "reports", "profile"]
    : roles.includes("teacher")
      ? ["home", "classes", "attendance", "homework", "profile"]
      : roles.includes("accountant")
        ? ["home", "finance", "reports", "notifications", "profile"]
        : roles.includes("receptionist")
          ? ["home", "admissions", "students", "attendance", "profile"]
          : roles.includes("librarian")
            ? ["home", "library", "notifications", "reports", "profile"]
            : roles.includes("content_editor")
              ? ["home", "cms", "courses", "notifications", "profile"]
              : roles.includes("student")
                ? ["home", "courses", "homework", "attendance", "profile"]
                : ["home", "students", "progress", "notifications", "profile"];
  const visible = visibleNavigation(roles);
  const byId = new Map(visible.map((item) => [item.id, item]));
  const unique = new Set<string>();
  return [...preferred, ...visible.map((item) => item.id)]
    .flatMap((id) => {
      const item = byId.get(id);
      if (!item || unique.has(id)) return [];
      unique.add(id);
      return [item];
    })
    .slice(0, 5);
}

/** Keep route generation central so submenus cannot invent destinations. */
export function sidebarDestination(item: NavigationItem): string {
  return modulePath(item);
}
