import {
  admissionStatuses, loadAdmissionHistoryExport, loadAdmissionRoster,
  type AdmissionHistoryExportRow, type AdmissionRosterRow,
} from "./admissions";
import { buildCsv, downloadCsv } from "./csv";

const actionLabels: Record<string, string> = {
  insert: "تسجيل الطلب",
  status_change: "تغيير الحالة",
  update: "تحديث بيانات الطلب",
};

const headers = [
  "رقم الطلب", "اسم المتقدم", "الفرع", "نوع الحركة",
  "الحالة السابقة", "الحالة الجديدة", "الحقول المعدّلة", "الموظف", "التاريخ والوقت",
] as const;

function statusLabel(value: string | null): string {
  if (!value) return "";
  const labels = admissionStatuses as Record<string, string>;
  return labels[value] ?? value;
}

function formatWhen(value: string): string {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return value;
  return parsed.toLocaleString("ar-EG", {
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hour12: false,
  });
}

function toRow(row: AdmissionHistoryExportRow): (string | null)[] {
  return [
    row.application_no,
    row.applicant_full_name,
    row.branch_name,
    actionLabels[row.action] ?? row.action,
    statusLabel(row.old_status),
    statusLabel(row.new_status),
    row.changed_columns,
    row.actor_name,
    formatWhen(row.occurred_at),
  ];
}

export type ExportScope = { branch: string | null; from: string | null; to: string | null; enquiryId: string | null };

export async function exportAdmissionHistoryCsv(scope: ExportScope): Promise<number> {
  const rows = await loadAdmissionHistoryExport(scope);
  const csv = buildCsv(headers, rows.map(toRow));
  const today = new Date().toISOString().slice(0, 10);
  const range = scope.enquiryId
    ? "enquiry"
    : `${scope.from || "start"}_${scope.to || "today"}`;
  downloadCsv(`sai-admissions-history-${range}-${today}.csv`, csv);
  return rows.length;
}

const rosterHeaders = [
  "رقم الطلب", "اسم المتقدم", "ولي الأمر", "الهاتف", "البريد الإلكتروني",
  "البرنامج", "المستوى", "الفرع", "الجلسة", "الحالة الحالية",
  "الموظف المسند إليه", "مصدر الطلب", "ملاحظات", "تاريخ التقديم", "آخر تحديث",
] as const;

function rosterRow(row: AdmissionRosterRow): (string | null)[] {
  return [
    row.application_no,
    row.applicant_full_name,
    row.guardian_name,
    row.phone,
    row.email,
    row.preferred_program,
    row.preferred_level,
    row.branch_name,
    row.session_name,
    statusLabel(row.status),
    row.assigned_name,
    row.source,
    row.notes,
    formatWhen(row.created_at),
    formatWhen(row.updated_at),
  ];
}

export type RosterScope = {
  branch: string | null;
  session: string | null;
  status: string | null;
  from: string | null;
  to: string | null;
};

export async function exportAdmissionRosterCsv(scope: RosterScope): Promise<number> {
  const rows = await loadAdmissionRoster(scope);
  const csv = buildCsv(rosterHeaders, rows.map(rosterRow));
  const today = new Date().toISOString().slice(0, 10);
  downloadCsv(`sai-admissions-roster-${scope.from || "start"}_${scope.to || "today"}-${today}.csv`, csv);
  return rows.length;
}