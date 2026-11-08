import { buildCsv, downloadCsv } from "./csv";
import { admissionStatuses } from "./admissions";
import { attendanceStatuses } from "./attendance";
import { formatDate } from "./learning";
import type { AdmissionsReport, AttendanceReport, DistributionReport, EnrollmentReport, HomeworkReport } from "./reports";

const attendanceKeys = Object.keys(attendanceStatuses);

const studentStatuses: Record<string, string> = {
  active: "نشط",
  inactive: "غير نشط",
  graduated: "متخرج",
  withdrawn: "منسحب",
};

function stamp(): string {
  const date = new Date();
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function slug(value: string): string {
  const ascii = value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40);
  return ascii || "report";
}

/** Attendance report as CSV: one row per student with each status count and the rate. */
export function exportAttendanceReport(report: AttendanceReport): string {
  const headers = [
    "#",
    "اسم الطالب",
    "رقم القبول",
    ...attendanceKeys.map((key) => attendanceStatuses[key as keyof typeof attendanceStatuses]),
    "إجمالي السجلات",
    "نسبة الحضور",
  ];
  const rows = report.rows.map((row, index) => [
    String(index + 1),
    row.full_name,
    row.admission_no,
    ...attendanceKeys.map((key) => String(row.counts[key] ?? 0)),
    String(row.total),
    row.total ? `${row.percent}%` : "",
  ]);
  const fileName = `attendance-${slug(report.className)}-${stamp()}.csv`;
  downloadCsv(fileName, buildCsv(headers, rows));
  return fileName;
}

/** Homework report as CSV: one row per published homework with delivery counts. */
export function exportHomeworkReport(report: HomeworkReport): string {
  const headers = [
    "#",
    "الواجب",
    "المقرر",
    "موعد التسليم",
    "الدرجة القصوى",
    "مُسلَّم",
    "مُصحَّح",
    "لم يُسلَّم",
  ];
  const rows = report.rows.map((row, index) => [
    String(index + 1),
    row.title,
    row.courseTitle,
    formatDate(row.dueAt),
    String(row.maxScore),
    String(row.submitted),
    String(row.graded),
    String(row.pending),
  ]);
  const fileName = `homework-${slug(report.className)}-${stamp()}.csv`;
  downloadCsv(fileName, buildCsv(headers, rows));
  return fileName;
}

/** Class roster ("كشف طلاب الصف") as CSV, mirroring the printed sheet columns. */
export function exportEnrollmentReport(report: EnrollmentReport): string {
  const headers = ["#", "الاسم الكامل", "رقم القبول", "تاريخ الميلاد", "الحالة"];
  const rows = report.rows.map((row, index) => [
    String(index + 1),
    row.full_name,
    row.admission_no,
    row.date_of_birth ? formatDate(row.date_of_birth) : "",
    studentStatuses[row.status] ?? row.status,
  ]);
  const fileName = `class-roster-${slug(report.className)}-${stamp()}.csv`;
  downloadCsv(fileName, buildCsv(headers, rows));
  return fileName;
}

/** College-wide distribution as CSV: detail rows plus branch and program totals. */
export function exportDistributionReport(report: DistributionReport): string {
  const detailHeader = ["#", "الفرع", "البرنامج", "عدد الصفوف", "نشط", "غير نشط", "الإجمالي"];
  const detailRows = report.rows.map((row, index) => [
    String(index + 1),
    row.branchName,
    row.program,
    String(row.classCount),
    String(row.active),
    String(row.other),
    String(row.total),
  ]);

  const branchHeader = ["", "الإجمالي حسب الفرع", "", "", "نشط", "غير نشط", "الإجمالي"];
  const branchRows = report.branchTotals.map((row) => [
    "", row.branchName, "", "", String(row.active), String(row.other), String(row.total),
  ]);

  const programHeader = ["", "الإجمالي حسب البرنامج", "", "", "نشط", "غير نشط", "الإجمالي"];
  const programRows = report.programTotals.map((row) => [
    "", row.program, "", "", String(row.active), String(row.other), String(row.total),
  ]);

  const totalsRow = [
    "", "إجمالي الكلية", "",
    String(report.totals.classes),
    String(report.totals.active),
    String(report.totals.other),
    String(report.totals.total),
  ];

  const rows = [
    ...detailRows,
    ["", "", "", "", "", "", ""],
    branchHeader,
    ...branchRows,
    ["", "", "", "", "", "", ""],
    programHeader,
    ...programRows,
    ["", "", "", "", "", "", ""],
    totalsRow,
  ];

  const fileName = `student-distribution-${stamp()}.csv`;
  downloadCsv(fileName, buildCsv(detailHeader, rows));
  return fileName;
}

/** Admissions report as CSV: status breakdown then one row per application. */
export function exportAdmissionsReport(report: AdmissionsReport): string {
  const headers = [
    "#",
    "رقم الطلب",
    "اسم المتقدم",
    "ولي الأمر",
    "الهاتف",
    "البريد الإلكتروني",
    "البرنامج",
    "المستوى",
    "الفرع",
    "الجلسة",
    "الحالة",
    "الموظف المسند إليه",
    "تاريخ التقديم",
  ];

  const rows = report.rows.map((row, index) => [
    String(index + 1),
    row.application_no,
    row.applicant_full_name,
    row.guardian_name ?? "",
    row.phone ?? "",
    row.email ?? "",
    row.preferred_program ?? "",
    row.preferred_level ?? "",
    row.branch_name ?? "",
    row.session_name ?? "",
    statusLabel(row.status),
    row.assigned_name ?? "",
    row.created_at ? formatDate(row.created_at) : "",
  ]);

  const statusHeader = ["", "ملخص الحالات", "", "", "", "", "", "", "", "", "", "", ""];
  const statusRows = Object.entries(report.counts).map(([key, value]) => [
    "", statusLabel(key), "", "", "", "", "", "", "", "", String(value), "", "",
  ]);
  const totalRow = ["", "الإجمالي", "", "", "", "", "", "", "", "", String(report.total), "", ""];

  const csvRows = report.rows.length
    ? [...rows, [...statusHeader], ...statusRows, [...totalRow]]
    : [...statusRows, [...totalRow]];

  const fileName = `admissions-report-${stamp()}.csv`;
  downloadCsv(fileName, buildCsv(headers, csvRows));
  return fileName;
}

function statusLabel(key: string): string {
  const labels = admissionStatuses as Record<string, string>;
  return labels[key] ?? key;
}