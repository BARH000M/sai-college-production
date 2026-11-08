import { supabase } from "./supabase";

export type ManagementKind = "branches" | "sessions" | "classes" | "students";
export type ManagementRow = {
  id: string;
  name?: string;
  code?: string;
  address?: string | null;
  is_active?: boolean;
  starts_on?: string;
  ends_on?: string;
  branch_id?: string;
  session_id?: string;
  program?: string;
  capacity?: number;
  teacher_id?: string | null;
  user_id?: string | null;
  admission_no?: string;
  full_name?: string;
  date_of_birth?: string | null;
  class_id?: string | null;
  status?: string;
};
export type Option = { id: string; name: string };
export type ManagementFilters = {
  search: string;
  branch: string;
  session: string;
  classId: string;
  status: string;
  page: number;
};

const tables: Record<ManagementKind, string> = {
  branches: "branches",
  sessions: "academic_sessions",
  classes: "classes",
  students: "students",
};
const columns: Record<ManagementKind, string> = {
  branches: "id,name,code,address,is_active",
  sessions: "id,name,starts_on,ends_on,is_active",
  classes: "id,name,branch_id,session_id,program,capacity,teacher_id,is_active",
  students: "id,user_id,branch_id,admission_no,full_name,date_of_birth,class_id,status",
};
export const pageSize = 25;

export function managementAccess(kind: ManagementKind, roles: readonly string[]) {
  const isSuperAdmin = roles.includes("super_admin");
  const isAdmin = roles.includes("admin");
  return {
    canCreate: isSuperAdmin || (isAdmin && kind !== "branches" && kind !== "sessions"),
    canEdit: isSuperAdmin || (isAdmin && kind !== "sessions"),
  };
}

export async function loadManagementBranches(userId: string): Promise<string[]> {
  const memberships: { branch_id: string }[] = [];
  let total = 0;
  do {
    const result = await supabase.from("branch_memberships")
      .select("branch_id", { count: "exact" }).eq("user_id", userId).eq("is_active", true)
      .order("branch_id").range(memberships.length, memberships.length + 999)
      .returns<{ branch_id: string }[]>();
    if (result.error) throw new Error(result.error.message);
    if (!result.data || result.count === null) throw new Error("لم تُرجع قاعدة البيانات عضويات الفروع أو عددها.");
    total = result.count;
    if (!result.data.length && memberships.length < total) throw new Error("تعذر تحميل جميع عضويات الفروع.");
    memberships.push(...result.data);
  } while (memberships.length < total);
  return memberships.map((membership) => membership.branch_id);
}

async function loadOptions(table: string, branch?: string, session?: string): Promise<Option[]> {
  const options: Option[] = [];
  let total = 0;
  do {
    let query = supabase.from(table).select("id,name", { count: "exact" })
      .order("name").order("id").range(options.length, options.length + 999);
    if (branch && session) query = query.eq("branch_id", branch).eq("session_id", session);
    const result = await query.returns<Option[]>();
    if (result.error) throw new Error(result.error.message);
    if (!result.data || result.count === null) throw new Error("لم تُرجع قاعدة البيانات خيارات التصفية أو عددها.");
    total = result.count;
    if (!result.data.length && options.length < total) throw new Error("تعذر تحميل جميع خيارات التصفية.");
    options.push(...result.data);
  } while (options.length < total);
  return options;
}

export async function loadManagementOptions(branch: string, session: string) {
  const [branches, sessions, classes] = await Promise.all([
    loadOptions("branches"),
    loadOptions("academic_sessions"),
    branch && session && session !== "unassigned"
      ? loadOptions("classes", branch, session)
      : Promise.resolve([] as Option[]),
  ]);
  return { branches, sessions, classes };
}

export async function loadManagementRows(kind: ManagementKind, filters: ManagementFilters) {
  if ((kind === "classes" || kind === "students") && (!filters.branch || !filters.session)) {
    return { rows: [] as ManagementRow[], count: 0 };
  }
  const studentSession = kind === "students" && filters.session !== "unassigned";
  const selected = studentSession ? `${columns.students},classes!inner(session_id,branch_id)` : columns[kind];
  let query = supabase.from(tables[kind]).select(selected, { count: "exact" });
  if (kind === "classes" || kind === "students") {
    query = query.eq("branch_id", filters.branch);
    if (kind === "classes") query = query.eq("session_id", filters.session);
    else if (studentSession) query = query.eq("classes.session_id", filters.session).eq("classes.branch_id", filters.branch);
    else query = query.is("class_id", null);
  }
  if (kind === "students" && filters.classId) query = query.eq("class_id", filters.classId);
  if (filters.status) query = kind === "students"
    ? query.eq("status", filters.status)
    : query.eq("is_active", filters.status === "active");
  if (filters.search.trim()) {
    const column = kind === "students" ? "full_name" : "name";
    query = query.ilike(column, `%${filters.search.trim().replace(/[\\%_]/g, "\\$&")}%`);
  }
  const start = filters.page * pageSize;
  const result = await query.order(kind === "students" ? "full_name" : "name").order("id")
    .range(start, start + pageSize - 1).returns<ManagementRow[]>();
  if (result.error) throw new Error(result.error.message);
  if (!result.data || result.count === null) throw new Error("لم تُرجع قاعدة البيانات السجلات أو عددها.");
  return { rows: result.data, count: result.count };
}

export async function saveManagementRow(
  kind: ManagementKind, id: string | null, values: Record<string, string | number | boolean | null>,
) {
  if (id) {
    const result = await supabase.from(tables[kind]).update(values).eq("id", id).select("id");
    if (result.error) throw new Error(result.error.message);
    if (!result.data?.length) throw new Error("لم يُحدّث السجل؛ قد لا تملك الصلاحية أو لم يعد السجل متاحاً.");
  } else {
    const result = await supabase.from(tables[kind]).insert<typeof values>(values);
    if (result.error) throw new Error(result.error.message);
  }
}
