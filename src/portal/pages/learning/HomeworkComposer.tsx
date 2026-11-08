import { useMemo, useState } from "react";
import { createHomework, type LearningScope } from "@/portal/lib/learning";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

function defaultDue(): string {
  const date = new Date();
  date.setDate(date.getDate() + 7);
  date.setHours(18, 0, 0, 0);
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export function HomeworkComposer({
  scope, onCreated,
}: {
  scope: LearningScope;
  onCreated: () => void;
}) {
  const { workspace } = scope;
  const [open, setOpen] = useState(false);
  const [courseId, setCourseId] = useState("");
  const [title, setTitle] = useState("");
  const [instructions, setInstructions] = useState("");
  const [dueAt, setDueAt] = useState(defaultDue);
  const [maxScore, setMaxScore] = useState("100");
  const [isPublished, setIsPublished] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const courses = useMemo(
    () => workspace.courses.slice().sort((a, b) => a.title.localeCompare(b.title, "ar")),
    [workspace.courses],
  );

  const activeCourseId = courseId || courses[0]?.id || "";
  const classOfCourse = (id: string) => {
    const course = workspace.courses.find((item) => item.id === id);
    return course ? workspace.classes.find((item) => item.id === course.class_id) ?? null : null;
  };

  function reset() {
    setTitle("");
    setInstructions("");
    setDueAt(defaultDue());
    setMaxScore("100");
    setIsPublished(true);
    setError(null);
  }

  async function submit() {
    if (busy) return;
    const score = Number(maxScore);
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await createHomework({
        courseId: activeCourseId,
        title,
        instructions,
        dueAt,
        maxScore: Number.isFinite(score) ? Math.round(score) : 0,
        isPublished,
      });
      setNotice(`نُشر الواجب «${title.trim()}» ${isPublished ? "وظهر للطلاب" : "كمسودة غير منشورة"}.`);
      reset();
      onCreated();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  if (!courses.length) {
    return <section className="panel">
      <h2>إنشاء واجب جديد</h2>
      <p className="muted">لا توجد مقررات متاحة لدورك، لذا لا يمكن نشر واجبات الآن.</p>
    </section>;
  }

  return <section className="panel">
    <div className="page-heading">
      <div>
        <h2>إنشاء واجب جديد</h2>
        <p className="data-note">
          يُنشر الواجب فوراً على طلاب الصف المرتبط بالمقرر، ويظهر في صفحتهم مع موعد التسليم والدرجة العظمى.
        </p>
      </div>
      <button className="button primary" type="button" onClick={() => { setOpen(!open); setError(null); }}>
        {open ? "إخفاء النموذج" : "واجب جديد"}
      </button>
    </div>

    {notice && <p className="success-box" role="status">{notice}</p>}

    {open && <div className="management-form learn-homework-form">
      <label>المقرر
        <select value={activeCourseId} onChange={(event) => setCourseId(event.target.value)}>
          {courses.map((course) => {
            const cls = classOfCourse(course.id);
            return <option key={course.id} value={course.id}>
              {course.title}{cls ? ` — ${cls.name}` : ""}
            </option>;
          })}
        </select>
      </label>

      <label>عنوان الواجب
        <input
          value={title}
          maxLength={120}
          placeholder="مثال: تحليل نص قصير عن العادات اليومية"
          onChange={(event) => setTitle(event.target.value)}
        />
        <small className="data-note">{title.trim().length} / 120 حرف</small>
      </label>

      <label>تعليمات الواجب
        <textarea
          rows={5}
          value={instructions}
          maxLength={500}
          placeholder="اشرح للطالب المطلوب بالضبط، والمعايير التي ستُقيَّم عليها الإجابة."
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
        نشر الواجب للطلاب مباشرة
      </label>

      {error && <p className="error-box" role="alert">تعذر نشر الواجب: {error}</p>}

      <div className="actions">
        <button className="button primary" type="button" disabled={busy} onClick={() => void submit()}>
          {busy ? "جارٍ النشر..." : "نشر الواجب"}
        </button>
        <button className="button secondary" type="button" disabled={busy} onClick={() => { reset(); setOpen(false); }}>
          إلغاء
        </button>
      </div>
    </div>}
  </section>;
}