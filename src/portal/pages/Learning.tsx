import { useEffect, useMemo, useState } from "react";
import {
  loadLearningWorkspace, summarizeProgress,
  type LearningScope, type LearningWorkspace,
} from "@/portal/lib/learning";
import { loadLearningSeen, markLearningSeen } from "@/portal/lib/learningNotifications";
import { CoursesView } from "@/portal/pages/learning/CoursesView";
import { HomeworkView } from "@/portal/pages/learning/HomeworkView";
import { ProgressView } from "@/portal/pages/learning/ProgressView";

export type LearningView = "courses" | "homework" | "progress";

const titles: Record<LearningView, string> = {
  courses: "المقررات والدروس",
  homework: "الواجبات",
  progress: "التقدم التعليمي",
};

const intros: Record<LearningView, string> = {
  courses: "استعرض مقرراتك، افتح الدروس بالترتيب، وسجّل إنجازك خطوة بخطوة.",
  homework: "تابع الواجبات المطلوبة ومواعيد التسليم والملاحظات الصادرة عن المعلم.",
  progress: "نظرة واضحة على ما أنجزته في كل مقرر وعلى أدائك في الواجبات.",
};

type State =
  | { status: "loading"; data: null; error: null }
  | { status: "ready"; data: LearningWorkspace; error: null }
  | { status: "error"; data: null; error: string };

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));
const staffRoles = ["super_admin", "admin", "teacher", "content_editor"];
const contentManagerRoles = ["super_admin", "admin", "teacher"];

