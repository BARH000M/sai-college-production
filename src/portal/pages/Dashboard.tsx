import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { KpiCard } from "../components/KpiCard";
import {
  loadContext, loadDashboard, loadStaleNewCount,
  type AcademicSession, type AuditEntry, type Branch, type Result,
} from "../lib/dashboard";
import { runAdmissionRemindersNow, type ReminderRunResult } from "../lib/reminders";
import { pendingModules } from "../lib/navigation";
import { usePortalLang } from "../lib/portalLangContext";
import { DashboardReportPrint } from "./DashboardReportPrint";

type DashboardData = { students: Result<number>; classes: Result<number>; audit: Result<AuditEntry[]> };
const unavailable: Result<number> = { data: null, error: null };
const numberLocales = { ar: "ar", en: "en-GB", zh: "zh-CN" } as const;

export function Dashboard() {
  const { t, lang } = usePortalLang();
  const [branches, setBranches] = useState<Branch[]>([]);
  const [sessions, setSessions] = useState<AcademicSession[]>([]);
  const [branchId, setBranchId] = useState("");
  const [sessionId, setSessionId] = useState("");
  const [contextError, setContextError] = useState<string | null>(null);
  const [contextLoading, setContextLoading] = useState(true);
  const [data, setData] = useState<DashboardData | null>(null);
  const [dataLoading, setDataLoading] = useState(false);
  const [stale, setStale] = useState<Result<number>>(unavailable);
  const [staleLoading, setStaleLoading] = useState(false);
  const [reminderBusy, setReminderBusy] = useState(false);
  const [reminderResult, setReminderResult] = useState<ReminderRunResult | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setContextLoading(true);
    void loadContext().then((result) => {
      if (!active) return;
      const newBranches = result.branches.data ?? [];
      const newSessions = result.sessions.data ?? [];
      setBranches(newBranches);
      setSessions(newSessions);
      setBranchId((current) => newBranches.some((b) => b.id === current) ? current : newBranches[0]?.id ?? "");
      setSessionId((current) => newSessions.some((s) => s.id === current) ? current : newSessions.find((s) => s.is_active)?.id ?? newSessions[0]?.id ?? "");
      setContextError([result.branches.error, result.sessions.error].filter(Boolean).join(" — ") || null);
      setContextLoading(false);
    });
    return () => { active = false; };
  }, [retry]);

  useEffect(() => {
    let active = true;
    setData(null);
    if (!branchId || !sessionId) { setDataLoading(false); return; }
    setDataLoading(true);
    void loadDashboard(branchId, sessionId).then((result) => {
      if (active) { setData(result); setDataLoading(false); }
    });
    return () => { active = false; };
  }, [branchId, sessionId, retry]);

  useEffect(() => {
    let active = true;
    if (!branchId) {
      setStale(unavailable);
      setStaleLoading(false);
      return;
    }
    setStaleLoading(true);
    void loadStaleNewCount(branchId).then((result) => {
      if (active) { setStale(result); setStaleLoading(false); }
    });
    return () => { active = false; };
  }, [branchId, retry]);

  const students = data?.students ?? unavailable;
  const classes = data?.classes ?? unavailable;
  const audit = data?.audit;
  const refresh = () => setRetry((current) => current + 1);
  const activeSession = sessions.find((session) => session.id === sessionId && session.is_active);
  const staleCount = staleLoading ? "—" : stale.data === null ? "—" : stale.data;
  const admissionHref = `/portal/modules/admissions?status=new&stale=1${branchId ? `&branch=${branchId}` : ""}`;

  async function runReminders() {
    if (reminderBusy) return;
    setReminderBusy(true);
    setReminderResult(null);
    try {
      const result = await runAdmissionRemindersNow();
      setReminderResult(result);
      if (result.status === "sent" || result.status === "not_configured") refresh();
    } finally {
      setReminderBusy(false);
    }
  }

  return <main className="workspace">
    <section id="overview">
      <div className="page-heading">
        <div>
          <p className="eyebrow">{t("opsEyebrow")}</p>
          <h1>{t("dashboardTitle")}</h1>
          <p className="muted">{t("opsIntro")}</p>
        </div>
        <button className="button secondary" onClick={refresh} disabled={contextLoading || dataLoading}>{t("refreshData")}</button>
      </div>
      <div className="context-card">
        <label>
          {t("branchLabel")}
          <select value={branchId} onChange={(e) => setBranchId(e.target.value)} disabled={contextLoading || !branches.length}>
            <option value="">{t("noBranchesOption")}</option>
            {branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>)}
          </select>
        </label>
        <label>
          {t("sessionLabel")}
          <select value={sessionId} onChange={(e) => setSessionId(e.target.value)} disabled={contextLoading || !sessions.length}>
            <option value="">{t("noSessionsOption")}</option>
            {sessions.map((session) => (
              <option key={session.id} value={session.id}>
                {session.name}{session.is_active ? ` — ${t("activeSuffix")}` : ""}
              </option>
            ))}
          </select>
        </label>
      </div>
      {contextLoading && <p className="muted" role="status">{t("loadingBranches")}</p>}
      {contextError && <div className="error-box" role="alert">
        {t("branchesLoadFailed")}: {contextError}{" "}
        <button className="text-button" onClick={refresh}>{t("retry")}</button>
      </div>}
      {!contextLoading && !contextError && (!branches.length || !sessions.length) && <div className="notice">{t("noScopeNotice")}</div>}
      <div className="kpi-grid">
        <KpiCard
          label={t("kpiActiveBranches")}
          value={contextLoading || contextError ? "—" : branches.filter((branch) => branch.is_active).length}
          detail={t("kpiActiveBranchesNote")}
          error={contextError}
        />
        <KpiCard
          label={t("kpiActiveStudentsShort")}
          value={dataLoading || students.data === null ? "—" : students.data}
          detail={t("kpiActiveStudentsShortNote")}
          error={students.error}
        />
        <KpiCard
          label={t("kpiClasses")}
          value={dataLoading || classes.data === null ? "—" : classes.data}
          detail={t("kpiClassesNote")}
          error={classes.error}
        />
        <KpiCard
          label={t("kpiAwaitingContact")}
          value={staleCount}
          detail={t("kpiAwaitingContactNote")}
          error={stale.error}
          action={stale.error ? null : <Link className="kpi-link" to={admissionHref}>{t("viewOverdue")}</Link>}
        />
        <KpiCard
          label={t("kpiActiveSession")}
          value={contextLoading ? "—" : activeSession?.name ?? t("noActiveSession")}
          detail={t("kpiActiveSessionNote")}
          error={contextError}
        />
      </div>
      {dataLoading && <p className="muted" role="status">{t("loadingDashboard")}</p>}
      {(students.error || classes.error || audit?.error) && (
        <button className="button secondary" onClick={refresh}>{t("retryDashboard")}</button>
      )}
      <p className="data-note">{t("figuresNote")}</p>
    </section>
    <DashboardReportPrint branchId={branchId} sessionId={sessionId} />
    <div className="dashboard-grid">
      <section id="pending" className="panel">
        <h2>{t("pendingSections")}</h2>
        <p className="muted">{t("pendingSectionsNote")}</p>
        {pendingModules.length === 0
          ? <p className="success-box" role="status">{t("allModulesComplete")}</p>
          : <ul className="pending-list">
            {pendingModules.map((item) => <li key={item.id}>
              <strong>{item.label}</strong>
              <span>{item.reason}</span>
            </li>)}
          </ul>}
      </section>
      <section id="admissions" className="panel admissions-glance">
        <div className="page-heading"><div><h2>{t("admissionsGlance")}</h2></div></div>
        <div className="stale-counter">
          <strong>{staleCount}</strong>
          <div>
            <p>{t("awaitingFirstContact")}</p>
            <small>{t("awaitingFirstContactNote")}</small>
          </div>
        </div>
        {staleLoading && <p className="muted" role="status">{t("calculatingOverdue")}</p>}
        {stale.error && <p className="error-box" role="alert">{t("overdueCalcFailed")}: {stale.error}</p>}
        <div className="actions">
          <Link className="button primary" to={admissionHref}>{t("openFilteredList")}</Link>
          <Link className="button secondary" to="/portal/modules/admissions">{t("admissionsWorkspace")}</Link>
        </div>
        <div className="reminder-block">
          <h3>{t("reminderTitle")}</h3>
          <p className="data-note">{t("reminderNote")}</p>
          <button className="button secondary" onClick={() => void runReminders()} disabled={reminderBusy}>
            {reminderBusy ? t("runningReminders") : t("runReminders")}
          </button>
          {reminderResult && <p
            className={reminderResult.status === "error" ? "error-box" : reminderResult.status === "sent" ? "success-box" : "notice"}
            role={reminderResult.status === "error" ? "alert" : "status"}
          >{reminderResult.message}</p>}
        </div>
      </section>
      <section id="upcoming" className="panel">
        <h2>{t("upcomingLessons")}</h2>
        <p className="muted">{t("upcomingLessonsBody")}</p>
        <div className="actions">
          <Link className="button secondary" to="/portal/modules/timetable">{t("viewTimetable")}</Link>
          <Link className="button secondary" to="/portal/modules/qr">{t("qrAttendance")}</Link>
        </div>
      </section>
      <section id="audit" className="panel audit-panel">
        <h2>{t("recentAudit")}</h2>
        <p className="data-note">{t("auditNote")}</p>
        {dataLoading
          ? <p className="muted">{t("loadingAudit")}</p>
          : audit?.error
            ? <p className="error-box" role="alert">{t("auditLoadFailed")}: {audit.error}</p>
            : !branchId || !sessionId
              ? <p className="muted">{t("selectScope")}</p>
              : audit?.data?.length
                ? <ul className="audit-list">{audit.data.map((entry) => (
                  <li key={entry.id}>
                    <strong>{entry.action}</strong>
                    <span>
                      {entry.entity_type} ·{" "}
                      <time>{new Date(entry.created_at).toLocaleString(numberLocales[lang])}</time>
                    </span>
                  </li>
                ))}</ul>
                : <p className="muted">{t("noAuditEvents")}</p>}
      </section>
    </div>
  </main>;
}