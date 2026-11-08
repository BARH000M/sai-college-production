import { supabase } from "./supabase";

export type ProvisionAccount = { userId: string; email: string; fullName: string };

export type ProvisionStudent = {
  studentId: string;
  studentName: string;
  admissionNo: string;
  className: string | null;
  program: string | null;
  studentAccount: ProvisionAccount | null;
  parentAccount: ProvisionAccount | null;
};

export type ProvisionKind = "student" | "parent";

export type CreatedAccount = {
  email: string;
  password: string;
  role: ProvisionKind;
  fullName: string;
  studentName: string;
};

type OverviewResponse = { ok?: boolean; students?: ProvisionStudent[]; message?: string };
type CreateResponse = { ok?: boolean; account?: CreatedAccount; message?: string };

const NOT_CONFIGURED = "تعذر الاتصال بخدمة إنشاء الحسابات. تحقق من نشر الوظائف ثم أعد المحاولة.";

async function invoke<T extends { ok?: boolean; message?: string }>(
  body: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await supabase.functions.invoke<T>("provision-learning-account", { body });
  if (error) throw new Error(error.message || NOT_CONFIGURED);
  if (!data) throw new Error(NOT_CONFIGURED);
  if (data.ok !== true) throw new Error(data.message ?? "تعذر تنفيذ الطلب.");
  return data;
}

export async function loadProvisionOverview(): Promise<ProvisionStudent[]> {
  const data = await invoke<OverviewResponse>({ action: "overview" });
  return data.students ?? [];
}

export async function provisionLearningAccount(input: {
  studentId: string;
  kind: ProvisionKind;
  email: string;
  password: string;
  parentName?: string;
}): Promise<CreatedAccount> {
  const data = await invoke<CreateResponse>({ action: "create", ...input });
  if (!data.account) throw new Error("لم تُرجع الخدمة بيانات الحساب المنشأ.");
  return data.account;
}

export function suggestAccountEmail(admissionNo: string, kind: ProvisionKind): string {
  const base = admissionNo
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "student";
  return kind === "parent" ? `${base}.parent@saicllege.com` : `${base}@saicllege.com`;
}

export function suggestPassword(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  const buffer = new Uint32Array(10);
  crypto.getRandomValues(buffer);
  const body = Array.from(buffer, (value) => alphabet[value % alphabet.length]).join("");
  return `Sai-${body}`;
}

export type TeacherClass = {
  id: string;
  name: string;
  branchName: string | null;
  teacherId: string | null;
  teacherName: string | null;
  teacherEmail: string | null;
};

export type TeacherWorkload = {
  classes: number;
  courses: number;
  assignments: number;
  ungraded: number;
  students: number;
};

export type TeacherAccount = {
  userId: string;
  fullName: string;
  email: string;
  classNames: string[];
  branchNames: string[];
  courseTitles: string[];
  workload: TeacherWorkload;
};

export type TeacherOverview = {
  classes: TeacherClass[];
  teachers: TeacherAccount[];
};

export type CreatedTeacher = {
  userId: string;
  email: string;
  password: string;
  fullName: string;
  className: string;
  emailSent?: boolean;
  emailReason?: string;
};

export type TeacherEmailStatus = { sent: boolean; reason?: string };

export function teacherEmailNote(status: TeacherEmailStatus | undefined): string | null {
  if (!status) return null;
  if (status.sent) return "أُرسل إشعار بالبريد الإلكتروني إلى المعلم.";
  if (status.reason === "NO_EMAIL") return "لم يُرسل إشعار بالبريد: لا يوجد بريد مسجل للمعلم.";
  if (status.reason === "EMAIL_NOT_CONFIGURED") {
    return "لم يُرسل إشعار بالبريد: مزوّد البريد غير مهيأ على الخادم. سلّم البيانات يدوياً.";
  }
  return "لم يُرسل إشعار بالبريد؛ تحقق من إعداد البريد ثم أعد المحاولة.";
}

type TeacherOverviewResponse = {
  ok?: boolean;
  classes?: TeacherClass[];
  teachers?: TeacherAccount[];
  message?: string;
};

type TeacherCreateResponse = { ok?: boolean; account?: CreatedTeacher; message?: string };

export async function loadTeacherOverview(): Promise<TeacherOverview> {
  const data = await invoke<TeacherOverviewResponse>({ action: "teacher-overview" });
  return { classes: data.classes ?? [], teachers: data.teachers ?? [] };
}

export async function provisionTeacherAccount(input: {
  fullName: string;
  email: string;
  password: string;
  classId: string;
}): Promise<CreatedTeacher> {
  const data = await invoke<TeacherCreateResponse>({ action: "create-teacher", ...input });
  if (!data.account) throw new Error("لم تُرجع الخدمة بيانات حساب المعلم.");
  return data.account;
}

export type ReassignedTeacher = {
  userId: string;
  email: string;
  fullName: string;
  className: string;
  previousClassNames: string[];
  emailSent?: boolean;
  emailReason?: string;
};

type TeacherResetResponse = { ok?: boolean; account?: CreatedTeacher; message?: string };
type TeacherReassignResponse = { ok?: boolean; account?: ReassignedTeacher; message?: string };
type TeacherRemoveResponse = {
  ok?: boolean;
  account?: {
    userId: string;
    removedClassNames: string[];
    emailSent?: boolean;
    emailReason?: string;
  };
  message?: string;
};

export type TeacherRemoval = {
  removedClassNames: string[];
  emailSent?: boolean;
  emailReason?: string;
};

export async function resetTeacherPassword(userId: string, password: string): Promise<CreatedTeacher> {
  const data = await invoke<TeacherResetResponse>({ action: "reset-teacher-password", userId, password });
  if (!data.account) throw new Error("لم تُرجع الخدمة بيانات كلمة المرور الجديدة.");
  return data.account;
}

export async function reassignTeacherClass(userId: string, classId: string): Promise<ReassignedTeacher> {
  const data = await invoke<TeacherReassignResponse>({ action: "reassign-teacher", userId, classId });
  if (!data.account) throw new Error("لم تُرجع الخدمة نتيجة نقل المعلم.");
  return data.account;
}

export async function removeTeacherFromClasses(userId: string): Promise<TeacherRemoval> {
  const data = await invoke<TeacherRemoveResponse>({ action: "remove-teacher", userId });
  return {
    removedClassNames: data.account?.removedClassNames ?? [],
    emailSent: data.account?.emailSent,
    emailReason: data.account?.emailReason,
  };
}

export function suggestTeacherEmail(fullName: string): string {
  const base = fullName
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  const tail = Math.floor(Math.random() * 9000 + 1000);
  return base ? `teacher.${base}@saicllege.com` : `teacher.${tail}@saicllege.com`;
}