import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useNotificationFeed } from "@/portal/hooks/useNotificationFeed";
import {
  formatNotificationTime, markNotificationsSeen, notificationCategoryIcons, notificationCategoryLabels,
  type NotificationCategory,
} from "@/portal/lib/notifications";
import { LabPage, LabStats, LabTabs } from "@/portal/pages/labs/LabShell";

type Tab = "all" | NotificationCategory;

export function NotificationsPage({ roles }: { roles: readonly string[] }) {
  const { items, userId, seenAt, loading, error, unread, refresh, applySeen } = useNotificationFeed(roles);
  const [tab, setTab] = useState<Tab>("all");

  const counts = useMemo(() => ({
    admissions: items.filter((item) => item.category === "admissions").length,
    homework: items.filter((item) => item.category === "homework").length,
    attendance: items.filter((item) => item.category === "attendance").length,
  }), [items]);

  const visible = tab === "all" ? items : items.filter((item) => item.category === tab);
  const seenTime = seenAt ? new Date(seenAt).getTime() : 0;

  const [marking, setMarking] = useState(false);

  async function markAll() {
    if (!userId || marking) return;
    setMarking(true);
    try {
      applySeen(await markNotificationsSeen(userId));
    } finally {
      setMarking(false);
    }
  }

  return <LabPage
    eyebrow="مركز التنبيهات"
    title="الإشعارات"
    intro="كل ما يحتاج انتباهك في مكان واحد: طلبات القبول الجديدة، الواجبات التي تنتظر التصحيح، وتسجيلات الغياب والتأخر."
    badge={unread > 0 ? `${unread} غير مقروء` : "لا جديد"}
  >
    {loading && <p className="muted" role="status">جارٍ تحميل الإشعارات...</p>}
    {error && <p className="error-box" role="alert">تعذر تحميل الإشعارات: {error} <button className="text-button" onClick={() => void refresh()}>إعادة المحاولة</button></p>}

    {!loading && !error && <>
      <LabStats items={[
        { label: "إجمالي الإشعارات", value: String(items.length), detail: "آخر ٦٠ تحديثاً" },
        { label: "غير مقروءة", value: String(unread), detail: unread ? "تحتاج مراجعة" : "كل شيء مقروء" },
        { label: "القبول والتسجيل", value: String(counts.admissions), detail: "طلبات جديدة" },
        { label: "الحضور", value: String(counts.attendance), detail: "غياب وتأخر مسجل" },
      ]} />

      <div className="lab-toolbar">
        <LabTabs
          label="تصفية الإشعارات"
          value={tab}
          onChange={setTab}
          tabs={[
            { id: "all", label: `الكل (${items.length})`, icon: "ri-inbox-line" },
            { id: "admissions", label: `القبول (${counts.admissions})`, icon: "ri-user-add-line" },
            { id: "homework", label: `الواجبات (${counts.homework})`, icon: "ri-task-line" },
            { id: "attendance", label: `الحضور (${counts.attendance})`, icon: "ri-calendar-check-line" },
          ]}
        />
        <div className="lab-toolbar-end">
          <button className="button secondary" type="button" onClick={() => void refresh()}>
            <i className="ri-refresh-line" aria-hidden="true"></i> تحديث
          </button>
          <button className="button primary" type="button" onClick={() => void markAll()} disabled={!unread || marking}>
            <i className="ri-check-double-line" aria-hidden="true"></i> {marking ? "جارٍ الحفظ..." : "تحديد الكل كمقروء"}
          </button>
        </div>
      </div>

      <section className="panel">
        <div className="page-heading">
          <div>
            <h2>{tab === "all" ? "أحدث الإشعارات" : notificationCategoryLabels[tab]}</h2>
            <p className="data-note">تُعرض السجلات التي تسمح بها صلاحيات حسابك فقط، الأحدث أولاً.</p>
          </div>
          <span className="lab-pill-count">{visible.length} إشعار</span>
        </div>

        {!visible.length
          ? <div className="notify-empty">
            <span className="notify-empty-icon"><i className="ri-notification-off-line" aria-hidden="true"></i></span>
            <strong>لا توجد إشعارات في هذا القسم</strong>
            <p className="muted">عندما يصل طلب قبول جديد أو تسليم واجب أو غياب مسجل، سيظهر هنا تلقائياً.</p>
          </div>
          : <ul className="notify-list">
            {visible.map((item) => {
              const isUnread = new Date(item.at).getTime() > seenTime;
              return <li key={item.id}>
                <Link className={`notify-item${isUnread ? " unread" : ""}`} to={item.href}>
                  <span className={`notify-icon notify-${item.category}`}>
                    <i className={notificationCategoryIcons[item.category]} aria-hidden="true"></i>
                  </span>
                  <span className="notify-body">
                    <strong>{item.title}</strong>
                    <small>{item.detail}</small>
                  </span>
                  <span className="notify-meta">
                    <span className="lab-tag">{notificationCategoryLabels[item.category]}</span>
                    <time>{formatNotificationTime(item.at)}</time>
                  </span>
                  <i className="ri-arrow-left-s-line notify-arrow" aria-hidden="true"></i>
                </Link>
              </li>;
            })}
          </ul>}
      </section>

      <p className="data-note">تُحفظ علامة «مقروء» في حسابك على الخادم، فتظهر على أي جهاز تدخل منه، ولا تؤثر على سجلات الطلاب أو إشعارات الواجبات في صفحة الواجبات.</p>
    </>}
  </LabPage>;
}