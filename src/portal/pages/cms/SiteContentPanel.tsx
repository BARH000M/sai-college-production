import { useEffect, useMemo, useState } from "react";
import {
  cmsError, cmsSections, loadSiteContent, saveSiteContent, type SiteContentRow,
} from "@/portal/lib/cms";
import { usePreviewDraft } from "./previewDraft";
import { CmsDirtyBadge } from "./CmsDirtyBadge";

type Draft = Record<string, { value_ar: string; value_en: string }>;

export function SiteContentPanel({ canEdit }: { canEdit: boolean }) {
  const [rows, setRows] = useState<SiteContentRow[]>([]);
  const [draft, setDraft] = useState<Draft>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    void loadSiteContent()
      .then((data) => {
        if (!active) return;
        setRows(data);
        const next: Draft = {};
        data.forEach((row) => { next[row.key] = { value_ar: row.value_ar, value_en: row.value_en }; });
        setDraft(next);
      })
      .catch((failure: unknown) => { if (active) setError(cmsError("تعذر تحميل محتوى الموقع", failure)); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [retry]);

  const groups = useMemo(() => {
    const map = new Map<string, SiteContentRow[]>();
    rows.forEach((row) => {
      const bucket = map.get(row.section) ?? [];
      bucket.push(row);
      map.set(row.section, bucket);
    });
    return Array.from(map.entries());
  }, [rows]);

  const { publish, setDirty } = usePreviewDraft();

  useEffect(() => {
    if (!rows.length) return;
    const next: Record<string, { value_ar: string; value_en: string }> = {};
    rows.forEach((row) => {
      const values = draft[row.key];
      next[row.key] = {
        value_ar: values?.value_ar ?? row.value_ar,
        value_en: values?.value_en ?? row.value_en,
      };
    });
    publish({ content: next });
  }, [rows, draft, publish]);

  const dirtyCount = rows.filter((row) => {
    const values = draft[row.key];
    return values && (values.value_ar !== row.value_ar || values.value_en !== row.value_en);
  }).length;

  useEffect(() => {
    setDirty("content", dirtyCount);
  }, [dirtyCount, setDirty]);

  function isFieldDirty(key: string, field: "value_ar" | "value_en"): boolean {
    const row = rows.find((item) => item.key === key);
    const values = draft[key];
    if (!row || !values) return false;
    return values[field] !== row[field];
  }

  const longFields = new Set([
    "hero.title", "hero.subtitle", "about.p1", "about.p2", "campus.subtitle",
  ]);

  function isLongField(key: string): boolean {
    return longFields.has(key);
  }

  function change(key: string, field: "value_ar" | "value_en", value: string) {
    setDraft((current) => ({ ...current, [key]: { ...current[key], [field]: value } }));
    setSuccess(null);
  }

  async function save() {
    if (!canEdit || saving || !dirtyCount) return;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const next = rows.map((row) => ({ ...row, ...(draft[row.key] ?? {}) }));
      await saveSiteContent(next);
      setRows(next);
      setSuccess("تم حفظ محتوى الموقع التعريفي ونشره للزوّار.");
    } catch (failure) {
      setError(cmsError("تعذر حفظ محتوى الموقع", failure));
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <section className="panel"><p role="status">جارٍ تحميل محتوى الموقع...</p></section>;
  if (error && !rows.length) {
    return <section className="panel">
      <p className="error-box" role="alert">{error}</p>
      <button className="button secondary" type="button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button>
    </section>;
  }

  return <div className="cms-panels">
    <section className="panel">
      <div className="page-heading">
        <div>
          <h2>نصوص الموقع التعريفي</h2>
          <p className="muted">كل ما تعدّله هنا يظهر مباشرة على الصفحة العامة بعد الحفظ.</p>
        </div>
        <div className="actions">
          <a className="button secondary" href="/" target="_blank" rel="noreferrer">معاينة الموقع</a>
          <button className="button primary" type="button" disabled={!canEdit || saving || !dirtyCount} onClick={() => void save()}>
            {saving ? "جارٍ الحفظ..." : dirtyCount ? `حفظ ${dirtyCount} تغييراً` : "لا تغييرات"}
          </button>
        </div>
      </div>
      {!canEdit && <p className="notice">حسابك يملك قراءة المحتوى فقط؛ التعديل والنشر متاحان للإدارة ومحرر المحتوى.</p>}
      {success && <p className="success-box" role="status">{success}</p>}
      {error && <p className="error-box" role="alert">{error}</p>}

      {groups.map(([section, items]) => <div key={section} className="cms-group">
        <h3 className="cms-group-title">{cmsSections[section] ?? section}</h3>
        <div className="cms-field-grid">
          {items.map((row) => <div key={row.key} className="cms-field">
            <label htmlFor={`cms-${row.key}`} className="cms-label-row">{row.label_ar}<CmsDirtyBadge show={isFieldDirty(row.key, "value_ar")} /></label>
            {isLongField(row.key)
              ? <textarea
                  id={`cms-${row.key}`}
                  rows={3}
                  value={draft[row.key]?.value_ar ?? ""}
                  disabled={!canEdit || saving}
                  onChange={(event) => change(row.key, "value_ar", event.target.value)}
                />
              : <input
                  id={`cms-${row.key}`}
                  dir={row.key.endsWith(".icon") || row.key.endsWith(".image") ? "ltr" : undefined}
                  value={draft[row.key]?.value_ar ?? ""}
                  disabled={!canEdit || saving}
                  onChange={(event) => change(row.key, "value_ar", event.target.value)}
                />}
            <label htmlFor={`cms-${row.key}-en`} className="cms-sub-label">English<CmsDirtyBadge show={isFieldDirty(row.key, "value_en")} /></label>
            {isLongField(row.key)
              ? <textarea
                  id={`cms-${row.key}-en`}
                  dir="ltr"
                  rows={3}
                  value={draft[row.key]?.value_en ?? ""}
                  disabled={!canEdit || saving}
                  onChange={(event) => change(row.key, "value_en", event.target.value)}
                />
              : <input
                  id={`cms-${row.key}-en`}
                  dir="ltr"
                  value={draft[row.key]?.value_en ?? ""}
                  disabled={!canEdit || saving}
                  onChange={(event) => change(row.key, "value_en", event.target.value)}
                />}
            <small className="cms-key" dir="ltr">{row.key}</small>
          </div>)}
        </div>
      </div>)}
    </section>
  </div>;
}