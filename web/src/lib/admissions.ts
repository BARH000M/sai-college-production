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
export type AdmissionFilters = { branch: string; session: string; status: string; assignee: string; search: string; page: number };
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

export async function loadAdmissionSessions(branch: string): Promise<AdmissionSession[]> {
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
