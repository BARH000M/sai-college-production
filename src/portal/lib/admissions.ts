import { supabase } from "./supabase";

export const admissionStatuses = {
  new: "جديد", contacted: "تم التواصل", assessment: "التقييم",
  accepted: "مقبول", enrolled: "مسجل", rejected: "مرفوض", withdrawn: "منسحب",
} as const;
export type AdmissionStatus = keyof typeof admissionStatuses;
export type Admission = {
  id: string; branch_id: string; academic_session_id: string; application_no: string;
  applicant_full_name: string; guardian_name: string | null; phone: string | null;
  email: string | null; preferred_program: string | null; preferred_level: string | null;
  source: string | null; notes: string | null; status: AdmissionStatus;
  assigned_to: string | null; created_by: string; created_at: string; updated_at: string; closed_at: string | null;
};
export type AdmissionFilters = { branch: string; session: string; status: string; assignee: string; search: string; page: number; stale?: boolean };
export type StaffOption = { user_id: string; full_name: string };
export type AdmissionSession = { id: string; name: string };
export type AdmissionDraft = {
  branch_id: string; academic_session_id: string; applicant_full_name: string;
  guardian_name: string; phone: string; email: string; preferred_program: string;
  preferred_level: string; source: string; notes: string; assigned_to: string; status: AdmissionStatus;
};
export const admissionsPageSize = 25;

export function canManageAdmissions(roles: readonly string[]): boolean {
  return roles.some((role) => ["super_admin", "admin", "receptionist"].includes(role));
}
export function isAdmissionStatus(value: string): value is AdmissionStatus {
  return Object.prototype.hasOwnProperty.call(admissionStatuses, value);
}
export function admissionDraft(row: Admission | null, branch: string, session: string): AdmissionDraft {
  return {
    branch_id: row?.branch_id ?? branch, academic_session_id: row?.academic_session_id ?? session,
    applicant_full_name: row?.applicant_full_name ?? "", guardian_name: row?.guardian_name ?? "",
    phone: row?.phone ?? "", email: row?.email ?? "", preferred_program: row?.preferred_program ?? "",
    preferred_level: row?.preferred_level ?? "", source: row?.source ?? "", notes: row?.notes ?? "",
    assigned_to: row?.assigned_to ?? "", status: row?.status ?? "new",
  };
}
export function admissionPayload(draft: AdmissionDraft, editing: boolean) {
  const optional = (value: string) => value.trim() || null;
  return {
    ...(editing ? { status: draft.status } : { branch_id: draft.branch_id }),
    academic_session_id: draft.academic_session_id,
    applicant_full_name: draft.applicant_full_name.trim(),
    guardian_name: optional(draft.guardian_name), phone: optional(draft.phone), email: optional(draft.email),
    preferred_program: optional(draft.preferred_program), preferred_level: optional(draft.preferred_level),
    source: optional(draft.source), notes: optional(draft.notes), assigned_to: draft.assigned_to || null,
  };
}
export function validateAdmission(draft: AdmissionDraft): string | null {
  if (!draft.branch_id || !draft.academic_session_id || !draft.applicant_full_name.trim()) return "الفرع والجلسة واسم المتقدم مطلوبة.";
  if (!isAdmissionStatus(draft.status)) return "حالة الطلب غير صالحة.";
  if (draft.email.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(draft.email.trim())) return "البريد الإلكتروني غير صالح.";
  return null;
}

function isStaffOption(value: unknown): value is StaffOption {
  return typeof value === "object" && value !== null
    && "user_id" in value && typeof value.user_id === "string"
    && "full_name" in value && typeof value.full_name === "string";
}

function isAdmissionSession(value: unknown): value is AdmissionSession {
  return typeof value === "object" && value !== null
    && "id" in value && typeof value.id === "string"
    && "name" in value && typeof value.name === "string";
}

async function loadSessionsFromServer(branch: string): Promise<AdmissionSession[]> {
  const sessions: AdmissionSession[] = [];
  let total = 0;
  do {
    const result = await supabase.rpc("sai_admissions_sessions", { wanted_branch: branch }, { count: "exact" })
      .range(sessions.length, sessions.length + 999);
    if (result.error) throw new Error(result.error.message);
    if (!Array.isArray(result.data) || !result.data.every(isAdmissionSession) || result.count === null) {
      throw new Error("تعذر تحميل قائمة الجلسات وعددها.");
    }
    total = result.count;
    if (!result.data.length && sessions.length < total) throw new Error("تعذر تحميل جميع الجلسات.");
    sessions.push(...result.data);
  } while (sessions.length < total);
  return sessions;
}

async function loadSessionsFromDirectory(): Promise<AdmissionSession[]> {
  const result = await supabase.from("academic_sessions")
    .select("id,name").eq("is_active", true).order("name").order("id")
    .returns<AdmissionSession[]>();
  if (result.error) throw new Error(result.error.message);
  if (!Array.isArray(result.data)) throw new Error("تعذر تحميل قائمة الجلسات.");
  return result.data.filter(isAdmissionSession);
}

