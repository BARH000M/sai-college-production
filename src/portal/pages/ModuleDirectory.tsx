import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { groupedSidebarModules, sidebarDestination } from "../lib/sidebarSections";
import { usePortalLang } from "../lib/portalLangContext";
import { isAppRole, roleLabels } from "../lib/navigation";

/**
 * Single index of every module the signed-in account can actually open, grouped
 * by operational zone and then by main module and submenu. It mirrors the sidebar
 * authorization exactly (visible + enabled + role-permitted) so it can never
 * advertise a destination the shell would block.
 */
export function ModuleDirectory({ roles }: { roles: readonly string[] }) {
  const { t, tNav, tModule, tSection, tZone, lang } = usePortalLang();
  const moduleLabel = (module: { id: string; label: string; customLabel?: boolean; labelI18n?: Record<string, string> }) => (
    module.customLabel && module.labelI18n ? (module.labelI18n[lang] || module.label) : tModule(module.id, module.label)
  );
  const [search, setSearch] = useState("");
  // Recomputed each render so module toggles apply without a remount.
  const groups = groupedSidebarModules(roles);

  const term = search.trim().toLowerCase();
  const filtered = useMemo(() => {
    if (!term) return groups;
    return groups
      .map((group) => ({
        ...group,
        modules: group.modules
          .map((module) => ({
            ...module,
            sections: module.sections
              .map((section) => ({
                ...section,
                items: section.items.filter((item) => (
                  tNav(item.id, item.label).toLowerCase().includes(term)
                  || tSection(section.id, section.label).toLowerCase().includes(term)
                )),
              }))
              .filter((section) => section.items.length > 0),
          }))
          .filter((module) => module.sections.length > 0),
      }))
      .filter((group) => group.modules.length > 0);
  }, [groups, term, tNav, tSection]);

  const total = groups.reduce((sum, group) => (
    sum + group.modules.reduce((inner, module) => (
      inner + module.sections.reduce((count, section) => count + section.items.length, 0)
    ), 0)
  ), 0);
  const portalNames = roles.filter(isAppRole).map((role) => roleLabels[role]).join(" · ");

  return (
    <main className="workspace">
      <section className="directory-hero">
        <div className="directory-hero-main">
          <p className="eyebrow">{t("portal")}</p>
          <h1>{t("directoryTitle")}</h1>
          <p className="muted">{t("directoryIntro")}</p>
        </div>
        <div className="directory-hero-badge">
          <i className="ri-shield-check-line" aria-hidden="true" />
          <span>{total} {t("modules")} · {portalNames || t("brandSubtitle")}</span>
        </div>
      </section>

      <fieldset className="context-card">
        <label>
          {t("searchPlaceholder")}
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder={t("searchPlaceholder")}
            autoComplete="off"
          />
        </label>
      </fieldset>

      {!filtered.length && (
        <div className="directory-empty">
          <i className="ri-search-eye-line" aria-hidden="true" style={{ fontSize: 22, display: "block", marginBottom: 6 }} />
          {term ? t("searchNoResults") : t("noAccess")}
        </div>
      )}

      {filtered.map((group) => (
        <section className="directory-zone" key={group.zone.id} aria-labelledby={`directory-zone-${group.zone.id}`}>
          <div className="directory-zone-head">
            <i className={group.zone.icon} aria-hidden="true" />
            <h2 id={`directory-zone-${group.zone.id}`}>{tZone(group.zone.id, group.zone.label)}</h2>
            <small>
              {group.modules.reduce((sum, module) => sum + module.sections.reduce((count, section) => count + section.items.length, 0), 0)}
              {" "}{t("modules")}
            </small>
          </div>

          {group.modules.map((module) => (
            <article className="directory-module" key={module.id}>
              <div className="directory-module-head">
                <span className="directory-module-icon" aria-hidden="true">
                  <i className={module.icon} />
                </span>
                <h3>{moduleLabel(module)}</h3>
                <small>
                  {module.sections.reduce((sum, section) => sum + section.items.length, 0)} {t("modules")}
                </small>
              </div>

              <div className="directory-grid">
                {module.sections.flatMap((section) => section.items.map((item) => (
                  <Link
                    key={item.id}
                    className="directory-card"
                    to={sidebarDestination(item)}
                    title={tNav(item.id, item.label)}
                  >
                    <span className="directory-card-icon" aria-hidden="true">
                      <i className={item.icon} />
                    </span>
                    <span className="directory-card-body">
                      <strong>{tNav(item.id, item.label)}</strong>
                      <small>{tSection(section.id, section.label)}</small>
                    </span>
                  </Link>
                )))}
              </div>
            </article>
          ))}
        </section>
      ))}
    </main>
  );
}

export default ModuleDirectory;