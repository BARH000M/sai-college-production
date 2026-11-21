import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { navigation, roleLabels } from "../lib/navigation";
import { portalModuleForPage } from "../lib/portalRegistry";
import { StatusCard } from "../components/StatusCard";
import { usePortalLang } from "../lib/portalLangContext";
import {
  appRoles, buildDefaultMatrix, diffMatrix, evaluatePermission, hasSensitiveChange,
  permissionActions, recordScopes,
  type AppRole, type PermissionAction, type PermissionMatrix, type RecordScope,
} from "../lib/permissionModel";
import { loadPermissionAudit, loadPermissionMatrix, savePermissionMatrix, type PermissionAuditRow } from "../lib/permissions";

const ADMIN = "super_admin";

/** One page row inside the matrix tree. */
type Row = { id: string; label: string; icon: string; parentId: string; parentLabel: string; zone: string };

export function PermissionsCenter({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const { t } = usePortalLang();
  const canEdit = roles.includes(ADMIN);
  const defaultMatrix = useMemo(() => buildDefaultMatrix(), []);

  const [working, setWorking] = useState<PermissionMatrix>(defaultMatrix);
  const [saved, setSaved] = useState<PermissionMatrix>(defaultMatrix);
  const [role, setRole] = useState<AppRole>("admin");
  const [compareRole, setCompareRole] = useState<AppRole | "">("");
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<string | null>(null);
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(() => new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [audit, setAudit] = useState<PermissionAuditRow[]>([]);

  useEffect(() => {
    if (!canEdit) { setLoading(false); return; }
    let active = true;
    setLoading(true); setError(null);
    void loadPermissionMatrix()
      .then((result) => { if (!active) return; setWorking(result.matrix); setSaved(result.matrix); })
      .catch((failure: unknown) => { if (active) setError(failure instanceof Error ? failure.message : String(failure)); })
      .finally(() => { if (active) setLoading(false); });
    void loadPermissionAudit().then((rows) => { if (active) setAudit(rows); }).catch(() => undefined);
    return () => { active = false; };
  }, [canEdit]);

  const allRows = useMemo<Row[]>(() => navigation
    .filter((item) => item.roles.includes(role))
    .map((item) => {
      const parent = portalModuleForPage(item.id);
      return {
        id: item.id,
        label: item.label,
        icon: item.icon,
        parentId: parent?.id ?? "other",
        parentLabel: parent?.label ?? "أخرى",
        zone: parent?.zone ?? "administration",
      };
    }), [role]);

  const rows = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return allRows;
    return allRows.filter((row) => `${row.label} ${row.parentLabel}`.toLowerCase().includes(term));
  }, [allRows, search]);

  const grouped = useMemo(() => {
    const map = new Map<string, { label: string; zone: string; rows: Row[] }>();
    for (const row of rows) {
      const entry = map.get(row.parentId) ?? { label: row.parentLabel, zone: row.zone, rows: [] };
      entry.rows.push(row);
      map.set(row.parentId, entry);
    }
    return [...map.entries()].map(([id, value]) => ({ id, ...value }));
  }, [rows]);

  const changes = useMemo(() => diffMatrix(saved, working), [saved, working]);
  const dirty = changes.length > 0;
  const sensitive = useMemo(() => hasSensitiveChange(changes, saved), [changes, saved]);

  const grantedCount = useMemo(
    () => Object.values(working[role] ?? {}).reduce((sum, permission) => sum + permission.actions.length, 0),
    [working, role],
  );

  function permissionOf(targetRole: AppRole, moduleId: string) {
    return working[targetRole]?.[moduleId] ?? { actions: [] as PermissionAction[], scope: defaultMatrix[targetRole]?.[moduleId]?.scope ?? ("own_records" as RecordScope) };
  }

  function toggleAction(moduleId: string, action: PermissionAction) {
    if (!canEdit) return;
    setNotice(null);
    setWorking((previous) => {
      const current = previous[role]?.[moduleId]
        ?? { actions: [] as PermissionAction[], scope: defaultMatrix[role]?.[moduleId]?.scope ?? ("own_records" as RecordScope) };
      const has = current.actions.includes(action);
      const actions = has ? current.actions.filter((entry) => entry !== action) : [...current.actions, action];
      return { ...previous, [role]: { ...previous[role], [moduleId]: { ...current, actions } } };
    });
  }

  function setScope(moduleId: string, scope: RecordScope) {
    if (!canEdit) return;
    setNotice(null);
    setWorking((previous) => {
      const current = previous[role]?.[moduleId]
        ?? { actions: [] as PermissionAction[], scope: defaultMatrix[role]?.[moduleId]?.scope ?? ("own_records" as RecordScope) };
      return { ...previous, [role]: { ...previous[role], [moduleId]: { ...current, scope } } };
    });
  }

  function toggleExpanded(parentId: string) {
    setExpanded((previous) => {
      const next = new Set(previous);
      if (next.has(parentId)) next.delete(parentId); else next.add(parentId);
      return next;
    });
  }

  function resetRole() {
    if (!canEdit) return;
    setWorking((previous) => ({ ...previous, [role]: structuredCloneSafe(defaultMatrix[role]) }));
    setNotice(null);
  }

  async function persist() {
    if (!canEdit || saving) return;
    setSaving(true); setError(null); setNotice(null);
    try {
      await savePermissionMatrix(working, userId);
      setSaved(working);
      setConfirmOpen(false);
      setNotice(`${t("savedAt")} · ${changes.length} ${t("changeSummary")}`);
      setAudit(await loadPermissionAudit());
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : String(failure));
    } finally {
      setSaving(false);
    }
  }

  if (!canEdit) {
    return <StatusCard title={t("restricted")} message={t("restrictedBody")} link="/portal/dashboard" />;
  }

  const selectedRow = selected ? allRows.find((row) => row.id === selected) : null;
  const workingPermission = selected ? permissionOf(role, selected) : null;

  return (
    <main className="workspace">
      <div className="page-heading">
        <div>
          <p className="eyebrow">{t("appName")} · {t("portal")}</p>
          <h1>{t("permissionsTitle")}</h1>
          <p className="muted">{t("permissionsIntro")}</p>
        </div>
        <div className="actions" style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <button className="button secondary" type="button" onClick={resetRole} disabled={saving}>
            <i className="ri-arrow-go-back-line" aria-hidden="true" /> {t("reset")}
          </button>
          <button className="button" type="button" disabled={!dirty || saving} onClick={() => (sensitive ? setConfirmOpen(true) : void persist())}>
            {saving ? t("saving") : t("save")}
          </button>
        </div>
      </div>

      <div className="lab-stats" style={{ marginBlock: 16 }}>
        <div className="lab-stat"><span>{t("rolesCount")}</span><strong>{appRoles.length}</strong><small>{roleLabels[role]}</small></div>
        <div className="lab-stat"><span>{t("modules")}</span><strong>{allRows.length}</strong><small>{t("moduleAccess")}</small></div>
        <div className="lab-stat"><span>{t("actions")}</span><strong>{grantedCount}</strong><small>{t("selectRole")}</small></div>
        <div className="lab-stat"><span>{t("changeSummary")}</span><strong>{changes.length}</strong><small>{dirty ? t("unsaved") : t("savedAt")}</small></div>
      </div>

      {error && <p className="error-box" role="alert">{error}</p>}
      {notice && <p className="success-box" role="status">{notice}</p>}
      {dirty && <p className="notice" role="status"><i className="ri-error-warning-line" aria-hidden="true" /> {t("unsaved")} · {changes.length} {t("changeSummary")}</p>}

      <fieldset className="context-card">
        <legend>{t("selectRole")}</legend>
        <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
          {appRoles.map((entry) => (
            <button
              key={entry}
              type="button"
              className={`button ${entry === role ? "" : "secondary"}`}
              aria-pressed={entry === role}
              onClick={() => { setRole(entry); setSelected(null); }}
            >
              {roleLabels[entry]}
            </button>
          ))}
        </div>
        <div style={{ display: "flex", gap: 12, alignItems: "center", marginTop: 12, flexWrap: "wrap" }}>
          <label htmlFor="perm-search" style={{ minWidth: 240, flex: 1 }}>
            {t("searchModules")}
            <input id="perm-search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder={t("searchModules")} />
          </label>
          <label htmlFor="perm-compare">
            {t("effectivePreview")}
            <select id="perm-compare" value={compareRole} onChange={(event) => setCompareRole(event.target.value as AppRole | "")}>
              <option value="">—</option>
              {appRoles.filter((entry) => entry !== role).map((entry) => <option key={entry} value={entry}>{roleLabels[entry]}</option>)}
            </select>
          </label>
        </div>
      </fieldset>

      {loading ? (
        <p role="status">{t("searchPlaceholder")}…</p>
      ) : (
        <div style={{ display: "grid", gap: 16, gridTemplateColumns: "minmax(0, 1fr)", marginTop: 16 }}>
          <section className="panel" aria-labelledby="perm-tree">
            <div className="home-panel-head">
              <h2 id="perm-tree">{roleLabels[role]}</h2>
              <span className="role-count">{rows.length}</span>
            </div>
            <div style={{ display: "flex", gap: 8, marginBottom: 8 }}>
              <button type="button" className="text-button" onClick={() => setExpanded(new Set(grouped.map((group) => group.id)))}>{t("expandAll")}</button>
              <button type="button" className="text-button" onClick={() => setExpanded(new Set())}>{t("collapseAll")}</button>
            </div>
            {!grouped.length && <p className="muted">{t("searchNoResults")}</p>}
            <div style={{ display: "grid", gap: 8 }}>
              {grouped.map((group) => {
                const isOpen = expanded.has(group.id) || Boolean(search.trim());
                const grantedInGroup = group.rows.reduce((sum, row) => sum + permissionOf(role, row.id).actions.length, 0);
                return (
                  <div key={group.id} className="panel" style={{ padding: 12 }}>
                    <button
                      type="button"
                      className="lab-item-button"
                      aria-expanded={isOpen}
                      style={{ display: "flex", width: "100%", justifyContent: "space-between", alignItems: "center", gap: 8, background: "transparent", border: "none", cursor: "pointer" }}
                      onClick={() => toggleExpanded(group.id)}
                    >
                      <strong>{group.label}</strong>
                      <span className="muted" style={{ fontSize: 12 }}>{grantedInGroup} {t("actions")} · {group.rows.length} {t("modules")}</span>
                      <i className={`ri-arrow-down-s-line ${isOpen ? "rotated" : ""}`} aria-hidden="true" />
                    </button>
                    {isOpen && (
                      <div style={{ display: "grid", gap: 4, marginTop: 8 }}>
                        {group.rows.map((row) => {
                          const permission = permissionOf(role, row.id);
                          const isActive = selected === row.id;
                          return (
                            <button
                              key={row.id}
                              type="button"
                              className={`lab-item-button ${isActive ? "active" : ""}`}
                              style={{ display: "flex", alignItems: "center", gap: 8, width: "100%", textAlign: "start", cursor: "pointer" }}
                              onClick={() => setSelected(row.id)}
                            >
                              <i className={row.icon} aria-hidden="true" />
                              <span style={{ flex: 1 }}>{row.label}</span>
                              <span className={`control-chip`} style={{ fontSize: 11 }}>{permission.actions.length}</span>
                              <span className="lab-meta" style={{ fontSize: 11 }}>{recordScopes.find((scope) => scope.id === permission.scope)?.ar}</span>
                            </button>
                          );
                        })}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </section>

          <section className="panel" aria-labelledby="perm-editor">
            <h2 id="perm-editor">{selectedRow ? `${roleLabels[role]} — ${selectedRow.label}` : t("effectivePreview")}</h2>
            {!selectedRow || !workingPermission ? (
              <p className="data-note">{t("searchHint")}</p>
            ) : (
              <>
                <label htmlFor="perm-scope" style={{ display: "block", marginBottom: 12 }}>
                  {t("scope")}
                  <select id="perm-scope" value={workingPermission.scope} onChange={(event) => setScope(selectedRow.id, event.target.value as RecordScope)}>
                    {recordScopes.map((scope) => <option key={scope.id} value={scope.id}>{scope.ar}</option>)}
                  </select>
                </label>

                <div style={{ display: "grid", gap: 6, gridTemplateColumns: "repeat(auto-fill, minmax(160px, 1fr))" }}>
                  {permissionActions.map((action) => {
                    const checked = workingPermission.actions.includes(action.id);
                    return (
                      <label key={action.id} className="control-note" style={{ display: "flex", alignItems: "center", gap: 8, cursor: "pointer", padding: "6px 10px" }}>
                        <input type="checkbox" checked={checked} onChange={() => toggleAction(selectedRow.id, action.id)} />
                        <span style={{ flex: 1 }}>{action.ar}</span>
                        {action.sensitive && <i className="ri-lock-2-line" aria-label={t("sensitiveConfirm")} />}
                      </label>
                    );
                  })}
                </div>

                <h3 style={{ marginTop: 18 }}>{t("effectivePreview")}</h3>
                <div style={{ display: "grid", gap: 8 }}>
                  {[role, ...(compareRole ? [compareRole] : [])].map((target) => {
                    const result = evaluatePermission(working, [target], selectedRow.id, "view");
                    const permission = permissionOf(target, selectedRow.id);
                    return (
                      <div key={target} className="control-note">
                        <strong>{roleLabels[target]}</strong>
                        <p className="muted" style={{ fontSize: 13 }}>
                          {permission.actions.length
                            ? permission.actions.map((action) => permissionActions.find((entry) => entry.id === action)?.ar).join(" · ")
                            : "لا توجد إجراءات"} — {recordScopes.find((scope) => scope.id === permission.scope)?.ar}
                          {result.granted ? "" : " · العرض غير مسموح"}
                        </p>
                      </div>
                    );
                  })}
                </div>
              </>
            )}
          </section>

          <section className="panel" aria-labelledby="perm-changes">
            <div className="home-panel-head">
              <h2 id="perm-changes">{t("changeSummary")}</h2>
              <span className="role-count">{changes.length}</span>
            </div>
            {!changes.length ? <p className="muted">{t("savedAt")}</p> : (
              <ul className="lab-compact-list">
                {changes.slice(0, 40).map((change, index) => (
                  <li key={`${change.role}:${change.moduleId}:${change.action ?? "scope"}:${index}`}>
                    <strong>{roleLabels[change.role]}</strong>
                    <span>{navigation.find((item) => item.id === change.moduleId)?.label ?? change.moduleId}</span>
                    <span className="lab-meta">
                      {change.action ? `${permissionActions.find((entry) => entry.id === change.action)?.ar}: ${change.after}` : `${t("scope")}: ${change.after}`}
                    </span>
                  </li>
                ))}
              </ul>
            )}

            <h3 style={{ marginTop: 18 }}>{t("auditHistory")}</h3>
            {!audit.length ? <p className="muted">لا يوجد سجل تدقيق بعد.</p> : (
              <ul className="lab-compact-list">
                {audit.map((entry) => (
                  <li key={`${entry.happened_at}-${entry.action}`}>
                    <span>{new Date(entry.happened_at).toLocaleString("ar")}</span>
                    <span className="lab-meta">{entry.action}</span>
                  </li>
                ))}
              </ul>
            )}
            <p style={{ marginTop: 16 }}><Link to="/portal/modules/roles">{t("manageRoles")}</Link> · <Link to="/portal/modules/sidebarManager">{t("sidebarManager")}</Link></p>
          </section>
        </div>
      )}

      {confirmOpen && (
        <div role="dialog" aria-modal="true" aria-labelledby="perm-confirm-title" className="panel" style={{ position: "fixed", inset: 0, margin: "auto", maxWidth: 560, height: "fit-content", zIndex: 60, padding: 24 }}>
          <h2 id="perm-confirm-title">{t("sensitiveConfirm")}</h2>
          <p className="data-note">تتضمن التغييرات إجراءات حساسة (حذف، استعادة، اعتماد، نشر، تصدير، استيراد، إدارة، اعتماد مالي/إداري). راجع ملخص التغييرات قبل التأكيد.</p>
          <ul className="lab-compact-list">
            {changes.filter((change) => change.action === null || change.after === "granted").slice(0, 10).map((change, index) => (
              <li key={index}><strong>{roleLabels[change.role]}</strong><span>{navigation.find((item) => item.id === change.moduleId)?.label ?? change.moduleId}</span></li>
            ))}
          </ul>
          <div className="actions" style={{ display: "flex", gap: 8, marginTop: 16 }}>
            <button className="button" type="button" disabled={saving} onClick={() => void persist()}>{saving ? t("saving") : t("confirm")}</button>
            <button className="button secondary" type="button" onClick={() => setConfirmOpen(false)}>{t("cancel")}</button>
          </div>
        </div>
      )}
    </main>
  );
}

/** Structured clone without relying on global availability in older engines. */
function structuredCloneSafe<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

export default PermissionsCenter;