/**
 * Loads the active academic sessions for a branch.
 *
 * The secure server function is preferred because it authorizes through branch
 * membership. If that function is unavailable or not yet deployed, we fall back
 * to reading the session directory directly, where row level security still
 * limits the rows to what the signed-in account may see. The dropdown therefore
 * keeps working instead of failing with a hard error.
 */
export async function loadAdmissionSessions(branch: string): Promise<AdmissionSession[]> {
  if (!branch) return [];
  try {
    return await loadSessionsFromServer(branch);
  } catch (failure) {
    try {
      return await loadSessionsFromDirectory();
    } catch {
      throw failure instanceof Error ? failure : new Error("تعذر تحميل قائمة الجلسات.");
    }
  }
}

export async function loadAdmissionStaff(branch: string): Promise<StaffOption[]> {
  const staff: StaffOption[] = [];
  let total = 0;
  do {
    const result = await supabase.rpc("sai_admissions_staff", { wanted_branch: branch }, { count: "exact" })
      .range(staff.length, staff.length + 999);
    if (result.error) throw new Error(result.error.message);
    if (!Array.isArray(result.data) || !result.data.every(isStaffOption) || result.count === null) throw new Error("تعذر تحميل قائمة الموظفين وعددها.");
    total = result.count;
    if (!result.data.length && staff.length < total) throw new Error("تعذر تحميل جميع الموظفين.");
    staff.push(...result.data);
  } while (staff.length < total);
  return staff;
}

