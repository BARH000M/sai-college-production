import { useCallback, useEffect, useMemo, useState } from "react";
import { LabPage, LabStats, LabTabs } from "@/portal/pages/labs/LabShell";
import { useActiveBranch } from "@/portal/hooks/useActiveBranch";
import {
  loadMediaAssets, uploadMediaAsset, setMediaStatus, mediaSignedUrl,
  loadCourseOptions, loadLessonOptions, validateMediaFile,
  type MediaAsset, type MediaType, type MediaStatus, type MediaDraft, type CourseOption,
} from "@/portal/lib/mediaRepository";

const mediaTypes: readonly { id: MediaType; label: string; icon: string }[] = [
  { id: "image", label: "صور", icon: "ri-image-line" },
  { id: "audio", label: "صوت", icon: "ri-music-line" },
  { id: "video", label: "فيديو", icon: "ri-video-line" },
  { id: "document", label: "مستندات", icon: "ri-file-text-line" },
];

const emptyDraft: MediaDraft = {
  titleAr: "", titleEn: "", titleZh: "", type: "image",
  category: "", courseId: "", lessonId: "", branchId: "",
};

function formatDate(value: string | null): string {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

function formatSize(bytes: number | null): string {
  if (!bytes) return "—";
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} م.ب`;
  return `${Math.max(1, Math.round(bytes / 1024))} ك.ب`;
}

export function MediaLibrary() {
  const { branchId } = useActiveBranch();
  const [assets, setAssets] = useState<MediaAsset[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tab, setTab] = useState<"catalogue" | "upload" | "categories">("catalogue");
  const [search, setSearch] = useState("");
  const [typeFilter, setTypeFilter] = useState<MediaType | "all">("all");
  const [statusFilter, setStatusFilter] = useState<MediaStatus | "all">("all");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);

  const [courses, setCourses] = useState<CourseOption[]>([]);
  const [lessons, setLessons] = useState<CourseOption[]>([]);
  const [draft, setDraft] = useState<MediaDraft>(emptyDraft);
  const [file, setFile] = useState<File | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState<"uploading" | "recording" | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setAssets(await loadMediaAssets());
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  useEffect(() => {
    let cancelled = false;
    loadCourseOptions()
      .then((rows) => { if (!cancelled) setCourses(rows); })
      .catch(() => { if (!cancelled) setCourses([]); });
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    let cancelled = false;
    loadLessonOptions(draft.courseId)
      .then((rows) => { if (!cancelled) setLessons(rows); })
      .catch(() => { if (!cancelled) setLessons([]); });
    return () => { cancelled = true; };
  }, [draft.courseId]);

  useEffect(() => {
    if (!draft.branchId && branchId) setDraft((current) => ({ ...current, branchId }));
  }, [branchId, draft.branchId]);

  const selected = assets.find((asset) => asset.id === selectedId) ?? null;

  useEffect(() => {
    if (!selected || selected.media_type !== "image") {
      setPreviewUrl(null);
      return;
    }
    let cancelled = false;
    setPreviewError(null);
    mediaSignedUrl(selected.storage_path)
      .then((url) => { if (!cancelled) setPreviewUrl(url); })
      .catch((caught) => { if (!cancelled) setPreviewError(caught instanceof Error ? caught.message : String(caught)); });
    return () => { cancelled = true; };
  }, [selected]);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    return assets
      .filter((asset) => (statusFilter === "all" ? true : asset.status === statusFilter))
      .filter((asset) => (typeFilter === "all" ? true : asset.media_type === typeFilter))
      .filter((asset) => !term || [asset.title_ar, asset.title_en, asset.title_zh, asset.category]
        .filter(Boolean).join(" ").toLowerCase().includes(term));
  }, [assets, search, typeFilter, statusFilter]);

  const stats = useMemo(() => ({
    total: assets.filter((asset) => asset.status !== "archived").length,
    image: assets.filter((asset) => asset.media_type === "image" && asset.status !== "archived").length,
    audio: assets.filter((asset) => asset.media_type === "audio" && asset.status !== "archived").length,
    archived: assets.filter((asset) => asset.status === "archived").length,
    size: assets.reduce((sum, asset) => sum + (asset.size_bytes ?? 0), 0),
  }), [assets]);

  const typeMeta = (type: MediaType) => mediaTypes.find((entry) => entry.id === type);

  async function submit() {
    setFormError(null);
    setNotice(null);
    const invalid = validateMediaFile(file, draft.type);
    if (invalid) { setFormError(invalid); return; }
    if (!draft.titleAr.trim()) { setFormError("العنوان العربي مطلوب."); return; }
    if (!file) { setFormError("اختر ملفاً للرفع."); return; }
    setBusy("uploading");
    try {
      const created = await uploadMediaAsset(file, { ...draft, branchId: draft.branchId || branchId }, (state) => setBusy(state));
      setAssets((current) => [created, ...current]);
      setDraft({ ...emptyDraft, branchId: draft.branchId || branchId });
      setFile(null);
      setTab("catalogue");
      setSelectedId(created.id);
      setNotice(`رُفع «${created.title_ar}» وأُضيف إلى فهرس الوسائط.`);
    } catch (caught) {
      setFormError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setBusy(null);
    }
  }

  async function toggleArchive(asset: MediaAsset) {
    setError(null);
    setNotice(null);
    try {
      const next: MediaStatus = asset.status === "archived" ? "draft" : "archived";
      await setMediaStatus(asset.id, next);
      setAssets((current) => current.map((row) => (row.id === asset.id ? { ...row, status: next } : row)));
      setNotice(next === "archived" ? "أُرشف الملف مع الاحتفاظ بسجله." : "أُعيد الملف إلى المسودات.");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    }
  }

  const retry = <button className="button secondary" type="button" onClick={() => void load()}>
    <i className="ri-refresh-line" aria-hidden="true"></i> إعادة المحاولة
  </button>;

  return <LabPage
    eyebrow="استوديو المحتوى"
    title="مكتبة الوسائط"
    intro="فهرس مركزي دائم للصور والصوت والفيديو والمستندات، مرتبط بالمقررات والدروس، مع تخزين خاص وتتبّع الاستخدام والأرشفة الآمنة."
    badge={`${stats.total} ملف نشط`}
  >
    <LabStats items={[
      { label: "ملفات نشطة", value: String(stats.total), detail: `${stats.archived} مؤرشف` },
      { label: "صور", value: String(stats.image), detail: "بطاقات ومخططات" },
      { label: "صوت", value: String(stats.audio), detail: "نطق واستماع" },
      { label: "الحجم الكلي", value: formatSize(stats.size), detail: "داخل المكتبة" },
    ]} />

    <LabTabs
      label="أقسام مكتبة الوسائط"
      value={tab}
      onChange={setTab}
      tabs={[
        { id: "catalogue", label: "الفهرس", icon: "ri-folder-open-line" },
        { id: "upload", label: "رفع ملف", icon: "ri-upload-cloud-line" },
        { id: "categories", label: "التصنيفات", icon: "ri-price-tag-3-line" },
      ]}
    />

    {notice && <p className="notice" role="status">{notice}</p>}
    {error && <p className="error-box" role="alert">{error} {retry}</p>}

    {tab === "catalogue" && <>
      <section className="panel">
        <div className="media-toolbar">
          <label className="media-search">
            <i className="ri-search-line" aria-hidden="true"></i>
            <input type="search" placeholder="ابحث بالعنوان أو التصنيف" value={search} onChange={(event) => setSearch(event.target.value)} aria-label="بحث في الوسائط" />
          </label>
          <select value={typeFilter} onChange={(event) => setTypeFilter(event.target.value as MediaType | "all")} aria-label="نوع الملف">
            <option value="all">كل الأنواع</option>
            {mediaTypes.map((type) => <option key={type.id} value={type.id}>{type.label}</option>)}
          </select>
          <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as MediaStatus | "all")} aria-label="حالة الملف">
            <option value="all">كل الحالات</option>
            <option value="draft">مسودة</option>
            <option value="published">منشور</option>
            <option value="archived">مؤرشف</option>
          </select>
        </div>

        {loading
          ? <p className="muted">جارٍ تحميل الفهرس من الخادم...</p>
          : !filtered.length
            ? <p className="muted">لا توجد ملفات مطابقة. ارفع أول ملف من تبويب «رفع ملف».</p>
            : <div className="media-grid">
              {filtered.map((asset) => {
                const meta = typeMeta(asset.media_type);
                return <button key={asset.id} type="button" className="media-card" onClick={() => setSelectedId(asset.id)}>
                  <span className={`media-card-icon media-${asset.media_type}`}><i className={meta?.icon ?? "ri-file-line"} aria-hidden="true"></i></span>
                  <span className="media-card-body">
                    <strong>{asset.title_ar}</strong>
                    <small dir="ltr">{asset.title_en ?? asset.storage_path.split("/").pop()}</small>
                    <span className="media-card-tags">
                      {asset.category && <span className="lab-tag">{asset.category}</span>}
                      <span className="lab-tag">{meta?.label}</span>
                    </span>
                    <span className="media-card-foot">
                      <span>{formatDate(asset.created_at)}</span>
                      <span>{formatSize(asset.size_bytes)}</span>
                    </span>
                  </span>
                  {asset.status === "archived" && <span className="lab-status status-neutral">مؤرشف</span>}
                </button>;
              })}
            </div>}
      </section>

      {selected && <section className="panel">
        <div className="page-heading">
          <div>
            <h2>{selected.title_ar}</h2>
            <p className="muted" dir="ltr">{selected.title_en ?? "—"}{selected.title_zh ? ` · ${selected.title_zh}` : ""}</p>
          </div>
          <button className="text-button" type="button" onClick={() => setSelectedId(null)} aria-label="إغلاق التفاصيل"><i className="ri-close-line" aria-hidden="true"></i></button>
        </div>

        {previewError && <p className="error-box" role="alert">تعذّر توليد رابط معاينة مؤقت: {previewError}</p>}
        {previewUrl && <div className="media-preview">
          <img src={previewUrl} alt={selected.title_ar} title={`${selected.title_ar} — معاينة مؤقتة`} />
          <p className="data-note">رابط موقّع قصير الأجل (5 دقائق). لا يُحفظ الرابط كمعرّف للملف.</p>
        </div>}

        <dl className="media-detail">
          <div><dt>النوع</dt><dd>{typeMeta(selected.media_type)?.label}</dd></div>
          <div><dt>التصنيف</dt><dd>{selected.category ?? "—"}</dd></div>
          <div><dt>المسار</dt><dd dir="ltr">{selected.storage_path}</dd></div>
          <div><dt>الحجم</dt><dd>{formatSize(selected.size_bytes)}</dd></div>
          <div><dt>الاستخدام</dt><dd>{selected.usage_count} ارتباط</dd></div>
          <div><dt>الحالة</dt><dd>{selected.status === "archived" ? "مؤرشف" : selected.status === "published" ? "منشور" : "مسودة"}</dd></div>
        </dl>
        <div className="actions">
          <button className="button secondary" type="button" onClick={() => void toggleArchive(selected)}>
            <i className={selected.status === "archived" ? "ri-arrow-go-back-line" : "ri-archive-line"} aria-hidden="true"></i>
            {selected.status === "archived" ? "استعادة الملف" : "أرشفة الملف"}
          </button>
          <span className="data-note">لا تُحذف الملفات المرتبطة بدروس منشورة؛ تُؤرشف للحفاظ على سجل المحتوى.</span>
        </div>
      </section>}
    </>}

    {tab === "upload" && <section className="panel">
      <h2>رفع ملف إلى المكتبة</h2>
      <p className="data-note">يُرفع الملف الثنائي إلى مساحة تخزين خاصة، ثم تُسجَّل بياناته الوصفية. لا يُحفظ أي رابط مؤقت كمعرّف.</p>
      {formError && <p className="error-box" role="alert">{formError}</p>}
      <div className="media-form">
        <label>العنوان العربي<input value={draft.titleAr} onChange={(event) => setDraft({ ...draft, titleAr: event.target.value })} /></label>
        <label>العنوان الإنجليزي<input dir="ltr" value={draft.titleEn} onChange={(event) => setDraft({ ...draft, titleEn: event.target.value })} /></label>
        <label>العنوان الصيني<input dir="ltr" value={draft.titleZh} onChange={(event) => setDraft({ ...draft, titleZh: event.target.value })} /></label>
        <label>النوع
          <select value={draft.type} onChange={(event) => setDraft({ ...draft, type: event.target.value as MediaType })}>
            {mediaTypes.map((type) => <option key={type.id} value={type.id}>{type.label}</option>)}
          </select>
        </label>
        <label>التصنيف<input value={draft.category} onChange={(event) => setDraft({ ...draft, category: event.target.value })} placeholder="مثال: نطق" /></label>
        <label>المقرر
          <select value={draft.courseId} onChange={(event) => setDraft({ ...draft, courseId: event.target.value, lessonId: "" })}>
            <option value="">— غير مرتبط —</option>
            {courses.map((course) => <option key={course.id} value={course.id}>{course.title}</option>)}
          </select>
        </label>
        <label>الدرس
          <select value={draft.lessonId} onChange={(event) => setDraft({ ...draft, lessonId: event.target.value })} disabled={!lessons.length}>
            <option value="">{draft.courseId ? "— غير مرتبط —" : "اختر المقرر أولاً"}</option>
            {lessons.map((lesson) => <option key={lesson.id} value={lesson.id}>{lesson.title}</option>)}
          </select>
        </label>
        <label>الملف<input type="file" onChange={(event) => setFile(event.target.files?.[0] ?? null)} /></label>
      </div>
      <div className="actions">
        <button className="button primary" type="button" onClick={() => void submit()} disabled={busy !== null}>
          <i className={busy ? "ri-loader-4-line" : "ri-upload-cloud-line"} aria-hidden="true"></i>
          {busy === "uploading" ? "جارٍ رفع الملف..." : busy === "recording" ? "جارٍ تسجيل البيانات..." : "رفع وإضافة إلى المكتبة"}
        </button>
        <button className="button secondary" type="button" onClick={() => { setDraft({ ...emptyDraft, branchId }); setFile(null); setFormError(null); }}>تفريغ النموذج</button>
      </div>
    </section>}

    {tab === "categories" && <section className="panel">
      <h2>التصنيفات والاستخدام</h2>
      {!assets.length
        ? <p className="muted">لا توجد وسائط بعد.</p>
        : <div className="media-category-list">
          {Array.from(new Set(assets.map((asset) => asset.category ?? "غير مصنّف"))).map((category) => {
            const rows = assets.filter((asset) => (asset.category ?? "غير مصنّف") === category);
            const active = rows.filter((asset) => asset.status !== "archived").length;
            const usage = rows.reduce((sum, asset) => sum + asset.usage_count, 0);
            return <div key={category} className="media-category-row">
              <span className="media-card-icon"><i className="ri-price-tag-3-line" aria-hidden="true"></i></span>
              <div><strong>{category}</strong><small>{active} ملف نشط · {usage} ارتباط بالدروس</small></div>
            </div>;
          })}
        </div>}
      <div className="actions">
        <button className="button secondary" type="button" onClick={() => void load()}><i className="ri-refresh-line" aria-hidden="true"></i> تحديث الفهرس من الخادم</button>
      </div>
    </section>}
  </LabPage>;
}