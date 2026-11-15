import { supabase } from "./supabase";

export type LinkableAccount = {
  id: string;
  fullName: string;
  email: string;
  roles: string[];
  linkedStudentId: string | null;
};

export type ParentStudentLink = {
  parent_user_id: string;
  full_name: string;
  email: string | null;
  is_verified: boolean;
  verified_at: string | null;
};

type ListResponse = { ok?: boolean; users?: LinkableAccount[]; message?: string };
type ActionResponse = { ok?: boolean; email?: string | null; message?: string };

function failure(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export async function loadLinkableAccounts(): Promise<LinkableAccount[]> {
  try {
    const { data, error } = await supabase.functions.invoke<ListResponse>("link-student-account", {
      body: { action: "list" },
    });
    if (error) throw new Error(error.message);
    if (!data || data.ok !== true) throw new Error(data?.message ?? "تعذر تحميل قائمة الحسابات.");
    return data.users ?? [];
  } catch (error) {
    throw new Error(failure(error));
  }
}

export async function linkStudentAccount(studentId: string, userId: string): Promise<string | null> {
  const { data, error } = await supabase.functions.invoke<ActionResponse>("link-student-account", {
    body: { action: "link", studentId, userId },
  });
  if (error) throw new Error(error.message);
  if (!data || data.ok !== true) throw new Error(data?.message ?? "تعذر ربط الحساب.");
  return data.email ?? null;
}

export async function unlinkStudentAccount(studentId: string): Promise<void> {
  const { data, error } = await supabase.functions.invoke<ActionResponse>("link-student-account", {
    body: { action: "unlink", studentId },
  });
  if (error) throw new Error(error.message);
  if (!data || data.ok !== true) throw new Error(data?.message ?? "تعذر فك ربط الحساب.");
}

export async function loadParentStudentLinks(studentId: string): Promise<ParentStudentLink[]> {
  const { data, error } = await supabase.rpc("admissions_list_parent_links", {
    p_student_id: studentId,
  });
  if (error) throw new Error(error.message);
  if (!Array.isArray(data)) throw new Error("تعذر تحميل روابط أولياء الأمور.");
  return data.map((row) => {
    if (!row || typeof row.parent_user_id !== "string" || typeof row.full_name !== "string"
      || typeof row.is_verified !== "boolean") {
      throw new Error("أعاد الخادم بيانات روابط غير صالحة.");
    }
    return {
      parent_user_id: row.parent_user_id,
      full_name: row.full_name,
      email: typeof row.email === "string" ? row.email : null,
      is_verified: row.is_verified,
      verified_at: typeof row.verified_at === "string" ? row.verified_at : null,
    };
  });
}

export async function verifyParentStudent(studentId: string, parentUserId: string): Promise<void> {
  const { error } = await supabase.rpc("admissions_verify_parent_student", {
    p_student_id: studentId,
    p_parent_user_id: parentUserId,
  });
  if (error) throw new Error(error.message);
}