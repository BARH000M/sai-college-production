import { useEffect, useMemo, useState, type FormEvent } from "react";
import {
  announcementAudiences, communicationsPermissions, createAnnouncement, deleteAnnouncement,
  emptyAnnouncementDraft, loadAnnouncementDeliveryCounts, loadAnnouncements, loadReadAnnouncementIds,
  markAnnouncementRead, sendAnnouncementEmail, setAnnouncementPublished, validateAnnouncementDraft,
  type Announcement, type AnnouncementDeliveryCounts, type AnnouncementDraft,
} from "../lib/communications";
import { loadReportBranches, type ReportOption } from "../lib/reports";
import { formatDate } from "../lib/learning";
import { CircularSheet } from "./communications/CircularSheet";

type Tab = "inbox" | "manage";

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function isLive(announcement: Announcement): boolean {
  if (!announcement.is_published || !announcement.published_at) return false;
  if (!announcement.expires_at) return true;
  return new Date(announcement.expires_at).getTime() > Date.now();
}

export function Communications({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const permissions = communicationsPermissions(roles);
  const canManage = permissions.canManage;

  const [branches, setBranches] = useState<ReportOption[]>([]);
  const [items, setItems] = useState<Announcement[]>([]);
  const [readIds, setReadIds] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [version, setVersion] = useState(0);
  const [emailCounts, setEmailCounts] = useState<Map<string, AnnouncementDeliveryCounts>>(new Map());
  const [emailBusy, setEmailBusy] = useState<string | null>(null);

  const [tab, setTab] = useState<Tab>("inbox");
  const [search, setSearch] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [draft, setDraft] = useState<AnnouncementDraft>(emptyAnnouncementDraft());
  const [publishNow, setPublishNow] = useState(true);
  const [circular, setCircular] = useState<Announcement | null>(null);

  useEffect(() => {
    let active = true;
    void loadReportBranches()
      .then((rows) => { if (active) setBranches(rows); })
      .catch(() => { if (active) setBranches([]); });
    return () => { active = false; };
  }, []);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    void Promise.all([
      loadAnnouncements(),
      userId ? loadReadAnnouncementIds(userId) : Promise.resolve(new Set<string>()),
      loadAnnouncementDeliveryCounts().catch(() => new Map<string, AnnouncementDeliveryCounts>()),
    ])
      .then(([rows, reads, counts]) => {
        if (!active) return;
        setItems(rows);
        setReadIds(reads);
        setEmailCounts(counts);
      })
      .catch((failure: unknown) => {
        if (active) { setItems([]); setError(`تعذر تحميل الإعلانات: ${message(failure)}`); }
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [userId, version]);

  const branchNames = useMemo(
    () => new Map(branches.map((row) => [row.id, row.name])),
    [branches],
  );

  const live = useMemo(() => items.filter(isLive), [items]);
  const drafts = useMemo(() => items.filter((item) => !item.is_published), [items]);
  const unread = useMemo(() => live.filter((item) => !readIds.has(item.id)), [live, readIds]);
  const expiring = useMemo(() => live.filter((item) => {
    if (!item.expires_at) return false;
    const days = (new Date(item.expires_at).getTime() - Date.now()) / (24 * 60 * 60 * 1000);
    return days >= 0 && days <= 7;
  }), [live]);

  const visible = useMemo(() => {
    const source = tab === "inbox" ? live : items;
    const term = search.trim().toLowerCase();
    if (!term) return source;
    return source.filter((item) => `${item.title} ${item.body}`.toLowerCase().includes(term));
  }, [tab, live, items, search]);

  async function refresh(done?: string) {
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      const [rows, reads, counts] = await Promise.all([
        loadAnnouncements(),
        userId ? loadReadAnnouncementIds(userId) : Promise.resolve(new Set<string>()),
        loadAnnouncementDeliveryCounts().catch(() => new Map<string, AnnouncementDeliveryCounts>()),
      ]);
      setItems(rows);
      setReadIds(reads);
      setEmailCounts(counts);
      if (done) setSuccess(done);
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  async function submitDraft(event: FormEvent) {
    event.preventDefault();
    if (!userId) { setError("تعذر التحقق من الحساب."); return; }
    const invalid = validateAnnouncementDraft(draft);
    if (invalid) { setError(invalid); return; }
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      await createAnnouncement(draft, userId, publishNow);
      setDraft(emptyAnnouncementDraft());
      setShowForm(false);
      setVersion((value) => value + 1);
      setSuccess(publishNow ? "نُشر الإعلان وظهر للمستهدفين." : "حُفظ الإعلان كمسودة.");
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  async function openCircular(announcement: Announcement) {
    setCircular(announcement);
    if (userId && !readIds.has(announcement.id)) {
      try {
        await markAnnouncementRead(announcement.id, userId);
        setReadIds((current) => new Set(current).add(announcement.id));
      } catch {
        // Reading state is a convenience; the circular still opens and prints.
      }
    }
  }

  async function sendEmail(announcement: Announcement) {
    setEmailBusy(announcement.id);
    setError(null);
    setSuccess(null);
    try {
      const summary = await sendAnnouncementEmail(announcement.id);
      setEmailCounts(await loadAnnouncementDeliveryCounts());
      if (!summary.configured) {
        setError(summary.message ?? "البريد غير مضبوط على الخادم بعد.");
      } else {
        setSuccess(
          `تم إرسال ${summary.sent} من ${summary.total} رسالة`
          + `${summary.failed ? `، وفشل ${summary.failed}` : ""}`
          + `${summary.skipped ? `، وتُخطّي ${summary.skipped}` : ""}.`,
        );
      }
    } catch (failure) {
      setError(message(failure));
    } finally {
      setEmailBusy(null);
    }
  }

  async function markRead(announcement: Announcement) {
    if (!userId || readIds.has(announcement.id)) return;
    try {
      await markAnnouncementRead(announcement.id, userId);
      setReadIds((current) => new Set(current).add(announcement.id));
    } catch (failure) {
      setError(`تعذر حفظ حالة القراءة: ${message(failure)}`);
    }
  }

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">كلية ساي · التواصل</p>
        <h1>التواصل والإعلانات</h1>
        <p className="muted">تعميمات موجّهة لكل جمهور، مع صندوق وارد مطبوع لكل إعلان. لا يرى أحد إعلاناً خارج جمهوره.</p>
      </div>
      {canManage && <button className="button primary" type="button" onClick={() => { setShowForm((value) => !value); setError(null); }}>
        <i className={showForm ? "ri-close-line" : "ri-megaphone-line"} aria-hidden="true"></i> {showForm ? "إغلاق" : "إعلان جديد"}
      </button>}
    </div>

    {error && <p className="error-box" role="alert">{error}</p>}
    {success && <p className="success-box" role="status">{success}</p>}
    {loading && <p role="status">جارٍ تحميل الإعلانات...</p>}

    {!loading && !error && <div className="kpi-grid">
      <div className="kpi-card"><span>إعلانات منشورة</span><strong>{live.length}</strong><small>سارية الآن</small></div>
      <div className="kpi-card"><span>غير مقروءة</span><strong>{unread.length}</strong><small>{unread.length ? "تحتاج مراجعة" : "قرأت كل شيء"}</small></div>
      <div className="kpi-card"><span>تنتهي هذا الأسبوع</span><strong>{expiring.length}</strong><small>خلال 7 أيام</small></div>
      <div className="kpi-card"><span>مسودات</span><strong>{drafts.length}</strong><small>{canManage ? "بانتظار النشر" : "—"}</small></div>
    </div>}

    {canManage && showForm && <section className="panel">
      <h2>إعلان جديد</h2>
      <p className="data-note">اختر الجمهور بدقة: الإعلان الموجّه لا يظهر لمن ليس ضمن الجمهور. اترك الفرع فارغاً ليصل لكل الفروع.</p>
      <form className="management-form" onSubmit={submitDraft}>
        <label>العنوان<span className="vocab-required"> *</span>
          <input required maxLength={160} value={draft.title} onChange={(event) => setDraft({ ...draft, title: event.target.value })} />
        </label>
        <label>الجمهور المستهدف<span className="vocab-required"> *</span>
          <select value={draft.audience} onChange={(event) => setDraft({ ...draft, audience: event.target.value as AnnouncementDraft["audience"] })}>
            {Object.entries(announcementAudiences).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select>
        </label>
        <label>الفرع
          <select value={draft.branch_id} onChange={(event) => setDraft({ ...draft, branch_id: event.target.value })}>
            <option value="">كل الفروع</option>
            {branches.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
          </select>
        </label>
        <label>تاريخ الانتهاء (اختياري)
          <input type="date" value={draft.expires_at} onChange={(event) => setDraft({ ...draft, expires_at: event.target.value })} />
        </label>
        <label style={{ gridColumn: "1 / -1" }}>نص الإعلان<span className="vocab-required"> *</span>
          <textarea required rows={5} maxLength={4000} value={draft.body} onChange={(event) => setDraft({ ...draft, body: event.target.value })} />
        </label>
        <label className="checkbox-field">
          <input type="checkbox" checked={publishNow} onChange={(event) => setPublishNow(event.target.checked)} />
          نشر الآن (بدون تحديد يُحفظ كمسودة)
        </label>
        <div className="actions">
          <button className="button primary" disabled={busy}>{busy ? "جارٍ الحفظ..." : publishNow ? "نشر الإعلان" : "حفظ المسودة"}</button>
          <button className="button secondary" type="button" disabled={busy} onClick={() => setDraft(emptyAnnouncementDraft())}>مسح الحقول</button>
        </div>
      </form>
    </section>}

    <div className="lab-toolbar">
      <div className="lab-tabs" role="tablist" aria-label="أقسام التواصل">
        <button className={`lab-tab${tab === "inbox" ? " active" : ""}`} type="button" role="tab" aria-selected={tab === "inbox"} onClick={() => setTab("inbox")}>
          <i className="ri-inbox-line" aria-hidden="true"></i> صندوق الوارد ({live.length})
        </button>
        {canManage && <button className={`lab-tab${tab === "manage" ? " active" : ""}`} type="button" role="tab" aria-selected={tab === "manage"} onClick={() => setTab("manage")}>
          <i className="ri-settings-3-line" aria-hidden="true"></i> إدارة الإعلانات ({items.length})
        </button>}
      </div>
      <div className="lab-toolbar-end">
        <label className="lab-search">
          <i className="ri-search-line" aria-hidden="true"></i>
          <span className="sr-only">البحث في الإعلانات</span>
          <input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="ابحث في العنوان أو النص" />
        </label>
      </div>
    </div>

    <section className="panel">
      <div className="home-panel-head">
        <div>
          <h2>{tab === "inbox" ? "الإعلانات السارية" : "كل الإعلانات"}</h2>
          <p className="data-note">تظهر الإعلانات التي تسمح بها صلاحيات حسابك وجمهوره فقط.</p>
        </div>
        <span className="lab-pill-count">{visible.length} إعلان</span>
      </div>

      {!visible.length
        ? <div className="notify-empty">
          <span className="notify-empty-icon"><i className="ri-megaphone-line" aria-hidden="true"></i></span>
          <strong>{search.trim() ? "لا نتائج مطابقة" : "لا توجد إعلانات"}</strong>
          <p className="muted">{canManage ? "أنشئ إعلاناً جديداً من الزر بالأعلى." : "ستظهر إعلانات الكلية هنا عند نشرها."}</p>
        </div>
        : <ul className="notify-list">
          {visible.map((announcement) => {
            const unreadItem = !readIds.has(announcement.id);
            const delivery = emailCounts.get(announcement.id);
            return <li key={announcement.id}>
              <article className={`notify-item${unreadItem && tab === "inbox" ? " unread" : ""}`}>
                <span className="notify-icon notify-admissions"><i className="ri-megaphone-line" aria-hidden="true"></i></span>
                <div className="notify-body">
                  <strong>{announcement.title}</strong>
                  <small>{announcement.body.length > 180 ? `${announcement.body.slice(0, 180)}…` : announcement.body}</small>
                  <span className="lab-meta-row">
                    <span><i className="ri-price-tag-3-line" aria-hidden="true"></i> {announcementAudiences[announcement.audience]}</span>
                    <span><i className="ri-map-pin-line" aria-hidden="true"></i> {announcement.branch_id ? branchNames.get(announcement.branch_id) ?? "فرع" : "كل الفروع"}</span>
                    <span><i className="ri-calendar-line" aria-hidden="true"></i> {announcement.published_at ? formatDate(announcement.published_at) : "مسودة"}</span>
                    {announcement.expires_at && <span><i className="ri-timer-line" aria-hidden="true"></i> ينتهي {formatDate(announcement.expires_at)}</span>}
                    {delivery && <span><i className="ri-mail-check-line" aria-hidden="true"></i> {delivery.sent} أُرسل{delivery.failed ? ` · ${delivery.failed} فشل` : ""}{delivery.skipped ? ` · ${delivery.skipped} متوقف` : ""}</span>}
                  </span>
                  <div className="homework-admin" style={{ marginTop: 6 }}>
                    {tab === "inbox" && unreadItem && <button className="text-button" type="button" onClick={() => void markRead(announcement)}>تحديد كمقروء</button>}
                    <button className="button secondary quick-action" type="button" onClick={() => void openCircular(announcement)}>
                      <i className="ri-printer-line" aria-hidden="true"></i> طباعة التعميم
                    </button>
                    {tab === "manage" && <>
                      {announcement.is_published && <button className="button secondary quick-action" type="button"
                        disabled={emailBusy === announcement.id} onClick={() => void sendEmail(announcement)}>
                        <i className="ri-mail-send-line" aria-hidden="true"></i>{" "}
                        {emailBusy === announcement.id ? "جارٍ الإرسال..." : "إرسال بالبريد"}
                      </button>}
                      <button className="button secondary quick-action" type="button" disabled={busy}
                        onClick={() => { setBusy(true); setError(null); void setAnnouncementPublished(announcement.id, !announcement.is_published)
                          .then(() => refresh(announcement.is_published ? "أُوقفت مشاهدته للجمهور." : "نُشر الإعلان."))
                          .catch((failure: unknown) => setError(message(failure)))
                          .finally(() => setBusy(false)); }}>
                        {announcement.is_published ? "إيقاف النشر" : "نشر"}
                      </button>
                      <button className="button secondary quick-action" type="button" disabled={busy}
                        onClick={() => { setBusy(true); setError(null); void deleteAnnouncement(announcement.id)
                          .then(() => refresh("حُذف الإعلان."))
                          .catch((failure: unknown) => setError(message(failure)))
                          .finally(() => setBusy(false)); }}>
                        حذف
                      </button>
                    </>}
                  </div>
                </div>
                <span className="notify-meta">
                  <span className="lab-tag">{announcement.is_published ? "منشور" : "مسودة"}</span>
                </span>
              </article>
            </li>;
          })}
        </ul>}
    </section>

    {circular && <CircularSheet
      announcement={circular}
      branchName={circular.branch_id ? branchNames.get(circular.branch_id) ?? "" : "كل الفروع"}
      onClose={() => setCircular(null)}
    />}
  </main>;
}