import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { loadStaffHome, type StaffHome as StaffHomeData } from "../../lib/home";
import { formatDateTime } from "./dateFormat";
import { AdmissionChip, OccupancyBar } from "./SectionBits";
import { SuperAdminOverview } from "./SuperAdminOverview";
import { usePortalLang } from "../../lib/portalLangContext";

type State =
  | { status: "loading"; data: null; error: null }
  | { status: "ready"; data: StaffHomeData; error: null }
  | { status: "error"; data: null; error: string };

export function StaffHome({ superAdmin = false }: { superAdmin?: boolean }) {
  const { t, lang } = usePortalLang();
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
        <p className="eyebrow">{t("adminEyebrow")}</p>
        <h1>{t("dashboardTitle")}</h1>
        <p className="muted">{t("dashboardIntro")}</p>
      </div>
      <div className="actions">
        <Link className="button secondary" to="/portal/operations">{t("reportsAndReminders")}</Link>
        <button className="button secondary" onClick={refresh} disabled={state.status === "loading"}>{t("refresh")}</button>
      </div>
    </div>

    {state.status === "loading" && <p role="status">{t("loadingAcademics")}</p>}

    {state.status === "error" && <section className="panel">
      <p className="error-box" role="alert">{t("dashboardLoadFailed")}: {state.error}</p>
      <div className="actions" style={{ marginTop: 12 }}>
        <button className="button secondary" onClick={refresh}>{t("retry")}</button>
      </div>
    </section>}

    {data && <>
      <div className="kpi-grid home-kpi-grid">
        <div className="kpi-card">
          <span>{t("kpiActiveStudents")}</span>
          <strong>{data.activeStudents}</strong>
          <small>{t("kpiActiveStudentsNote")}</small>
        </div>
        <div className="kpi-card">
          <span>{t("kpiRunningClasses")}</span>
          <strong>{data.runningClasses}</strong>
          <small>{t("kpiRunningClassesNote")}</small>
        </div>
        <div className="kpi-card">
          <span>{t("kpiNewEnquiries")}</span>
          <strong>{data.newEnquiries}</strong>
          <small>{t("kpiNewEnquiriesNote")}</small>
        </div>
        <div className="kpi-card">
          <span>{t("kpiBranches")}</span>
          <strong>{data.branches.length}</strong>
          <small>{t("kpiSessionsNote").replace("{count}", String(data.sessions.length))}</small>
        </div>
      </div>

      <div className="home-split">
        <section className="panel">
          <div className="home-panel-head">
            <h2>{t("latestEnquiries")}</h2>
            <Link className="text-button" to="/portal/modules/admissions">{t("openAdmissionsWorkspace")}</Link>
          </div>
          {!data.enquiries.length
            ? <p className="muted">{t("noEnquiries")}</p>
            : <ul className="home-enquiry-list">
              {data.enquiries.map((row) => <li key={row.id} className="home-enquiry">
                <div className="home-enquiry-main">
                  <strong>{row.applicant_full_name}</strong>
                  <small dir="ltr">{row.application_no}</small>
                  <small>{row.preferred_program ?? t("programUnspecified")} · {formatDateTime(row.created_at, lang)}</small>
                </div>
                <AdmissionChip status={row.status} />
              </li>)}
            </ul>}
        </section>

        <section className="panel">
          <div className="home-panel-head">
            <h2>{t("branchesAndSessions")}</h2>
            <Link className="text-button" to="/portal/modules/branches">{t("manageBranches")}</Link>
          </div>
          <h3 className="home-subheading">{t("branchesLabel")}</h3>
          {!data.branches.length
            ? <p className="muted">{t("noBranches")}</p>
            : <div className="role-chips">{data.branches.map((branch) => <span className="role-chip" key={branch.id}>{branch.name}</span>)}</div>}
          <h3 className="home-subheading">{t("academicSessionsLabel")}</h3>
          {!data.sessions.length
            ? <p className="muted">{t("noSessions")}</p>
            : <ul className="home-session-list">
              {data.sessions.map((session) => <li key={session.id}><i className="ri-calendar-2-line" aria-hidden="true"></i>{session.name}</li>)}
            </ul>}
        </section>
      </div>

      <section className="panel">
        <div className="home-panel-head">
          <h2>{t("sectionsOccupancy")}</h2>
          <Link className="text-button" to="/portal/modules/classes">{t("manageClasses")}</Link>
        </div>
        <p className="data-note">{t("sectionsOccupancyNote")}</p>
        {!data.sections.length
          ? <p className="muted">{t("noSections")}</p>
          : <div className="table-scroll">
            <table className="management-table">
              <thead>
                <tr>
                  <th>{t("thSection")}</th>
                  <th>{t("thProgram")}</th>
                  <th>{t("thBranch")}</th>
                  <th>{t("thOccupancy")}</th>
                  <th>{t("thAttendance")}</th>
                </tr>
              </thead>
              <tbody>
                {data.sections.map((section) => <tr key={section.id}>
                  <td>
                    <strong>{section.name}</strong>
                    <small className="learn-meta">{section.sessionName}{section.isActive ? "" : ` · ${t("inactive")}`}</small>
                  </td>
                  <td>{section.program}</td>
                  <td>{section.branchName}</td>
                  <td><OccupancyBar enrolled={section.enrolled} capacity={section.capacity} /></td>
                  <td>
                    <Link className="button secondary attendance-shortcut" to={`/portal/modules/attendance?class=${section.id}`}>
                      <i className="ri-calendar-check-line" aria-hidden="true"></i> {t("attendanceRegister")}
                    </Link>
                  </td>
                </tr>)}
              </tbody>
            </table>
          </div>}
      </section>
    </>}
  </main>;
}