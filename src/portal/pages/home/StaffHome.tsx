import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { loadStaffHome, type StaffHome as StaffHomeData } from "../../lib/home";
import { formatDateTime } from "./dateFormat";
import { AdmissionChip, OccupancyBar } from "./SectionBits";
import { SuperAdminOverview } from "./SuperAdminOverview";

type State =
  | { status: "loading"; data: null; error: null }
  | { status: "ready"; data: StaffHomeData; error: null }
  | { status: "error"; data: null; error: string };

export function StaffHome({ superAdmin = false }: { superAdmin?: boolean }) {
  const [state, setState] = useState<State>({ status: "loading", data: null, error: null });
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setState({ status: "loading", data: null, error: null });
    loadStaffHome()
      .then((data) => { if (active) setState({ status: "ready", data, error: null }); })
      .catch((error: unknown) => {
        if (active) setState({ status: "error", data: null, error: error instanceof Error ? error.message : String(error) });
      });
    return () => { active = false; };
  }, [retry]);

  const data = state.status === "ready" ? state.data : null;
  const refresh = () => setRetry((value) => value + 1);

  return <main className="workspace">
    {superAdmin && <SuperAdminOverview />}
    <div className="page-heading">
      <div>
        <p className="eyebrow">الإدارة والأكاديمية</p>
        <h1>لوحة التحكم</h1>
        <p className="muted">نظرة سريعة على الطلاب والصفوف وطلبات القبول الجديدة.</p>
      </div>
      <div className="actions">
        <Link className="button secondary" to="/portal/operations">التقارير والتذكيرات</Link>
        <button className="button secondary" onClick={refresh} disabled={state.status === "loading"}>تحديث</button>
      </div>
    </div>

    {state.status === "loading" && <p role="status">جارٍ تحميل بيانات الأكاديمية...</p>}

    {state.status === "error" && <section className="panel">
      <p className="error-box" role="alert">تعذر تحميل بيانات اللوحة: {state.error}</p>
      <div className="actions" style={{ marginTop: 12 }}>
        <button className="button secondary" onClick={refresh}>إعادة المحاولة</button>
      </div>
    </section>}

    {data && <>
      <div className="kpi-grid home-kpi-grid">
        <div className="kpi-card">
          <span>الطلاب النشطون</span>
          <strong>{data.activeStudents}</strong>
          <small>السجلات النشطة المتاحة لحسابك</small>
        </div>
        <div className="kpi-card">
          <span>الصفوف النشطة</span>
          <strong>{data.runningClasses}</strong>
          <small>شعب مفتوحة في الجلسات المسموحة</small>
        </div>
        <div className="kpi-card">
          <span>طلبات قبول جديدة</span>
          <strong>{data.newEnquiries}</strong>
          <small>بانتظار أول تواصل</small>
        </div>
        <div className="kpi-card">
          <span>الفروع</span>
          <strong>{data.branches.length}</strong>
          <small>{data.sessions.length} جلسة أكاديمية</small>
        </div>
      </div>

      <div className="home-split">
        <section className="panel">
          <div className="home-panel-head">
            <h2>أحدث طلبات القبول</h2>
            <Link className="text-button" to="/portal/modules/admissions">فتح مساحة القبول</Link>
          </div>
          {!data.enquiries.length
            ? <p className="muted">لا توجد طلبات قبول متاحة لحسابك بعد.</p>
            : <ul className="home-enquiry-list">
              {data.enquiries.map((row) => <li key={row.id} className="home-enquiry">
                <div className="home-enquiry-main">
                  <strong>{row.applicant_full_name}</strong>
                  <small dir="ltr">{row.application_no}</small>
                  <small>{row.preferred_program ?? "برنامج غير محدد"} · {formatDateTime(row.created_at)}</small>
                </div>
                <AdmissionChip status={row.status} />
              </li>)}
            </ul>}
        </section>

        <section className="panel">
          <div className="home-panel-head">
            <h2>الفروع والجلسات</h2>
            <Link className="text-button" to="/portal/modules/branches">إدارة الفروع</Link>
          </div>
          <h3 className="home-subheading">الفروع</h3>
          {!data.branches.length
            ? <p className="muted">لا توجد فروع متاحة.</p>
            : <div className="role-chips">{data.branches.map((branch) => <span className="role-chip" key={branch.id}>{branch.name}</span>)}</div>}
          <h3 className="home-subheading">الجلسات الأكاديمية</h3>
          {!data.sessions.length
            ? <p className="muted">لا توجد جلسات متاحة.</p>
            : <ul className="home-session-list">
              {data.sessions.map((session) => <li key={session.id}><i className="ri-calendar-2-line" aria-hidden="true"></i>{session.name}</li>)}
            </ul>}
        </section>
      </div>

      <section className="panel">
        <div className="home-panel-head">
          <h2>شعب الصفوف والإشغال</h2>
          <Link className="text-button" to="/portal/modules/classes">إدارة الصفوف</Link>
        </div>
        <p className="data-note">عدد المسجلين لكل شعبة من الطلاب النشطين، مقارنة بالسعة المعتمدة.</p>
        {!data.sections.length
          ? <p className="muted">لا توجد شعب متاحة لحسابك بعد.</p>
          : <div className="table-scroll">
            <table className="management-table">
              <thead><tr><th>الشعبة</th><th>البرنامج</th><th>الفرع</th><th>الإشغال</th><th>الحضور</th></tr></thead>
              <tbody>
                {data.sections.map((section) => <tr key={section.id}>
                  <td>
                    <strong>{section.name}</strong>
                    <small className="learn-meta">{section.sessionName}{section.isActive ? "" : " · غير نشطة"}</small>
                  </td>
                  <td>{section.program}</td>
                  <td>{section.branchName}</td>
                  <td><OccupancyBar enrolled={section.enrolled} capacity={section.capacity} /></td>
                  <td><Link className="button secondary attendance-shortcut" to={`/portal/modules/attendance?class=${section.id}`}><i className="ri-calendar-check-line" aria-hidden="true"></i> سجل الحضور</Link></td>
                </tr>)}
              </tbody>
            </table>
          </div>}
      </section>
    </>}
  </main>;
}