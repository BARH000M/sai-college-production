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

export type StudentRosterExportRow = {
  full_name: string;
  admission_no: string;
  date_of_birth: string | null;
  status: string;
  class_name: string | null;
  branch_name: string | null;
  session_name: string | null;
};

type ExportStudentRecord = {
  full_name: string;
  admission_no: string;
  date_of_birth: string | null;
  status: string;
  class_id: string | null;
  branch_id: string;
};

function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, "\\$&");
}

/**
 * One CSV row per student for the current records filter, across every page.
 * Names for class/branch/session are resolved separately so the export never
 * depends on nested PostgREST relations.
 */
export async function loadStudentRecordsForExport(filters: ManagementFilters): Promise<StudentRosterExportRow[]> {
  if (!filters.branch || !filters.session) return [];
  const sessionFiltered = filters.session !== "unassigned";
  const selected = sessionFiltered
    ? "full_name,admission_no,date_of_birth,status,class_id,branch_id,classes!inner(session_id,branch_id)"
    : "full_name,admission_no,date_of_birth,status,class_id,branch_id";

  const rows: ExportStudentRecord[] = [];
  let total = 0;
  do {
    let query = supabase.from("students").select(selected, { count: "exact" });
    query = query.eq("branch_id", filters.branch);
    if (sessionFiltered) {
      query = query.eq("classes.session_id", filters.session).eq("classes.branch_id", filters.branch);
    } else {
      query = query.is("class_id", null);
    }
    if (filters.classId) query = query.eq("class_id", filters.classId);
    if (filters.status) query = query.eq("status", filters.status);
    if (filters.search.trim()) query = query.ilike("full_name", `%${escapeLike(filters.search.trim())}%`);

    const result = await query
      .order("full_name").order("admission_no")
      .range(rows.length, rows.length + 499)
      .returns<ExportStudentRecord[]>();
    if (result.error) throw new Error(result.error.message);
    if (!result.data || result.count === null) throw new Error("لم تُرجع قاعدة البيانات سجلات الطلاب أو عددها.");
    total = result.count;
    if (!result.data.length && rows.length < total) throw new Error("تعذر تحميل جميع سجلات الطلاب.");
    rows.push(...result.data);
  } while (rows.length < total);

  if (!rows.length) return [];

  const [branchRes, classRes, sessionRes] = await Promise.all([
    supabase.from("branches").select("id,name"),
    supabase.from("classes").select("id,name,session_id,branch_id"),
    supabase.from("academic_sessions").select("id,name"),
  ]);
  if (branchRes.error) throw new Error(branchRes.error.message);
  if (classRes.error) throw new Error(classRes.error.message);
  if (sessionRes.error) throw new Error(sessionRes.error.message);

  const branchNames = new Map(((branchRes.data ?? []) as Option[]).map((row) => [row.id, row.name]));
  const classes = (classRes.data ?? []) as { id: string; name: string; session_id: string; branch_id: string }[];
  const classMap = new Map(classes.map((row) => [row.id, row]));
  const sessionNames = new Map(((sessionRes.data ?? []) as Option[]).map((row) => [row.id, row.name]));

  return rows.map((row) => {
    const cls = row.class_id ? classMap.get(row.class_id) ?? null : null;
    return {
      full_name: row.full_name,
      admission_no: row.admission_no,
      date_of_birth: row.date_of_birth,
      status: row.status,
      class_name: cls?.name ?? null,
      branch_name: branchNames.get(cls ? cls.branch_id : row.branch_id) ?? null,
      session_name: cls ? sessionNames.get(cls.session_id) ?? null : null,
    };
  });
}
