import { useEffect, useMemo, useState, type ReactNode } from "react";
import { NavLink, useLocation } from "react-router-dom";
import logo from "../assets/saiLogo";
import { isAppRole, modulePath, roleLabels, visibleNavigation } from "../lib/navigation";
import { mobileTabs, moduleForPage, sectionForModule } from "../lib/sidebarSections";
import { usePortalLang } from "../lib/portalLangContext";
import { useLearningNotifications } from "../hooks/useLearningNotifications";
import { useNotificationFeed } from "../hooks/useNotificationFeed";
import { LanguageSwitcher } from "./LanguageSwitcher";
import { RoleSidebar } from "./RoleSidebar";
import "./role-sidebar.css";
import "./portal-redesign.css";

const ACTIVE_ROLE_KEY = "sai-portal-active-role";

type AppShellProps = {
  profileName: string;
  email: string | null;
  roles: readonly string[];
  onSignOut: () => void;
  busy: boolean;
  signOutError: string | null;
  onboardingNotices?: readonly string[];
  children: ReactNode;
};

export function AppShell({
  profileName, email, roles, onSignOut, busy, signOutError, onboardingNotices = [], children,
}: AppShellProps) {
  const [collapsed, setCollapsed] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [search, setSearch] = useState("");
  const { t, tNav, tModule, tSection, dir } = usePortalLang();
  // Breadcrumb chevrons must point toward the reading direction.
  const crumbSeparator = dir === "rtl" ? "ri-arrow-left-s-line" : "ri-arrow-right-s-line";
  const location = useLocation();
  const { count: unreadCount } = useLearningNotifications(roles);
  const { unread: noticeCount } = useNotificationFeed(roles);

  // Active portal role. An account with several approved roles may narrow the
  // portal it is viewing; this only ever reduces the visible navigation and never
  // grants access, because every page still authorizes against the full role list.
  const [activeRole, setActiveRole] = useState<string>(() => {
    if (typeof window !== "undefined") {
      try {
        const stored = window.localStorage.getItem(ACTIVE_ROLE_KEY) ?? "";
        if (stored && roles.includes(stored)) return stored;
      } catch {
        // Storage may be blocked; fall through to the default role.
      }
    }
    return roles.includes("super_admin") ? "super_admin" : (roles[0] ?? "");
  });

  useEffect(() => {
    if (activeRole && roles.includes(activeRole)) return;
    setActiveRole(roles.includes("super_admin") ? "super_admin" : (roles[0] ?? ""));
  }, [roles, activeRole]);

  function switchRole(role: string) {
    if (!roles.includes(role)) return;
    setActiveRole(role);
    try {
      window.localStorage.setItem(ACTIVE_ROLE_KEY, role);
    } catch {
      // Persisting the preference is best effort; the session still switches.
    }
  }

  // Navigation is scoped to the active portal role; a single-role account is unaffected.
  const navRoles = activeRole && roles.includes(activeRole) ? [activeRole] : [...roles];
  const links = visibleNavigation(navRoles);
  const portalNames = navRoles.filter(isAppRole).map((role) => roleLabels[role]).join(" · ");
  const canAdminister = roles.includes("super_admin") || roles.includes("admin");

  const matches = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (term.length < 2) return [];
    return links
      .map((item) => ({ item, label: tNav(item.id, item.label) }))
      .filter((entry) => entry.label.toLowerCase().includes(term))
      .slice(0, 8);
  }, [links, search, tNav]);

  // Breadcrumb: portal → section → page, derived from the live route.
  const activeModuleId = location.pathname.startsWith("/portal/modules/")
    ? location.pathname.split("/")[3]
    : null;
  const activeSection = activeModuleId ? sectionForModule(navRoles, activeModuleId) : null;
  const activeModule = activeModuleId ? moduleForPage(navRoles, activeModuleId) : null;
  const activeItem = activeModuleId ? links.find((item) => item.id === activeModuleId) : null;
  const pageTitle = activeItem
    ? tNav(activeItem.id, activeItem.label)
    : location.pathname.endsWith("/directory")
      ? t("directory")
      : location.pathname.endsWith("/control-center")
        ? t("controlCenter")
        : location.pathname.endsWith("/profile")
          ? tNav("profile", "ملفي الشخصي")
          : tNav("home", "الرئيسية");

  function closeMenu() {
    setMenuOpen(false);
  }

  return (
    <div className={`layout ${collapsed ? "collapsed" : ""}`}>
      <a className="skip-link" href="#portal-main">{t("skipToContent")}</a>

      {menuOpen && (
        <button className="drawer-backdrop" aria-label={t("closeMenu")} onClick={closeMenu} />
      )}

      <aside className={`sidebar ${menuOpen ? "open" : ""}`} id="sidebar" aria-label={t("portal")}>
        <div className="sidebar-brand">
          <img className="brand-logo" src={logo} alt={t("appName")} />
          <div className="sidebar-label sidebar-brand-text">
            <strong>{t("appName")}</strong>
            <small title={portalNames}>{portalNames || t("brandSubtitle")}</small>
          </div>
          <button
            className="icon-button collapse-button"
            onClick={() => setCollapsed(!collapsed)}
            aria-label={collapsed ? t("expand") : t("collapse")}
            aria-expanded={!collapsed}
          >
            <i className={collapsed ? "ri-menu-unfold-line" : "ri-menu-fold-line"} aria-hidden="true" />
          </button>
        </div>

        <div className="portal-search sidebar-label">
          <label className="sr-only" htmlFor="portal-nav-search">{t("searchPlaceholder")}</label>
          <i className="ri-search-line" aria-hidden="true" />
          <input
            id="portal-nav-search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder={t("searchPlaceholder")}
            autoComplete="off"
          />
        </div>
        {search.trim().length >= 2 && (
          <div className="portal-search-results sidebar-label" role="status">
            {matches.length
              ? matches.map(({ item, label }) => (
                <NavLink key={item.id} to={modulePath(item)} onClick={() => { setSearch(""); closeMenu(); }}>
                  <i className={item.icon} aria-hidden="true" />
                  <span>{label}</span>
                  {activeSection?.items.some((entry) => entry.id === item.id) && (
                    <small>{tSection(activeSection.id, activeSection.label)}</small>
                  )}
                </NavLink>
              ))
              : <p>{t("searchNoResults")}</p>}
          </div>
        )}

        <RoleSidebar
          roles={navRoles}
          collapsed={collapsed}
          onExpand={() => setCollapsed(false)}
          onNavigate={() => { setSearch(""); closeMenu(); }}
          unreadCount={unreadCount}
        />

        <div className="sidebar-footer">
          <NavLink className="sidebar-footer-link" to="/portal/directory" onClick={closeMenu}>
            <i className="ri-apps-2-line" aria-hidden="true" />
            <span className="sidebar-label">{t("directory")}</span>
          </NavLink>
          {canAdminister && (
            <NavLink className="sidebar-footer-link" to="/portal/control-center" onClick={closeMenu}>
              <i className="ri-shield-star-line" aria-hidden="true" />
              <span className="sidebar-label">{t("controlCenter")}</span>
            </NavLink>
          )}
          <NavLink className="sidebar-footer-link" to="/" onClick={closeMenu}>
            <i className="ri-global-line" aria-hidden="true" />
            <span className="sidebar-label">{t("website")}</span>
          </NavLink>
          <div className="sidebar-footer-lang sidebar-label">
            <span>{t("language")}</span>
            <LanguageSwitcher compact />
          </div>
        </div>
      </aside>

      <div className="main-area">
        <header className="topbar">
          <button
            className="icon-button mobile-menu"
            onClick={() => setMenuOpen(true)}
            aria-label={t("openMenu")}
            aria-controls="sidebar"
            aria-expanded={menuOpen}
          >
            <i className="ri-menu-2-line" aria-hidden="true" />
          </button>

          <div className="mobile-brand">
            <img src={logo} alt="" />
            <strong>{t("appName")}</strong>
          </div>

          <nav className="portal-crumbs" aria-label={t("navLabel")}>
            <span className="portal-crumb-root">
              <i className="ri-layout-grid-line" aria-hidden="true" />
              {t("portal")}
            </span>
            {activeModule && (
              <>
                <i className={`${crumbSeparator} portal-crumb-sep`} aria-hidden="true" />
                <span>{tModule(activeModule.id, activeModule.label)}</span>
              </>
            )}
            {activeSection && activeModule?.sections.length !== 1 && (
              <>
                <i className={`${crumbSeparator} portal-crumb-sep`} aria-hidden="true" />
                <span>{tSection(activeSection.id, activeSection.label)}</span>
              </>
            )}
            <i className={`${crumbSeparator} portal-crumb-sep`} aria-hidden="true" />
            <strong aria-current="page">{pageTitle}</strong>
          </nav>

          <div className="search-wrap">
            <label className="sr-only" htmlFor="global-search">{t("searchPlaceholder")}</label>
            <input
              id="global-search"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder={t("searchPlaceholder")}
              autoComplete="off"
            />
            {search.trim().length >= 2 && (
              <div className="search-results">
                {matches.length
                  ? matches.map(({ item, label }) => (
                    <NavLink key={item.id} to={modulePath(item)} onClick={() => setSearch("")}>{label}</NavLink>
                  ))
                  : <span>{t("searchNoResults")}</span>}
              </div>
            )}
          </div>

          <div className="topbar-lang">
            <LanguageSwitcher />
          </div>

          <NavLink
            className="icon-button notice-link"
            to="/portal/modules/notifications"
            title={noticeCount > 0 ? `${noticeCount} ${t("unreadNotifications")}` : t("notifications")}
            aria-label={noticeCount > 0 ? `${noticeCount} ${t("unreadNotifications")}` : t("notifications")}
          >
            <i className="ri-notification-3-line" aria-hidden="true" />
            {noticeCount > 0 && (
              <span className="notice-badge" aria-hidden="true">{noticeCount > 99 ? "99+" : noticeCount}</span>
            )}
          </NavLink>

          <details className="profile-menu">
            <summary>{profileName}</summary>
            <div>
              <span dir="ltr">{email ?? "—"}</span>
              {roles.length > 1 && (
                <fieldset className="role-switcher">
                  <legend>{t("activePortal")}</legend>
                  {roles.filter(isAppRole).map((role) => (
                    <button
                      key={role}
                      type="button"
                      className={`role-switch-option ${role === activeRole ? "is-active" : ""}`}
                      aria-pressed={role === activeRole}
                      onClick={() => switchRole(role)}
                    >
                      {roleLabels[role]}
                    </button>
                  ))}
                </fieldset>
              )}
              <button type="button" onClick={onSignOut} disabled={busy}>
                {busy ? t("signingOut") : t("signOut")}
              </button>
            </div>
          </details>
        </header>

        {signOutError && (
          <p className="error-box global-error" role="alert">{t("signOut")}: {signOutError}</p>
        )}

        {!!onboardingNotices.length && (
          <section className="data-note onboarding-strip" role="status" aria-label={t("signedInAs")}>
            <strong>{t("signedInAs")}</strong>
            <ul>{onboardingNotices.map((notice) => <li key={notice}>{notice}</li>)}</ul>
          </section>
        )}

        <div id="portal-main">{children}</div>
      </div>

      <nav className="bottom-nav" aria-label={t("navLabel")}>
        {mobileTabs(navRoles).map((item) => (
          <NavLink key={item.id} to={modulePath(item)}>
            <i className={item.icon} aria-hidden="true" />
            <small>{tNav(item.id, item.label)}</small>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}