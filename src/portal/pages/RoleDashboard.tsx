import { Link } from "react-router-dom";
import { isAppRole, modulePath, roleLabels, visibleNavigation } from "../lib/navigation";

export function RoleDashboard({ roles }: { roles: readonly string[] }) {
  const modules = visibleNavigation(roles).filter((item) => item.id !== "home");
  return <main className="workspace">
    <p className="eyebrow">كلية ساي التعليمية اليمنية الصينية</p>
    <h1>لوحة التحكم</h1>
    <p className="muted">الأدوار المسندة: {roles.filter(isAppRole).map((role) => roleLabels[role]).join(" · ")}</p>
    <section className="panel" aria-labelledby="modules-title">
      <h2 id="modules-title">الأقسام المتاحة لحسابك</h2>
      <p className="data-note">تحدد الأدوار التنقل فقط؛ تُفرض صلاحيات البيانات في قاعدة البيانات.</p>
      {modules.length ? <div className="module-grid">{modules.map((item) =>
        <Link className="module-card" key={item.id} to={modulePath(item)}><strong>{item.label}</strong><small>عرض القسم</small></Link>
      )}</div> : <p className="muted">لا توجد أقسام إضافية متاحة لهذا الحساب.</p>}
    </section>
  </main>;
}
