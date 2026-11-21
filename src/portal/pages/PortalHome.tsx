import { StaffHome } from "./home/StaffHome";
import { SpecialistHome } from "./home/SpecialistHome";
import { TeacherHome } from "./home/TeacherHome";
import { ParentHome } from "./home/FamilyHome";
import { LearnerHome } from "./LearnerHome";
import { StatusCard } from "../components/StatusCard";
import { usePortalLang } from "../lib/portalLangContext";

const adminRoles = ["super_admin", "admin"];
const specialistRoles = ["accountant", "receptionist", "librarian", "content_editor"];

export function PortalHome({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const { t } = usePortalLang();

  if (!userId) {
    return <StatusCard title={t("accountNotIdentified")} message={t("accountNotIdentifiedBody")} />;
  }
  if (roles.includes("super_admin")) return <StaffHome superAdmin />;
  if (roles.some((role) => adminRoles.includes(role))) return <StaffHome />;
  if (roles.includes("teacher")) return <TeacherHome userId={userId} />;
  if (roles.some((role) => specialistRoles.includes(role))) return <SpecialistHome roles={roles} />;
  if (roles.includes("student")) return <LearnerHome roles={roles} userId={userId} />;
  if (roles.includes("parent")) return <ParentHome userId={userId} />;
  return <StatusCard title={t("noRoleYetTitle")} message={t("noRoleYetBody")} />;
}

export default PortalHome;