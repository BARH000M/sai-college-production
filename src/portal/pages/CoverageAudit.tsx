import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  coverageGroups, coverageRequirements, coverageStatusMeta, coverageSummary,
  type CoverageGroup, type CoverageStatus,
} from "../lib/portalCoverage";
import { portalModuleForPage } from "../lib/portalRegistry";
import { usePortalLang } from "../lib/portalLangContext";

const statusTone: Record<CoverageStatus, string> = {
  completed: "status-ok",
  implemented_unverified: "status-neutral",
  partial: "status-warn",
  pending: "status-neutral",
  blocked: "status-danger",
};

export function CoverageAudit() {
  const { t } = usePortalLang();
  const [search, setSearch] = useState("");
  const [group, setGroup] = useState<CoverageGroup | "all">("all");
  const summary = useMemo(() => coverageSummary(), []);

  const rows = useMemo(() => {
    const term = search.trim().toLowerCase();
    return coverageRequirements.filter((row) => {
      if (group !== "all" && row.group !== group) return false;
      if (!term) return true;
      return `${row.id} ${row.nameAr} ${row.nameEn} ${row.nameZh} ${row.parentModuleId}`.toLowerCase().includes(term);
    });
  }, [search, group]);

  return (
    <main className="workspace">
      <div className="page-heading">
        <div>
          <p className="eyebrow">{t("appName")} · {t("portal")}</p>
          <h1>{t("coverageTitle")}</h1>
          <p className="muted">{t("coverageIntro")}</p>
        </div>
        <span className="learn-pill">{summary.completed} / {summary.total} · {summary.percent}%</span>
      </div>

      <div className="lab-stats" style={{ marginBlock: 16 }}>
        <div className="lab-stat"><span>{t("modulesAvailable")}</span><strong>{summary.completed}</strong><small>{coverageStatusMeta.completed.ar}</small></div>
        <div className="lab-stat"><span>{coverageStatusMeta.partial.ar}</span><strong>{summary.partial}</strong><small>{coverageStatusMeta.partial.en}</small></div>
        <div className="lab-stat"><span>{t("pendingCount")}</span><strong>{summary.pending + summary.blocked}</strong><small>{coverageStatusMeta.pending.ar}</small></div>
        <div className="lab-stat"><span>{t("deployStatus")}</span><strong>{summary.percent}%</strong><small>{coverageStatusMeta.completed.en}</small></div>
      </div>

      <fieldset className="context-card">
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "flex-end" }}>
          <label style={{ flex: 1, minWidth: 240 }}>
            {t("searchModules")}
            <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder={`${t("requirement")} / ${t("module")}`} />
          </label>
          <label>
            {t("group")}
            <select value={group} onChange={(event) => setGroup(event.target.value as CoverageGroup | "all")}>
              <option value="all">—</option>
              {coverageGroups.map((entry) => <option key={entry.id} value={entry.id}>{entry.labelAr}</option>)}
            </select>
          </label>
        </div>
      </fieldset>

      {!rows.length && <p className="muted" style={{ marginTop: 16 }}>{t("searchNoResults")}</p>}

      <div style={{ display: "grid", gap: 8, marginTop: 16 }}>
        {rows.map((row) => {
          const parent = portalModuleForPage(row.route ?? "") ?? null;
          const meta = coverageStatusMeta[row.status];
          return (
            <article key={row.id} className="panel" style={{ padding: 14 }}>
              <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>
                <span className="control-chip" style={{ fontSize: 11 }}>{row.id}</span>
                <strong style={{ flex: 1, minWidth: 160 }}>{row.nameAr}</strong>
                <span className={`lab-status ${statusTone[row.status]}`}>{meta.ar}</span>
                <span className="lab-meta" style={{ fontSize: 11 }}>{row.nameEn}</span>
              </div>
              <div style={{ display: "grid", gap: 4, marginTop: 8, gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))", fontSize: 13 }}>
                <p className="muted"><strong>{t("module")}:</strong> {row.parentModuleId}</p>
                <p className="muted"><strong>{t("scope")}:</strong> {row.scope}</p>
                <p className="muted"><strong>{t("actions")}:</strong> {row.permission}</p>
                <p className="muted"><strong>{t("testStatus")}:</strong> {row.testStatus}</p>
                <p className="muted"><strong>{t("deployStatus")}:</strong> {row.deployStatus}</p>
                <p className="muted"><strong>{t("dataSource")}:</strong> {row.dataSource}</p>
              </div>
              {row.note && <p className="data-note" style={{ marginTop: 6 }}>{row.note}</p>}
              {row.route && parent && (
                <p style={{ marginTop: 8 }}><Link to={`/portal/modules/${row.route}`}>{t("preview")}: {parent.label}</Link></p>
              )}
            </article>
          );
        })}
      </div>
    </main>
  );
}

export default CoverageAudit;