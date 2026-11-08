import { useEffect, useState } from "react";
import {
  admissionStatuses, loadAdmissionHistoryExport, loadAdmissionRoster,
  type AdmissionHistoryExportRow, type AdmissionRosterRow,
} from "@/portal/lib/admissions";
import { formatDate } from "@/portal/lib/learning";
import { ReportSheet, type SummaryItem } from "@/portal/pages/reports/ReportShell";

export type AdmissionPrintKind = "roster" | "history";

export type AdmissionPrintScope = {
  branch: string | null;
  session: string | null;
  status: string | null;
  from: string | null;
  to: string | null;
  branchLabel: string;
};

const actionLabels: Record<string, string> = {
  insert: "تسجيل الطلب",
  status_change: "تغيير الحالة",
  update: "تحديث بيانات الطلب",
};

function statusLabel(value: string | null): string {
  if (!value) return "—";
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

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

type Loaded =
  | { kind: "roster"; rows: AdmissionRosterRow[] }
  | { kind: "history"; rows: AdmissionHistoryExportRow[] };

export function AdmissionPrintSheet({ kind, scope, onClose }: {
  kind: AdmissionPrintKind;
  scope: AdmissionPrintScope;
  onClose: () => void;
}) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [loaded, setLoaded] = useState<Loaded | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    setLoaded(null);
    const task = kind === "roster"
      ? loadAdmissionRoster({
          branch: scope.branch,
          session: scope.session,
          status: scope.status,
          from: scope.from,
          to: scope.to,
        }).then((rows) => ({ kind: "roster", rows } as Loaded))
      : loadAdmissionHistoryExport({
          branch: scope.branch,
          from: scope.from,
          to: scope.to,
          enquiryId: null,
        }).then((rows) => ({ kind: "history", rows } as Loaded));
    void task
      .then((value) => { if (active) setLoaded(value); })
      .catch((failure: unknown) => { if (active) setError(`تعذر تجهيز الكشف: ${message(failure)}`); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [kind, scope.branch, scope.session, scope.status, scope.from, scope.to, retry]);

  const counts: Record<string, number> = {};
  if (loaded?.kind === "roster") {
    loaded.rows.forEach((row) => { counts[row.status] = (counts[row.status] ?? 0) + 1; });
  }

  const summary: SummaryItem[] = loaded?.kind === "roster"
    ? [
        { label: "النطاق", value: scope.branchLabel },
        { label: "إجمالي الطلبات", value: String(loaded.rows.length) },
        { label: "قيد المراجعة", value: String(counts.new ?? 0) },
        { label: "مقبول", value: String(counts.accepted ?? 0) },
        { label: "مسجل", value: String(counts.enrolled ?? 0) },
      ]
    : loaded?.kind === "history"
      ? [
          { label: "النطاق", value: scope.branchLabel },
          { label: "إجمالي الحركات", value: String(loaded.rows.length) },
          { label: "من تاريخ", value: scope.from ? formatDate(scope.from) : "البداية" },
          { label: "إلى تاريخ", value: scope.to ? formatDate(scope.to) : "اليوم" },
        ]
      : [];

  const title = kind === "roster" ? "كشف طلبات القبول والتسجيل" : "سجل تغييرات حالات القبول";

  return <ReportSheet
    title={title}
    subtitle={`${scope.branchLabel} · تقرير رسمي معتمد للطباعة`}
    summary={summary}
    loading={loading}
    error={error}
    onRetry={() => setRetry((value) => value + 1)}
    onClose={onClose}
    canPrint={!loading && !error && Boolean(loaded)}
  >
    {loaded?.kind === "roster" && <RosterTable rows={loaded.rows} />}
    {loaded?.kind === "history" && <HistoryTable rows={loaded.rows} />}
  </ReportSheet>;
}

function RosterTable({ rows }: { rows: AdmissionRosterRow[] }) {
  if (!rows.length) return <p className="sheet-empty">لا توجد طلبات داخل النطاق المحدد.</p>;
  return <div className="report-section">
    <strong className="report-heading">كشف الطلبات ({rows.length} طلباً)</strong>
    <div className="table-scroll"><table className="sheet-table">
      <thead><tr>
        <th>#</th><th>الرقم المرجعي</th><th>المتقدم</th><th>ولي الأمر</th><th>الهاتف</th>
        <th>البرنامج</th><th>الفرع / الجلسة</th><th>الحالة</th><th>الموظف</th><th>تاريخ التقديم</th>
      </tr></thead>
      <tbody>{rows.map((row, index) => <tr key={`${row.application_no}-${index}`}>
        <td>{index + 1}</td>
        <td dir="ltr">{row.application_no}</td>
        <td><strong>{row.applicant_full_name}</strong></td>
        <td>{row.guardian_name ?? "—"}</td>
        <td dir="ltr">{row.phone ?? "—"}</td>
        <td>{row.preferred_program ?? "—"}</td>
        <td>{row.branch_name ?? "—"}{row.session_name ? ` · ${row.session_name}` : ""}</td>
        <td>{statusLabel(row.status)}</td>
        <td>{row.assigned_name ?? "غير مسند"}</td>
        <td>{row.created_at ? formatDate(row.created_at) : "—"}</td>
      </tr>)}</tbody>
    </table></div>
  </div>;
}

function HistoryTable({ rows }: { rows: AdmissionHistoryExportRow[] }) {
  if (!rows.length) return <p className="sheet-empty">لا توجد حركات مسجّلة داخل النطاق المحدد.</p>;
  return <div className="report-section">
    <strong className="report-heading">سجل الحركات ({rows.length} حركة)</strong>
    <div className="table-scroll"><table className="sheet-table">
      <thead><tr>
        <th>#</th><th>الرقم المرجعي</th><th>المتقدم</th><th>الفرع</th><th>نوع الحركة</th>
        <th>الحالة السابقة</th><th>الحالة الجديدة</th><th>الحقول المعدّلة</th><th>الموظف</th><th>التاريخ والوقت</th>
      </tr></thead>
      <tbody>{rows.map((row, index) => <tr key={`${row.application_no}-${row.occurred_at}-${index}`}>
        <td>{index + 1}</td>
        <td dir="ltr">{row.application_no}</td>
        <td><strong>{row.applicant_full_name}</strong></td>
        <td>{row.branch_name ?? "—"}</td>
        <td>{actionLabels[row.action] ?? row.action}</td>
        <td>{statusLabel(row.old_status)}</td>
        <td>{statusLabel(row.new_status)}</td>
        <td>{row.changed_columns || "—"}</td>
        <td>{row.actor_name ?? "—"}</td>
        <td>{formatWhen(row.occurred_at)}</td>
      </tr>)}</tbody>
    </table></div>
  </div>;
}