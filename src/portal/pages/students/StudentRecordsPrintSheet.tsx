import { useEffect, useState } from "react";
import { loadStudentRecordsForExport, type ManagementFilters, type StudentRosterExportRow } from "@/portal/lib/management";
import { exportStudentRecordsCsv } from "@/portal/lib/reportExport";
import { formatDate } from "@/portal/lib/learning";
import { ReportSheet, type SummaryItem } from "@/portal/pages/reports/ReportShell";

const statusLabels: Record<string, string> = {
  active: "نشط", inactive: "غير نشط", graduated: "متخرج", withdrawn: "منسحب",
};

export type RecordsPrintScope = {
  branchLabel: string;
  sessionLabel: string;
  classLabel: string;
  statusLabel: string;
};

/**
 * Official roster of every student matching the current Student Records filter,
 * printed on the college letterhead with a signature column so it can be
 * stamped and handed over like an admission sheet.
 */
export function StudentRecordsPrintSheet({ filters, scope, onClose }: {
  filters: ManagementFilters;
  scope: RecordsPrintScope;
  onClose: () => void;
}) {
  const [rows, setRows] = useState<StudentRosterExportRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    loadStudentRecordsForExport(filters)
      .then((value) => { if (active) setRows(value); })
      .catch((failure: unknown) => {
        if (active) setError(failure instanceof Error ? failure.message : String(failure));
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [filters, retry]);

  const activeCount = rows.filter((row) => row.status === "active").length;
  const summary: SummaryItem[] = [
    { label: "الفرع", value: scope.branchLabel },
    { label: "الجلسة", value: scope.sessionLabel },
    { label: "الصف", value: scope.classLabel },
    { label: "الحالة", value: scope.statusLabel },
    { label: "إجمالي الطلاب", value: String(rows.length) },
    { label: "الطلاب النشطون", value: String(activeCount) },
  ];

  const scopeText = `${scope.branchLabel} · ${scope.sessionLabel} · ${scope.classLabel}`;

  return <ReportSheet
    title="كشف سجلات الطلاب الرسمي"
    subtitle={`${scopeText} — كشف رسمي معتمد للتسليم والتوقيع`}
    summary={summary}
    loading={loading}
    error={error ? `تعذر تجهيز كشف الطلاب: ${error}` : null}
    onRetry={() => setRetry((value) => value + 1)}
    onClose={onClose}
    canPrint={!loading && !error && rows.length > 0}
    onExportCsv={() => exportStudentRecordsCsv(rows, scopeText)}
  >
    {rows.length === 0
      ? <p className="sheet-empty">لا توجد سجلات طلاب مطابقة للتصفية الحالية. عدّل الفرع أو الجلسة أو الحالة ثم أعد المحاولة.</p>
      : <div className="report-section">
        <strong className="report-heading">بيانات الطلاب المسجلين ({rows.length} طالباً)</strong>
        <div className="table-scroll"><table className="sheet-table">
          <thead><tr>
            <th className="sheet-col-index">#</th>
            <th>الاسم الكامل</th>
            <th>رقم القبول</th>
            <th>تاريخ الميلاد</th>
            <th>الحالة</th>
            <th>الصف</th>
            <th>الفرع</th>
            <th>الجلسة</th>
            <th className="sheet-sign-cell">توقيع</th>
          </tr></thead>
          <tbody>{rows.map((row, index) => <tr key={`${row.admission_no}-${index}`}>
            <td className="sheet-col-index">{index + 1}</td>
            <td><strong>{row.full_name}</strong></td>
            <td dir="ltr">{row.admission_no}</td>
            <td>{row.date_of_birth ? formatDate(row.date_of_birth) : "—"}</td>
            <td>{statusLabels[row.status] ?? row.status}</td>
            <td>{row.class_name ?? "بدون صف"}</td>
            <td>{row.branch_name ?? "—"}</td>
            <td>{row.session_name ?? "—"}</td>
            <td className="sheet-sign-cell" />
          </tr>)}</tbody>
        </table></div>
      </div>}
  </ReportSheet>;
}