import { useEffect, useState } from "react";
import { NavLink, useLocation } from "react-router-dom";
import {
  groupedSidebarModules,
  sidebarDestination,
  type SidebarModule,
  type SidebarSection,
} from "../lib/sidebarSections";
import { usePortalLang } from "../lib/portalLangContext";

type RoleSidebarProps = {
  roles: readonly string[];
  collapsed: boolean;
  onExpand: () => void;
  onNavigate: () => void;
  unreadCount: number;
};

/**
 * Zone-grouped, three-level portal navigation.
 *
 * Zone → main module (expandable) → submenu → page. Only authorized and enabled
 * modules are rendered, so a collapsed module can never hide the active
 * destination. The module that owns the current page always re-opens, and the
 * expansion choice is preserved while the user moves between pages.
 */
export function RoleSidebar({ roles, collapsed, onExpand, onNavigate, unreadCount }: RoleSidebarProps) {
  const { t, tNav, tModule, tSection, tZone, lang } = usePortalLang();
  const moduleLabel = (module: SidebarModule) => (
    module.customLabel && module.labelI18n ? (module.labelI18n[lang] || module.label) : tModule(module.id, module.label)
  );
  const location = useLocation();
  // Recomputed each render so module toggles apply without a remount.
  const groups = groupedSidebarModules(roles);

  const activeModuleId = (() => {
    for (const group of groups) {
      for (const module of group.modules) {
        if (module.sections.some((section) => section.items.some((item) => sidebarDestination(item) === location.pathname))) {
          return module.id;
        }
      }
    }
    return null;
  })();

  const [expanded, setExpanded] = useState<ReadonlySet<string>>(() => new Set());

  // Re-open the module that owns the current page after navigation.
  useEffect(() => {
    if (!activeModuleId) return;
    setExpanded((previous) => (
      previous.has(activeModuleId) ? previous : new Set(previous).add(activeModuleId)
    ));
  }, [activeModuleId]);

  function toggleModule(module: SidebarModule, isOpen: boolean) {
    if (collapsed) onExpand();
    setExpanded((previous) => {
      const next = new Set(previous);
      if (isOpen) next.delete(module.id); else next.add(module.id);
      return next;
    });
  }

  function renderPage(section: SidebarSection, item: SidebarSection["items"][number], nested: boolean) {
    return (
      <NavLink
        key={item.id}
        className={`nav-link ${nested ? "role-nav-child" : ""}`}
        to={sidebarDestination(item)}
        title={tNav(item.id, item.label)}
        onClick={onNavigate}
      >
        <i className={item.icon} aria-hidden="true" />
        <span className="sidebar-label">
          {tNav(item.id, item.label)}
          {item.id === "homework" && unreadCount > 0 && (
            <small className="nav-badge" aria-label={`${unreadCount} ${t("unreadNotifications")}`}>
              {unreadCount > 99 ? "99+" : unreadCount}
            </small>
          )}
        </span>
      </NavLink>
    );
  }

  return (
    <nav className="role-sidebar-nav" aria-label={t("navLabel")}>
      {groups.map((group) => (
        <div className="portal-zone" key={group.zone.id}>
          <p className="portal-zone-label sidebar-label">
            <i className={group.zone.icon} aria-hidden="true" />
            <span>{tZone(group.zone.id, group.zone.label)}</span>
          </p>

          {group.modules.map((module) => {
            const isActive = module.id === activeModuleId;
            const isOpen = isActive || expanded.has(module.id);
            const pageCount = module.sections.reduce((sum, section) => sum + section.items.length, 0);

            // A module with a single submenu and a single page is a direct link.
            if (module.sections.length === 1 && module.sections[0].items.length === 1) {
              const section = module.sections[0];
              const item = section.items[0];
              return (
                <NavLink
                  key={module.id}
                  to={sidebarDestination(item)}
                  className="nav-link"
                  title={tNav(item.id, item.label)}
                  onClick={onNavigate}
                >
                  <i className={item.icon} aria-hidden="true" />
                  <span className="sidebar-label">{tNav(item.id, item.label)}</span>
                </NavLink>
              );
            }

            const childId = `role-nav-module-${module.id}`;
            return (
              <div className={`role-nav-section ${isActive ? "role-nav-current" : ""}`} key={module.id}>
                <button
                  className="nav-link role-nav-toggle"
                  type="button"
                  aria-expanded={isOpen}
                  aria-controls={childId}
                  title={moduleLabel(module)}
                  onClick={() => toggleModule(module, isOpen)}
                >
                  <i className={module.icon} aria-hidden="true" />
                  <span className="sidebar-label role-nav-label">{moduleLabel(module)}</span>
                  <span className="sidebar-label nav-count">{pageCount}</span>
                  <i
                    className={`ri-arrow-down-s-line sidebar-label role-nav-chevron ${isOpen ? "rotated" : ""}`}
                    aria-hidden="true"
                  />
                </button>

                <div className={`role-nav-children ${isOpen ? "is-open" : ""}`} id={childId}>
                  {module.sections.map((section) => (
                    <div className="role-nav-submenu" key={section.id}>
                      {section.items.length > 1 && (
                        <p className="role-nav-submenu-label sidebar-label">
                          {tSection(section.id, section.label)}
                        </p>
                      )}
                      {section.items.map((item) => renderPage(section, item, true))}
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      ))}
    </nav>
  );
}

export default RoleSidebar;