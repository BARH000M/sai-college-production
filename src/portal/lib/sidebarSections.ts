import { modulePath, visibleNavigation, type NavigationItem } from "./navigation";
import { portalModules, portalZones, type PortalModule, type PortalZoneId } from "./portalRegistry";
import { currentSidebarLayout, orderedModuleIds, type SidebarLabelOverride } from "./sidebarLayout";

/**
 * Information architecture for the unified portal.
 *
 * SAI College runs nine role portals on one application. The sidebar follows the
 * approved hierarchy: operational zone → main module → submenu → page. A submenu
 * is omitted when none of its pages are authorized and enabled, so a user never
 * lands on a dead or unpermitted destination.
 *
 * The hierarchy itself lives in `portalRegistry.ts`; this file only resolves it
 * against the live navigation state (role mapping + module toggles).
 */
export type SidebarZoneId = PortalZoneId;

export type SidebarSection = {
  /** Submenu id; also the translation key in `sectionLabels`. */
  id: string;
  /** Arabic source label; translated by `usePortalLang`. */
  label: string;
  icon: string;
  zone: SidebarZoneId;
  /** Main module that owns this submenu. */
  moduleId: string;
  direct?: boolean;
  items: NavigationItem[];
};

export type SidebarModule = {
  id: string;
  label: string;
  icon: string;
  zone: SidebarZoneId;
  sections: SidebarSection[];
  /** True when an administrator saved a custom label for this module. */
  customLabel?: boolean;
  /** Per-language custom labels, used by the sidebar when present. */
  labelI18n?: SidebarLabelOverride;
};

/** Render order and source labels for the sidebar zones. */
export const sidebarZones = portalZones;

/** Modules visible to a set of roles, in registry order. */
export function visibleSidebarModules(roles: readonly string[]): SidebarModule[] {
  const allowed = new Map(visibleNavigation(roles).map((item) => [item.id, item]));
  const layout = currentSidebarLayout();
  const byId = new Map<string, PortalModule>(portalModules.map((module) => [module.id, module]));

  return orderedModuleIds(layout.order)
    .map((id) => byId.get(id))
    .filter((module): module is PortalModule => Boolean(module))
    // Presentation-level hide only; security permissions are enforced elsewhere.
    .filter((module) => !layout.hidden.includes(module.id))
    .map((module) => {
      const sections = module.submenus
        .map((submenu) => {
          const items = submenu.pages
            .map((page) => allowed.get(page.moduleId))
            .filter((item): item is NavigationItem => Boolean(item));
          return {
            id: submenu.id,
            label: submenu.label,
            icon: module.icon,
            zone: module.zone,
            moduleId: module.id,
            direct: items.length === 1 && module.submenus.length === 1,
            items,
          } satisfies SidebarSection;
        })
        .filter((section) => section.items.length > 0);
      const override = layout.labels[module.id];
      const hasOverride = Boolean(override && (override.ar || override.en || override.zh));
      return {
        id: module.id,
        label: (override?.ar?.trim()) || module.label,
        icon: layout.icons[module.id] ?? module.icon,
        zone: module.zone,
        sections,
        customLabel: hasOverride,
        labelI18n: hasOverride ? override : undefined,
      } satisfies SidebarModule;
    })
    .filter((module) => module.sections.length > 0);
}

/** Sections visible to a set of roles, in sidebar order, with their zone. */
export function visibleSidebarSections(roles: readonly string[]): SidebarSection[] {
  return visibleSidebarModules(roles).flatMap((module) => module.sections);
}

/** Groups the visible sections by zone, preserving zone order and dropping empties. */
export function groupedSidebarSections(
  roles: readonly string[],
): { zone: (typeof sidebarZones)[number]; sections: SidebarSection[] }[] {
  const visible = visibleSidebarSections(roles);
  return sidebarZones
    .map((zone) => ({ zone, sections: visible.filter((section) => section.zone === zone.id) }))
    .filter((group) => group.sections.length > 0);
}

/** Groups the visible modules by zone, preserving zone order and dropping empties. */
export function groupedSidebarModules(
  roles: readonly string[],
): { zone: (typeof sidebarZones)[number]; modules: SidebarModule[] }[] {
  const visible = visibleSidebarModules(roles);
  return sidebarZones
    .map((zone) => ({ zone, modules: visible.filter((module) => module.zone === zone.id) }))
    .filter((group) => group.modules.length > 0);
}

/** Sections that contain the given module id, if any. */
export function sectionForModule(roles: readonly string[], moduleId: string): SidebarSection | null {
  return visibleSidebarSections(roles).find((section) => section.items.some((item) => item.id === moduleId)) ?? null;
}

/** The main module that contains the given page, if any. */
export function moduleForPage(roles: readonly string[], moduleId: string): SidebarModule | null {
  return visibleSidebarModules(roles).find((module) => module.sections.some((section) => section.items.some((item) => item.id === moduleId))) ?? null;
}

/**
 * The bottom bar uses useful shortcuts for the signed-in role, never the first
 * five items of the administrative menu. Multi-role accounts get the union of
 * routes they can actually open.
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