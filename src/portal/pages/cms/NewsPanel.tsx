import { useEffect, useState } from "react";
import {
  cmsError, deleteNews, emptyNewsDraft, loadNews, newsToDraft, saveNews, validateNews,
  type CmsNews, type NewsDraft,
} from "@/portal/lib/cms";

export function NewsPanel({ canEdit }: { canEdit: boolean }) {
  const [rows, setRows] = useState<CmsNews[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  const [editingId, setEditingId] = useState<string | null | undefined>(undefined);
  const [draft, setDraft] = useState<NewsDraft>(emptyNewsDraft);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    void loadNews(true)
      .then((data) => { if (active) setRows(data); })
      .catch((failure: unknown) => { if (active) setError(cmsError("تعذر تحميل الأخبار", failure)); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [retry]);

  function openForm(row: CmsNews | null) {
    if (!canEdit) return;
    setFormError(null);
    setSuccess(null);
    if (row) { setEditingId(row.id); setDraft(newsToDraft(row)); return; }
    const nextOrder = rows.reduce((max, item) => Math.max(max, item.sort_order), 0) + 10;
    setEditingId(null);
    setDraft({ ...emptyNewsDraft(), sort_order: nextOrder });
  }

  function change<K extends keyof NewsDraft>(key: K, value: NewsDraft[K]) {
    setDraft((current) => ({ ...current, [key]: value }));
  }

  async function submit() {
    if (!canEdit || saving || editingId === undefined) return;
    const validation = validateNews(draft);
    if (validation) { setFormError(validation); return; }
    setSaving(true);
    setFormError(null);
    try {
      await saveNews(draft, editingId);
      setEditingId(undefined);
      setSuccess(editingId ? "تم تحديث الخبر على الموقع." : "تم نشر الخبر على الموقع.");
      setRetry((value) => value + 1);
    } catch (failure) {
      setFormError(cmsError("تعذر حفظ الخبر", failure));
    } finally {
      setSaving(false);
    }
  }

  async function togglePublish(row: CmsNews) {
    if (!canEdit || saving) return;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await saveNews({ ...newsToDraft(row), is_published: !row.is_published }, row.id);
      setSuccess(row.is_published ? "تم إخفاء الخبر من الموقع." : "تم نشر الخبر على الموقع.");
      setRetry((value) => value + 1);
    } catch (failure) {
      setError(cmsError("تعذر تغيير حالة النشر", failure));
    } finally {
      setSaving(false);
    }
  }

  async function remove(row: CmsNews) {
    if (!canEdit || saving) return;
    if (!window.confirm(`سيُحذف «${row.title_ar}» نهائياً من الموقع. هل تريد المتابعة؟`)) return;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await deleteNews(row.id);
      setSuccess("تم حذف الخبر من الموقع.");
      setRetry((value) => value + 1);
    } catch (failure) {
      setError(cmsError("تعذر حذف الخبر", failure));
    } finally {
      setSaving(false);
    }
  }

  return <div className="cms-panels">
    <section className="panel">
      <div className="page-heading">
        <div>
          <h2>أخبار الحرم الجامعي</h2>
          <p className="muted">تظهر الأخبار المنشورة فقط في قسم «آخر الأخبار» على الصفحة العامة.</p>
        </div>
        {canEdit && <button className="button primary" type="button" disabled={saving || editingId !== undefined} onClick={() => openForm(null)}>إضافة خبر</button>}
      </div>
      {success && <p className="success-box" role="status">{success}</p>}
      {error && <p className="error-box" role="alert">{error} <button className="text-button" type="button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}
      {loading ? <p role="status">جارٍ تحميل الأخبار...</p> : !rows.length ? <p className="muted">لا توجد أخبار بعد.</p> :
        <div className="cms-news-list">
          {rows.map((row) => <article key={row.id} className="cms-news-item">
            <div className="cms-news-thumb">
              {row.image_url
                ? <img src={row.image_url} alt={row.title_ar} title={row.title_ar} className="w-full h-full object-cover object-top" />
                : <span className="cms-news-placeholder"><i className="ri-image-line" aria-hidden="true"></i></span>}
            </div>
            <div className="cms-news-body">
              <div className="cms-news-head">
                <span className="learn-tag">{row.tag_ar}</span>
                <span className={`learn-pill ${row.is_published ? "learn-status-completed" : "learn-status-not_started"}`}>{row.is_published ? "منشور" : "مخفي"}</span>
                <span className="learn-meta" dir="ltr">{row.published_at}</span>
              </div>
              <strong>{row.title_ar}</strong>
              <p className="learn-meta">{row.summary_ar}</p>
              <div className="homework-admin">
                <button className="button secondary" type="button" disabled={saving || editingId !== undefined || !canEdit} onClick={() => openForm(row)}>تعديل</button>
                <button className="button secondary" type="button" disabled={saving || editingId !== undefined || !canEdit} onClick={() => void togglePublish(row)}>{row.is_published ? "إخفاء" : "نشر"}</button>
                <button className="button secondary" type="button" disabled={saving || editingId !== undefined || !canEdit} onClick={() => void remove(row)}>حذف</button>
              </div>
            </div>
          </article>)}
        </div>}
    </section>

    {editingId !== undefined && <section className="panel management-detail">
      <div className="page-heading">
        <h2>{editingId ? "تعديل خبر" : "خبر جديد"}</h2>
        <button className="button secondary" type="button" disabled={saving} onClick={() => setEditingId(undefined)}>إغلاق</button>
      </div>
      <div className="management-form">
        <label>العنوان بالعربية<input required value={draft.title_ar} onChange={(event) => change("title_ar", event.target.value)} /></label>
        <label>العنوان بالإنجليزية<input dir="ltr" value={draft.title_en} onChange={(event) => change("title_en", event.target.value)} /></label>
        <label>التصنيف بالعربية<input value={draft.tag_ar} onChange={(event) => change("tag_ar", event.target.value)} /></label>
        <label>التصنيف بالإنجليزية<input dir="ltr" value={draft.tag_en} onChange={(event) => change("tag_en", event.target.value)} /></label>
        <label>تاريخ النشر<input type="date" value={draft.published_at} onChange={(event) => change("published_at", event.target.value)} /></label>
        <label>الترتيب<input type="number" value={draft.sort_order} onChange={(event) => change("sort_order", Number(event.target.value) || 0)} /></label>
        <label>الملخص بالعربية<textarea rows={3} value={draft.summary_ar} onChange={(event) => change("summary_ar", event.target.value)} /></label>
        <label>الملخص بالإنجليزية<textarea dir="ltr" rows={3} value={draft.summary_en} onChange={(event) => change("summary_en", event.target.value)} /></label>
        <label className="cms-image-field">رابط الصورة (اختياري)
          <input dir="ltr" value={draft.image_url ?? ""} onChange={(event) => change("image_url", event.target.value)} placeholder="https://..." />
        </label>
        <label className="cms-checkbox"><input type="checkbox" checked={draft.is_published} onChange={(event) => change("is_published", event.target.checked)} /> نشر على الموقع فوراً</label>
        {draft.image_url && <div className="cms-image-preview"><img src={draft.image_url} alt="معاينة صورة الخبر" title={draft.title_ar || "معاينة"} className="w-full h-full object-cover object-top" /></div>}
        {formError && <p className="error-box" role="alert">{formError}</p>}
        <div className="actions">
          <button className="button primary" type="button" disabled={saving} onClick={() => void submit()}>{saving ? "جارٍ الحفظ..." : "حفظ الخبر"}</button>
          <button className="button secondary" type="button" disabled={saving} onClick={() => setEditingId(undefined)}>إلغاء</button>
        </div>
      </div>
    </section>}
  </div>;
}