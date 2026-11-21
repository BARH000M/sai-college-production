import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { loadSuperAdminSummary, type SuperAdminSummary } from "../../lib/roles";
import { useNotificationFeed } from "../../hooks/useNotificationFeed";
import { usePortalLang } from "../../lib/portalLangContext";

type SummaryState =
  | { status: "loading"; data: null; error: null }
  | { status: "ready"; data: SuperAdminSummary; error: null }
  | { status: "error"; data: null; error: string };

type SummaryKey = keyof SuperAdminSummary;

const errorMessage = (error: unknown) => (error instanceof Error ? error.message : String(error));

/** Translation keys for every metric, so no label is hardcoded Arabic. */
const metricKeys: Record<SummaryKey, string> = {
  totalUsers: "metricTotalUsers",
  emailConfirmedUsers: "metricEmailConfirmed",
  pendingEmailConfirmation: "metricPendingEmail",
  bannedUsers: "metricBanned",
  usersWithoutRoles: "metricNoRoles",
  totalProfiles: "metricProfiles",
  totalRoleAssignments: "metricRoleAssignments",
  teachers: "metricTeachers",
  students: "metricStudents",
  activeStudents: "metricActiveStudents",
  studentsWithoutAccounts: "metricStudentsWithoutAccounts",
  activeClasses: "metricActiveClasses",
  activeClassesWithoutTeachers: "metricClassesWithoutTeachers",
  branches: "kpiBranches",
  academicSessions: "academicSessionsLabel",
  courses: "metricCourses",
  activeCourses: "metricActiveCourses",
  lessons: "metricLessons",
  publishedLessons: "metricPublishedLessons",
  lessonsWithAssetPaths: "metricLessonAssets",
  lessonsMissingContent: "metricLessonsMissingContent",
  activeEnrollments: "metricActiveEnrollments",
  lessonProgressInProgress: "metricLessonProgress",
  legacyCompletedProgress: "metricLegacyProgress",
  homeworkSubmissionsPendingReview: "metricHomeworkPending",
  homeworkSubmissionsGraded: "metricHomeworkGraded",
  pendingAdmissions: "metricPendingAdmissions",
};

const numberLocales = { ar: "ar", en: "en-GB", zh: "zh-CN" } as const;

function Metric({ label, value, to }: { label: string; value: number; to?: string }) {
  const { lang } = usePortalLang();
  const content = <>
    <span>{label}</span>
    <strong>{value.toLocaleString(numberLocales[lang])}</strong>
  </>;
  return to
    ? <Link className="kpi-card" to={to}>{content}</Link>
    : <div className="kpi-card">{content}</div>;
}

function MetricGrid({ data, keys }: { data: SuperAdminSummary; keys: readonly SummaryKey[] }) {
  const { t } = usePortalLang();
  return <div className="kpi-grid home-kpi-grid">
    {keys.map((key) => <Metric
      key={key}
      label={t(metricKeys[key])}
      value={data[key]}
      to={key === "pendingAdmissions" ? "/portal/modules/admissions" : undefined}
    />)}
  </div>;
}

