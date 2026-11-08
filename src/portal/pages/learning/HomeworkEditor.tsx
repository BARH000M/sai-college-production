import { useMemo, useState } from "react";
import {
  deleteHomework, updateHomework, type LearningHomework, type LearningScope,
} from "@/portal/lib/learning";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

function toLocalInput(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export function HomeworkEditor({
  scope, homework, onClose, onDone,
}: {
  scope: LearningScope;
  homework: LearningHomework;
  onClose: () => void;
  onDone: (notice: string) => void;
}) {
  const { workspace } = scope;
  const course = workspace.courses.find((item) => item.id === homework.course_id) ?? null;

  const [title, setTitle] = useState(homework.title);
  const [instructions, setInstructions] = useState(homework.instructions ?? "");
  const [dueAt, setDueAt] = useState(toLocalInput(homework.due_at));
  const [maxScore, setMaxScore] = useState(String(homework.max_score));
  const [isPublished, setIsPublished] = useState(homework.is_published);
  const [busy, setBusy] = useState<"save" | "delete" | "">("");
  const [error, setError] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);

  const submissionCount = useMemo(
    () => workspace.submissions.filter((row) => row.homework_id === homework.id).length,
    [workspace.submissions, homework.id],
  );

  async function save() {
    if (busy) return;
    const score = Number(maxScore);
    setBusy("save");
    setError(null);
    try {
      await updateHomework(homework.id, {
        title,
        instructions,
        dueAt,
        maxScore: Number.isFinite(score) ? Math.round(score) : 0,
        isPublished,
      });
      onDone(isPublished
        ? `حُفظ تعديل «${title.trim()}» وهو منشور للطلاب.`
        : `حُفظ تعديل «${title.trim()}» كمسودة مخفية عن الطلاب.`);
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy("");
    }
  }

  async function remove() {
    if (busy) return;
    setBusy("delete");
    setError(null);
    try {
      await deleteHomework(homework.id);
      onDone(`حُذف الواجب «${homework.title}»${submissionCount ? ` مع ${submissionCount} تسليماً مرتبطاً به` : ""}.`);
    } catch (failure) {
      setError(message(failure));
      setBusy("");
    }
  }

  return <section className="panel homework-editor">
    <div className="page-heading">
      <div>
        <h2>تعديل الواجب</h2>
        <p className="data-note">
          {course?.title ?? "مقرر غير معروف"} · {submissionCount} تسليماً مرتبطاً بهذا الواجب
        </p>
      </div>
      <button className="button secondary" type="button" onClick={onClose} disabled={!!busy}>إغلاق</button>
    </div>

    <div className="management-form learn-homework-form">
      <label>عنوان الواجب
        <input
          value={title}
          maxLength={120}
          onChange={(event) => setTitle(event.target.value)}
        />
        <small className="data-note">{title.trim().length} / 120 حرف</small>
      </label>

      <label>تعليمات الواجب
        <textarea
          rows={5}
          value={instructions}
          maxLength={500}
          placeholder="اشرح للطالب المطلوب بالمعايير التي ستُقيَّم عليها الإجابة."
          onChange={(event) => setInstructions(event.target.value)}
        />
        <small className="data-note">{instructions.trim().length} / 500 حرف</small>
      </label>

      <div className="learn-form-row">
        <label>موعد التسليم
          <input dir="ltr" type="datetime-local" value={dueAt} onChange={(event) => setDueAt(event.target.value)} />
        </label>
        <label>الدرجة العظمى
          <input
            dir="ltr"
            type="number"
            min={1}
            max={1000}
            value={maxScore}
            onChange={(event) => setMaxScore(event.target.value)}
          />
        </label>
      </div>

      <label className="learn-checkbox">
        <input type="checkbox" checked={isPublished} onChange={(event) => setIsPublished(event.target.checked)} />
        منشور للطلاب (أزل العلامة لحفظه كمسودة)
      </label>

      {error && <p className="error-box" role="alert">تعذر تنفيذ الطلب: {error}</p>}

      <div className="actions">
        <button className="button primary" type="button" disabled={!!busy} onClick={() => void save()}>
          {busy === "save" ? "جارٍ الحفظ..." : "حفظ التعديلات"}
        </button>
        <button className="button secondary" type="button" disabled={!!busy} onClick={onClose}>إلغاء</button>
      </div>

      <div className="homework-delete-zone">
        <strong>حذف الواجب نهائياً</strong>
        <p className="data-note">
          {submissionCount
            ? `سيُحذف الواجب و${submissionCount} تسليماً مرتبطاً به، وتختفي الدرجات والملاحظات من سجل الطلاب. لا يمكن التراجع.`
            : "لا توجد تسليمات على هذا الواجب. سيُحذف نهائياً ولا يمكن التراجع."}
        </p>
        {confirmDelete ? <div className="actions">
          <button className="button primary" type="button" disabled={!!busy} onClick={() => void remove()}>
            {busy === "delete" ? "جارٍ الحذف..." : "تأكيد الحذف النهائي"}
          </button>
          <button className="button secondary" type="button" disabled={!!busy} onClick={() => setConfirmDelete(false)}>
            إلغاء الحذف
          </button>
        </div> : <div className="actions">
          <button className="button secondary" type="button" disabled={!!busy} onClick={() => setConfirmDelete(true)}>
            حذف الواجب
          </button>
        </div>}
      </div>
    </div>
  </section>;
}