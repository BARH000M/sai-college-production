import { supabase } from "./supabase";

export const attendanceStatuses = { present: "حاضر", absent: "غائب", late: "متأخر", excused: "بعذر" } as const;
export type AttendanceStatus = keyof typeof attendanceStatuses;
export type AttendanceClass = { id: string; name: string; branch_id: string; academic_session_id: string; teacher_id: string | null };
export type AttendanceSession = { id: string; branch_id: string; academic_session_id: string; class_id: string; attendance_date: string; status: "open" | "closed" | "cancelled" };
export type AttendanceRecord = { id: string; student_id: string; status: AttendanceStatus; note: string | null };
export type RosterEntry = { student_id: string; full_name: string; record_id: string | null; attendance_status: AttendanceStatus | null; note: string | null };
export type AttendanceFilters = { branch: string; session: string; classId: string; date: string; page: number };
export const attendancePageSize = 25;
export function isAttendanceStatus(value: string): value is AttendanceStatus {
  return Object.prototype.hasOwnProperty.call(attendanceStatuses, value);
}

export function attendanceToday(now = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Aden", year: "numeric", month: "2-digit", day: "2-digit" }).format(now);
}
export function validateAttendanceDate(date: string, today = attendanceToday()): string | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || Number.isNaN(Date.parse(`${date}T00:00:00Z`))
    || new Date(`${date}T00:00:00Z`).toISOString().slice(0, 10) !== date) return "التاريخ غير صالح.";
  if (date > today) return "لا يمكن تسجيل الحضور في المستقبل.";
  return null;
}
export function canManageAttendance(roles: readonly string[], userId: string | null, memberships: readonly string[], item: AttendanceClass): boolean {
  return roles.includes("super_admin") || (memberships.includes(item.branch_id)
    && (roles.includes("admin") || (roles.includes("teacher") && item.teacher_id === userId && !!userId)));
}
export function canCorrectAttendance(roles: readonly string[], memberships: readonly string[], branch: string): boolean {
  return roles.includes("receptionist") && memberships.includes(branch);
}
function isAttendanceClass(value: unknown): value is AttendanceClass {
  return typeof value === "object" && value !== null && "id" in value && typeof value.id === "string"
    && "name" in value && typeof value.name === "string" && "branch_id" in value && typeof value.branch_id === "string"
    && "academic_session_id" in value && typeof value.academic_session_id === "string"
    && "teacher_id" in value && (typeof value.teacher_id === "string" || value.teacher_id === null);
}
function isRosterEntry(value: unknown): value is RosterEntry {
  if (typeof value !== "object" || value === null || !("student_id" in value) || typeof value.student_id !== "string"
    || !("full_name" in value) || typeof value.full_name !== "string" || !("record_id" in value)
    || !(typeof value.record_id === "string" || value.record_id === null) || !("note" in value)
    || !(typeof value.note === "string" || value.note === null) || !("attendance_status" in value)) return false;
  return value.attendance_status === null || (typeof value.attendance_status === "string" && isAttendanceStatus(value.attendance_status));
}
async function loadDirectory<T>(name: string, args: Record<string, string>, guard: (value: unknown) => value is T): Promise<T[]> {
  const rows: T[] = [];
  let total = 0;
  do {
    const result = await supabase.rpc(name, args, { count: "exact" }).range(rows.length, rows.length + 999);
    if (result.error) throw new Error(result.error.message);
    if (!Array.isArray(result.data) || !result.data.every(guard) || result.count === null) throw new Error("تعذر تحميل البيانات وعددها.");
    total = result.count;
    if (!result.data.length && rows.length < total) throw new Error("تعذر تحميل جميع البيانات.");
    rows.push(...result.data);
  } while (rows.length < total);
  return rows;
}
export const loadAttendanceClasses = () => loadDirectory("sai_attendance_classes", {}, isAttendanceClass);
export const loadAttendanceRoster = (id: string) => loadDirectory("sai_attendance_roster", { wanted_session: id }, isRosterEntry);

