import { useMemo } from "react";
import {
  formatDate, lessonStatusLabels, submissionStatusLabels, summarizeProgress,
  type LearningScope,
} from "@/portal/lib/learning";

export function ProgressView({ scope }: { scope: LearningScope }) {
  const { workspace, mode, learnerId } = scope;
  const learner = workspace.students.find((student) => student.id === learnerId) ?? null;

  const courses = useMemo(() => (mode === "staff"
    ? workspace.courses
    : workspace.courses.filter((course) => course.class_id === learner?.class_id)), [mode, workspace.courses, learner?.class_id]);

  const rows = courses.map((course) => {
    const lessons = workspace.lessons
      .filter((lesson) => lesson.course_id === course.id)
      .sort((a, b) => a.position - b.position);
    const cls = workspace.classes.find((item) => item.id === course.class_id) ?? null;
    if (mode === "staff") {
      const students = workspace.students.filter((student) => student.class_id === course.class_id);
      const lessonIds = new Set(lessons.map((lesson) => lesson.id));
      const slots = lessons.length * students.length;
      const completed = workspace.progress
        .filter((row) => lessonIds.has(row.lesson_id) && row.status === "completed").length;
      const homeworkIds = new Set(
        workspace.homework.filter((item) => item.course_id === course.id).map((item) => item.id),
      );
      const submissions = workspace.submissions.filter((row) => homeworkIds.has(row.homework_id));
      const graded = submissions.filter((row) => row.status === "graded" && row.score !== null);
      const percentages = graded.flatMap((row) => {
        const homework = workspace.homework.find((item) => item.id === row.homework_id);
        return homework && homework.max_score > 0 && row.score !== null ? [row.score / homework.max_score * 100] : [];
      });
      const average = percentages.length
        ? Math.round(percentages.reduce((total, score) => total + score, 0) / percentages.length)
        : null;
      return {
        course, className: cls?.name ?? "—", program: cls?.program ?? "—",
        lessons: lessons.length, students: students.length,
        percent: slots ? Math.round((completed / slots) * 100) : 0,
        detail: `${completed} من ${slots} إنجاز · ${submissions.length} تسليم · ${graded.length} مصحّح`,
        average, next: null as string | null,
      };
    }
    const summary = summarizeProgress(lessons, workspace.progress, learner?.id ?? "");
    const nextLesson = lessons.find((lesson) => {
      const row = workspace.progress.find((entry) => entry.lesson_id === lesson.id && entry.student_id === learner?.id);
      return row?.status !== "completed";
    }) ?? null;
    return {
      course, className: cls?.name ?? "—", program: cls?.program ?? "—",
      lessons: lessons.length, students: 0, percent: summary.percent,
      detail: `${summary.completed} مكتمل · ${summary.inProgress} قيد الدراسة · ${summary.total - summary.completed - summary.inProgress} لم يبدأ`,
      average: null as number | null, next: nextLesson?.title ?? null,
    };
  });

  const learnerHomework = mode === "learner" && learner
    ? workspace.homework
      .filter((item) => courses.some((course) => course.id === item.course_id))
      .slice()
      .sort((a, b) => new Date(b.due_at).getTime() - new Date(a.due_at).getTime())
      .map((item) => ({
        item,
        course: workspace.courses.find((course) => course.id === item.course_id) ?? null,
        submission: workspace.submissions.find((row) => row.homework_id === item.id && row.student_id === learner.id) ?? null,
      }))
    : [];

  const gradedScores = learnerHomework.flatMap(({ item, submission }) =>
    submission?.status === "graded" && submission.score !== null && item.max_score > 0
      ? [submission.score / item.max_score * 100] : []);
  const averageScore = gradedScores.length
    ? Math.round(gradedScores.reduce((total, score) => total + score, 0) / gradedScores.length)
    : null;

  if (!courses.length) {
    return <section className="panel learn-empty">
      <h2>لا توجد بيانات تقدم بعد</h2>
      <p className="muted">{mode === "staff"
        ? "لم تُسجَّل مقررات أو دروس في النطاق المتاح لدورك."
        : "لم يُسجَّل مقرر لصفك بعد؛ سيظهر التقدم هنا بمجرد إضافة المقررات والدروس."}</p>
    </section>;
  }

  return <>
    <section className="panel">
      <h2>{mode === "staff" ? "تقدم الصفوف في المقررات" : "التقدم في كل مقرر"}</h2>
      <p className="data-note">حالات الإكمال القديمة قد تكون مسجلة ذاتياً وغير متحققة، ولا تمثل إنجازاً معتمداً.</p>
      <div className="table-scroll">
        <table className="management-table">
          <thead><tr>
            <th>المقرر</th><th>الصف</th><th>الدروس</th>
            {mode === "staff" ? <><th>الطلبة</th><th>متوسط الدرجات</th></> : <th>الحالة</th>}
            <th>نسبة الحالات السابقة</th><th>الخطوة التالية</th>
          </tr></thead>
          <tbody>
            {rows.map((row) => <tr key={row.course.id}>
              <td>{row.course.title}</td>
              <td>{row.className}</td>
              <td>{row.lessons}</td>
              {mode === "staff"
                ? <><td>{row.students}</td><td>{row.average === null ? "—" : `${row.average}%`}</td></>
                : <td>{row.detail}</td>}
              <td>
                <div className="learn-bar" aria-hidden="true"><span style={{ width: `${row.percent}%` }} /></div>
                <small className="learn-meta">{row.percent}%</small>
              </td>
              <td>{mode === "staff" ? row.detail : row.next ?? "لا توجد حالة أخرى مسجلة"}</td>
            </tr>)}
          </tbody>
        </table>
      </div>
    </section>

    {mode === "learner" && learner && <section className="panel">
      <h2>أدائي في الواجبات</h2>
      {averageScore === null
        ? <p className="muted">لا توجد واجبات مصحّحة بعد.</p>
        : <p className="learn-score">متوسط الدرجات: <strong>{averageScore}%</strong></p>}
      {!learnerHomework.length ? <p className="muted">لا توجد واجبات مرتبطة بمقرراتك.</p> : <div className="table-scroll">
        <table className="management-table">
          <thead><tr><th>الواجب</th><th>المقرر</th><th>التسليم</th><th>الحالة</th><th>الدرجة</th></tr></thead>
          <tbody>
            {learnerHomework.map(({ item, course, submission }) => <tr key={item.id}>
              <td>{item.title}</td>
              <td>{course?.title ?? "—"}</td>
              <td>{formatDate(item.due_at)}</td>
              <td>{submission ? submissionStatusLabels[submission.status] : "لم يُسلَّم"}</td>
              <td>{submission?.score === null || submission?.score === undefined ? "—" : `${submission.score} / ${item.max_score}`}</td>
            </tr>)}
          </tbody>
        </table>
      </div>}
    </section>}

    {mode === "learner" && learner && <section className="panel">
      <h2>ملخص الدروس</h2>
      <p className="data-note">الإكمال معطل حتى يتوفر تقييم موثوق على الخادم.</p>
      <div className="table-scroll">
        <table className="management-table">
          <thead><tr><th>الدرس</th><th>المقرر</th><th>الحالة</th></tr></thead>
          <tbody>
            {workspace.lessons
              .filter((lesson) => courses.some((course) => course.id === lesson.course_id))
              .sort((a, b) => a.course_id.localeCompare(b.course_id) || a.position - b.position)
              .map((lesson) => {
                const row = workspace.progress.find((entry) => entry.lesson_id === lesson.id && entry.student_id === learner.id);
                return <tr key={lesson.id}>
                  <td>{lesson.position}. {lesson.title}</td>
                  <td>{workspace.courses.find((course) => course.id === lesson.course_id)?.title ?? "—"}</td>
                  <td>{lessonStatusLabels[row?.status ?? "not_started"]}</td>
                </tr>;
              })}
          </tbody>
        </table>
      </div>
    </section>}
  </>;
}