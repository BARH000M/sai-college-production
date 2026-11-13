import { Link, useParams } from "react-router-dom";
import { canAccessModule, isModuleAvailable, navigation, pendingModules } from "../lib/navigation";
import { ManagementPage } from "./ManagementPage";
import { Admissions } from "./Admissions";
import { Scanner } from "./Scanner";
import { Learning } from "./Learning";
import { Roles } from "./Roles";
import { Attendance } from "./Attendance";
import { Reports } from "./Reports";
import { Cms } from "./Cms";
import { AcademicAffairs } from "./academics/AcademicAffairs";
import { QrAttendance } from "./academics/QrAttendance";
import { Timetable } from "./academics/Timetable";
import { VocabularyPage } from "./vocabulary/VocabularyPage";
import { NotificationsPage } from "./Notifications";
import { Library } from "./Library";
import { Communications } from "./Communications";
import { Finance } from "./Finance";
import { SystemSettings } from "./SystemSettings";
import { SystemInventory } from "./SystemInventory";
import { UnifiedModulePage } from "./UnifiedModulePage";
import { unifiedModules, type UnifiedId } from "../lib/unifiedModules";

export function ModuleEntry({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const { moduleId } = useParams();
  const item = navigation.find((entry) => entry.id === moduleId && entry.id !== "home");
  if (!item) return <main className="workspace"><section className="panel"><h1>الصفحة غير موجودة</h1><Link to="/portal/dashboard">العودة للرئيسية</Link></section></main>;
  if (!canAccessModule(item.id, roles)) {
    return <main className="workspace"><section className="panel" role="alert"><h1>الوصول غير متاح</h1><p>هذا القسم غير متاح للأدوار المسندة إلى حسابك.</p><Link to="/portal/dashboard">العودة للرئيسية</Link></section></main>;
  }
  if (!isModuleAvailable(item.id)) {
    const pending = pendingModules.find((entry) => entry.id === item.id);
    return <main className="workspace"><section className="panel">
      <p className="eyebrow">كلية ساي</p><h1>{item.label}</h1>
      <p className="muted">هذا القسم قيد التجهيز ولم يُفعَّل بعد، لذلك لا يظهر في القائمة الجانبية.</p>
      {pending && <p className="data-note">{pending.reason}</p>}
      <div className="actions" style={{ marginTop: 12 }}>
        <Link className="button secondary" to="/portal/dashboard">العودة للرئيسية</Link>
      </div>
    </section></main>;
  }
  if (item.id === "branches" || item.id === "sessions" || item.id === "classes" || item.id === "students") {
    return <ManagementPage key={item.id} kind={item.id} roles={roles} userId={userId} />;
  }
  if (item.id === "roles") return <Roles />;
  if (item.id === "reports") return <Reports roles={roles} />;
  if (item.id === "cms") return <Cms roles={roles} />;
  if (item.id === "admissions") return <Admissions roles={roles} userId={userId} />;
  if (item.id === "scanner") return <Scanner roles={roles} />;
  if (item.id === "attendance") return <Attendance roles={roles} userId={userId} />;
  if (item.id === "courses") return <Learning key={`courses:${userId}`} view="courses" roles={roles} userId={userId} />;
  if (item.id === "homework") return <Learning key={`homework:${userId}`} view="homework" roles={roles} userId={userId} />;
  if (item.id === "progress") return <Learning key={`progress:${userId}`} view="progress" roles={roles} userId={userId} />;
  if (item.id === "timetable") return <Timetable />;
  if (item.id === "academics") return <AcademicAffairs />;
  if (item.id === "qr") return <QrAttendance />;
  if (item.id === "vocabulary") return <VocabularyPage roles={roles} />;
  if (item.id === "notifications") return <NotificationsPage roles={roles} />;
  if (item.id === "library") return <Library roles={roles} userId={userId} />;
  if (item.id === "communications") return <Communications roles={roles} userId={userId} />;
  if (item.id === "finance") return <Finance roles={roles} userId={userId} />;
  if (item.id === "settings") return <SystemSettings roles={roles} />;
  if (item.id === "systemCatalog") return <SystemInventory />;
  if (Object.prototype.hasOwnProperty.call(unifiedModules, item.id)) {
    return <UnifiedModulePage key={item.id} roles={roles} spec={unifiedModules[item.id as UnifiedId]} />;
  }
  return <main className="workspace"><section className="panel">
    <p className="eyebrow">كلية ساي</p><h1>{item.label}</h1>
    <p className="muted">هذا القسم غير متاح بعد. لم تُفعّل وظائفه في التطبيق.</p>
    <Link className="button secondary" to="/portal/dashboard">العودة للرئيسية</Link>
  </section></main>;
}
