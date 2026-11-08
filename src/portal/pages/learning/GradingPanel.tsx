import { useEffect, useMemo, useState } from "react";
import {
  formatDate, gradeSubmission, submissionStatusLabels,
  type LearningScope,
} from "@/portal/lib/learning";
import { exportHomeworkSubmissions } from "@/portal/lib/learningExport";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

export function GradingPanel({
  scope, homeworkId, onHomeworkChange, teacherId = "", teacherName = "", pendingOnly = false, onClearFilter,
}: {
  scope: LearningScope;
  homeworkId: string;
  onHomeworkChange: (id: string) => void;
  teacherId?: string;
  teacherName?: string;
  pendingOnly?: boolean;
  onClearFilter?: () => void;
}) {
  const { workspace } = scope;

  // A teacher owns a course directly or through the class assigned to them.
  const teacherCourseIds = useMemo(() => {
    if (!teacherId) return null;
    const classIds = new Set(
      workspace.classes.filter((row) => row.teacher_id === teacherId).map((row) => row.id),
    );
    const ids = new Set<string>();
    workspace.courses.forEach((row) => {
      if (row.teacher_id === teacherId || classIds.has(row.class_id)) ids.add(row.id);
    });
    return ids;
  }, [teacherId, workspace.classes, workspace.courses]);

  const items = useMemo(() => {
    const base = workspace.homework
      .filter((row) => !teacherCourseIds || teacherCourseIds.has(row.course_id))
      .slice()
      .sort((a, b) => new Date(a.due_at).getTime() - new Date(b.due_at).getTime());
    if (!pendingOnly) return base;
    return base.filter((row) => workspace.submissions.some(
      (entry) => entry.homework_id === row.id && entry.status === "submitted",
    ));
  }, [workspace.homework, workspace.submissions, teacherCourseIds, pendingOnly]);

  const active = items.find((item) => item.id === homeworkId) ?? items[0] ?? null;
  const course = active ? workspace.courses.find((entry) => entry.id === active.course_id) ?? null : null;
  const classStudents = course
    ? workspace.students.filter((student) => student.class_id === course.class_id)
    : [];

  const rows = useMemo(() => (active
    ? workspace.submissions
        .filter((entry) => entry.homework_id === active.id)
        .filter((entry) => !pendingOnly || entry.status === "submitted")
        .map((submission) => ({
          submission,
          student: workspace.students.find((student) => student.id === submission.student_id) ?? null,
        }))
        .sort((a, b) => new Date(a.submission.submitted_at).getTime() - new Date(b.submission.submitted_at).getTime())
    : []), [active, workspace.submissions, workspace.students, pendingOnly]);

  const [selectedId, setSelectedId] = useState("");
  const selectedRow = rows.find((row) => row.submission.id === selectedId) ?? rows[0] ?? null;
  const submission = selectedRow?.submission ?? null;

  const [score, setScore] = useState("");
  const [feedback, setFeedback] = useState("");
  const [saving, setSaving] = useState<"graded" | "returned" | "">("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const currentId = submission?.id ?? "";
  const currentScore = submission?.score ?? null;
  const currentFeedback = submission?.feedback ?? null;

  useEffect(() => {
    setScore(currentScore === null ? "" : String(currentScore));
    setFeedback(currentFeedback ?? "");
    setError(null);
    setNotice(null);
  }, [currentId, currentScore, currentFeedback]);

  const gradedCount = rows.filter((row) => row.submission.status === "graded").length;
  const pendingCount = rows.filter((row) => row.submission.status !== "graded").length;

  async function save(status: "graded" | "returned") {
    if (!submission || !active || saving) return;
    const parsed = score.trim() === "" ? null : Number(score);
    setSaving(status);
    setError(null);
    setNotice(null);
    try {
      await gradeSubmission({
        submissionId: submission.id,
        score: parsed,
        feedback,
        status,
        maxScore: active.max_score,
      });
      setNotice(status === "graded"
        ? `حُفظ تقييم ${selectedRow?.student?.full_name ?? "الطالب"} وأصبحت الدرجة والملاحظات ظاهرة له.`
        : `أُعيد الواجب إلى ${selectedRow?.student?.full_name ?? "الطالب"} مع الملاحظات.`);
      scope.reload();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving("");
    }
  }

  function handleExport() {
    if (!active) return;
    try {
      const result = exportHomeworkSubmissions(scope, active);
      setError(null);
      setNotice(`صُدِّر سجل «${active.title}» (${result.students} طالباً · ${result.submitted} تسليماً · ${result.graded} مصحّحاً) إلى ملف ${result.fileName}.`);
    } catch (failure) {
      setNotice(null);
      setError(message(failure));
    }
  }

  if (!items.length) {
    return <section className="panel learn-empty">
      <h2>{teacherId ? "لا توجد تسليمات بانتظار التصحيح" : "لا توجد واجبات للتصحيح"}</h2>
      <p className="muted">{teacherId
        ? `لا توجد تسليمات غير مصححة لدى ${teacherName || "هذا المعلم"} حالياً.`
        : "لم تُسجَّل واجبات في المقررات المتاحة لدورك بعد."}</p>
      {teacherId && onClearFilter && <button className="button secondary" type="button" onClick={onClearFilter}>
        عرض كل الواجبات
      </button>}
    </section>;
  }

  return <section className="panel">
    <div className="page-heading">
      <div>
        <h2>تصحيح الواجبات وإرسال الملاحظات</h2>
        <p className="data-note">تصلك تسليمات طلبة صفوفك فقط. الدرجة والملاحظات تظهر للطالب فور الحفظ.</p>
      </div>
      <div className="actions">
        <button className="button secondary" type="button" onClick={handleExport}>تصدير CSV</button>
        <span className="learn-pill">{pendingCount} بانتظار التصحيح</span>
      </div>
    </div>

    <fieldset className="context-card">
      <label>الواجب
        <select
          value={active?.id ?? ""}
          onChange={(event) => { setSelectedId(""); onHomeworkChange(event.target.value); }}
        >
          {items.map((item) => <option key={item.id} value={item.id}>{item.title}</option>)}
        </select>
      </label>
      <label>المقرر
        <input value={course?.title ?? "—"} readOnly />
      </label>
      <label>الدرجة العظمى
        <input value={active?.max_score ?? 0} readOnly />
      </label>
    </fieldset>

    {teacherId && <p className="notice grading-filter-note">
      <span><i className="ri-filter-3-line" aria-hidden="true" /> عرض مقيّد على تسليمات {teacherName || "المعلم"}{pendingOnly ? " بانتظار التصحيح فقط" : ""}</span>
      {onClearFilter && <button className="text-button" type="button" onClick={onClearFilter}>إلغاء التصفية</button>}
    </p>}

    {notice && <p className="success-box" role="status">{notice}</p>}
    {error && <p className="error-box" role="alert">تعذر الحفظ: {error}</p>}

    <p className="data-note">
      {rows.length} تسليماً من {classStudents.length} طالباً · {gradedCount} مصحّح · التسليم قبل {active ? formatDate(active.due_at, true) : "—"}
    </p>

    {!rows.length && <p className="muted">{pendingOnly
      ? "لا توجد تسليمات بانتظار التصحيح على هذا الواجب."
      : "لم يسلّم أي طالب هذا الواجب بعد؛ سيظهر هنا فور وصول أول تسليم."}</p>}

    {!!rows.length && <div className="grade-layout">
      <div className="grade-list">
        {rows.map(({ submission: row, student }) => <button
          key={row.id}
          type="button"
          className={`grade-item ${row.id === submission?.id ? "active" : ""}`}
          onClick={() => setSelectedId(row.id)}
        >
          <strong>{student?.full_name ?? "طالب غير معروف"}</strong>
          <small className="learn-meta">{student?.admission_no ?? "—"} · {formatDate(row.submitted_at, true)}</small>
          <span className={`learn-pill ${row.status === "graded" ? "learn-status-completed" : row.status === "returned" ? "learn-status-in_progress" : ""}`}>
            {submissionStatusLabels[row.status]}
          </span>
          <small className="learn-meta">
            {row.score === null ? "بدون درجة" : `${row.score} / ${active?.max_score ?? 0}`}
          </small>
        </button>)}
      </div>

      {submission && active && <div className="grade-form">
        <h3>{selectedRow?.student?.full_name ?? "الطالب"}</h3>
        <p className="learn-answer" dir="auto">
          {submission.content && submission.content.trim()
            ? submission.content
            : "لم يُرفق الطالب نصاً مع التسليم."}
        </p>
        <p className="data-note">سُلّم في {formatDate(submission.submitted_at, true)} · الدرجة العظمى {active.max_score}</p>

        <label>الدرجة
          <input
            type="number"
            min={0}
            max={active.max_score}
            inputMode="numeric"
            value={score}
            placeholder={`من ٠ إلى ${active.max_score}`}
            onChange={(event) => setScore(event.target.value)}
          />
        </label>

        <label>ملاحظات للطالب
          <textarea
            rows={5}
            maxLength={500}
            value={feedback}
            placeholder="اكتب ملاحظة واضحة تساعد الطالب على التحسن."
            onChange={(event) => setFeedback(event.target.value)}
          />
          <small className="data-note">{feedback.trim().length} / 500 حرف</small>
        </label>

        {error && <p className="error-box" role="alert">{error}</p>}

        <div className="actions">
          <button
            type="button"
            className="button primary"
            disabled={!!saving}
            onClick={() => void save("graded")}
          >{saving === "graded" ? "جارٍ الحفظ..." : "حفظ الدرجة والملاحظات"}</button>
          <button
            type="button"
            className="button secondary"
            disabled={!!saving}
            onClick={() => void save("returned")}
          >{saving === "returned" ? "جارٍ الإرجاع..." : "إعادة للمراجعة"}</button>
        </div>
        <p className="data-note">إعادة الواجب تتيح للطالب التسليم من جديد، وتُمسح الدرجة السابقة.</p>
      </div>}
    </div>}
  </section>;
}