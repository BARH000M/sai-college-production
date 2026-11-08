import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  loadAttendanceReport, loadEnrollmentReport, loadReportClasses,
  type AttendanceReport, type EnrollmentReport, type ReportOption,
} from "../lib/reports";
import { exportAttendanceReport, exportEnrollmentReport } from "../lib/reportExport";
import { loadArchiveList, loadLastArchive, rememberArchive, type SavedArchive } from "../lib/archiveHeader";
import { ReportSheet, type SummaryItem } from "./reports/ReportShell";
import { AttendanceSheet, EnrollmentSheet } from "./reports/ReportSheets";
import { ArchiveDropdown } from "./reports/ArchiveDropdown";

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function isoDate(date: Date): string {
  const offset = date.getTimezoneOffset() * 60000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 10);
}

function defaultRange(): { from: string; to: string } {
  const to = new Date();
  const from = new Date(to.getTime() - 90 * 24 * 60 * 60 * 1000);
  return { from: isoDate(from), to: isoDate(to) };
}

type QuickKind = "students" | "attendance";

const quickKinds: { id: QuickKind; label: string; icon: string }[] = [
  { id: "students", label: "كشف طلاب الصف", icon: "ri-file-list-3-line" },
  { id: "attendance", label: "ملخص الحضور", icon: "ri-calendar-check-line" },
];

/**
 * Quick print straight from the dashboard: pick one of the current branch/session
 * classes and print its roster or attendance summary without opening Reports.
 * Remembers the last used term / prepared-by header.
 */
