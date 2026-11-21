import { Link } from "react-router-dom";
import {
  alwaysOnModuleIds, isAppRole, modulePath, navigation, pendingModules, roleLabels,
  visibleNavigation, type AppRole,
} from "../lib/navigation";
import { portalModules } from "../lib/portalRegistry";
import { usePortalLang } from "../lib/portalLangContext";
import { StatusCard } from "../components/StatusCard";

const allRoles = Object.keys(roleLabels) as AppRole[];
const ADMIN_ROLES = ["super_admin", "admin"];

const quickActions = [
  { id: "roles", labelKey: "manageRoles", icon: "ri-shield-user-line" },
  { id: "settings", labelKey: "manageToggles", icon: "ri-toggle-line" },
  { id: "systemCatalog", labelKey: "systemInventory", icon: "ri-list-check-2" },
  { id: "backups", labelKey: "backups", icon: "ri-database-2-line" },
  { id: "reports", labelKey: "auditLog", icon: "ri-file-list-3-line" },
] as const;

/**
 * Consolidated control centre for the platform.
 *
 * It reads the same authorization catalogue and hierarchical registry as the
 * sidebar, so the counts, role coverage and quick links can never disagree with
 * what a role can actually open. Global module state always wins over per-role
 * overrides, and the always-on modules are listed separately because they cannot
 * be switched off.
 */
export function ControlCenter({ roles }: { roles: readonly string[] }) {
  const { t, tNav, tModule } = usePortalLang();

  const canAdminister = roles.some((role) => ADMIN_ROLES.includes(role));
  // Recomputed on every render so a toggle change is reflected immediately.
  const available = visibleNavigation(roles);
  const availableIds = new Set(available.map((item) => item.id));
  const activeModules = portalModules.filter((module) => (
    module.submenus.some((submenu) => submenu.pages.some((page) => availableIds.has(page.moduleId)))
  ));
  const totalSubmenus = portalModules.reduce((sum, module) => sum + module.submenus.length, 0);

  const coverage = allRoles.map((role) => {
    const visible = visibleNavigation([role]);
    const ids = new Set(visible.map((item) => item.id));
    const modules = portalModules.filter((module) => (
      module.submenus.some((submenu) => submenu.pages.some((page) => ids.has(page.moduleId)))
    ));
    return { role, visible, total: navigation.length, modules };
  });

  const maxCoverage = Math.max(1, ...coverage.map((entry) => entry.visible.length));

  if (!canAdminister) {
    return (
      <StatusCard
        title={t("restricted")}
        message={t("restrictedBody")}
        link="/portal/dashboard"
      />
    );
  }

  return (
    <main className="workspace">
      <section className="control-hero">
        <div className="control-hero-main">
          <p className="eyebrow">{t("appName")} · {t("portal")}</p>
          <h1>{t("controlCenterTitle")}</h1>
          <p className="muted">{t("controlCenterIntro")}</p>
        </div>
        <div className="control-hero-badge">
          <i className="ri-shield-star-line" aria-hidden="true" />
          <span>{roles.filter(isAppRole).map((role) => roleLabels[role]).join(" · ")}</span>
        </div>
      </section>

      <div className="control-kpis">
        <div className="control-kpi">
          <span>{t("modulesAvailable")}</span>
          <strong>{available.length}</strong>
          <small>{activeModules.length} {t("mainModule")} · {navigation.length} {t("modules")}</small>
        </div>
        <div className="control-kpi">
          <span>{t("rolesCount")}</span>
          <strong>{allRoles.length}</strong>
          <small>{t("roleCoverage")} · {totalSubmenus} {t("sectionsCount")}</small>
        </div>
        <div className="control-kpi">
          <span>{t("pendingCount")}</span>
          <strong>{pendingModules.length}</strong>
          <small>{t("pendingModules")}</small>
        </div>
        <div className="control-kpi">
          <span>{t("alwaysOnCount")}</span>
          <strong>{alwaysOnModuleIds.length}</strong>
          <small>{t("alwaysOnNote")}</small>
        </div>
      </div>

      <div className="control-grid">
        <section className="panel" aria-labelledby="control-role-coverage">
          <div className="home-panel-head">
            <h2 id="control-role-coverage">{t("roleCoverage")}</h2>
            <Link className="text-button" to="/portal/modules/roles">{t("viewAll")}</Link>
          </div>
          <p className="data-note">{t("multiRoleNote")}</p>

          <div className="control-role-list">
            {coverage.map(({ role, visible, total, modules }) => (
              <article className="control-role-card" key={role}>
                <div className="control-role-head">
                  <strong>{roleLabels[role]}</strong>
                  <small>{visible.length} / {total} {t("modules")}</small>
                </div>
                <span className="control-role-bar" aria-hidden="true">
                  <span style={{ width: `${Math.round((visible.length / maxCoverage) * 100)}%` }} />
                </span>
                <div className="control-chips">
                  {modules.slice(0, 8).map((module) => (
                    <span key={module.id} className="control-chip">
                      <i className={module.icon} aria-hidden="true" />
                      {tModule(module.id, module.label)}
                    </span>
                  ))}
                  {modules.length > 8 && (
                    <span className="control-chip">+{modules.length - 8}</span>
                  )}
                  {!visible.length && <span className="control-chip">{t("noAccess")}</span>}
                </div>
              </article>
            ))}
          </div>
        </section>

        <div style={{ display: "grid", gap: 16, alignContent: "start" }}>
          <section className="panel" aria-labelledby="control-quick-actions">
            <h2 id="control-quick-actions">{t("quickActions")}</h2>
            <div className="control-actions">
              {quickActions.map((action) => (
                <Link key={action.id} className="control-action" to={`/portal/modules/${action.id}`}>
                  <i className={action.icon} aria-hidden="true" />
                  <span>{t(action.labelKey)}</span>
                  <i className="ri-arrow-left-s-line" aria-hidden="true" />
                </Link>
              ))}
            </div>
          </section>

          <section className="panel" aria-labelledby="control-rules">
            <h2 id="control-rules">{t("moduleAccess")}</h2>
            <div className="control-note">
              <strong>{t("globalRuleTitle")}</strong>
              <p>{t("globalToggleNote")}</p>
            </div>
            <div className="control-note">
              <strong>{t("multiRoleTitle")}</strong>
              <p>{t("multiRoleNote")}</p>
            </div>
          </section>

          <section className="panel" aria-labelledby="control-pending">
            <h2 id="control-pending">{t("pendingModules")}</h2>
            {pendingModules.length === 0
              ? <p className="success-box" role="status">كل الوحدات المخطط لها مفعّلة ومُتحقق منها.</p>
              : <ul className="control-pending">
                {pendingModules.map((item) => (
                  <li key={item.id}>
                    <strong>{tNav(item.id, item.label)}</strong>
                    <span>{item.reason}</span>
                  </li>
                ))}
              </ul>}
          </section>
        </div>
      </div>

      <p className="data-note" style={{ marginTop: 16 }}>
        {available.length} {t("modules")} · {activeModules.length} {t("mainModule")} · {t("roles")}: {roles.filter(isAppRole).length}
      </p>
    </main>
  );
}

export default ControlCenter;