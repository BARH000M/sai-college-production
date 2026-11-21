import { supabase } from "./supabase";

export type EnquiryStatus =
  | "new" | "contacted" | "assessment" | "accepted" | "enrolled" | "rejected" | "withdrawn";

export type Enquiry = {
  id: string;
  applicant_full_name: string;
  guardian_name: string | null;
  phone: string | null;
  preferred_program: string | null;
  source: string | null;
  status: EnquiryStatus;
  assigned_to: string | null;
  notes: string | null;
  created_at: string;
  branch_id: string;
};

export type FollowUp = {
  id: string;
  enquiry_id: string;
  note: string;
  created_by: string | null;
  created_at: string;
};

export type Visitor = {
  id: string;
  full_name: string;
  phone: string | null;
  purpose: string | null;
  host_name: string | null;
  branch_id: string;
  check_in_at: string;
  check_out_at: string | null;
  status: "on_site" | "checked_out" | "cancelled";
};

export type Appointment = {
  id: string;
  full_name: string;
  phone: string | null;
  purpose: string | null;
  branch_id: string;
  scheduled_at: string;
  status: "scheduled" | "completed" | "cancelled" | "no_show";
};

export type Complaint = {
  id: string;
  complainant_name: string;
  phone: string | null;
  category: string | null;
  severity: "low" | "medium" | "high";
  subject: string;
  description: string | null;
  branch_id: string;
  status: "open" | "in_progress" | "resolved" | "closed";
  resolution: string | null;
  resolved_at: string | null;
  created_at: string;
};

export const ENQUIRY_STATUS_LABELS: Record<EnquiryStatus, string> = {
  new: "جديد",
  contacted: "تم التواصل",
  assessment: "مرحلة التقييم",
  accepted: "مقبول",
  enrolled: "مسجَّل",
  rejected: "مرفوض",
  withdrawn: "منسحب",
};

/** Normalises a telephone number for duplicate detection. */
export function normalizePhone(value: string | null | undefined): string {
  return (value ?? "").replace(/\D/g, "");
}

export async function loadEnquiries(branchId: string): Promise<Enquiry[]> {
  if (!branchId) return [];
  const result = await supabase
    .from("admissions_enquiries")
    .select("id,applicant_full_name,guardian_name,phone,preferred_program,source,status,assigned_to,notes,created_at,branch_id")
    .eq("branch_id", branchId)
    .order("created_at", { ascending: false })
    .limit(300);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as Enquiry[];
}

export async function loadFollowUps(enquiryIds: string[]): Promise<FollowUp[]> {
  if (!enquiryIds.length) return [];
  const result = await supabase
    .from("sai_enquiry_followups")
    .select("id,enquiry_id,note,created_by,created_at")
    .in("enquiry_id", enquiryIds)
    .order("created_at", { ascending: false });
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as FollowUp[];
}

/** Detects an existing enquiry with the same normalised telephone number. */
export function findDuplicateEnquiry(enquiries: Enquiry[], phone: string): Enquiry | null {
  const target = normalizePhone(phone);
  if (!target) return null;
  return enquiries.find((row) => normalizePhone(row.phone) === target) ?? null;
}

export type EnquiryDraft = {
  applicant: string;
  guardian: string;
  phone: string;
  program: string;
  source: string;
  assignedTo: string | null;
  notes: string;
  branchId: string;
  sessionId: string | null;
};

/** Resolves the active academic session. A new enquiry requires one. */
export async function loadActiveSessionId(): Promise<string | null> {
  const result = await supabase
    .from("academic_sessions")
    .select("id")
    .eq("is_active", true)
    .limit(1);
  if (result.error) throw new Error(result.error.message);
  return ((result.data ?? []) as { id: string }[])[0]?.id ?? null;
}

export async function createEnquiry(draft: EnquiryDraft): Promise<Enquiry> {
  if (!draft.applicant.trim()) throw new Error("اسم المتقدم مطلوب.");
  if (!draft.branchId) throw new Error("لا يوجد فرع متاح لحسابك.");
  const sessionId = draft.sessionId || (await loadActiveSessionId());
  if (!sessionId) throw new Error("لا توجد دورة أكاديمية نشطة؛ لا يمكن تسجيل استفسار قبول.");
  const result = await supabase
    .from("admissions_enquiries")
    .insert({
      branch_id: draft.branchId,
      academic_session_id: sessionId,
      applicant_full_name: draft.applicant.trim(),
      guardian_name: draft.guardian.trim() || null,
      phone: draft.phone.trim() || null,
      preferred_program: draft.program.trim() || null,
      source: draft.source.trim() || null,
      assigned_to: draft.assignedTo || null,
      notes: draft.notes.trim() || null,
      status: "new",
    })
    .select("id,applicant_full_name,guardian_name,phone,preferred_program,source,status,assigned_to,notes,created_at,branch_id")
    .limit(1);
  if (result.error || !result.data?.length) {
    throw new Error(result.error ? result.error.message : "تعذّر تسجيل الاستفسار.");
  }
  return (result.data as Enquiry[])[0];
}

