import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  daysUntil, formatDate, loadLearningWorkspace, submissionStatusLabels, summarizeProgress,
  type LearningWorkspace,
} from "@/portal/lib/learning";

type State =
  | { status: "loading"; data: null; error: null }
  | { status: "ready"; data: LearningWorkspace; error: null }
  | { status: "error"; data: null; error: string };

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

/**
 * Home screen for students and parents.
 *
 * Staff land on the administrative dashboard, but a learner account has nothing to
 * do there. This view gathers the pieces a learner actually needs on arrival: their
 * courses, the homework still due, and the grades already released.
 */
export function LearnerHome({ roles }: { roles: readonly string[] }) {
  const isStudent = roles.includes("student");
  const [state, setState] = useState<State>({ status: "loading", data: null, error: null });
  const [version, setVersion] = useState(0);
  const [learnerId, setLearnerId] = useState("");

  useEffect(() => {
    let active = true;
    setState({ status: "loading", data: null, error: null });
    loadLearningWorkspace()
      .then((data) => { if (active) setState({ status: "ready", data, error: null }); })
      .catch((error: unknown) => { if (active) setState({ status: "error", data: null, error: message(error) }); });
    return () => { active = false; };
  }, [version]);

  const workspace = state.status === "ready" ? state.data : null;
  const students = workspace?.students ?? [];

  useEffect(() => {
    if (!students.length) {
      setLearnerId("");
      return;
    }
    setLearnerId((current) => (students.some((student) => student.id === current) ? current : students[0].id));
  }, [students]);

  const learner = students.find((student) => student.id === learnerId) ?? null;
  const learnerClass = learner
    ? workspace?.classes.find((item) => item.id === learner.class_id) ?? null
    : null;

  const courses = useMemo(() => {
    if (!workspace || !learner) return [];
    return workspace.courses
      .filter((course) => course.class_id === learner.class_id)
      .slice()
      .sort((a, b) => a.title.localeCompare(b.title));
  }, [workspace, learner]);

  const courseRows = useMemo(() => {
    if (!workspace || !learner) return [];
    return courses.map((course) => {
      const lessons = workspace.lessons
        .filter((lesson) => lesson.course_id === course.id)
        .sort((a, b) => a.position - b.position);
      const summary = summarizeProgress(lessons, workspace.progress, learner.id);
      const homeworkCount = workspace.homework.filter((item) => item.course_id === course.id).length;
      return { course, lessonCount: lessons.length, homeworkCount, summary };
    });
  }, [workspace, learner, courses]);

  const homeworkRows = useMemo(() => {
    if (!workspace || !learner) return [];
    const courseIds = new Set(courses.map((course) => course.id));
    return workspace.homework
      .filter((item) => courseIds.has(item.course_id) && item.is_published)
      .map((item) => ({
        item,
        course: workspace.courses.find((course) => course.id === item.course_id) ?? null,
        submission: workspace.submissions.find(
          (row) => row.homework_id === item.id && row.student_id === learner.id,
        ) ?? null,
      }))
      .sort((a, b) => new Date(a.item.due_at).getTime() - new Date(b.item.due_at).getTime());
  }, [workspace, learner, courses]);

  const pending = homeworkRows.filter(
    (row) => !row.submission || row.submission.status !== "graded",
  );
  const upcoming = pending.slice(0, 6);
  const gradedRows = homeworkRows
    .filter((row) => row.submission?.status === "graded" && row.submission.score !== null)
    .sort((a, b) => new Date(b.submission?.graded_at ?? 0).getTime() - new Date(a.submission?.graded_at ?? 0).getTime())
    .slice(0, 6);

  const gradedScores = gradedRows.map((row) => row.submission?.score ?? 0);
  const average = gradedScores.length
    ? Math.round(gradedScores.reduce((total, score) => total + score, 0) / gradedScores.length)
    : null;

  const overall = useMemo(() => {
    if (!workspace || !learner) return { total: 0, completed: 0, inProgress: 0, percent: 0 };
    const courseIds = new Set(courses.map((course) => course.id));
    const lessons = workspace.lessons.filter((lesson) => courseIds.has(lesson.course_id));
    return summarizeProgress(lessons, workspace.progress, learner.id);
  }, [workspace, learner, courses]);

  const reload = () => setVersion((value) => value + 1);

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">{isStudent ? "بوابة الطالب" : "بوابة ولي الأمر"}</p>
        <h1>لوحتي التعليمية</h1>
        <p className="muted">
          {isStudent
            ? "مقرراتك، واجباتك المستحقة، ودرجاتك في مكان واحد."
            : "تابع مقررات ابنك وواجباته ودرجاته دون الحاجة إلى حسابه."}
        </p>
      </div>
      <button className="button secondary" onClick={reload} disabled={state.status === "loading"}>تحديث</button>
    </div>

    {state.status === "loading" && <p role="status">جارٍ تحميل بياناتك التعليمية...</p>}

    {state.status === "error" && <section className="panel">
      <p className="error-box" role="alert">تعذر تحميل بياناتك التعليمية: {state.error}</p>
      <div className="actions" style={{ marginTop: 12 }}>
        <button className="button secondary" onClick={reload}>إعادة المحاولة</button>
      </div>
    </section>}

    {state.status === "ready" && !students.length && <section className="panel learn-empty">
      <h2>لا يوجد سجل طالب مرتبط بحسابك بعد</h2>
      <p className="muted">
        تعرض هذه الصفحة المقررات والواجبات والدرجات للسجل المرتبط بحسابك. لم نجد سجلاً مرتبطاً،
        أو أن ربط حساب ولي الأمر بالطالب لم يُعتمد من الإدارة بعد.
      </p>
      <p className="data-note">تواصل مع شؤون الطلاب لربط حسابك بسجل الطالب أو لاعتماد صلة ولي الأمر.</p>
    </section>}

    {students.length > 1 && <fieldset className="context-card">
      <label>عرض سجل الطالب
        <select value={learnerId} onChange={(event) => setLearnerId(event.target.value)}>
          {students.map((student) => <option key={student.id} value={student.id}>
            {student.full_name} — {student.admission_no}
          </option>)}
        </select>
      </label>
    </fieldset>}

    {learner && <section className="panel learn-hero">
      <div className="learn-hero-main">
        <p className="eyebrow">السجل الأكاديمي</p>
        <h2>{learner.full_name}</h2>
        <p className="muted">
          {learnerClass ? `${learnerClass.name} · ${learnerClass.program}` : "الصف غير محدد"} · الرقم الأكاديمي {learner.admission_no}
        </p>
        {!isStudent && <p className="data-note">حساب ولي الأمر للقراءة فقط؛ لا يمكن تسليم الواجبات أو تسجيل التقدم من هنا.</p>}
      </div>
      <div className="learn-stats">
        <div className="learn-stat"><span>المقررات</span><strong>{courses.length}</strong></div>
        <div className="learn-stat"><span>دروس مكتملة</span><strong>{overall.completed} / {overall.total}</strong></div>
        <div className="learn-stat"><span>نسبة التقدم</span><strong>{overall.percent}%</strong></div>
        <div className="learn-stat"><span>واجبات مستحقة</span><strong>{pending.length}</strong></div>
      </div>
    </section>}

    {learner && <div className="learner-links">
      <Link className="button primary" to="/portal/modules/courses">فتح المقررات</Link>
      <Link className="button secondary" to="/portal/modules/homework">الواجبات</Link>
      <Link className="button secondary" to="/portal/modules/progress">التقدم والأداء</Link>
    </div>}

    {learner && !courses.length && <section className="panel learn-empty">
      <h2>لم تُسجَّل مقررات لصفك بعد</h2>
      <p className="muted">سيظهر هنا المقرر فور إضافته من إدارة الأكاديمية إلى صفك الدراسي.</p>
    </section>}

    {learner && !!courses.length && <div className="learner-grid">
      <section className="panel">
        <h2>مقرراتي</h2>
        <p className="data-note">نسبة الإنجاز تعتمد على الدروس التي سُجّلت كمكتملة.</p>
        <div className="learn-course-grid">
          {courseRows.map(({ course, lessonCount, homeworkCount, summary }) => <Link
            key={course.id}
            className="learn-course"
            to="/portal/modules/courses"
          >
            <strong>{course.title}</strong>
            <small>{lessonCount} درساً · {homeworkCount} واجباً</small>
            <span className="learn-bar" aria-hidden="true"><span style={{ width: `${summary.percent}%` }} /></span>
            <small className="learn-course-stat">{summary.completed} من {lessonCount} دروس · {summary.percent}%</small>
          </Link>)}
        </div>
      </section>

      <div className="learner-side">
        <section className="panel">
          <h2>واجبات مستحقة</h2>
          {!upcoming.length
            ? <p className="muted">لا توجد واجبات مستحقة حالياً. أحسنت.</p>
            : <div className="table-scroll">
              <table className="management-table">
                <thead><tr><th>الواجب</th><th>التسليم</th><th>الحالة</th><th><span className="sr-only">التفاصيل</span></th></tr></thead>
                <tbody>
                  {upcoming.map(({ item, course, submission }) => {
                    const due = daysUntil(item.due_at);
                    return <tr key={item.id}>
                      <td>
                        {item.title}
                        <small className="learn-meta">{course?.title ?? "—"}</small>
                      </td>
                      <td>
                        <span className={`learner-due${due < 0 && !submission ? " overdue" : ""}`}>
                          {formatDate(item.due_at)}
                        </span>
                        {due < 0 && !submission && <small className="learn-meta">متأخر</small>}
                      </td>
                      <td>{submission ? submissionStatusLabels[submission.status] : "لم يُسلَّم"}</td>
                      <td><Link className="button secondary" to="/portal/modules/homework">عرض</Link></td>
                    </tr>;
                  })}
                </tbody>
              </table>
            </div>}
        </section>

        <section className="panel">
          <h2>أحدث الدرجات</h2>
          {average !== null && <p className="learn-score">متوسط الدرجات: <strong>{average}%</strong></p>}
          {!gradedRows.length
            ? <p className="muted">لا توجد درجات مصحّحة بعد.</p>
            : <div className="table-scroll">
              <table className="management-table">
                <thead><tr><th>الواجب</th><th>الدرجة</th><th>الملاحظات</th></tr></thead>
                <tbody>
                  {gradedRows.map(({ item, submission }) => <tr key={item.id}>
                    <td>{item.title}</td>
                    <td>{submission?.score ?? 0} / {item.max_score}</td>
                    <td>{submission?.feedback ?? "—"}</td>
                  </tr>)}
                </tbody>
              </table>
            </div>}
        </section>
      </div>
    </div>}
  </main>;
}