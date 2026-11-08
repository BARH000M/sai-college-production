import { attendanceStatuses } from "@/portal/lib/attendance";
import { admissionStatuses } from "@/portal/lib/admissions";
import { formatDate } from "@/portal/lib/learning";
import type { AdmissionsReport, AttendanceReport, EnrollmentReport, HomeworkReport } from "@/portal/lib/reports";

const studentStatuses: Record<string, string> = {
  active: "نشط", inactive: "غير نشط", graduated: "متخرج", withdrawn: "منسحب",
};
const attendanceKeys = Object.keys(attendanceStatuses);

export function EnrollmentSheet({ report }: { report: EnrollmentReport }) {
  if (!report.rows.length) return <p className="sheet-empty">لا يوجد طلاب مسجلون في هذا الصف.</p>;
  return <div className="report-section">
    <strong className="report-heading">كشف طلاب الصف ({report.rows.length} طالباً · السعة {report.capacity ?? "—"})</strong>
    <div className="table-scroll"><table className="sheet-table">
      <thead><tr><th>#</th><th>الاسم الكامل</th><th>رقم القبول</th><th>تاريخ الميلاد</th><th>الحالة</th><th className="sheet-sign-cell">توقيع</th></tr></thead>
      <tbody>{report.rows.map((row, index) => <tr key={row.id}>
        <td>{index + 1}</td>
        <td><strong>{row.full_name}</strong></td>
        <td dir="ltr">{row.admission_no}</td>
        <td>{row.date_of_birth ? formatDate(row.date_of_birth) : "—"}</td>
        <td>{studentStatuses[row.status] ?? row.status}</td>
        <td className="sheet-sign-cell"></td>
      </tr>)}</tbody>
    </table></div>
  </div>;
}

export function AttendanceSheet({ report }: { report: AttendanceReport }) {
  return <>
    {report.sessionCount === 0 && <p className="sheet-empty">لا توجد جلسات حضور مفتوحة لهذا الصف داخل الفترة المحددة.</p>}
    <div className="report-section">
      <strong className="report-heading">ملخص الحضور العام ({report.totalRecords} سجل داخل {report.sessionCount} جلسة)</strong>
      <div className="sheet-summary">
        {attendanceKeys.map((key) => <div key={key}>
          <span>{attendanceStatuses[key as keyof typeof attendanceStatuses]}</span>
          <strong>{report.totals[key] ?? 0}</strong>
        </div>)}
      </div>
    </div>
    <div className="report-section">
      <strong className="report-heading">حضور الطلاب بالتفصيل</strong>
      {report.rows.length === 0 ? <p className="sheet-empty">لا يوجد طلاب نشطون في هذا الصف.</p> : <div className="table-scroll"><table className="sheet-table">
        <thead><tr>
          <th>#</th><th>الطالب</th><th>رقم القبول</th>
          {attendanceKeys.map((key) => <th key={key}>{attendanceStatuses[key as keyof typeof attendanceStatuses]}</th>)}
          <th>الإجمالي</th><th>نسبة الحضور</th>
        </tr></thead>
        <tbody>{report.rows.map((row, index) => <tr key={row.studentId}>
          <td>{index + 1}</td>
          <td><strong>{row.full_name}</strong></td>
          <td dir="ltr">{row.admission_no}</td>
          {attendanceKeys.map((key) => <td key={key}>{row.counts[key] ?? 0}</td>)}
          <td>{row.total}</td>
          <td>{row.total ? `${row.percent}%` : "—"}</td>
        </tr>)}</tbody>
      </table></div>}
    </div>
  </>;
}

export function HomeworkSheet({ report }: { report: HomeworkReport }) {
  if (!report.rows.length) return <p className="sheet-empty">لا توجد واجبات منشورة لصف هذا الطالب بعد.</p>;
  return <div className="report-section">
    <strong className="report-heading">حالة الواجبات مقابل عدد الطلاب النشطين ({report.rosterSize} طالباً)</strong>
    <div className="table-scroll"><table className="sheet-table">
      <thead><tr><th>الواجب</th><th>المقرر</th><th>موعد التسليم</th><th>الدرجة القصوى</th><th>مُسلَّم</th><th>مُصحَّح</th><th>لم يُسلَّم</th></tr></thead>
      <tbody>{report.rows.map((row) => <tr key={row.id}>
        <td><strong>{row.title}</strong></td>
        <td>{row.courseTitle}</td>
        <td>{formatDate(row.dueAt)}</td>
        <td>{row.maxScore}</td>
        <td>{row.submitted}</td>
        <td>{row.graded}</td>
        <td>{row.pending}</td>
      </tr>)}</tbody>
    </table></div>
  </div>;
}

export function AdmissionsSheet({ report }: { report: AdmissionsReport }) {
  const statusEntries = Object.entries(admissionStatuses);
  return <>
    <div className="report-section">
      <strong className="report-heading">توزيع الطلبات حسب الحالة ({report.total} طلباً)</strong>
      <div className="sheet-summary">
        {statusEntries.map(([key, label]) => <div key={key}>
          <span>{label}</span>
          <strong>{report.counts[key] ?? 0}</strong>
        </div>)}
      </div>
    </div>
    <div className="report-section">
      <strong className="report-heading">كشف الطلبات</strong>
      {report.rows.length === 0 ? <p className="sheet-empty">لا توجد طلبات داخل النطاق المحدد.</p> : <div className="table-scroll"><table className="sheet-table">
        <thead><tr><th>#</th><th>الرقم المرجعي</th><th>المتقدم</th><th>ولي الأمر</th><th>الهاتف</th><th>البرنامج</th><th>الفرع / الجلسة</th><th>الحالة</th><th>التاريخ</th></tr></thead>
        <tbody>{report.rows.map((row, index) => <tr key={`${row.application_no}-${index}`}>
          <td>{index + 1}</td>
          <td dir="ltr">{row.application_no}</td>
          <td><strong>{row.applicant_full_name}</strong></td>
          <td>{row.guardian_name ?? "—"}</td>
          <td dir="ltr">{row.phone ?? "—"}</td>
          <td>{row.preferred_program ?? "—"}</td>
          <td>{row.branch_name ?? "—"}{row.session_name ? ` · ${row.session_name}` : ""}</td>
          <td>{admissionStatuses[row.status as keyof typeof admissionStatuses] ?? row.status}</td>
          <td>{row.created_at ? formatDate(row.created_at) : "—"}</td>
        </tr>)}</tbody>
      </table></div>}
    </div>
  </>;
}