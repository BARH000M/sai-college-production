import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { navigation, roleLabels, type AppRole } from "../lib/navigation";
import { portalModules, portalZones } from "../lib/portalRegistry";
import { StatusCard } from "../components/StatusCard";
import { usePortalLang } from "../lib/portalLangContext";
import {
  emptySidebarLayout, loadLayoutAudit, loadSidebarLayout, normalizeSidebarLayout, saveSidebarLayout,
  type LayoutAuditRow, type SidebarLayout,
} from "../lib/sidebarLayout";

const ADMIN = "super_admin";
const ICON_PATTERN = /^ri-[a-z0-9-]+$/;
const LANGUAGES = ["ar", "en", "zh"] as const;

function clone(layout: SidebarLayout): SidebarLayout {
  return JSON.parse(JSON.stringify(layout)) as SidebarLayout;
}

export function SidebarManager({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const { t } = usePortalLang();
  const canEdit = roles.includes(ADMIN);
  const [layout, setLayout] = useState<SidebarLayout>({ ...emptySidebarLayout });
  const [savedLayout, setSavedLayout] = useState<SidebarLayout>({ ...emptySidebarLayout });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [previewRole, setPreviewRole] = useState<AppRole>("super_admin");
  const [previewLang, setPreviewLang] = useState<(typeof LANGUAGES)[number]>("ar");
  const [audit, setAudit] = useState<LayoutAuditRow[]>([]);
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(() => new Set(portalModules.slice(0, 1).map((module) => module.id)));

  useEffect(() => {
    if (!canEdit) { setLoading(false); return; }
    let active = true;
    setLoading(true); setError(null);
    void loadSidebarLayout()
      .then((next) => { if (!active) return; setLayout(next); setSavedLayout(clone(next)); })
      .catch((failure: unknown) => { if (active) setError(failure instanceof Error ? failure.message : String(failure)); })
      .finally(() => { if (active) setLoading(false); });
    void loadLayoutAudit().then((rows) => { if (active) setAudit(rows); }).catch(() => undefined);
    return () => { active = false; };
  }, [canEdit]);

  const orderedIds = useMemo(() => {
    const known = layout.order.filter((id) => portalModules.some((module) => module.id === id));
    const rest = portalModules.map((module) => module.id).filter((id) => !known.includes(id));
    return [...known, ...rest];
  }, [layout.order]);

  const dirty = useMemo(() => JSON.stringify(normalizeSidebarLayout(layout)) !== JSON.stringify(normalizeSidebarLayout(savedLayout)), [layout, savedLayout]);

  function update(patch: Partial<SidebarLayout>) {
    setLayout((previous) => ({ ...previous, ...patch }));
    setNotice(null);
  }

  function move(moduleId: string, direction: -1 | 1) {
    const index = orderedIds.indexOf(moduleId);
    const target = index + direction;
    if (index < 0 || target < 0 || target >= orderedIds.length) return;
    const next = [...orderedIds];
    [next[index], next[target]] = [next[target], next[index]];
    update({ order: next });
  }

  function toggleHidden(moduleId: string) {
    update({ hidden: layout.hidden.includes(moduleId) ? layout.hidden.filter((id) => id !== moduleId) : [...layout.hidden, moduleId] });
  }

  function setLabel(moduleId: string, lang: (typeof LANGUAGES)[number], value: string) {
    const current = layout.labels[moduleId] ?? { ar: "", en: "", zh: "" };
    update({ labels: { ...layout.labels, [moduleId]: { ...current, [lang]: value } } });
  }

  function setIcon(moduleId: string, value: string) {
    const clean = value.trim();
    const icons = { ...layout.icons };
    if (!clean) delete icons[moduleId];
    else if (ICON_PATTERN.test(clean)) icons[moduleId] = clean;
    update({ icons });
  }

  function toggleQuickLink(pageId: string) {
    update({
      quickLinks: layout.quickLinks.includes(pageId)
        ? layout.quickLinks.filter((id) => id !== pageId)
        : [...layout.quickLinks, pageId].slice(0, 12),
    });
  }

  function toggleDefaultExpanded(moduleId: string) {
    update({
      defaultExpanded: layout.defaultExpanded.includes(moduleId)
        ? layout.defaultExpanded.filter((id) => id !== moduleId)
        : [...layout.defaultExpanded, moduleId],
    });
  }

  function resetAll() {
    setLayout({ ...emptySidebarLayout });
    setNotice(null);
  }

  async function persist() {
    if (!canEdit || saving) return;
    setSaving(true); setError(null); setNotice(null);
    try {
      await saveSidebarLayout(layout, userId);
      setSavedLayout(clone(layout));
      setNotice(`${t("savedAt")} · ${t("sidebarTitle")}`);
      window.dispatchEvent(new Event("sai:sidebar-layout-changed"));
      setAudit(await loadLayoutAudit());
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : String(failure));
    } finally {
      setSaving(false);
    }
  }

  const preview = useMemo(() => {
    const hidden = new Set(layout.hidden);
    return portalZones
      .map((zone) => ({
        zone,
        modules: orderedIds
          .map((id) => portalModules.find((module) => module.id === id)!)
          .filter((module) => module && module.zone === zone.id && !hidden.has(module.id))
          .filter((module) => module.submenus.some((submenu) => submenu.pages.some((page) => {
            const item = navigation.find((entry) => entry.id === page.moduleId);
            return item?.roles.includes(previewRole);
          })))
          .map((module) => ({
            id: module.id,
            label: layout.labels[module.id]?.[previewLang]?.trim() || module.label,
            icon: layout.icons[module.id] ?? module.icon,
          })),
      }))
      .filter((group) => group.modules.length > 0);
  }, [layout, orderedIds, previewRole, previewLang]);

  if (!canEdit) {
    return <StatusCard title={t("restricted")} message={t("restrictedBody")} link="/portal/dashboard" />;
  }

  return (
    <main className="workspace">
      <div className="page-heading">
        <div>
          <p className="eyebrow">{t("appName")} · {t("portal")}</p>
          <h1>{t("sidebarTitle")}</h1>
          <p className="muted">{t("sidebarIntro")}</p>
        </div>
        <div className="actions" style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <button className="button secondary" type="button" onClick={resetAll} disabled={saving}>{t("reset")}</button>
          <button className="button" type="button" disabled={!dirty || saving} onClick={() => void persist()}>
            {saving ? t("saving") : t("save")}
          </button>
        </div>
      </div>

      <p className="data-note">هذه التهيئة للعرض فقط: إخفاء وحدة من القائمة لا يمنح أو يسحب أي صلاحية أمنية، فالبيانات تظل محمية بسياسات RLS. تفعيل الوحدات يُدار من <Link to="/portal/modules/settings">إعدادات النظام</Link>، والصلاحيات من <Link to="/portal/modules/permissionsCenter">مصفوفة الصلاحيات</Link>.</p>

      {dirty && <p className="notice" role="status"><i className="ri-error-warning-line" aria-hidden="true" /> {t("unsaved")}</p>}
      {error && <p className="error-box" role="alert">{error}</p>}
      {notice && <p className="success-box" role="status">{notice}</p>}
      {loading && <p role="status">…</p>}

      {!loading && (
        <div style={{ display: "grid", gap: 16, gridTemplateColumns: "minmax(0, 1.6fr) minmax(0, 1fr)" }}>
          <section className="panel" aria-labelledby="sidebar-modules">
            <div className="home-panel-head">
              <h2 id="sidebar-modules">{t("mainMenu")}</h2>
              <span className="role-count">{portalModules.length}</span>
            </div>
            <div style={{ display: "grid", gap: 8 }}>
              {orderedIds.map((moduleId, index) => {
                const module = portalModules.find((entry) => entry.id === moduleId);
                if (!module) return null;
                const isHidden = layout.hidden.includes(moduleId);
                const isOpen = expanded.has(moduleId);
                const label = layout.labels[moduleId] ?? { ar: "", en: "", zh: "" };
                return (
                  <div key={moduleId} className="panel" style={{ padding: 12 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
                      <span className="control-chip" style={{ fontSize: 11 }}>{index + 1}</span>
                      <i className={layout.icons[moduleId] ?? module.icon} aria-hidden="true" />
                      <strong style={{ flex: 1 }}>{module.label}</strong>
                      <button type="button" className="icon-button" aria-label={t("moveUp")} onClick={() => move(moduleId, -1)} disabled={index === 0}><i className="ri-arrow-up-line" aria-hidden="true" /></button>
                      <button type="button" className="icon-button" aria-label={t("moveDown")} onClick={() => move(moduleId, 1)} disabled={index === orderedIds.length - 1}><i className="ri-arrow-down-line" aria-hidden="true" /></button>
                      <button type="button" className={`button ${isHidden ? "secondary" : ""}`} aria-pressed={!isHidden} onClick={() => toggleHidden(moduleId)}>
                        {isHidden ? t("showModule") : t("hideModule")}
                      </button>
                      <button type="button" className="button secondary" aria-expanded={isOpen} onClick={() => setExpanded((previous) => {
                        const next = new Set(previous);
                        if (next.has(moduleId)) next.delete(moduleId); else next.add(moduleId);
                        return next;
                      })}>{t("preview")}</button>
                    </div>
                    {isOpen && (
                      <div style={{ display: "grid", gap: 8, marginTop: 12 }}>
                        <div style={{ display: "grid", gap: 6, gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))" }}>
                          {LANGUAGES.map((lang) => (
                            <label key={lang}>
                              {lang === "ar" ? t("labelsAr") : lang === "en" ? t("labelsEn") : t("labelsZh")}
                              <input value={label[lang]} placeholder={module.label} maxLength={80} onChange={(event) => setLabel(moduleId, lang, event.target.value)} />
                            </label>
                          ))}
                          <label>
                            {t("icon")}
                            <input value={layout.icons[moduleId] ?? ""} placeholder={module.icon} onChange={(event) => setIcon(moduleId, event.target.value)} />
                          </label>
                        </div>
                        <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
                          <input type="checkbox" checked={layout.defaultExpanded.includes(moduleId)} onChange={() => toggleDefaultExpanded(moduleId)} />
                          {t("expandAll")}
                        </label>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </section>

          <div style={{ display: "grid", gap: 16, alignContent: "start" }}>
            <section className="panel" aria-labelledby="sidebar-preview">
              <h2 id="sidebar-preview">{t("preview")}</h2>
              <div style={{ display: "flex", gap: 8, marginBottom: 12, flexWrap: "wrap" }}>
                <select aria-label={t("selectRole")} value={previewRole} onChange={(event) => setPreviewRole(event.target.value as AppRole)}>
                  {Object.keys(roleLabels).map((entry) => <option key={entry} value={entry}>{roleLabels[entry as AppRole]}</option>)}
                </select>
                <select aria-label={t("language")} value={previewLang} onChange={(event) => setPreviewLang(event.target.value as (typeof LANGUAGES)[number])}>
                  {LANGUAGES.map((lang) => <option key={lang} value={lang}>{lang.toUpperCase()}</option>)}
                </select>
              </div>
              <div dir={previewLang === "ar" ? "rtl" : "ltr"} style={{ display: "grid", gap: 10 }}>
                {preview.map((group) => (
                  <div key={group.zone.id}>
                    <p className="eyebrow" style={{ marginBottom: 4 }}>{group.zone.label}</p>
                    <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
                      {group.modules.map((module) => (
                        <span key={module.id} className="control-chip"><i className={module.icon} aria-hidden="true" /> {module.label}</span>
                      ))}
                    </div>
                  </div>
                ))}
                {!preview.length && <p className="muted">{t("noAccess")}</p>}
              </div>
            </section>

            <section className="panel" aria-labelledby="sidebar-quick">
              <h2 id="sidebar-quick">{t("quickLink")}</h2>
              <p className="data-note">حدد حتى 12 صفحة تظهر كروابط سريعة في اللوحة. لا يمكن ربط رابط سريع بصفحة غير معتمدة في السجل.</p>
              <div style={{ display: "grid", gap: 4, maxHeight: 260, overflow: "auto" }}>
                {navigation.map((item) => (
                  <label key={item.id} style={{ display: "flex", gap: 8, alignItems: "center" }}>
                    <input type="checkbox" checked={layout.quickLinks.includes(item.id)} onChange={() => toggleQuickLink(item.id)} />
                    <i className={item.icon} aria-hidden="true" />
                    <span>{item.label}</span>
                  </label>
                ))}
              </div>
            </section>

            <section className="panel" aria-labelledby="sidebar-history">
              <h2 id="sidebar-history">{t("auditHistory")}</h2>
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
            </section>
          </div>
        </div>
      )}
    </main>
  );
}

export default SidebarManager;