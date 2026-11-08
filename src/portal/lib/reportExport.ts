import { buildCsv, downloadCsv } from "./csv";
import { admissionStatuses } from "./admissions";
import { attendanceStatuses } from "./attendance";
import { formatDate } from "./learning";
import { collegeIdentity, printDate } from "./letterhead";
import type { StudentRosterExportRow } from "./management";
import type { StudentReport } from "./studentReport";
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

/** Student records ("سجلات الطلاب") as CSV, exported straight from the records screen. */
export function exportStudentRecordsCsv(rows: readonly StudentRosterExportRow[], scopeLabel: string): string {
  const headers = ["#", "الاسم الكامل", "رقم القبول", "تاريخ الميلاد", "الحالة", "الصف", "الفرع", "الجلسة"];
  const body = rows.map((row, index) => [
    String(index + 1),
    row.full_name,
    row.admission_no,
    row.date_of_birth ? formatDate(row.date_of_birth) : "",
    studentStatuses[row.status] ?? row.status,
    row.class_name ?? "بدون صف",
    row.branch_name ?? "",
    row.session_name ?? "",
  ]);

  const statusKeys = ["active", "inactive", "graduated", "withdrawn"];
  const summaryHeader = ["", "ملخص الحالات", "", "", "", "", "", ""];
  const summaryRows = statusKeys.map((key) => [
    "", studentStatuses[key], "", "", String(rows.filter((row) => row.status === key).length), "", "", "",
  ]);
  const totalRow = ["", "الإجمالي", "", "", String(rows.length), "", "", ""];

  const csvRows = [...body, [""], summaryHeader, ...summaryRows, totalRow];
  const fileName = `students-records-${slug(scopeLabel)}-${stamp()}.csv`;
  downloadCsv(fileName, buildCsv(headers, csvRows));
  return fileName;
}

function statusLabel(key: string): string {
  const labels = admissionStatuses as Record<string, string>;
  return labels[key] ?? key;
}

/**
 * Single-student parent report as CSV: the same sections that are printed on the
 * parent sheet (identity, courses, homework, grades, attendance) so the copy
 * handed to the guardian also exists as a spreadsheet.
 */
export function exportStudentReportCsv(report: StudentReport): string {
  const headers = ["القسم", "العنصر", "التفاصيل", "القيمة", "ملاحظات"];
  const rows: (string | null)[][] = [];

  rows.push(["بيانات التقرير", "اسم الكلية", collegeIdentity.nameAr, "", ""]);
  rows.push(["بيانات التقرير", "الموقع الإلكتروني", "", collegeIdentity.website, ""]);
  rows.push(["بيانات التقرير", "هاتف الكلية", "", collegeIdentity.phone, ""]);
  rows.push(["بيانات التقرير", "تاريخ الإصدار", "", printDate(), ""]);
  rows.push(["بيانات الطالب", "الاسم", report.student.full_name, "", ""]);
  rows.push(["بيانات الطالب", "رقم القبول", report.student.admission_no, "", ""]);
  rows.push(["بيانات الطالب", "الصف", report.className ?? "بدون صف", "", ""]);
  rows.push(["بيانات الطالب", "الفرع", report.branchName ?? "—", "", ""]);
  rows.push(["بيانات الطالب", "نسبة الإنجاز العامة", "", `${report.overallPercent}%`, ""]);
  rows.push([
    "بيانات الطالب", "المعدل العام للدرجات", "",
    report.averageGrade === null ? "—" : `${report.averageGrade}%`, "",
  ]);

  rows.push(["", "", "", "", ""]);
  if (!report.courses.length) {
    rows.push(["المقررات", "لا توجد مقررات مرتبطة بصف الطالب", "", "", ""]);
  } else {
    report.courses.forEach((course) => rows.push([
      "المقررات",
      course.title,
      course.level ?? "—",
      `${course.completed}/${course.totalLessons} درساً`,
      `${course.percent}%`,
    ]));
  }

  rows.push(["", "", "", "", ""]);
  if (!report.homework.length) {
    rows.push(["الواجبات", "لا توجد واجبات منشورة", "", "", ""]);
  } else {
    report.homework.forEach((item) => rows.push([
      "الواجبات", item.title, item.courseTitle, formatDate(item.dueAt), item.statusLabel,
    ]));
  }
  rows.push(["الواجبات", "الإجمالي", `${report.homeworkDone} منجز`, `${report.homeworkPending} مستحق`, ""]);

  rows.push(["", "", "", "", ""]);
  if (!report.grades.length) {
    rows.push(["الدرجات", "لم تُعتمد درجات بعد", "", "", ""]);
  } else {
    report.grades.forEach((grade) => rows.push([
      "الدرجات",
      grade.homeworkTitle,
      grade.courseTitle,
      `${grade.score} / ${grade.maxScore}`,
      `${grade.feedback ?? "—"} (${grade.percent}%)`,
    ]));
  }

  rows.push(["", "", "", "", ""]);
  if (!report.attendanceTotal) {
    rows.push(["الحضور", "لا توجد سجلات حضور لهذا الطالب بعد", "", "", ""]);
  } else {
    report.attendance.forEach((item) => rows.push(["الحضور", item.label, "", String(item.count), ""]));
    rows.push(["الحضور", "إجمالي السجلات", "", String(report.attendanceTotal), ""]);
  }

  const fileName = `student-report-${slug(report.student.admission_no || report.student.full_name)}-${stamp()}.csv`;
  downloadCsv(fileName, buildCsv(headers, rows));
  return fileName;
}