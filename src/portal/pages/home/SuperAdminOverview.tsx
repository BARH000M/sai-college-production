import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { loadSuperAdminSummary, type SuperAdminSummary } from "../../lib/roles";
import { useNotificationFeed } from "../../hooks/useNotificationFeed";

type SummaryState =
  | { status: "loading"; data: null; error: null }
  | { status: "ready"; data: SuperAdminSummary; error: null }
  | { status: "error"; data: null; error: string };

type SummaryKey = keyof SuperAdminSummary;

const errorMessage = (error: unknown) => error instanceof Error ? error.message : String(error);

function Metric({ label, value, note, to }: {
  label: string;
  value: number;
  note?: string;
  to?: string;
}) {
  const content = <>
    <span>{label}</span>
    <strong>{value.toLocaleString("ar")}</strong>
    {note && <small>{note}</small>}
  </>;
  return to
    ? <Link className="kpi-card" to={to}>{content}</Link>
    : <div className="kpi-card">{content}</div>;
}

function MetricGrid({ data, keys }: { data: SuperAdminSummary; keys: readonly SummaryKey[] }) {
  const labels: Record<SummaryKey, string> = {
    totalUsers: "إجمالي حسابات الدخول",
    emailConfirmedUsers: "حسابات مؤكدة البريد",
    pendingEmailConfirmation: "بانتظار تأكيد البريد",
    bannedUsers: "حسابات موقوفة مؤقتاً",
    usersWithoutRoles: "حسابات بلا أدوار",
    totalProfiles: "ملفات المستخدمين",
    totalRoleAssignments: "إسنادات الأدوار",
    teachers: "حسابات بدور معلم",
    students: "إجمالي الطلاب",
    activeStudents: "الطلاب النشطون",
    studentsWithoutAccounts: "طلاب بلا حساب مرتبط",
    activeClasses: "الصفوف النشطة",
    activeClassesWithoutTeachers: "صفوف بلا معلم مسند",
    branches: "الفروع",
    academicSessions: "الجلسات الأكاديمية",
    courses: "إجمالي المقررات",
    activeCourses: "المقررات النشطة",
    lessons: "إجمالي الدروس",
    publishedLessons: "الدروس المنشورة",
    lessonsWithAssetPaths: "دروس لها مسارات وسائط مسجلة",
    lessonsMissingContent: "دروس بلا محتوى مسجل",
    activeEnrollments: "طلاب نشطون مسندون إلى صف",
    lessonProgressInProgress: "حالات تعلم قيد الدراسة",
    legacyCompletedProgress: "حالات إكمال تاريخية غير متحققة",
    homeworkSubmissionsPendingReview: "تسليمات بانتظار التصحيح",
    homeworkSubmissionsGraded: "تسليمات صُححت",
    pendingAdmissions: "طلبات قبول جديدة",
  };
  return <div className="kpi-grid home-kpi-grid">
    {keys.map((key) => <Metric
      key={key}
      label={labels[key]}
      value={data[key]}
      to={key === "pendingAdmissions" ? "/portal/modules/admissions" : undefined}
    />)}
  </div>;
}