export async function loadAttendanceSessions(filters: AttendanceFilters, classIds?: string[]) {
  if (classIds && !classIds.length) return { rows: [], count: 0 };
  let query = supabase.from("attendance_sessions").select("id,branch_id,academic_session_id,class_id,attendance_date,status", { count: "exact" });
  if (classIds) query = query.in("class_id", classIds);
  if (filters.branch) query = query.eq("branch_id", filters.branch);
  if (filters.session) query = query.eq("academic_session_id", filters.session);
  if (filters.classId) query = query.eq("class_id", filters.classId);
  if (filters.date) query = query.eq("attendance_date", filters.date);
  const start = filters.page * attendancePageSize;
  const result = await query.order("attendance_date", { ascending: false }).order("id").range(start, start + attendancePageSize - 1).returns<AttendanceSession[]>();
  if (result.error) throw new Error(result.error.message);
  if (!result.data || result.count === null) throw new Error("تعذر تحميل جلسات الحضور وعددها.");
  return { rows: result.data, count: result.count };
}
export async function loadAttendanceHistory(sessionId: string): Promise<AttendanceRecord[]> {
  const rows: AttendanceRecord[] = [];
  let total = 0;
  do {
    const result = await supabase.from("attendance_records").select("id,student_id,status,note", { count: "exact" })
      .eq("attendance_session_id", sessionId).order("id").range(rows.length, rows.length + 999).returns<AttendanceRecord[]>();
    if (result.error) throw new Error(result.error.message);
    if (!result.data || result.count === null) throw new Error("تعذر تحميل سجل الحضور وعدده.");
    total = result.count;
    if (!result.data.length && rows.length < total) throw new Error("تعذر تحميل جميع سجلات الحضور.");
    rows.push(...result.data);
  } while (rows.length < total);
  return rows;
}
export async function createAttendanceSession(item: AttendanceClass, date: string): Promise<void> {
  const error = validateAttendanceDate(date);
  if (error) throw new Error(error);
  const result = await supabase.from("attendance_sessions").insert({ branch_id: item.branch_id, academic_session_id: item.academic_session_id, class_id: item.id, attendance_date: date });
  if (result.error) throw new Error(result.error.message);
}
export async function setAttendanceSessionStatus(id: string, status: "closed" | "cancelled"): Promise<void> {
  const result = await supabase.from("attendance_sessions").update({ status }).eq("id", id).eq("status", "open").select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم تُحدّث الجلسة؛ قد تكون مغلقة أو لا تملك الصلاحية.");
}
export async function saveAttendance(sessionId: string, row: RosterEntry, status: AttendanceStatus, note: string): Promise<void> {
  if (!isAttendanceStatus(status)) throw new Error("حالة الحضور غير صالحة.");
  const values = { status, note: note.trim() || null };
  if (row.record_id) {
    const result = await supabase.from("attendance_records").update(values).eq("id", row.record_id).eq("attendance_session_id", sessionId).select("id");
    if (result.error) throw new Error(result.error.message);
    if (!result.data?.length) throw new Error("لم يُحدّث السجل؛ تحقق من الصلاحية وحالة الجلسة.");
  } else {
    const result = await supabase.from("attendance_records").insert({ attendance_session_id: sessionId, student_id: row.student_id, ...values });
    if (result.error) throw new Error(result.error.message);
  }
}

export type AttendanceBatchItem = { row: RosterEntry; status: AttendanceStatus; note: string };

/**
 * Saves a whole class register in one go — used after "mark everyone present"
 * and by the teacher's final save. Records are written one by one so a single
 * rejected row cannot roll back the rest of the class; the failures are
 * summarised back to the caller.
 */
export async function saveAttendanceBatch(sessionId: string, items: readonly AttendanceBatchItem[]): Promise<number> {
  if (!items.length) throw new Error("لا توجد سجلات جاهزة للحفظ.");
  let saved = 0;
  const failures: string[] = [];
  for (const item of items) {
    if (!isAttendanceStatus(item.status)) continue;
    try {
      await saveAttendance(sessionId, item.row, item.status, item.note);
      saved += 1;
    } catch (failure) {
      const name = item.row.full_name || item.row.student_id;
      failures.push(`${name}: ${failure instanceof Error ? failure.message : String(failure)}`);
    }
  }
  if (failures.length) {
    throw new Error(`حُفظ ${saved} سجلاً، وتعذّر حفظ ${failures.length}. أول خطأ — ${failures[0]}`);
  }
  return saved;
}
