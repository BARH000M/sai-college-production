import { useState } from "react";
import { Link } from "react-router-dom";
import { UnifiedModulePage } from "../UnifiedModulePage";
import { unifiedModules } from "../../lib/unifiedModules";
import { PayrollPanel } from "./PayrollPanel";
import { LeavePanel } from "./LeavePanel";

type HrTab = "employees" | "payroll" | "leaves";

const TABS: { id: HrTab; label: string; icon: string; roles: readonly string[] }[] = [
  { id: "employees", label: "دليل الموظفين", icon: "ri-team-line", roles: ["super_admin", "admin"] },
  { id: "payroll", label: "الرواتب", icon: "ri-wallet-3-line", roles: ["super_admin", "admin", "accountant"] },
  { id: "leaves", label: "الإجازات", icon: "ri-calendar-event-line", roles: ["super_admin", "admin"] },
];

function TabBar({ active, onChange, roles }: { active: HrTab; onChange: (tab: HrTab) => void; roles: readonly string[] }) {
  const visible = TABS.filter((tab) => tab.roles.some((role) => roles.includes(role)));
  return (
    <div className="hr-tabs" role="tablist" aria-label="أقسام الموارد البشرية">
      {visible.map((tab) => (
        <button
          key={tab.id}
          type="button"
          role="tab"
          aria-selected={active === tab.id}
          className={`hr-tab ${active === tab.id ? "is-active" : ""}`}
          onClick={() => onChange(tab.id)}
        >
          <span className="hr-tab-icon" aria-hidden="true"><i className={tab.icon} /></span>
          {tab.label}
        </button>
      ))}
    </div>
  );
}

export function HrPage({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const [tab, setTab] = useState<HrTab>(() => (TABS.find((entry) => entry.roles.some((role) => roles.includes(role)))?.id ?? "employees"));
  const permitted = TABS.some((entry) => entry.roles.some((role) => roles.includes(role)));

  if (!permitted) {
    return <main className="workspace"><section className="panel"><h1>الوصول غير متاح</h1>
      <p className="muted">وحدة الموارد البشرية متاحة للإدارة فقط.</p>
      <Link className="button secondary" to="/portal/dashboard">العودة للرئيسية</Link></section></main>;
  }

  if (tab === "employees") {
    return <UnifiedModulePage roles={roles} spec={unifiedModules.staff} headerExtra={<TabBar active={tab} onChange={setTab} roles={roles} />} />;
  }

  return <main className="workspace" dir="rtl">
    <section className="panel">
      <p className="eyebrow">الموارد البشرية</p>
      <h1>{tab === "payroll" ? "مسير الرواتب" : "إدارة الإجازات"}</h1>
      <TabBar active={tab} onChange={setTab} roles={roles} />
    </section>
    {tab === "payroll" && <PayrollPanel roles={roles} userId={userId} />}
    {tab === "leaves" && <LeavePanel roles={roles} userId={userId} />}
  </main>;
}