export function DashboardReportPrint({ branchId, sessionId }: { branchId: string; sessionId: string }) {
  const range = useMemo(defaultRange, []);
  const [classes, setClasses] = useState<ReportOption[]>([]);
  const [classId, setClassId] = useState("");
  const [classesLoading, setClassesLoading] = useState(false);
  const [listError, setListError] = useState<string | null>(null);

  const [kind, setKind] = useState<QuickKind>("students");
  const [from, setFrom] = useState(range.from);
  const [to, setTo] = useState(range.to);

  const [term, setTerm] = useState(() => loadLastArchive()?.term ?? "");
  const [preparedBy, setPreparedBy] = useState(() => loadLastArchive()?.preparedBy ?? "");
  const [archiveEntries, setArchiveEntries] = useState<SavedArchive[]>(() => loadArchiveList());

  const [roster, setRoster] = useState<EnrollmentReport | null>(null);
  const [attendance, setAttendance] = useState<AttendanceReport | null>(null);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [sheetLoading, setSheetLoading] = useState(false);
  const [sheetError, setSheetError] = useState<string | null>(null);

  useEffect(() => {
    if (!branchId || !sessionId) { setClasses([]); setClassId(""); return; }
    let active = true;
    setClassesLoading(true);
    setListError(null);
    void loadReportClasses(branchId, sessionId)
      .then((rows) => {
        if (!active) return;
        setClasses(rows);
        setClassId((current) => (current && rows.some((row) => row.id === current) ? current : rows[0]?.id ?? ""));
      })
      .catch((failure: unknown) => { if (active) setListError(message(failure)); })
      .finally(() => { if (active) setClassesLoading(false); });
    return () => { active = false; };
  }, [branchId, sessionId]);

  function resetSheet() {
    setRoster(null);
    setAttendance(null);
    setSheetError(null);
  }

  async function openSheet() {
    if (!classId) return;
    if (kind === "attendance" && (!from || !to)) { setSheetError("حدد بداية ونهاية الفترة."); return; }
    setArchiveEntries(rememberArchive({ term, preparedBy }));
    setSheetOpen(true);
    setSheetLoading(true);
    setSheetError(null);
    setRoster(null);
    setAttendance(null);
    try {
      if (kind === "students") setRoster(await loadEnrollmentReport(classId));
      else setAttendance(await loadAttendanceReport(classId, from, to));
    } catch (failure) {
      setSheetError(`تعذر تجهيز الكشف: ${message(failure)}`);
    } finally {
      setSheetLoading(false);
    }
  }

  const summary: SummaryItem[] = kind === "students"
    ? roster
      ? [
          { label: "الصف", value: roster.className },
          { label: "الفرع", value: roster.branchName },
          { label: "إجمالي الطلاب", value: String(roster.counts.total) },
          { label: "الطلاب النشطون", value: String(roster.counts.active) },
          { label: "السعة", value: roster.capacity ? String(roster.capacity) : "—" },
        ]
      : []
    : attendance
      ? (() => {
          const present = attendance.totals.present ?? 0;
          const excused = attendance.totals.excused ?? 0;
          const rate = attendance.totalRecords ? Math.round(((present + excused) / attendance.totalRecords) * 100) : 0;
          return [
            { label: "الصف", value: attendance.className },
            { label: "عدد الجلسات", value: String(attendance.sessionCount) },
            { label: "إجمالي السجلات", value: String(attendance.totalRecords) },
            { label: "حاضر", value: String(present) },
            { label: "نسبة الحضور", value: attendance.totalRecords ? `${rate}%` : "—" },
          ];
        })()
      : [];

  const canPrint = kind === "students" ? Boolean(roster) : Boolean(attendance);

  return <section id="quick-print" className="panel">
    <div className="page-heading">
      <div>
        <h2>طباعة سريعة لكشوف الصفوف</h2>
        <p className="muted">اطبع كشف طلاب الصف أو ملخص الحضور مباشرة من هنا، دون فتح صفحة التقارير.</p>
      </div>
      <Link className="button secondary" to="/portal/modules/reports">كل التقارير</Link>
    </div>

    {listError && <p className="error-box" role="alert">تعذر تحميل الصفوف: {listError}</p>}

    {!branchId || !sessionId
      ? <p className="muted">اختر فرعاً وجلسة من الأعلى لعرض الصفوف المتاحة.</p>
      : classesLoading
        ? <p className="muted" role="status">جارٍ تحميل الصفوف...</p>
        : classes.length === 0
          ? <p className="notice">لا توجد صفوف نشطة في هذا الفرع والجلسة.</p>
          : <div className="management-form">
              <label>نوع الكشف
                <select value={kind} onChange={(event) => { setKind(event.target.value as QuickKind); resetSheet(); }}>
                  {quickKinds.map((item) => <option key={item.id} value={item.id}>{item.label}</option>)}
                </select>
              </label>
              <label>الصف
                <select value={classId} onChange={(event) => { setClassId(event.target.value); resetSheet(); }}>
                  {classes.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
                </select>
              </label>
              {kind === "attendance" && <>
                <label>من تاريخ<input type="date" value={from} onChange={(event) => { setFrom(event.target.value); resetSheet(); }} /></label>
                <label>إلى تاريخ<input type="date" value={to} onChange={(event) => { setTo(event.target.value); resetSheet(); }} /></label>
              </>}
              <label>الفصل / الفترة (اختياري)
                <input type="text" value={term} placeholder="مثال: الفصل الأول 2025/2026" onChange={(event) => setTerm(event.target.value)} />
              </label>
              <label>أعدّه (اختياري)
                <input type="text" value={preparedBy} placeholder="اسم الموظف المُعِد" onChange={(event) => setPreparedBy(event.target.value)} />
              </label>
              <ArchiveDropdown entries={archiveEntries} onPick={(value) => { setTerm(value.term); setPreparedBy(value.preparedBy); }} />
              <div className="actions" style={{ alignSelf: "end" }}>
                <button className="button primary" type="button" disabled={!classId || sheetLoading} onClick={() => void openSheet()}>
                  <i className="ri-printer-line" aria-hidden="true"></i> {sheetLoading ? "جارٍ التجهيز..." : kind === "attendance" ? "معاينة وطباعة ملخص الحضور" : "معاينة وطباعة الكشف"}
                </button>
              </div>
            </div>}

    {sheetOpen && <ReportSheet
      title={kind === "students" ? "كشف طلاب الصف" : "ملخص الحضور"}
      subtitle={`${(kind === "students" ? roster : attendance) ? `${(kind === "students" ? roster : attendance)?.className} · ` : ""}كشف رسمي معتمد للطباعة`}
      summary={summary}
      loading={sheetLoading}
      error={sheetError}
      onRetry={() => void openSheet()}
      onClose={() => setSheetOpen(false)}
      canPrint={canPrint}
      archive={{ term, preparedBy }}
      onExportCsv={kind === "students"
        ? (roster ? () => exportEnrollmentReport(roster) : undefined)
        : (attendance ? () => exportAttendanceReport(attendance) : undefined)}
    >
      {kind === "students" && roster && <EnrollmentSheet report={roster} />}
      {kind === "attendance" && attendance && <AttendanceSheet report={attendance} />}
    </ReportSheet>}
  </section>;
}