import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { loadTeacherHome, type TeacherSection } from "../../lib/home";
import { OccupancyBar } from "./SectionBits";
import { loadLearningWorkspace, type LearningWorkspace } from "../../lib/learning";
import { supabase } from "../../lib/supabase";

type State =
  | { status: "loading"; sections: null; error: null }
  | { status: "ready"; sections: TeacherSection[]; error: null }
  | { status: "error"; sections: null; error: string };

export function TeacherHome({ userId }: { userId: string }) {
  const [state, setState] = useState<State>({ status: "loading", sections: null, error: null });
  const [retry, setRetry] = useState(0);
  const [learning, setLearning] = useState<LearningWorkspace | null>(null);
  const [learningError, setLearningError] = useState<string | null>(null);
  const [attendance, setAttendance] = useState<{ class_id: string; attendance_date: string; status: string }[] | null>(null);
  const [attendanceError, setAttendanceError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    setState({ status: "loading", sections: null, error: null });
    loadTeacherHome(userId)
      .then((sections) => { if (active) setState({ status: "ready", sections, error: null }); })
      .catch((error: unknown) => {
        if (active) setState({ status: "error", sections: null, error: error instanceof Error ? error.message : String(error) });
      });
    return () => { active = false; };
  }, [userId, retry]);

  const sections = state.status === "ready" ? state.sections : null;
  useEffect(() => {
    let active = true;
    setLearning(null); setLearningError(null);
    loadLearningWorkspace(false, undefined, userId)
      .then((data) => { if (active) setLearning(data); })
      .catch((error: unknown) => { if (active) setLearningError(error instanceof Error ? error.message : String(error)); });
    return () => { active = false; };
  }, [userId, retry]);
  useEffect(() => {
    if (!sections) return;
    let active = true;
    setAttendance(null); setAttendanceError(null);
    const ids = sections.map((section) => section.id);
    if (!ids.length) { setAttendance([]); return; }
    void supabase.from("attendance_sessions").select("class_id,attendance_date,status")
      .in("class_id", ids).order("attendance_date", { ascending: false }).limit(10)
      .then(({ data, error }) => {
        if (!active) return;
        if (error) setAttendanceError(error.message);
        else setAttendance(data);
      });
    return () => { active = false; };
  }, [sections, retry]);
  const studentTotal = sections?.reduce((total, section) => total + section.students.length, 0) ?? 0;
  const seatTotal = sections?.reduce((total, section) => total + section.capacity, 0) ?? 0;

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">بوابة المعلم</p>
        <h1>شعبي الدراسية</h1>
        <p className="muted">تظهر فقط الشعب المسندة إليك، مع كشف الطلاب والسعة المتاحة.</p>
      </div>
      <div className="actions">
        <Link className="button secondary" to="/portal/modules/attendance">الحضور والمتابعة</Link>
        <button className="button secondary" onClick={() => setRetry((value) => value + 1)} disabled={state.status === "loading"}>تحديث</button>
      </div>
    </div>

    {state.status === "loading" && <p role="status">جارٍ تحميل شعبك...</p>}
    {state.status === "error" && <section className="panel">
      <p className="error-box" role="alert">تعذر تحميل شعبك: {state.error}</p>
      <div className="actions" style={{ marginTop: 12 }}>
        <button className="button secondary" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button>
      </div>
    </section>}

    {sections && !sections.length && <section className="panel">
      <h2>لم تُسند إليك شعبة بعد</h2>
      <p className="muted">عندما تربط الإدارة شعبة باسمك ستظهر هنا مع كشف طلابها وعدد المقاعد.</p>
      <p className="data-note">إن كنت تتوقع شعباً ولم تظهر، اطلب من الإدارة تحديث إسناد المعلم للصف.</p>
    </section>}

    {sections && !!sections.length && <>
      <div className="kpi-grid home-kpi-grid">
        <div className="kpi-card"><span>الشعب المسندة</span><strong>{sections.length}</strong><small>الشعب المتاحة لحسابك</small></div>
        <div className="kpi-card"><span>إجمالي الطلاب</span><strong>{studentTotal}</strong><small>طالب مسجل في شعبك</small></div>
        <div className="kpi-card"><span>إجمالي المقاعد</span><strong>{seatTotal}</strong><small>السعة المعتمدة</small></div>
        <div className="kpi-card"><span>نسبة الإشغال</span><strong>{seatTotal ? Math.round((studentTotal / seatTotal) * 100) : 0}%</strong><small>المسجلون من السعة</small></div>
      </div>

      <section className="panel">
        <h2>المقررات والواجبات</h2>
        {learningError && <p className="error-box" role="alert">تعذر تحميل بيانات التعليم: {learningError}</p>}
        {!learning && !learningError && <p role="status">جارٍ تحميل المقررات والواجبات...</p>}
        {learning && <>
          <p>التسليمات المحمّلة بانتظار التصحيح: {learning.submissions.filter((row) => row.status === "submitted").length}</p>
          <p className="data-note">قد تكون بيانات التعليم المحمّلة محدودة بعدد الصفوف الذي تسمح به الخدمة؛ لا يُعد العدد إجمالياً مؤكداً.</p>
          <Link className="button secondary" to="/portal/modules/homework">مراجعة الواجبات والتسليمات</Link>
          {!learning.courses.length ? <p>لا توجد مقررات نشطة للشعب المسندة.</p> : <ul>
            {learning.courses.map((course) => <li key={course.id}>
              <Link to={`/portal/modules/courses?course=${encodeURIComponent(course.id)}`}>{course.title}</Link>
              {" · "}{sections.find((section) => section.id === course.class_id)?.name ?? "الصف"}
            </li>)}
          </ul>}
        </>}
      </section>
      <section className="panel">
        <h2>جلسات الحضور الأخيرة</h2>
        {attendanceError && <p className="error-box" role="alert">تعذر تحميل جلسات الحضور: {attendanceError}</p>}
        {!attendance && !attendanceError && <p role="status">جارٍ تحميل الحضور...</p>}
        {attendance && !attendance.length && <p>لا توجد جلسات حضور متاحة.</p>}
        {attendance && !!attendance.length && <ul>{attendance.map((item, index) => <li key={`${item.class_id}:${item.attendance_date}:${index}`}>
          {sections.find((section) => section.id === item.class_id)?.name} · {item.attendance_date} · {item.status}
        </li>)}</ul>}
      </section>
      <div className="home-section-grid">
        {sections.map((section) => <section className="panel home-section-card" key={section.id}>
          <div className="home-panel-head">
            <div>
              <h2>{section.name}</h2>
              <p className="muted home-section-meta">{section.program} · {section.branchName} · {section.sessionName}</p>
            </div>
            <Link className="button secondary attendance-shortcut" to={`/portal/modules/attendance?class=${section.id}`}>
              <i className="ri-calendar-check-line" aria-hidden="true"></i> سجل الحضور
            </Link>
          </div>
          <OccupancyBar enrolled={section.students.length} capacity={section.capacity} />
          <h3 className="home-subheading">كشف الطلاب ({section.students.length})</h3>
          {!section.students.length
            ? <p className="muted">لا يوجد طلاب مسجلون في هذه الشعبة بعد.</p>
            : <ul className="home-roster">
              {section.students.map((student) => <li key={student.id}>
                <i className="ri-user-line" aria-hidden="true"></i>
                <span>{student.fullName}</span>
                <small dir="ltr">{student.admissionNo}</small>
              </li>)}
            </ul>}
        </section>)}
      </div>
    </>}
  </main>;
}