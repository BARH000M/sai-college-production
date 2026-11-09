import type { ManagementFilters, ManagementKind, ManagementRow, Option } from "./management";

export type Draft = Record<string, string>;

export function isAvailableStudentClass(classId: string, options: readonly Option[], loading: boolean, error: string | null): boolean {
  return !classId || (!loading && !error && options.some((item) => item.id === classId));
}

export function makeDraft(kind: ManagementKind, row: ManagementRow | null, filters: ManagementFilters): Draft {
  const draft: Draft = {
    name: "", code: "", address: "", is_active: "true", starts_on: "", ends_on: "",
    branch_id: filters.branch, session_id: filters.session === "unassigned" ? "" : filters.session,
    program: "", capacity: "20", teacher_id: "", user_id: "", admission_no: "",
    full_name: "", date_of_birth: "", class_id: "", status: "active",
  };
  if (row) for (const [key, value] of Object.entries(row)) {
    if (key in draft) draft[key] = value == null ? "" : String(value);
  }
  if (kind === "students" && row) draft.session_id = filters.session === "unassigned" ? "" : filters.session;
  return draft;
}

export function managementPayload(kind: ManagementKind, draft: Draft, editing: boolean): Record<string, string | number | boolean | null> {
  if (kind === "branches") return { name: draft.name.trim(), code: draft.code.trim(), address: draft.address.trim() || null, is_active: draft.is_active === "true" };
  if (kind === "sessions") return { name: draft.name.trim(), starts_on: draft.starts_on, ends_on: draft.ends_on, is_active: draft.is_active === "true" };
  if (kind === "classes") {
    const values: Record<string, string | number | boolean | null> = {
      name: draft.name.trim(), program: draft.program.trim(), capacity: Number(draft.capacity), is_active: draft.is_active === "true",
    };
    if (!editing) Object.assign(values, { branch_id: draft.branch_id, session_id: draft.session_id, teacher_id: draft.teacher_id.trim() || null });
    return values;
  }
  const values: Record<string, string | number | boolean | null> = {
    full_name: draft.full_name.trim(), admission_no: draft.admission_no.trim(),
    date_of_birth: draft.date_of_birth || null, class_id: draft.class_id || null, status: draft.status,
  };
  if (!editing) Object.assign(values, { branch_id: draft.branch_id, user_id: draft.user_id.trim() || null });
  return values;
}

export function validateManagementDraft(kind: ManagementKind, draft: Draft, editing: boolean): string | null {
  if (kind === "students" ? !draft.full_name.trim() || !draft.admission_no.trim() : !draft.name.trim()) return "يرجى إدخال الحقول المطلوبة.";
  if (kind === "branches" && !draft.code.trim()) return "رمز الفرع مطلوب.";
  if (kind === "sessions" && (!draft.starts_on || !draft.ends_on || draft.ends_on <= draft.starts_on)) return "يجب أن يكون تاريخ الانتهاء بعد تاريخ البدء.";
  if ((kind === "classes" || kind === "students") && !draft.branch_id) return "يرجى اختيار الفرع.";
  if (kind === "classes" && (!draft.session_id || !draft.program.trim() || !Number.isInteger(Number(draft.capacity)) || Number(draft.capacity) < 1)) return "يرجى اختيار الجلسة وإدخال برنامج وسعة صحيحة.";
  if (kind === "students" && draft.class_id && !draft.session_id) return "يرجى اختيار جلسة الصف.";
  if (!editing && (kind === "students" || kind === "classes")) {
    const id = (kind === "students" ? draft.user_id : draft.teacher_id).trim();
    if (id && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) return "معرّف الحساب يجب أن يكون UUID صحيحاً.";
  }
  return null;
}
