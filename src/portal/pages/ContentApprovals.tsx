import { useCallback, useEffect, useMemo, useState } from "react";
import { LabPage, LabStats, LabTabs } from "@/portal/pages/labs/LabShell";
import { useActiveBranch } from "@/portal/hooks/useActiveBranch";
import {
  loadContentItems, loadContentComments, loadContentHistory, loadReviewers,
  createContentDraft, addContentComment, assignReviewer, transitionContent,
  CONTENT_STATUS_LABELS, CONTENT_TYPE_LABELS,
  type ContentItem, type ContentStatus, type ContentType,
  type ContentComment, type ContentHistoryEntry, type ReviewerOption,
} from "@/portal/lib/contentApprovalRepository";

const transitions: Record<ContentStatus, ContentStatus[]> = {
  draft: ["submitted"],
  submitted: ["changes_requested", "approved", "rejected"],
  changes_requested: ["submitted"],
  approved: ["published", "archived"],
  rejected: ["submitted", "archived"],
  published: ["archived"],
  archived: ["draft"],
};

const statusTone: Record<ContentStatus, string> = {
  draft: "status-neutral",
  submitted: "status-warn",
  changes_requested: "status-warn",
  approved: "status-ok",
  rejected: "status-danger",
  published: "status-ok",
  archived: "status-neutral",
};

const actionLabels: Record<ContentStatus, string> = {
  draft: "إصدار مسودة معدّلة",
  submitted: "إرسال للمراجعة",
  changes_requested: "طلب تعديل",
  approved: "اعتماد",
  rejected: "رفض",
  published: "نشر",
  archived: "أرشفة",
};

const actionIcons: Record<ContentStatus, string> = {
  draft: "ri-draft-line",
  submitted: "ri-send-plane-line",
  changes_requested: "ri-edit-line",
  approved: "ri-check-line",
  rejected: "ri-close-line",
  published: "ri-global-line",
  archived: "ri-archive-line",
};

