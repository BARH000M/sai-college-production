import { supabase } from "./supabase";

// Every role the super administrator can grant, with its Arabic label and
// whether it joins the campus team (staff) or not (families).
export const assignableRoles = [
  { id: "admin", label: "مدير / مسجّل", staff: true },
  { id: "teacher", label: "معلم", staff: true },
  { id: "receptionist", label: "استقبال", staff: true },
  { id: "accountant", label: "محاسب", staff: true },
  { id: "librarian", label: "أمين مكتبة", staff: true },
  { id: "content_editor", label: "محرر محتوى", staff: true },
  { id: "student", label: "طالب", staff: false },
  { id: "parent", label: "ولي أمر", staff: false },
  { id: "super_admin", label: "مسؤول عام", staff: true },
] as const;

export type AssignableRole = (typeof assignableRoles)[number]["id"];

const assignableIds = new Set<string>(assignableRoles.map((role) => role.id));
export function isAssignableRole(value: string): value is AssignableRole {
  return assignableIds.has(value);
}

export type DirectoryUser = {
  id: string;
  fullName: string;
  email: string;
  roles: string[];
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
  summary?: SuperAdminSummary;
  message?: string;
};

function failureMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

async function call(body: Record<string, unknown>): Promise<FunctionResponse> {
  const { data, error } = await supabase.functions.invoke<FunctionResponse>("manage-roles", { body });
  if (error) throw new Error(error.message);
  if (!data || data.ok !== true) throw new Error(data?.message ?? "تعذر تنفيذ الطلب.");
  return data;
}

export async function loadDirectoryUsers(): Promise<DirectoryUser[]> {
  try {
    const data = await call({ action: "list" });
    return (data.users ?? []).map((user) => ({ ...user, roles: [...user.roles] }));
  } catch (error) {
    throw new Error(failureMessage(error));
  }
}

export async function loadSuperAdminSummary(): Promise<SuperAdminSummary> {
  const data = await call({ action: "summary" });
  if (!data.summary) throw new Error("استجابة ملخص الإدارة العامة غير مكتملة.");
  return data.summary;
}

export async function changeUserRole(userId: string, role: AssignableRole, grant: boolean): Promise<void> {
  await call({ action: grant ? "grant" : "revoke", userId, role });
}