export async function loadAdmissions(filters: AdmissionFilters): Promise<{ rows: Admission[]; count: number }> {
  if (!filters.branch) return { rows: [], count: 0 };
  let query = supabase.from("admissions_enquiries").select(
    "id,branch_id,academic_session_id,application_no,applicant_full_name,guardian_name,phone,email,preferred_program,preferred_level,source,notes,status,assigned_to,created_by,created_at,updated_at,closed_at",
    { count: "exact" },
  ).eq("branch_id", filters.branch);
  if (filters.session) query = query.eq("academic_session_id", filters.session);
  if (filters.status) query = query.eq("status", filters.status);
  if (filters.stale) {
    query = query.eq("status", "new").lte("created_at", new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString());
  }
  if (filters.assignee === "unassigned") query = query.is("assigned_to", null);
  else if (filters.assignee) query = query.eq("assigned_to", filters.assignee);
  if (filters.search.trim()) {
    const term = filters.search.trim().replace(/[\\%_]/g, "\\$&").replace(/"/g, '\\"');
    const pattern = `"%${term}%"`;
    query = query.or(["applicant_full_name", "guardian_name", "phone", "application_no"].map((field) => `${field}.ilike.${pattern}`).join(","));
  }
  const start = filters.page * admissionsPageSize;
  const result = await query.order("created_at", { ascending: false }).order("id").range(start, start + admissionsPageSize - 1).returns<Admission[]>();
  if (result.error) throw new Error(result.error.message);
  if (!result.data || result.count === null) throw new Error("تعذر تحميل الطلبات وعددها.");
  return { rows: result.data, count: result.count };
}

const admissionColumns = "id,branch_id,academic_session_id,application_no,applicant_full_name,guardian_name,phone,email,preferred_program,preferred_level,source,notes,status,assigned_to,created_by,created_at,updated_at,closed_at";

export function applicationStatusUrl(reference: string): string {
  const basePath = typeof __BASE_PATH__ === "string" ? __BASE_PATH__.split("/").filter(Boolean).join("/") : "";
  const prefix = basePath ? `/${basePath}` : "";
  const origin = typeof window === "undefined" ? "" : window.location.origin;
  return `${origin}${prefix}/application-status?ref=${encodeURIComponent(reference)}`;
}

export async function loadAdmissionByReference(reference: string): Promise<Admission | null> {
  const term = reference.trim().replace(/[\\%_]/g, "\\$&");
  if (term.length < 6) throw new Error("الرقم المرجعي غير صالح.");
  const result = await supabase.from("admissions_enquiries").select(admissionColumns)
    .ilike("application_no", term).limit(1).maybeSingle<Admission>();
  if (result.error) throw new Error(result.error.message);
  return result.data ?? null;
}

export type StatusNotifyResult = { sent: boolean; reason: string | null };

export async function notifyAdmissionStatusChange(enquiryId: string, statusUrl: string): Promise<StatusNotifyResult> {
  const result = await supabase.functions.invoke("admission-notify", {
    body: { mode: "status_update", enquiryId, statusUrl },
  });
  if (result.error) return { sent: false, reason: "REQUEST_FAILED" };
  const payload = result.data as { sent?: unknown; reason?: unknown } | null;
  return {
    sent: payload?.sent === true,
    reason: typeof payload?.reason === "string" ? payload.reason : null,
  };
}

export type AdmissionHistoryExportRow = {
  application_no: string;
  applicant_full_name: string;
  branch_name: string | null;
  action: string;
  old_status: string | null;
  new_status: string | null;
  changed_columns: string | null;
  actor_name: string;
  occurred_at: string;
};

function text(value: unknown): string {
  return typeof value === "string" ? value : value == null ? "" : String(value);
}

export async function loadAdmissionHistoryExport(options: {
  branch: string | null;
  from: string | null;
  to: string | null;
  enquiryId: string | null;
}): Promise<AdmissionHistoryExportRow[]> {
  const result = await supabase.rpc("sai_admission_history_export", {
    p_branch: options.enquiryId ? null : options.branch,
    p_from: options.from ? new Date(`${options.from}T00:00:00`).toISOString() : null,
    p_to: options.to ? new Date(`${options.to}T23:59:59`).toISOString() : null,
    p_enquiry_id: options.enquiryId,
  });
  if (result.error) throw new Error(result.error.message);
  const rows = Array.isArray(result.data) ? result.data as Record<string, unknown>[] : [];
  return rows.map((row) => ({
    application_no: text(row.application_no),
    applicant_full_name: text(row.applicant_full_name),
    branch_name: typeof row.branch_name === "string" ? row.branch_name : null,
    action: text(row.action),
    old_status: typeof row.old_status === "string" ? row.old_status : null,
    new_status: typeof row.new_status === "string" ? row.new_status : null,
    changed_columns: typeof row.changed_columns === "string" ? row.changed_columns : null,
    actor_name: text(row.actor_name),
    occurred_at: text(row.occurred_at),
  }));
}

export type AdmissionHistoryEntry = {
  entry_id: string;
  action: string;
  old_status: string | null;
  new_status: string | null;
  changed_columns: string[];
  actor_id: string | null;
  actor_name: string;
  occurred_at: string;
};

function isHistoryEntry(value: unknown): value is AdmissionHistoryEntry {
  if (typeof value !== "object" || value === null) return false;
  const row = value as Record<string, unknown>;
  return typeof row.entry_id === "string"
    && typeof row.action === "string"
    && typeof row.actor_name === "string"
    && typeof row.occurred_at === "string"
    && Array.isArray(row.changed_columns);
}

export async function loadAdmissionHistory(enquiryId: string): Promise<AdmissionHistoryEntry[]> {
  const result = await supabase.rpc("sai_admission_history", { p_enquiry_id: enquiryId });
  if (result.error) throw new Error(result.error.message);
  const rows = Array.isArray(result.data) ? result.data : [];
  return rows.filter(isHistoryEntry).map((row) => ({
    ...row,
    changed_columns: (row.changed_columns as unknown[]).filter((item): item is string => typeof item === "string"),
  }));
}

export async function saveAdmission(draft: AdmissionDraft, id: string | null): Promise<void> {
  const error = validateAdmission(draft);
  if (error) throw new Error(error);
  const values = admissionPayload(draft, !!id);
  if (id) {
    const result = await supabase.from("admissions_enquiries").update(values).eq("id", id).select("id");
    if (result.error) throw new Error(result.error.message);
    if (!result.data?.length) throw new Error("لم يُحدّث الطلب؛ قد لا تملك الصلاحية أو لم يعد متاحاً.");
  } else {
    const result = await supabase.from("admissions_enquiries").insert<typeof values>(values);
    if (result.error) throw new Error(result.error.message);
  }
}

export async function assignAdmission(enquiryId: string, userId: string | null): Promise<void> {
  const result = await supabase.from("admissions_enquiries")
    .update({ assigned_to: userId }).eq("id", enquiryId).select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحدّث الإسناد؛ قد لا تملك الصلاحية أو لم يعد الطلب متاحاً.");
}

export type AdmissionRosterRow = {
  application_no: string;
  applicant_full_name: string;
  guardian_name: string | null;
  phone: string | null;
  email: string | null;
  preferred_program: string | null;
  preferred_level: string | null;
  branch_name: string | null;
  session_name: string | null;
  status: string;
  assigned_name: string;
  source: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

function optionalText(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value : null;
}

export async function loadAdmissionRoster(options: {
  branch: string | null;
  session: string | null;
  status: string | null;
  from: string | null;
  to: string | null;
}): Promise<AdmissionRosterRow[]> {
  const result = await supabase.rpc("sai_admission_roster_export", {
    p_branch: options.branch,
    p_session: options.session,
    p_status: options.status,
    p_from: options.from ? new Date(`${options.from}T00:00:00`).toISOString() : null,
    p_to: options.to ? new Date(`${options.to}T23:59:59`).toISOString() : null,
  });
  if (result.error) throw new Error(result.error.message);
  const rows = Array.isArray(result.data) ? (result.data as Record<string, unknown>[]) : [];
  return rows.map((row) => ({
    application_no: text(row.application_no),
    applicant_full_name: text(row.applicant_full_name),
    guardian_name: optionalText(row.guardian_name),
    phone: optionalText(row.phone),
    email: optionalText(row.email),
    preferred_program: optionalText(row.preferred_program),
    preferred_level: optionalText(row.preferred_level),
    branch_name: optionalText(row.branch_name),
    session_name: optionalText(row.session_name),
    status: text(row.status),
    assigned_name: text(row.assigned_name),
    source: optionalText(row.source),
    notes: optionalText(row.notes),
    created_at: text(row.created_at),
    updated_at: text(row.updated_at),
  }));
}
