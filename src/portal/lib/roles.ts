import { supabase } from "./supabase";
import { functionFailure } from "./functionErrors";

// Every role the super administrator can grant, with its Arabic label and
// whether it joins the campus team (staff) or not (families).
export const assignableRoles = [
  { id: "admin", label: "مدير / مسجّل", staff: true, branchScoped: true },
  { id: "teacher", label: "معلم", staff: true, branchScoped: true },
  { id: "receptionist", label: "استقبال", staff: true, branchScoped: true },
  { id: "accountant", label: "محاسب", staff: true, branchScoped: true },
  { id: "librarian", label: "أمين مكتبة", staff: true, branchScoped: true },
  { id: "content_editor", label: "محرر محتوى", staff: true, branchScoped: true },
  { id: "student", label: "طالب", staff: false, branchScoped: false },
  { id: "parent", label: "ولي أمر", staff: false, branchScoped: false },
  { id: "super_admin", label: "مسؤول عام", staff: true, branchScoped: false },
] as const;

export type AssignableRole = (typeof assignableRoles)[number]["id"];
export type BranchOption = { id: string; name: string };

const assignableIds = new Set<string>(assignableRoles.map((role) => role.id));
export function isAssignableRole(value: string): value is AssignableRole {
  return assignableIds.has(value);
}

export function isBranchScopedRole(role: AssignableRole): boolean {
  return assignableRoles.find((item) => item.id === role)?.branchScoped ?? false;
}

export type DirectoryUser = {
  id: string;
  fullName: string;
  email: string;
  roles: string[];
  branchIds: string[];
  createdAt: string;
  emailConfirmed: boolean;
  profileMissing: boolean;
};

export type SuperAdminSummary = {
  totalUsers: number;
  emailConfirmedUsers: number;
  pendingEmailConfirmation: number;
  bannedUsers: number;
  usersWithoutRoles: number;
  totalProfiles: number;
  totalRoleAssignments: number;
  teachers: number;
  students: number;
  activeStudents: number;
  studentsWithoutAccounts: number;
  activeClasses: number;
  activeClassesWithoutTeachers: number;
  branches: number;
  academicSessions: number;
  courses: number;
  activeCourses: number;
  lessons: number;
  publishedLessons: number;
  lessonsWithAssetPaths: number;
  lessonsMissingContent: number;
  activeEnrollments: number;
  lessonProgressInProgress: number;
  legacyCompletedProgress: number;
  homeworkSubmissionsPendingReview: number;
  homeworkSubmissionsGraded: number;
  pendingAdmissions: number;
};

type FunctionResponse = {
  ok?: boolean;
  users?: DirectoryUser[];
  branches?: BranchOption[];
  summary?: SuperAdminSummary;
  message?: string;
  code?: string;
};

function failureMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

async function call(body: Record<string, unknown>): Promise<FunctionResponse> {
  const { data, error } = await supabase.functions.invoke<FunctionResponse>("manage-roles", { body });
  if (error) throw await functionFailure(error, "manage-roles");
  if (!data || data.ok !== true) throw new Error(data?.message ?? "تعذر تنفيذ الطلب.");
  return data;
}

export async function loadDirectoryUsers(): Promise<{ users: DirectoryUser[]; branches: BranchOption[] }> {
  try {
    const data = await call({ action: "list" });
    if (!Array.isArray(data.users) || !Array.isArray(data.branches) || data.users.some((user) => !Array.isArray(user.branchIds))) {
      throw new Error("استجابة إدارة الأدوار لا تتضمن قائمة الحسابات ونطاق الفروع؛ يلزم نشر عقد الخدمة المعتمد قبل استخدام هذه الشاشة.");
    }
    return {
      users: data.users.map((user) => ({
        ...user,
        roles: [...user.roles],
        branchIds: [...user.branchIds],
      })),
      branches: data.branches,
    };
  } catch (error) {
    throw new Error(failureMessage(error));
  }
}

export async function loadSuperAdminSummary(): Promise<SuperAdminSummary> {
  const data = await call({ action: "summary" });
  if (!data.summary) throw new Error("استجابة ملخص الإدارة العامة غير مكتملة.");
  return data.summary;
}

export async function changeUserRole(
  userId: string,
  role: AssignableRole,
  grant: boolean,
  branchIds: readonly string[] = [],
  confirmSuperAdminGrant = false,
): Promise<void> {
  await call({
    action: grant ? "grant" : "revoke",
    userId,
    role,
    branchIds: [...branchIds],
    confirmSuperAdminGrant,
  });
}
