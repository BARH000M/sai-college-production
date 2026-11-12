import { useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import {
  daysUntil, formatDate, setHomeworkPublished, submissionStatusLabels, submitHomework,
  type LearningHomework, type LearningScope,
} from "@/portal/lib/learning";
import {
  buildLearningNotifications, isUnreadGrade, isUnreadHomework,
} from "@/portal/lib/learningNotifications";
import { GradingPanel } from "@/portal/pages/learning/GradingPanel";
import { HomeworkComposer } from "@/portal/pages/learning/HomeworkComposer";
import { HomeworkEditor } from "@/portal/pages/learning/HomeworkEditor";
import { exportCourseGrades, exportHomeworkSubmissions } from "@/portal/lib/learningExport";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

export function HomeworkView({ scope, seenAt }: { scope: LearningScope; seenAt: string | null | undefined }) {
  const { workspace, mode, learnerId, canSubmit } = scope;
  const learner = workspace.students.find((student) => student.id === learnerId) ?? null;
  const [selectedId, setSelectedId] = useState("");
  const [gradingHomeworkId, setGradingHomeworkId] = useState("");
  const [editingId, setEditingId] = useState("");
  const [publishingId, setPublishingId] = useState("");
  const [content, setContent] = useState("");
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [exportCourseId, setExportCourseId] = useState("");

  const [searchParams, setSearchParams] = useSearchParams();
  const teacherFilterId = searchParams.get("teacher") ?? "";
  const teacherFilterName = searchParams.get("name") ?? "";
  const pendingOnly = searchParams.get("pending") === "1";
  const gradingRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!teacherFilterId) return;
    const node = gradingRef.current;
    if (node) node.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [teacherFilterId]);

  function clearTeacherFilter() {
    const next = new URLSearchParams(searchParams);
    next.delete("teacher");
    next.delete("pending");
    next.delete("name");
    setSearchParams(next, { replace: true });
  }

  const courses = useMemo(() => (mode === "staff"
    ? workspace.courses
    : workspace.courses.filter((course) => course.class_id === learner?.class_id)), [mode, workspace.courses, learner?.class_id]);

  const courseIds = useMemo(() => new Set(courses.map((course) => course.id)), [courses]);

  const items = useMemo(() => workspace.homework
    .filter((item) => courseIds.has(item.course_id))
    .slice()
    .sort((a, b) => new Date(a.due_at).getTime() - new Date(b.due_at).getTime()), [workspace.homework, courseIds]);

  const selected = items.find((item) => item.id === selectedId) ?? null;
  const editing = items.find((item) => item.id === editingId) ?? null;
  const submission = selected
    ? workspace.submissions.find((row) => row.homework_id === selected.id && row.student_id === learnerId) ?? null
    : null;
  const selectedCourse = selected ? workspace.courses.find((course) => course.id === selected.course_id) ?? null : null;

  const notifications = useMemo(() => {
    if (mode !== "learner" || !learner || seenAt === undefined) return [];
    return buildLearningNotifications(
      items,
      workspace.submissions.filter((row) => row.student_id === learner.id),
      [learner.id],
      seenAt,
    );
  }, [mode, learner, items, workspace.submissions, seenAt]);

  useEffect(() => {
    const current = items.find((item) => item.id === selectedId);
    if (!current) return;
    const existing = workspace.submissions.find((row) => row.homework_id === current.id && row.student_id === learnerId);
    setContent(existing?.content ?? "");
    setNotice(null);
    setError(null);
  }, [selectedId, items, workspace.submissions, learnerId]);

  function submissionCounts(homeworkId: string) {
    const course = workspace.homework.find((item) => item.id === homeworkId);
    const classStudents = course
      ? workspace.students.filter((student) => student.class_id === courses.find((entry) => entry.id === course.course_id)?.class_id)
      : [];
    const rows = workspace.submissions.filter((entry) => entry.homework_id === homeworkId);
    const graded = rows.filter((entry) => entry.status === "graded" && entry.score !== null);
    const average = graded.length && course && course.max_score > 0
      ? Math.round(graded.reduce((total, entry) => total + (entry.score ?? 0), 0) / graded.length / course.max_score * 100)
      : null;
    return { expected: classStudents.length, submitted: rows.length, graded: graded.length, average };
  }

  async function handleSubmit() {
    if (!selected || !learner || !canSubmit || saving) return;
    setSaving(true); setError(null); setNotice(null);
    try {
      await submitHomework(selected.id, learner.id, content);
      setNotice("تم تسليم الواجب وحفظه.");
      scope.reload();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  function handleExport(item: LearningHomework) {
    try {
      const result = exportHomeworkSubmissions(scope, item);
      setError(null);
      setNotice(`صُدِّر سجل «${item.title}» (${result.students} طالباً · ${result.submitted} تسليماً · ${result.graded} مصحّحاً) إلى ملف ${result.fileName}.`);
    } catch (failure) {
      setNotice(null);
      setError(message(failure));
    }
  }

  const exportCourse = courses.find((course) => course.id === exportCourseId) ?? courses[0] ?? null;
  const exportCourseHomework = exportCourse
    ? workspace.homework.filter((item) => item.course_id === exportCourse.id).length
    : 0;
  const exportCourseStudents = exportCourse
    ? workspace.students.filter((student) => student.class_id === exportCourse.class_id).length
    : 0;

  function handleCourseExport() {
    if (!exportCourse) return;
    try {
      const result = exportCourseGrades(scope, exportCourse.id);
      setError(null);
      setNotice(`صُدِّر مقرر «${exportCourse.title}» كاملاً: ${result.homeworks} واجباً · ${result.students} طالباً · ${result.graded} درجة مصححة في ملف ${result.fileName}.`);
    } catch (failure) {
      setNotice(null);
      setError(message(failure));
    }
  }

  async function togglePublish(item: LearningHomework) {
    if (publishingId) return;
    setPublishingId(item.id);
    setError(null);
    setNotice(null);
    try {
      await setHomeworkPublished(item.id, !item.is_published);
      setNotice(item.is_published
        ? `أصبح «${item.title}» مسودة مخفية عن الطلاب.`
        : `نُشر «${item.title}» وظهر لطلاب الصف مع إشعار جديد.`);
      scope.reload();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setPublishingId("");
    }
  }

  if (!items.length) {
    return <>
      {mode === "staff" && <HomeworkComposer scope={scope} onCreated={scope.reload} />}
      <section className="panel learn-empty">
        <h2>لا توجد واجبات حالياً</h2>
        <p className="muted">{mode === "staff"
          ? "لم تُسجَّل واجبات في المقررات المتاحة لدورك. استخدم نموذج الإنشاء أعلاه لنشر أول واجب."
          : "لم يُسجَّل واجب لمقررات صفك بعد. سيظهر هنا فور إضافته من المعلم."}</p>
      </section>
    </>;
  }

  return <>
    {mode === "staff" && <HomeworkComposer scope={scope} onCreated={scope.reload} />}

    {notice && <p className="success-box" role="status">{notice}</p>}
    {error && <p className="error-box" role="alert">تعذر تنفيذ الطلب: {error}</p>}

    {mode === "learner" && !!notifications.length && <section className="panel learn-notify">
      <div className="learn-notify-head">
        <h2>تحديثات جديدة</h2>
        <span className="learn-pill learn-new">{notifications.length} جديد</span>
      </div>
      <ul className="learn-notify-list">
        {notifications.map((item) => <li key={item.id} className="learn-notify-item">
          <span className="learn-notify-icon" aria-hidden="true">{item.kind === "grade" ? "✓" : "✎"}</span>
          <div className="learn-notify-body">
            <strong>{item.title}</strong>
            <small>{item.detail}</small>
          </div>
          <button
            className="button secondary"
            type="button"
            onClick={() => {
              setSelectedId(item.homeworkId);
              window.scrollTo({ top: 0, behavior: "smooth" });
            }}
          >عرض</button>
        </li>)}
      </ul>
      <p className="data-note">تُحتسب التحديثات منذ آخر زيارة لصفحة الواجبات.</p>
    </section>}

    <section className="panel">
      <h2>{mode === "staff" ? "الواجبات ومتابعة التسليم" : "واجباتي"}</h2>
      <p className="data-note">{mode === "staff"
        ? "يمكنك تعديل أي واجب أو تحويله إلى مسودة أو حذفه. المسودات لا تظهر للطلاب."
        : "يعرض الجدول مواعيد التسليم وحالة كل واجب. اختر واجباً لعرض تفاصيله."}</p>

      {mode === "staff" && !!courses.length && <fieldset className="context-card">
        <label>تصدير مقرر كامل
          <select
            value={exportCourse?.id ?? ""}
            onChange={(event) => setExportCourseId(event.target.value)}
          >
            {courses.map((course) => <option key={course.id} value={course.id}>{course.title}</option>)}
          </select>
        </label>
        <label>محتوى الملف
          <input readOnly value={`${exportCourseHomework} واجباً · ${exportCourseStudents} طالباً`} />
        </label>
        <label>ملاحظة
          <input readOnly value="كل واجبات المقرر في ملف CSV واحد" />
        </label>
        <div className="actions">
          <button className="button secondary" type="button" onClick={handleCourseExport} disabled={!exportCourseHomework}>
            تصدير درجات المقرر
          </button>
        </div>
      </fieldset>}

      <div className="table-scroll">
        <table className="management-table">
          <thead><tr>
            <th>الواجب</th><th>المقرر</th><th>تاريخ التسليم</th>
            {mode === "staff"
              ? <><th>التسليمات</th><th>المتوسط</th><th>الإدارة</th></>
              : <><th>الحالة</th><th>الدرجة</th><th>التفاصيل</th></>}
          </tr></thead>
          <tbody>
            {items.map((item) => {
              const row = workspace.submissions.find((entry) => entry.homework_id === item.id && entry.student_id === learnerId);
              const course = workspace.courses.find((entry) => entry.id === item.course_id);
              const overdue = daysUntil(item.due_at) < 0;
              if (mode === "staff") {
                const counts = submissionCounts(item.id);
                return <tr key={item.id}>
                  <td>
                    {item.title}
                    <span className={`learn-pill ${item.is_published ? "learn-status-completed" : ""}`}>
                      {item.is_published ? "منشور" : "مسودة"}
                    </span>
                  </td>
                  <td>{course?.title ?? "—"}</td>
                  <td>{formatDate(item.due_at, true)}{overdue ? " · انتهت" : ""}</td>
                  <td>{counts.submitted} / {counts.expected}</td>
                  <td>{counts.average === null ? "—" : `${counts.average}%`}</td>
                  <td>
                    <div className="homework-admin">
                      <button className="button secondary" type="button" onClick={() => setEditingId(item.id)}>تعديل</button>
                      <button
                        className="button secondary"
                        type="button"
                        disabled={publishingId === item.id}
                        onClick={() => void togglePublish(item)}
                      >{publishingId === item.id ? "..." : item.is_published ? "إلى مسودة" : "نشر"}</button>
                      <button className="button secondary" type="button" onClick={() => setGradingHomeworkId(item.id)}>تصحيح</button>
                      <button className="button secondary" type="button" onClick={() => handleExport(item)}>تصدير CSV</button>
                    </div>
                  </td>
                </tr>;
              }
              const status = row ? submissionStatusLabels[row.status] : "لم يُسلَّم";
              const unreadHomework = seenAt !== undefined && isUnreadHomework(item, seenAt);
              const unreadGrade = seenAt !== undefined && row ? isUnreadGrade(row, seenAt) : false;
              return <tr key={item.id}>
                <td>
                  {item.title}
                  {(unreadHomework || unreadGrade) && <span className="learn-pill learn-new">
                    {unreadGrade ? "درجة جديدة" : "جديد"}
                  </span>}
                </td>
                <td>{course?.title ?? "—"}</td>
                <td>{formatDate(item.due_at, true)}{overdue && !row ? " · متأخر" : ""}</td>
                <td>{status}</td>
                <td>{row?.score === null || row?.score === undefined ? "—" : `${row.score} / ${item.max_score}`}</td>
                <td><button className="button secondary" type="button" onClick={() => setSelectedId(item.id)}>عرض</button></td>
              </tr>;
            })}
          </tbody>
        </table>
      </div>
    </section>

    {editing && mode === "staff" && <HomeworkEditor
      key={editing.id}
      scope={scope}
      homework={editing}
      onClose={() => setEditingId("")}
      onDone={(text) => {
        setEditingId("");
        setNotice(text);
        setError(null);
        scope.reload();
      }}
    />}

    {selected && mode !== "staff" && <section className="panel management-detail">
      <div className="page-heading">
        <div>
          <h2>{selected.title}</h2>
          <p className="muted">{selectedCourse?.title ?? "—"} · التسليم قبل {formatDate(selected.due_at, true)} · الدرجة العظمى {selected.max_score}</p>
        </div>
        <button className="button secondary" type="button" onClick={() => setSelectedId("")}>إغلاق</button>
      </div>
      {selected.instructions && <p>{selected.instructions}</p>}
      {submission && <div className="learn-feedback">
        <strong>{submissionStatusLabels[submission.status]}</strong>
        <p className="data-note">سُلّم في {formatDate(submission.submitted_at, true)}</p>
        {submission.status === "graded" && <>
          <p>الدرجة: {submission.score === null ? "غير متاحة" : `${submission.score} من ${selected.max_score}`}</p>
          {submission.feedback && <p className="muted">ملاحظات المعلم: {submission.feedback}</p>}
        </>}
        {submission.content && <p className="learn-answer">{submission.content}</p>}
      </div>}

      {!canSubmit && <p className="notice">حساب ولي الأمر للقراءة فقط؛ لا يمكن تسليم الواجب من هذا الحساب.</p>}

      {canSubmit && submission?.status !== "graded" && <div className="learn-submit">
        <label htmlFor="homework-answer">إجابتك
          <textarea
            id="homework-answer"
            value={content}
            maxLength={500}
            rows={6}
            placeholder="اكتب إجابتك هنا (١٠ أحرف على الأقل)..."
            onChange={(event) => setContent(event.target.value)}
          />
        </label>
        <div className="actions">
          <button className="button primary" type="button" disabled={saving || content.trim().length < 10} onClick={() => void handleSubmit()}>
            {saving ? "جارٍ التسليم..." : submission ? "إعادة التسليم" : "تسليم الواجب"}
          </button>
          <span className="data-note">{content.trim().length} / 500 حرف</span>
        </div>
      </div>}

      {canSubmit && submission?.status === "graded" && <p className="data-note">تم تصحيح هذا الواجب، ولا يمكن إعادة تسليمه.</p>}
    </section>}

    {mode === "staff" && <div ref={gradingRef}>
      <GradingPanel
        scope={scope}
        homeworkId={gradingHomeworkId}
        onHomeworkChange={setGradingHomeworkId}
        teacherId={teacherFilterId}
        teacherName={teacherFilterName}
        pendingOnly={pendingOnly}
        onClearFilter={teacherFilterId ? clearTeacherFilter : undefined}
      />
    </div>}
  </>;
}