export function SuperAdminOverview() {
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

  return <section className="panel super-admin-overview" aria-labelledby="super-admin-overview-title">
    <div className="home-panel-head">
      <div>
        <p className="eyebrow">إشراف الإدارة العامة</p>
        <h2 id="super-admin-overview-title">مؤشرات النظام من الخدمات المعتمدة</h2>
      </div>
      <div className="actions">
        <Link className="button secondary" to="/portal/modules/systemCatalog">جرد الوحدات</Link>
        <button className="button secondary" type="button" onClick={() => setRetry((value) => value + 1)}
          disabled={state.status === "loading"}>تحديث المؤشرات</button>
      </div>
    </div>
    <p className="data-note">
      الأعداد تُقرأ من ملخص Edge Function المخصص للمسؤول العام. لا تمثل حالات الإكمال التاريخية إتقاناً موثقاً،
      ومسارات الوسائط المسجلة لا تثبت وجود الملف في التخزين.
    </p>

    {state.status === "loading" && <p role="status">جارٍ تحميل مؤشرات النظام...</p>}
    {state.status === "error" && <div className="error-box" role="alert">
      تعذر تحميل مؤشرات النظام: {state.error}
      <button className="text-button" type="button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button>
    </div>}

    {data && <>
      <h3 className="home-subheading">الحسابات والهوية</h3>
      <MetricGrid data={data} keys={[
        "totalUsers", "totalProfiles", "totalRoleAssignments", "teachers",
        "emailConfirmedUsers", "pendingEmailConfirmation", "bannedUsers",
        "usersWithoutRoles",
      ]} />
      <h3 className="home-subheading">الطلاب والأكاديميا</h3>
      <MetricGrid data={data} keys={[
        "students", "activeStudents", "activeEnrollments", "studentsWithoutAccounts",
        "activeClasses", "activeClassesWithoutTeachers", "branches", "academicSessions",
      ]} />
      <h3 className="home-subheading">التعلّم والتقييم</h3>
      <MetricGrid data={data} keys={[
        "courses", "activeCourses", "lessons", "publishedLessons",
        "lessonProgressInProgress", "legacyCompletedProgress",
        "homeworkSubmissionsPendingReview", "homeworkSubmissionsGraded",
      ]} />
      <h3 className="home-subheading">جاهزية المحتوى والتنبيهات التشغيلية</h3>
      <MetricGrid data={data} keys={[
        "lessonsWithAssetPaths", "lessonsMissingContent", "pendingAdmissions",
      ]} />
      <section className="panel" aria-labelledby="operational-alerts-title">
        <h3 id="operational-alerts-title">تنبيهات تحتاج متابعة</h3>
        {(() => {
          const allAlerts: { key: SummaryKey; to: string; text: string }[] = [
            { key: "pendingAdmissions", to: "/portal/modules/admissions", text: "طلبات قبول جديدة تنتظر التواصل" },
            { key: "homeworkSubmissionsPendingReview", to: "/portal/modules/homework", text: "تسليمات واجبات تنتظر التصحيح" },
            { key: "activeClassesWithoutTeachers", to: "/portal/modules/classes", text: "صفوف نشطة بلا معلم مسند" },
            { key: "studentsWithoutAccounts", to: "/portal/modules/students", text: "سجلات طلاب نشطة بلا حساب مرتبط" },
            { key: "usersWithoutRoles", to: "/portal/modules/roles", text: "حسابات دخول بلا دور" },
            { key: "pendingEmailConfirmation", to: "/portal/modules/roles", text: "حسابات بانتظار تأكيد البريد" },
            { key: "lessonsMissingContent", to: "/portal/modules/courses", text: "دروس بلا محتوى مسجل" },
          ];
          const alerts = allAlerts.filter((alert) => data[alert.key] > 0);
          return alerts.length
            ? <ul className="home-enquiry-list">{alerts.map((alert) => <li className="home-enquiry" key={alert.key}>
              <span>{data[alert.key].toLocaleString("ar")} · {alert.text}</span>
              <Link className="text-button" to={alert.to}>مراجعة</Link>
            </li>)}</ul>
            : <p className="muted">لا توجد تنبيهات في المؤشرات المعروضة.</p>;
        })()}
        {data.lessonsWithAssetPaths > 0 && <p className="data-note">
          توجد {data.lessonsWithAssetPaths.toLocaleString("ar")} إحالات لمسارات ملفات؛ لم يتحقق هذا الملخص من وجود الملفات فعلياً في Storage.
        </p>}
      </section>
      <div className="home-section-grid">
        <section className="panel">
          <div className="home-panel-head">
            <h3>الإشعارات غير المقروءة لهذا الحساب</h3>
            <Link className="text-button" to="/portal/modules/notifications">فتح الإشعارات</Link>
          </div>
          {feed.loading && <p role="status">جارٍ تحميل الإشعارات...</p>}
          {feed.error && <p className="error-box" role="alert">تعذر تحميل الإشعارات: {feed.error}</p>}
          {!feed.loading && !feed.error && <p className="learn-score">
            <strong>{feed.unread.toLocaleString("ar")}</strong> غير مقروءة
          </p>}
          <p className="data-note">هذا العدد خاص بحساب المسؤول العام الحالي، وليس إجمالي إشعارات جميع المستخدمين.</p>
        </section>
        <section className="panel">
          <div className="home-panel-head">
            <h3>حدود مؤشرات الوسائط والتقييم</h3>
            <Link className="text-button" to="/portal/modules/courses">مراجعة المقررات</Link>
          </div>
          <p>المهام المصححة هي تسليمات واجبات موجودة؛ لا يوجد بنك امتحانات أو إحصاء موثوق لمحاولات اختبارات في العقد الحالي.</p>
          <p>مسارات الملفات مؤشرات مرجعية فقط. يلزم فحص وجود كائنات التخزين المصرح بها قبل وصف الوسائط بأنها جاهزة.</p>
        </section>
      </div>
      <div className="actions" style={{ marginTop: 16 }}>
        <Link className="button secondary" to="/portal/modules/roles">إدارة الحسابات والأدوار</Link>
        <Link className="button secondary" to="/portal/modules/reports">التقارير</Link>
      </div>
    </>}
  </section>;
}
