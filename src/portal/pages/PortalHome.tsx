import { StaffHome } from "./home/StaffHome";
import { TeacherHome } from "./home/TeacherHome";
import { ParentHome } from "./home/FamilyHome";
import { LearnerHome } from "./LearnerHome";
import { StatusCard } from "../components/StatusCard";

const staffRoles = ["super_admin", "admin", "receptionist", "accountant", "librarian", "content_editor"];

export function PortalHome({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  if (!userId) {
    return <StatusCard title="تعذر تحديد الحساب" message="أعد تسجيل الدخول للوصول إلى لوحتك." />;
  }
  if (roles.some((role) => staffRoles.includes(role))) return <StaffHome />;
  if (roles.includes("teacher")) return <TeacherHome userId={userId} />;
  if (roles.includes("student")) return <LearnerHome roles={roles} userId={userId} />;
  if (roles.includes("parent")) return <ParentHome userId={userId} />;
  return <StatusCard title="لا يوجد دور بعد" message="سيظهر محتوى لوحتك بعد اعتماد دورك من الإدارة." />;
}

export default PortalHome;