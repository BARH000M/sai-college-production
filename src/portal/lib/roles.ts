import { supabase } from "./supabase";

export const assignableRoles = [
  { id: "teacher", label: "معلم" },
  { id: "parent", label: "ولي أمر" },
  { id: "student", label: "طالب" },
] as const;

export type AssignableRole = (typeof assignableRoles)[number]["id"];

export type DirectoryUser = {
  id: string;
  fullName: string;
  email: string;
  roles: string[];
  createdAt: string;
  profileMissing: boolean;
};

type FunctionResponse = {
  ok?: boolean;
  users?: DirectoryUser[];
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
    return data.users ?? [];
  } catch (error) {
    throw new Error(failureMessage(error));
  }
}

export async function changeUserRole(userId: string, role: AssignableRole, grant: boolean): Promise<void> {
  await call({ action: grant ? "grant" : "revoke", userId, role });
}