import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { loadTeacherHome, type TeacherSection } from "../../lib/home";
import { OccupancyBar } from "./SectionBits";

type State =
  | { status: "loading"; sections: null; error: null }
  | { status: "ready"; sections: TeacherSection[]; error: null }
  | { status: "error"; sections: null; error: string };

export function TeacherHome({ userId }: { userId: string }) {
  const [state, setState] = useState<State>({ status: "loading", sections: null, error: null });
  const [retry, setRetry] = useState(0);

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
        <div className="kpi-card"><span>الشعب المسندة</span><strong>{sections.length}</strong><small>شعب في جلستك الحالية</small></div>
        <div className="kpi-card"><span>إجمالي الطلاب</span><strong>{studentTotal}</strong><small>طالب مسجل في شعبك</small></div>
        <div className="kpi-card"><span>إجمالي المقاعد</span><strong>{seatTotal}</strong><small>السعة المعتمدة</small></div>
        <div className="kpi-card"><span>نسبة الإشغال</span><strong>{seatTotal ? Math.round((studentTotal / seatTotal) * 100) : 0}%</strong><small>المسجلون من السعة</small></div>
      </div>

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