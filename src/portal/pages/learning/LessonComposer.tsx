import { useState } from "react";
import {
  createLesson, lessonKindLabels, lessonKinds, updateLesson,
  type LearningCourse, type LearningLesson, type LessonKind,
} from "@/portal/lib/learning";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

const emptyForm = { title: "", summary: "", kind: "lesson" as LessonKind, duration: "45", published: true };

/**
 * Teacher-facing lesson management for one course: create new lessons and
 * edit the basics of existing ones. Teaching content, media and vocabulary
 * stay in their dedicated panels; RLS limits every write to course managers.
 */
export function LessonComposer({
  course, lessons, onSaved,
}: {
  course: LearningCourse;
  lessons: readonly LearningLesson[];
  onSaved: () => void;
}) {
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<LearningLesson | null>(null);
  const [form, setForm] = useState(emptyForm);
  const [position, setPosition] = useState("1");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  function startCreate() {
    setEditing(null);
    setForm(emptyForm);
    setPosition(String((lessons[lessons.length - 1]?.position ?? 0) + 1));
    setError(null);
    setNotice(null);
    setOpen(true);
  }

  function startEdit(lesson: LearningLesson) {
    setEditing(lesson);
    setForm({
      title: lesson.title,
      summary: lesson.summary ?? "",
      kind: (lessonKinds as readonly string[]).includes(lesson.kind) ? lesson.kind as LessonKind : "lesson",
      duration: String(lesson.duration_minutes),
      published: lesson.is_published,
    });
    setPosition(String(lesson.position));
    setError(null);
    setNotice(null);
    setOpen(true);
  }

  async function submit() {
    if (busy) return;
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      const input = {
        courseId: course.id,
        title: form.title,
        summary: form.summary,
        kind: form.kind,
        durationMinutes: Number(form.duration),
        isPublished: form.published,
      };
      if (editing) {
        await updateLesson(editing.id, input, Number(position));
        setNotice(`حُفظ تعديل الدرس «${form.title.trim()}».`);
      } else {
        await createLesson(input);
        setNotice(`أُضيف الدرس «${form.title.trim()}» ${form.published ? "ونُشر للطلاب" : "كمسودة غير منشورة"}.`);
      }
      setOpen(false);
      setEditing(null);
      setForm(emptyForm);
      onSaved();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  return <section className="panel management-detail" aria-label="إدارة دروس المقرر">
    <div className="page-heading">
      <div>
        <h2>إدارة الدروس</h2>
        <p className="muted">أضف دروساً للمقرر أو عدّل عناوينها وترتيبها ونشرها. المحتوى والوسائط تُدار من داخل كل درس.</p>
      </div>
      <div className="actions">
        <button type="button" className="button primary" disabled={busy || open} onClick={startCreate}>
          <i className="ri-add-line" aria-hidden="true"></i> إضافة درس
        </button>
      </div>
    </div>

    {notice && <p className="success-box" role="status">{notice}</p>}

    {!lessons.length
      ? <p className="muted">لم تُضف دروس لهذا المقرر بعد.</p>
      : <ul className="learn-lesson-manage">
        {lessons.map((lesson) => <li key={lesson.id}>
          <span>{lesson.position}. {lesson.title} <small className="learn-meta">{lessonKindLabels[lesson.kind] ?? lesson.kind} · {lesson.is_published ? "منشور" : "مسودة"}</small></span>
          <button type="button" className="text-button" disabled={busy} onClick={() => startEdit(lesson)}>تعديل</button>
        </li>)}
      </ul>}

    {open && <form className="management-form" onSubmit={(event) => { event.preventDefault(); void submit(); }}>
      <label>عنوان الدرس<span className="vocab-required"> *</span>
        <input required value={form.title} onChange={(event) => setForm({ ...form, title: event.target.value })} />
      </label>
      <label>ملخص الدرس
        <input value={form.summary} onChange={(event) => setForm({ ...form, summary: event.target.value })} />
      </label>
      <label>نوع الدرس
        <select value={form.kind} onChange={(event) => {
          if ((lessonKinds as readonly string[]).includes(event.target.value)) {
            setForm({ ...form, kind: event.target.value as LessonKind });
          }
        }}>
          {lessonKinds.map((kind) => <option key={kind} value={kind}>{lessonKindLabels[kind]}</option>)}
        </select>
      </label>
      <label>المدة بالدقائق
        <input required type="number" min="1" max="600" step="1" value={form.duration}
          onChange={(event) => setForm({ ...form, duration: event.target.value })} />
      </label>
      {editing && <label>الترتيب
        <input required type="number" min="1" max="500" step="1" value={position}
          onChange={(event) => setPosition(event.target.value)} />
      </label>}
      <label>النشر
        <select value={form.published ? "yes" : "no"}
          onChange={(event) => setForm({ ...form, published: event.target.value === "yes" })}>
          <option value="yes">منشور للطلاب</option>
          <option value="no">مسودة مخفية</option>
        </select>
      </label>
      {error && <p className="error-box" role="alert">{error}</p>}
      <div className="actions">
        <button className="button primary" disabled={busy}>{busy ? "جارٍ الحفظ..." : editing ? "حفظ التعديل" : "إضافة الدرس"}</button>
        <button type="button" className="button secondary" disabled={busy} onClick={() => { setOpen(false); setEditing(null); }}>إلغاء</button>
      </div>
    </form>}
  </section>;
}
