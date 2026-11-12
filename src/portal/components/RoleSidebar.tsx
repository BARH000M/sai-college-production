import { useState } from "react";
import { NavLink, useLocation } from "react-router-dom";
import { sidebarDestination, visibleSidebarSections } from "../lib/sidebarSections";

export function RoleSidebar({ roles, collapsed, onExpand, onNavigate, unreadCount }: {
  roles: readonly string[];
  collapsed: boolean;
  onExpand: () => void;
  onNavigate: () => void;
  unreadCount: number;
}) {
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(() => new Set());
  const location = useLocation();
  const sections = visibleSidebarSections(roles);

  return <nav className="role-sidebar-nav" aria-label="التنقل الرئيسي">
    {sections.map((section) => {
      const active = section.items.some((item) => sidebarDestination(item) === location.pathname);
      const open = active || expanded.has(section.id);
      if (section.direct && section.items.length === 1) {
        const item = section.items[0];
        return <NavLink
          key={section.id}
          to={sidebarDestination(item)}
          className="nav-link"
          title={item.label}
          onClick={onNavigate}
        >
          <i className={item.icon} aria-hidden="true" />
          <span className="sidebar-label">{item.label}</span>
        </NavLink>;
      }
      return <div className={`role-nav-section ${active ? "role-nav-current" : ""}`} key={section.id}>
        <button
          className="nav-link role-nav-toggle"
          type="button"
          aria-expanded={open}
          aria-controls={`role-nav-${section.id}`}
          title={section.label}
          onClick={() => {
            if (collapsed) onExpand();
            setExpanded((previous) => {
              const next = new Set(previous);
              if (next.has(section.id)) next.delete(section.id);
              else next.add(section.id);
              return next;
            });
          }}
        >
          <i className={section.icon} aria-hidden="true" />
          <span className="sidebar-label role-nav-label">{section.label}</span>
          <i className={`ri-arrow-down-s-line sidebar-label role-nav-chevron ${open ? "rotated" : ""}`} aria-hidden="true" />
        </button>
        {open && <div className="role-nav-children" id={`role-nav-${section.id}`}>
          {section.items.map((item) => <NavLink
            key={item.id}
            className="nav-link role-nav-child"
            to={sidebarDestination(item)}
            title={item.label}
            onClick={onNavigate}
          >
            <i className={item.icon} aria-hidden="true" />
            <span className="sidebar-label">
              {item.label}
              {item.id === "homework" && unreadCount > 0 && <small className="nav-badge">{unreadCount}</small>}
            </span>
          </NavLink>)}
        </div>}
      </div>;
    })}
  </nav>;
}
