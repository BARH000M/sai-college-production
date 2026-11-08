import { Link, useParams } from "react-router-dom";
import { navigation, visibleNavigation } from "../lib/navigation";
import { ManagementPage } from "./ManagementPage";
import { Admissions } from "./Admissions";

export function ModuleEntry({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const { moduleId } = useParams();
  const item = navigation.find((entry) => entry.id === moduleId && entry.id !== "home");
  if (!item) return <main className="workspace"><section className="panel"><h1>الصفحة غير موجودة</h1><Link to="/dashboard">العودة للرئيسية</Link></section></main>;
  if (!visibleNavigation(roles).some((entry) => entry.id === item.id)) {
    return <main className="workspace"><section className="panel" role="alert"><h1>الوصول غير متاح</h1><p>هذا القسم غير متاح للأدوار المسندة إلى حسابك.</p><Link to="/dashboard">العودة للرئيسية</Link></section></main>;
  }
  if (item.id === "branches" || item.id === "sessions" || item.id === "classes" || item.id === "students") {
    return <ManagementPage key={item.id} kind={item.id} roles={roles} userId={userId} />;
  }
  if (item.id === "admissions") return <Admissions roles={roles} userId={userId} />;
  return <main className="workspace"><section className="panel">
    <p className="eyebrow">كلية ساي</p><h1>{item.label}</h1>
    <p className="muted">هذا القسم غير متاح بعد. لم تُفعّل وظائفه في التطبيق.</p>
    <Link className="button secondary" to="/dashboard">العودة للرئيسية</Link>
  </section></main>;
}