function formatDate(value: string | null): string {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export function ContentApprovals({ userId }: { userId: string | null }) {
  const { branchId } = useActiveBranch();
  const [items, setItems] = useState<ContentItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tab, setTab] = useState<"queue" | "mine" | "history">("queue");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [comments, setComments] = useState<ContentComment[]>([]);
  const [history, setHistory] = useState<ContentHistoryEntry[]>([]);
  const [reviewers, setReviewers] = useState<ReviewerOption[]>([]);
  const [comment, setComment] = useState("");
  const [actionError, setActionError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [filter, setFilter] = useState<ContentStatus | "all">("all");
  const [showCreate, setShowCreate] = useState(false);
  const [draftTitle, setDraftTitle] = useState("");
  const [draftType, setDraftType] = useState<ContentType>("lesson");

  const selected = items.find((item) => item.id === selectedId) ?? null;

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const rows = await loadContentItems();
      setItems(rows);
      setSelectedId((current) => current ?? rows[0]?.id ?? null);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  useEffect(() => {
    let cancelled = false;
    loadReviewers()
      .then((rows) => { if (!cancelled) setReviewers(rows); })
      .catch(() => { if (!cancelled) setReviewers([]); });
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    if (!selectedId) { setComments([]); setHistory([]); return; }
    let cancelled = false;
    Promise.all([loadContentComments(selectedId), loadContentHistory(selectedId)])
      .then(([commentRows, historyRows]) => {
        if (cancelled) return;
        setComments(commentRows);
        setHistory(historyRows);
      })
      .catch((caught) => { if (!cancelled) setActionError(caught instanceof Error ? caught.message : String(caught)); });
    return () => { cancelled = true; };
  }, [selectedId]);

  const stats = useMemo(() => ({
    review: items.filter((item) => item.status === "submitted").length,
    changes: items.filter((item) => item.status === "changes_requested").length,
    published: items.filter((item) => item.status === "published").length,
    drafts: items.filter((item) => item.status === "draft").length,
  }), [items]);

  const list = useMemo(() => {
    const base = tab === "mine" && userId ? items.filter((item) => item.author_id === userId) : items;
    return base
      .filter((item) => (filter === "all" ? true : item.status === filter))
      .sort((a, b) => b.updated_at.localeCompare(a.updated_at));
  }, [items, tab, filter, userId]);

  async function refreshSelection() {
    await load();
    if (selectedId) {
      setComments(await loadContentComments(selectedId));
      setHistory(await loadContentHistory(selectedId));
    }
  }

  async function transition(next: ContentStatus) {
    if (!selected) return;
    setActionError(null);
    setNotice(null);
    setBusy(true);
    try {
      const result = await transitionContent(selected.id, next, comment);
      setNotice(`تم التحديث إلى «${CONTENT_STATUS_LABELS[next]}» — الإصدار ${result.version}.`);
      setComment("");
      await refreshSelection();
    } catch (caught) {
      setActionError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setBusy(false);
    }
  }

  async function submitComment() {
    if (!selected || !userId) return;
    setActionError(null);
    try {
      await addContentComment(selected.id, comment, userId);
      setComment("");
      setComments(await loadContentComments(selected.id));
    } catch (caught) {
      setActionError(caught instanceof Error ? caught.message : String(caught));
    }
  }

  async function changeReviewer(reviewerId: string) {
    if (!selected) return;
    setActionError(null);
    try {
      await assignReviewer(selected.id, reviewerId || null);
      setItems((current) => current.map((row) => (row.id === selected.id ? { ...row, reviewer_id: reviewerId || null } : row)));
      setNotice("حُدِّث المراجع المعيّن.");
    } catch (caught) {
      setActionError(caught instanceof Error ? caught.message : String(caught));
    }
  }

  async function createDraft() {
    if (!userId) { setActionError("تعذّر تحديد هوية المستخدم."); return; }
    setActionError(null);
    try {
      const created = await createContentDraft(
        { title: draftTitle, titleEn: "", titleZh: "", contentType: draftType, summary: "", branchId },
        userId,
      );
      setItems((current) => [created, ...current]);
      setSelectedId(created.id);
      setDraftTitle("");
      setShowCreate(false);
      setTab("mine");
      setNotice("أُنشئت مسودة جديدة.");
    } catch (caught) {
      setActionError(caught instanceof Error ? caught.message : String(caught));
    }
  }

  const allowed = selected ? transitions[selected.status] : [];
  const reviewerName = (id: string | null) => reviewers.find((row) => row.id === id)?.full_name ?? (id ? id.slice(0, 8) : "");

  return <LabPage
    eyebrow="استوديو المحتوى"
    title="مراجعة المحتوى والاعتمادات"
    intro="دورة تحريرية دائمة: مسودة، إرسال للمراجعة، تعديلات، اعتماد، نشر وأرشفة — تُفرض الحالات على الخادم ولا يمكن تجاوزها من المتصفح."
    badge={`${stats.review} بانتظار المراجعة`}
  >
    <LabStats items={[
      { label: "بانتظار المراجعة", value: String(stats.review), detail: "تحتاج قراراً" },
      { label: "مطلوب تعديل", value: String(stats.changes), detail: "لدى المؤلفين" },
      { label: "منشور", value: String(stats.published), detail: "متاح للطلاب" },
      { label: "مسودات", value: String(stats.drafts), detail: "قيد الإعداد" },
    ]} />

    <LabTabs
      label="أقسام المراجعة"
      value={tab}
      onChange={setTab}
      tabs={[
        { id: "queue", label: "طابور المراجعة", icon: "ri-inbox-line" },
        { id: "mine", label: "محتواي", icon: "ri-draft-line" },
        { id: "history", label: "السياسة والسجل", icon: "ri-history-line" },
      ]}
    />

    {notice && <p className="notice" role="status">{notice}</p>}
    {error && <p className="error-box" role="alert">{error} <button className="button secondary" type="button" onClick={() => void load()}>إعادة المحاولة</button></p>}

    {tab !== "history" && <div className="approval-layout">
      <section className="panel approval-list-panel">
        <div className="media-toolbar">
          <select value={filter} onChange={(event) => setFilter(event.target.value as ContentStatus | "all")} aria-label="تصفية الحالة">
            <option value="all">كل الحالات</option>
            {Object.entries(CONTENT_STATUS_LABELS).map(([id, label]) => <option key={id} value={id}>{label}</option>)}
          </select>
          <button className="button secondary" type="button" onClick={() => setShowCreate((current) => !current)}>
            <i className="ri-add-line" aria-hidden="true"></i> مسودة جديدة
          </button>
        </div>

        {showCreate && <div className="approval-create">
          <label>عنوان المحتوى<input value={draftTitle} onChange={(event) => setDraftTitle(event.target.value)} placeholder="مثال: الدرس 8 — الألوان" /></label>
          <label>النوع
            <select value={draftType} onChange={(event) => setDraftType(event.target.value as ContentType)}>
              {Object.entries(CONTENT_TYPE_LABELS).map(([id, label]) => <option key={id} value={id}>{label}</option>)}
            </select>
          </label>
          <button className="button primary" type="button" onClick={() => void createDraft()}><i className="ri-save-line" aria-hidden="true"></i> إنشاء</button>
        </div>}

        {loading
          ? <p className="muted">جارٍ تحميل سجل المحتوى...</p>
          : !list.length
            ? <p className="muted">لا يوجد محتوى في هذا القسم.</p>
            : <ul className="approval-list">
              {list.map((item) => <li key={item.id}>
                <button type="button" className={`approval-item${selectedId === item.id ? " active" : ""}`} onClick={() => { setSelectedId(item.id); setActionError(null); }}>
                  <span className="approval-item-top">
                    <span className="lab-tag">{CONTENT_TYPE_LABELS[item.content_type]}</span>
                    <span className={`lab-status ${statusTone[item.status]}`}>{CONTENT_STATUS_LABELS[item.status]}</span>
                  </span>
                  <strong>{item.title}</strong>
                  <small>إصدار {item.version} · {formatDate(item.updated_at)}</small>
                </button>
              </li>)}
            </ul>}
      </section>

      <section className="panel approval-detail-panel">
        {!selected
          ? <p className="muted">اختر عنصراً من القائمة لعرض تفاصيله.</p>
          : <>
            <div className="page-heading">
              <div>
                <h2>{selected.title}</h2>
                <p className="muted">{CONTENT_TYPE_LABELS[selected.content_type]} · المؤلف {reviewerName(selected.author_id)}</p>
              </div>
              <span className={`lab-status ${statusTone[selected.status]}`}>{CONTENT_STATUS_LABELS[selected.status]}</span>
            </div>

            {actionError && <p className="error-box" role="alert">{actionError}</p>}

            <div className="approval-assign">
              <label>المراجع المعيّن
                <select value={selected.reviewer_id ?? ""} onChange={(event) => void changeReviewer(event.target.value)}>
                  <option value="">— غير معيّن —</option>
                  {reviewers.map((reviewer) => <option key={reviewer.id} value={reviewer.id}>{reviewer.full_name}</option>)}
                </select>
              </label>
            </div>

            <label className="approval-comment">ملاحظة المراجعة
              <textarea rows={3} maxLength={500} value={comment} onChange={(event) => setComment(event.target.value)} placeholder="اكتب تعليقاً أو سبب القرار..." />
            </label>

            <div className="actions approval-actions">
              {allowed.length === 0 && <span className="data-note">لا توجد إجراءات متاحة في هذه الحالة.</span>}
              {allowed.map((next) => <button
                key={next}
                type="button"
                className={`button ${next === "approved" || next === "published" ? "primary" : next === "rejected" ? "button-danger" : "secondary"}`}
                onClick={() => void transition(next)}
                disabled={busy}
              >
                <i className={actionIcons[next]} aria-hidden="true"></i>
                {actionLabels[next]}
              </button>)}
              {comment.trim() && <button className="text-button" type="button" onClick={() => void submitComment()}><i className="ri-chat-3-line" aria-hidden="true"></i> إضافة تعليق فقط</button>}
            </div>

            <h3>التعليقات</h3>
            {!comments.length
              ? <p className="muted">لا توجد تعليقات بعد.</p>
              : <ul className="approval-comments">
                {comments.map((entry) => <li key={entry.id}>
                  <div><strong>{reviewerName(entry.author_id) || "مستخدم"}</strong><small>{formatDate(entry.created_at)}</small></div>
                  <p>{entry.body}</p>
                </li>)}
              </ul>}

            <h3>سجل الحالة</h3>
            {!history.length
              ? <p className="muted">لا يوجد سجل بعد.</p>
              : <ol className="approval-history">
                {history.map((entry) => <li key={entry.id}>
                  <span className="approval-dot" aria-hidden="true"></span>
                  <div>
                    <strong>{entry.to_status ? CONTENT_STATUS_LABELS[entry.to_status] : entry.action}</strong>
                    <small>{reviewerName(entry.actor_id) || "النظام"} · {formatDate(entry.created_at)}</small>
                    {entry.note && <p>{entry.note}</p>}
                  </div>
                </li>)}
              </ol>}
          </>}
      </section>
    </div>}

    {tab === "history" && <section className="panel">
      <h2>سياسة المراجعة والنشر</h2>
      <ul className="lab-compact-list">
        <li><strong>فصل الأدوار</strong><span>المنشئ لا يعتمد محتواه؛ يرفض الخادم الاعتماد الذاتي.</span></li>
        <li><strong>حالات معتمدة</strong><span>مسودة ← مراجعة ← (تعديل أو اعتماد أو رفض) ← نشر ← أرشفة. الحالات تُفرض على الخادم.</span></li>
        <li><strong>حماية المنشور</strong><span>المنشور يُؤرشف فقط؛ تُنشأ مسودة معدّلة بإصدار جديد.</span></li>
        <li><strong>وصول الطلاب</strong><span>لا يظهر المحتوى للطلاب قبل النشر واعتماد الأهلية.</span></li>
      </ul>
      <div className="actions">
        <button className="button secondary" type="button" onClick={() => void load()}><i className="ri-refresh-line" aria-hidden="true"></i> تحديث من الخادم</button>
      </div>
    </section>}
  </LabPage>;
}