export function SuperAdminOverview() {
  const { t, lang } = usePortalLang();
  const [state, setState] = useState<SummaryState>({ status: "loading", data: null, error: null });
  const [retry, setRetry] = useState(0);
  const feed = useNotificationFeed(["super_admin"]);

  useEffect(() => {
    let active = true;
    setState({ status: "loading", data: null, error: null });
    void loadSuperAdminSummary().then((data) => {
      if (active) setState({ status: "ready", data, error: null });
    }).catch((failure: unknown) => {
      if (active) setState({ status: "error", data: null, error: errorMessage(failure) });
    });
    return () => { active = false; };
  }, [retry]);

  const data = state.status === "ready" ? state.data : null;
  const format = (value: number) => value.toLocaleString(numberLocales[lang]);

  const allAlerts: { key: SummaryKey; to: string; labelKey: string }[] = [
    { key: "pendingAdmissions", to: "/portal/modules/admissions", labelKey: "alertPendingAdmissions" },
    { key: "homeworkSubmissionsPendingReview", to: "/portal/modules/homework", labelKey: "alertHomeworkPending" },
    { key: "activeClassesWithoutTeachers", to: "/portal/modules/classes", labelKey: "alertClassesWithoutTeachers" },
    { key: "studentsWithoutAccounts", to: "/portal/modules/students", labelKey: "alertStudentsWithoutAccounts" },
    { key: "usersWithoutRoles", to: "/portal/modules/roles", labelKey: "alertUsersWithoutRoles" },
    { key: "pendingEmailConfirmation", to: "/portal/modules/roles", labelKey: "alertPendingEmail" },
    { key: "lessonsMissingContent", to: "/portal/modules/courses", labelKey: "alertLessonsMissingContent" },
  ];
  const alerts = data ? allAlerts.filter((alert) => data[alert.key] > 0) : [];

  return <section className="panel super-admin-overview" aria-labelledby="super-admin-overview-title">
    <div className="home-panel-head">
      <div>
        <p className="eyebrow">{t("superAdminEyebrow")}</p>
        <h2 id="super-admin-overview-title">{t("superAdminTitle")}</h2>
      </div>
      <div className="actions">
        <Link className="button secondary" to="/portal/modules/systemCatalog">{t("systemInventoryLink")}</Link>
        <button className="button secondary" type="button" onClick={() => setRetry((value) => value + 1)}
          disabled={state.status === "loading"}>{t("refreshIndicators")}</button>
      </div>
    </div>
    <p className="data-note">{t("superAdminNote")}</p>

    {state.status === "loading" && <p role="status">{t("loadingIndicators")}</p>}
    {state.status === "error" && <div className="error-box" role="alert">
      {t("indicatorsLoadFailed")}: {state.error}
      <button className="text-button" type="button" onClick={() => setRetry((value) => value + 1)}>{t("retry")}</button>
    </div>}

    {data && <>
      <h3 className="home-subheading">{t("groupAccountsIdentity")}</h3>
      <MetricGrid data={data} keys={[
        "totalUsers", "totalProfiles", "totalRoleAssignments", "teachers",
        "emailConfirmedUsers", "pendingEmailConfirmation", "bannedUsers",
        "usersWithoutRoles",
      ]} />
      <h3 className="home-subheading">{t("groupStudentsAcademics")}</h3>
      <MetricGrid data={data} keys={[
        "students", "activeStudents", "activeEnrollments", "studentsWithoutAccounts",
        "activeClasses", "activeClassesWithoutTeachers", "branches", "academicSessions",
      ]} />
      <h3 className="home-subheading">{t("groupLearningAssessment")}</h3>
      <MetricGrid data={data} keys={[
        "courses", "activeCourses", "lessons", "publishedLessons",
        "lessonProgressInProgress", "legacyCompletedProgress",
        "homeworkSubmissionsPendingReview", "homeworkSubmissionsGraded",
      ]} />
      <h3 className="home-subheading">{t("groupContentReadiness")}</h3>
      <MetricGrid data={data} keys={[
        "lessonsWithAssetPaths", "lessonsMissingContent", "pendingAdmissions",
      ]} />
      <section className="panel" aria-labelledby="operational-alerts-title">
        <h3 id="operational-alerts-title">{t("operationalAlerts")}</h3>
        {alerts.length
          ? <ul className="home-enquiry-list">{alerts.map((alert) => <li className="home-enquiry" key={alert.key}>
            <span>{format(data[alert.key])} · {t(alert.labelKey)}</span>
            <Link className="text-button" to={alert.to}>{t("reviewAction")}</Link>
          </li>)}</ul>
          : <p className="muted">{t("noAlerts")}</p>}
        {data.lessonsWithAssetPaths > 0 && <p className="data-note">
          {t("assetPathNote").replace("{count}", format(data.lessonsWithAssetPaths))}
        </p>}
      </section>
      <div className="home-section-grid">
        <section className="panel">
          <div className="home-panel-head">
            <h3>{t("unreadForAccount")}</h3>
            <Link className="text-button" to="/portal/modules/notifications">{t("openNotifications")}</Link>
          </div>
          {feed.loading && <p role="status">{t("loadingNotifications")}</p>}
          {feed.error && <p className="error-box" role="alert">{t("notificationsLoadFailed")}: {feed.error}</p>}
          {!feed.loading && !feed.error && <p className="learn-score">
            <strong>{format(feed.unread)}</strong> {t("unreadSuffix")}
          </p>}
          <p className="data-note">{t("notificationsScopeNote")}</p>
        </section>
        <section className="panel">
          <div className="home-panel-head">
            <h3>{t("mediaLimitsTitle")}</h3>
            <Link className="text-button" to="/portal/modules/courses">{t("reviewCourses")}</Link>
          </div>
          <p>{t("mediaLimitBody1")}</p>
          <p>{t("mediaLimitBody2")}</p>
        </section>
      </div>
      <div className="actions" style={{ marginTop: 16 }}>
        <Link className="button secondary" to="/portal/modules/roles">{t("manageAccountsRoles")}</Link>
        <Link className="button secondary" to="/portal/modules/reports">{t("reports")}</Link>
      </div>
    </>}
  </section>;
}