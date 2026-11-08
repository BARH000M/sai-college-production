import { supabase } from "./supabase";

export type LinkableAccount = {
  id: string;
  fullName: string;
  email: string;
  roles: string[];
  linkedStudentId: string | null;
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