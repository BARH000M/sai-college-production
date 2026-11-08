import { useEffect, useRef, useState } from "react";
import {
  cmsError, deleteProgram, emptyProgramDraft, loadPrograms, programToDraft, saveProgram, validateProgram,
  type CmsProgram, type ProgramDraft,
} from "@/portal/lib/cms";
import { usePreviewDraft } from "./previewDraft";
import { CmsDirtyBadge } from "./CmsDirtyBadge";

export function ProgramsPanel({ canEdit }: { canEdit: boolean }) {
  const [rows, setRows] = useState<CmsProgram[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  const [editingId, setEditingId] = useState<string | null | undefined>(undefined);
  const [draft, setDraft] = useState<ProgramDraft>(emptyProgramDraft);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    void loadPrograms(true)
      .then((data) => { if (active) setRows(data); })
      .catch((failure: unknown) => { if (active) setError(cmsError("تعذر تحميل البرامج", failure)); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [retry]);

  const { publish, setDirty, resetSignal } = usePreviewDraft();

  // Discarding unsaved edits closes the open form so its changes are dropped.
  const lastReset = useRef(resetSignal);
  useEffect(() => {
    if (resetSignal === lastReset.current) return;
    lastReset.current = resetSignal;
    setEditingId(undefined);
    setFormError(null);
    setSuccess(null);
  }, [resetSignal]);

  useEffect(() => {
    if (loading) return;
    let next: CmsProgram[];
    if (editingId === null) {
      next = [...rows, { id: "__new_draft__", ...draft }];
    } else if (typeof editingId === "string") {
      next = rows.map((row) => (row.id === editingId ? { ...row, ...draft } : row));
    } else {
      next = rows;
    }
    publish({ programs: next });
  }, [rows, editingId, draft, loading, publish]);

  function openForm(row: CmsProgram | null) {
    if (!canEdit) return;
    setFormError(null);
    setSuccess(null);
    if (row) { setEditingId(row.id); setDraft(programToDraft(row)); return; }
    const nextOrder = rows.reduce((max, item) => Math.max(max, item.sort_order), 0) + 10;
    setEditingId(null);
    setDraft({ ...emptyProgramDraft(), sort_order: nextOrder });
  }

  function change<K extends keyof ProgramDraft>(key: K, value: ProgramDraft[K]) {
    setDraft((current) => ({ ...current, [key]: value }));
    setSuccess(null);
  }

  async function submit() {
    if (!canEdit || saving || editingId === undefined) return;
    const validation = validateProgram(draft);
    if (validation) { setFormError(validation); return; }
    setSaving(true);
    setFormError(null);
    try {
      await saveProgram(draft, editingId);
      setEditingId(undefined);
      setSuccess(editingId ? "تم تحديث البرنامج ونشره على الموقع." : "تمت إضافة البرنامج إلى الموقع.");
      setRetry((value) => value + 1);
    } catch (failure) {
      setFormError(cmsError("تعذر حفظ البرنامج", failure));
    } finally {
      setSaving(false);
    }
  }

  async function togglePublish(row: CmsProgram) {
    if (!canEdit || saving) return;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const next = { ...programToDraft(row), is_published: !row.is_published };
      await saveProgram(next, row.id);
      setSuccess(next.is_published ? "تم نشر البرنامج على الموقع." : "تم إخفاء البرنامج من الموقع.");
      setRetry((value) => value + 1);
    } catch (failure) {
      setError(cmsError("تعذر تغيير حالة النشر", failure));
    } finally {
      setSaving(false);
    }
  }

  async function remove(row: CmsProgram) {
    if (!canEdit || saving) return;
    if (!window.confirm(`سيُحذف «${row.title_ar}» نهائياً من الموقع. هل تريد المتابعة؟`)) return;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await deleteProgram(row.id);
      setSuccess("تم حذف البرنامج من الموقع.");
      setRetry((value) => value + 1);
    } catch (failure) {
      setError(cmsError("تعذر حذف البرنامج", failure));
    } finally {
      setSaving(false);
    }
  }

  const unsavedFields: string[] = (() => {
    if (editingId === undefined) return [];
    const baseline: ProgramDraft = typeof editingId === "string"
      ? (() => {
          const row = rows.find((item) => item.id === editingId);
          return row ? programToDraft(row) : emptyProgramDraft();
        })()
      : emptyProgramDraft();
    return (Object.keys(baseline) as (keyof ProgramDraft)[])
      .filter((key) => !(key === "sort_order" && editingId === null) && draft[key] !== baseline[key])
      .map((key) => String(key));
  })();

  function fieldDirty(key: keyof ProgramDraft): boolean {
    return unsavedFields.includes(String(key));
  }

  useEffect(() => {
    setDirty("programs", unsavedFields.length);
  }, [unsavedFields.length, setDirty]);

  return <div className="cms-panels">
    <section className="panel">
      <div className="page-heading">
        <div>
          <h2>البرامج الأكاديمية على الموقع</h2>
          <p className="muted">تظهر البرامج المنشورة فقط في قسم «البرامج» بالصفحة العامة.</p>
        </div>
        {canEdit && <button className="button primary" type="button" disabled={saving || editingId !== undefined} onClick={() => openForm(null)}>إضافة برنامج</button>}
      </div>
      {success && <p className="success-box" role="status">{success}</p>}
      {error && <p className="error-box" role="alert">{error} <button className="text-button" type="button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}
      {loading ? <p role="status">جارٍ تحميل البرامج...</p> : !rows.length ? <p className="muted">لا توجد برامج بعد. أضف أول برنامج ليظهر على الموقع.</p> :
        <div className="table-scroll"><table className="management-table">
          <thead><tr><th>الترتيب</th><th>البرنامج</th><th>المدة</th><th>الحالة</th><th>الإجراءات</th></tr></thead>
          <tbody>{rows.map((row) => <tr key={row.id}>
            <td>{row.sort_order}</td>
            <td><strong><i className={`${row.icon} text-primary-600`} aria-hidden="true"></i> {row.title_ar}</strong><span className="learn-meta" dir="ltr">{row.title_en}</span></td>
            <td>{row.duration_ar}</td>
            <td><span className={`learn-pill ${row.is_published ? "learn-status-completed" : "learn-status-not_started"}`}>{row.is_published ? "منشور" : "مخفي"}</span></td>
            <td><div className="homework-admin">
              <button className="button secondary" type="button" disabled={saving || editingId !== undefined || !canEdit} onClick={() => openForm(row)}>تعديل</button>
              <button className="button secondary" type="button" disabled={saving || editingId !== undefined || !canEdit} onClick={() => void togglePublish(row)}>{row.is_published ? "إخفاء" : "نشر"}</button>
              <button className="button secondary" type="button" disabled={saving || editingId !== undefined || !canEdit} onClick={() => void remove(row)}>حذف</button>
            </div></td>
          </tr>)}</tbody>
        </table></div>}
    </section>

    {editingId !== undefined && <section className="panel management-detail">
      <div className="page-heading">
        <h2>{editingId ? "تعديل برنامج" : "برنامج جديد"}</h2>
        <button className="button secondary" type="button" disabled={saving} onClick={() => setEditingId(undefined)}>إغلاق</button>
      </div>
      {unsavedFields.length > 0 && <p className="notice cms-dirty-note">
        <CmsDirtyBadge show />
        <strong>{unsavedFields.length} حقل لم يُنشر بعد.</strong> اضغط «حفظ البرنامج» لتطبيق التعديلات على الموقع.
      </p>}
      <div className="management-form">
        <label><span className="cms-label-row">الاسم بالعربية<CmsDirtyBadge show={fieldDirty("title_ar")} /></span><input required value={draft.title_ar} onChange={(event) => change("title_ar", event.target.value)} /></label>
        <label><span className="cms-label-row">الاسم بالإنجليزية<CmsDirtyBadge show={fieldDirty("title_en")} /></span><input dir="ltr" value={draft.title_en} onChange={(event) => change("title_en", event.target.value)} /></label>
        <label><span className="cms-label-row">المدة بالعربية<CmsDirtyBadge show={fieldDirty("duration_ar")} /></span><input value={draft.duration_ar} onChange={(event) => change("duration_ar", event.target.value)} /></label>
        <label><span className="cms-label-row">المدة بالإنجليزية<CmsDirtyBadge show={fieldDirty("duration_en")} /></span><input dir="ltr" value={draft.duration_en} onChange={(event) => change("duration_en", event.target.value)} /></label>
        <label><span className="cms-label-row">الأيقونة (Remix Icon)<CmsDirtyBadge show={fieldDirty("icon")} /></span><input dir="ltr" value={draft.icon} onChange={(event) => change("icon", event.target.value)} placeholder="ri-book-open-line" /></label>
        <label><span className="cms-label-row">الترتيب<CmsDirtyBadge show={fieldDirty("sort_order")} /></span><input type="number" value={draft.sort_order} onChange={(event) => change("sort_order", Number(event.target.value) || 0)} /></label>
        <label><span className="cms-label-row">الوصف بالعربية<CmsDirtyBadge show={fieldDirty("summary_ar")} /></span><textarea rows={3} value={draft.summary_ar} onChange={(event) => change("summary_ar", event.target.value)} /></label>
        <label><span className="cms-label-row">الوصف بالإنجليزية<CmsDirtyBadge show={fieldDirty("summary_en")} /></span><textarea dir="ltr" rows={3} value={draft.summary_en} onChange={(event) => change("summary_en", event.target.value)} /></label>
        <label className="cms-checkbox"><input type="checkbox" checked={draft.is_published} onChange={(event) => change("is_published", event.target.checked)} /> نشر على الموقع فوراً<CmsDirtyBadge show={fieldDirty("is_published")} /></label>
        {formError && <p className="error-box" role="alert">{formError}</p>}
        <div className="actions">
          <button className="button primary" type="button" disabled={saving} onClick={() => void submit()}>{saving ? "جارٍ الحفظ..." : "حفظ البرنامج"}</button>
          <button className="button secondary" type="button" disabled={saving} onClick={() => setEditingId(undefined)}>إلغاء</button>
        </div>
        {draft.title_ar && <p className="muted">معاينة: <i className={`${draft.icon} text-primary-600`} aria-hidden="true"></i> <strong>{draft.title_ar}</strong> — {draft.duration_ar} — {draft.summary_ar}</p>}
      </div>
    </section>}
  </div>;
}