export async function setEnquiryStatus(id: string, status: EnquiryStatus): Promise<void> {
  const patch: Record<string, unknown> = { status, updated_at: new Date().toISOString() };
  if (status === "withdrawn" || status === "rejected") patch.closed_at = new Date().toISOString();
  const result = await supabase.from("admissions_enquiries").update(patch).eq("id", id);
  if (result.error) throw new Error(result.error.message);
}

export async function addFollowUp(enquiryId: string, note: string, userId: string | null): Promise<void> {
  const text = note.trim();
  if (!text) throw new Error("اكتب نص المتابعة.");
  const result = await supabase
    .from("sai_enquiry_followups")
    .insert({ enquiry_id: enquiryId, note: text, created_by: userId });
  if (result.error) throw new Error(result.error.message);
}

export async function loadVisitors(branchId: string): Promise<Visitor[]> {
  if (!branchId) return [];
  const result = await supabase
    .from("sai_visitors")
    .select("id,full_name,phone,purpose,host_name,branch_id,check_in_at,check_out_at,status")
    .eq("branch_id", branchId)
    .order("check_in_at", { ascending: false })
    .limit(200);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as Visitor[];
}

export async function checkInVisitor(input: {
  name: string; phone: string; purpose: string; host: string; branchId: string; userId: string | null;
}): Promise<void> {
  if (!input.name.trim()) throw new Error("اسم الزائر مطلوب.");
  if (!input.branchId) throw new Error("لا يوجد فرع متاح لحسابك.");
  const result = await supabase.from("sai_visitors").insert({
    full_name: input.name.trim(),
    phone: input.phone.trim() || null,
    phone_normalized: normalizePhone(input.phone) || null,
    purpose: input.purpose.trim() || null,
    host_name: input.host.trim() || null,
    branch_id: input.branchId,
    created_by: input.userId,
    status: "on_site",
  });
  if (result.error) throw new Error(result.error.message);
}

export async function checkOutVisitor(id: string): Promise<void> {
  const result = await supabase
    .from("sai_visitors")
    .update({ check_out_at: new Date().toISOString(), status: "checked_out" })
    .eq("id", id);
  if (result.error) throw new Error(result.error.message);
}

export async function loadAppointments(branchId: string): Promise<Appointment[]> {
  if (!branchId) return [];
  const result = await supabase
    .from("sai_appointments")
    .select("id,full_name,phone,purpose,branch_id,scheduled_at,status")
    .eq("branch_id", branchId)
    .order("scheduled_at", { ascending: false })
    .limit(200);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as Appointment[];
}

export async function createAppointment(input: {
  name: string; phone: string; purpose: string; date: string; time: string; branchId: string; userId: string | null;
}): Promise<void> {
  if (!input.name.trim()) throw new Error("اسم صاحب الموعد مطلوب.");
  if (!input.date) throw new Error("تاريخ الموعد مطلوب.");
  if (!input.time) throw new Error("وقت الموعد مطلوب.");
  if (!input.branchId) throw new Error("لا يوجد فرع متاح لحسابك.");
  const scheduledAt = new Date(`${input.date}T${input.time}:00`);
  if (Number.isNaN(scheduledAt.getTime())) throw new Error("التاريخ أو الوقت غير صالح.");
  const result = await supabase.from("sai_appointments").insert({
    full_name: input.name.trim(),
    phone: input.phone.trim() || null,
    purpose: input.purpose.trim() || null,
    scheduled_at: scheduledAt.toISOString(),
    branch_id: input.branchId,
    created_by: input.userId,
    status: "scheduled",
  });
  if (result.error) throw new Error(result.error.message);
}

export async function setAppointmentStatus(
  id: string,
  status: Appointment["status"],
): Promise<void> {
  const result = await supabase
    .from("sai_appointments")
    .update({ status, updated_at: new Date().toISOString() })
    .eq("id", id);
  if (result.error) throw new Error(result.error.message);
}

export async function loadComplaints(branchId: string): Promise<Complaint[]> {
  if (!branchId) return [];
  const result = await supabase
    .from("sai_complaints")
    .select("id,complainant_name,phone,category,severity,subject,description,branch_id,status,resolution,resolved_at,created_at")
    .eq("branch_id", branchId)
    .order("created_at", { ascending: false })
    .limit(200);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as Complaint[];
}

export async function createComplaint(input: {
  name: string; phone: string; subject: string; severity: Complaint["severity"]; branchId: string; userId: string | null;
}): Promise<void> {
  if (!input.name.trim()) throw new Error("اسم مقدّم الشكوى مطلوب.");
  if (!input.subject.trim()) throw new Error("موضوع الشكوى مطلوب.");
  if (!input.branchId) throw new Error("لا يوجد فرع متاح لحسابك.");
  const result = await supabase.from("sai_complaints").insert({
    complainant_name: input.name.trim(),
    phone: input.phone.trim() || null,
    subject: input.subject.trim(),
    severity: input.severity,
    branch_id: input.branchId,
    created_by: input.userId,
    status: "open",
  });
  if (result.error) throw new Error(result.error.message);
}

export async function resolveComplaint(id: string, resolution: string): Promise<void> {
  const result = await supabase
    .from("sai_complaints")
    .update({
      status: "resolved",
      resolution: resolution.trim() || null,
      resolved_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("id", id);
  if (result.error) throw new Error(result.error.message);
}