export function Learning({ view, roles }: { view: LearningView; roles: readonly string[] }) {
  const [state, setState] = useState<State>({ status: "loading", data: null, error: null });
  const [version, setVersion] = useState(0);
  const [learnerId, setLearnerId] = useState("");
  const [seenAt, setSeenAt] = useState<string | null | undefined>(undefined);

  useEffect(() => {
    let active = true;
    setState((current) => (current.status === "ready" ? current : { status: "loading", data: null, error: null }));
    loadLearningWorkspace()
      .then((data) => { if (active) setState({ status: "ready", data, error: null }); })
      .catch((error: unknown) => { if (active) setState({ status: "error", data: null, error: message(error) }); });
    return () => { active = false; };
  }, [version]);

  useEffect(() => {
    let active = true;
    void (async () => {
      // Read the previous timestamp first, then mark the list as seen.
      const previous = await loadLearningSeen();
      if (!active) return;
      setSeenAt(previous.seenAt);
      if (view === "homework") {
        try {
          await markLearningSeen();
        } catch {
          // The notification badge simply stays visible if the marker cannot be written.
        }
      }
    })();
    return () => { active = false; };
  }, [view, version]);

  const mode: "staff" | "learner" = roles.some((role) => staffRoles.includes(role)) ? "staff" : "learner";
  const isStudent = roles.includes("student");

  const students = useMemo(() => state.data?.students ?? [], [state.data]);
  useEffect(() => {
    if (mode !== "learner" || !students.length) return;
    if (!students.some((student) => student.id === learnerId)) setLearnerId(students[0].id);
  }, [mode, students, learnerId]);

  const scope = useMemo<LearningScope | null>(() => {
    if (state.status !== "ready") return null;
    return {
      workspace: state.data,
      mode,
      learnerId: mode === "learner" ? learnerId || null : null,
      canTrack: mode === "learner" && isStudent,
      canSubmit: mode === "learner" && isStudent,
      canManageContent: mode === "staff" && roles.some((role) => contentManagerRoles.includes(role)),
      reload: () => setVersion((value) => value + 1),
    };
  }, [state, mode, learnerId, isStudent, roles]);

  const learner = students.find((student) => student.id === learnerId) ?? null;
  const learnerClass = scope?.workspace.classes.find((item) => item.id === learner?.class_id) ?? null;

  const learnerStats = useMemo(() => {
    if (!scope || !learner) return null;
    const courses = scope.workspace.courses.filter((course) => course.class_id === learner.class_id);
    const courseIds = new Set(courses.map((course) => course.id));
    const lessons = scope.workspace.lessons.filter((lesson) => courseIds.has(lesson.course_id));
    const progress = summarizeProgress(lessons, scope.workspace.progress, learner.id);
    const homework = scope.workspace.homework.filter((item) => courseIds.has(item.course_id));
    const submissions = scope.workspace.submissions.filter((item) => item.student_id === learner.id);
    return {
      courses: courses.length,
      lessons: progress.completed,
      percent: progress.percent,
      submitted: submissions.length,
      homework: homework.length,
    };
  }, [scope, learner]);

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">بوابة التعلّم</p>
        <h1>{titles[view]}</h1>
        <p className="muted">{intros[view]}</p>
      </div>
      {mode === "staff" && <span className="learn-pill">عرض إشرافي</span>}
    </div>

    {state.status === "loading" && <p role="status">جارٍ تحميل بوابة التعلّم...</p>}

    {state.status === "error" && <div className="panel">
      <p className="error-box" role="alert">تعذر تحميل بيانات التعلّم: {state.error}</p>
      <div className="actions" style={{ marginTop: 12 }}>
        <button className="button secondary" onClick={() => setVersion((value) => value + 1)}>إعادة المحاولة</button>
      </div>
    </div>}

    {scope && mode === "learner" && !students.length && <section className="panel learn-empty">
      <h2>لا يوجد سجل طالب مرتبط بحسابك</h2>
      <p className="muted">
        تعرض هذه البوابة المقررات والواجبات والتقدم لسجل الطالب المرتبط بحسابك. لم نجد سجلاً مرتبطاً بعد،
        أو أن ربط ولي الأمر بالطالب لم يُعتمد من الإدارة.
      </p>
      <p className="data-note">تواصل مع شؤون الطلاب لربط حسابك بسجل الطالب أو لاعتماد صلة ولي الأمر.</p>
    </section>}

    {scope && mode === "learner" && students.length > 1 && <fieldset className="context-card" disabled={false}>
      <label>عرض سجل الطالب
        <select value={learnerId} onChange={(event) => setLearnerId(event.target.value)}>
          {students.map((student) => <option key={student.id} value={student.id}>{student.full_name} — {student.admission_no}</option>)}
        </select>
      </label>
    </fieldset>}

    {scope && mode === "learner" && learner && <section className="panel learn-hero">
      <div className="learn-hero-main">
        <p className="eyebrow">{isStudent ? "حساب الطالب" : "حساب ولي الأمر"}</p>
        <h2>{learner.full_name}</h2>
        <p className="muted">
          {learnerClass ? `${learnerClass.name} · ${learnerClass.program}` : "الصف غير محدد"} · الرقم الأكاديمي {learner.admission_no}
        </p>
        {!isStudent && <p className="data-note">أنت تشاهد سجل الطالب للقراءة فقط؛ لا يمكن تعديل التقدم أو تسليم الواجبات من حساب ولي الأمر.</p>}
      </div>
      {learnerStats && <div className="learn-stats">
        <div className="learn-stat"><span>المقررات</span><strong>{learnerStats.courses}</strong></div>
        <div className="learn-stat"><span>دروس مكتملة</span><strong>{learnerStats.lessons}</strong></div>
        <div className="learn-stat"><span>نسبة التقدم</span><strong>{learnerStats.percent}%</strong></div>
        <div className="learn-stat"><span>واجبات مسلَّمة</span><strong>{learnerStats.submitted} / {learnerStats.homework}</strong></div>
      </div>}
    </section>}

    {scope && mode === "staff" && view === "courses" && <StaffSummary scope={scope} />}

    {scope && (mode === "staff" || students.length > 0) && <>
      {view === "courses" && <CoursesView scope={scope} />}
      {view === "homework" && <HomeworkView scope={scope} seenAt={seenAt} />}
      {view === "progress" && <ProgressView scope={scope} />}
    </>}
  </main>;
}

function StaffSummary({ scope }: { scope: LearningScope }) {
  const { workspace } = scope;
  const classes = new Set(workspace.courses.map((course) => course.class_id));
  const completed = workspace.progress.filter((row) => row.status === "completed").length;
  const graded = workspace.submissions.filter((row) => row.status === "graded").length;
  return <section className="panel learn-hero">
    <div className="learn-hero-main">
      <p className="eyebrow">ملخص إشرافي</p>
      <h2>المحتوى التعليمي المسجّل في النظام</h2>
      <p className="muted">تُعرض هنا المقررات والواجبات المسموح بها لدورك فقط؛ الصلاحيات مفروضة من قاعدة البيانات.</p>
    </div>
    <div className="learn-stats">
      <div className="learn-stat"><span>المقررات</span><strong>{workspace.courses.length}</strong></div>
      <div className="learn-stat"><span>الصفوف</span><strong>{classes.size}</strong></div>
      <div className="learn-stat"><span>دروس مكتملة</span><strong>{completed}</strong></div>
      <div className="learn-stat"><span>واجبات مصححة</span><strong>{graded}</strong></div>
    </div>
  </section>;
}