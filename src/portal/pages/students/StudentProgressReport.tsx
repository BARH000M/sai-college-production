import { useEffect, useRef, useState } from "react";
import { loadStudentReport, type StudentReport } from "@/portal/lib/studentReport";
import { formatDate } from "@/portal/lib/learning";
import { exportStudentReportCsv } from "@/portal/lib/reportExport";
import { printDate, buildSheetMeta, type ArchiveHeader } from "@/portal/lib/letterhead";
import { PrintFooter, PrintLetterhead } from "@/portal/components/PrintLetterhead";

export function StudentProgressReport({ studentId, onClose, autoPrint = false, archive }: {
  studentId: string;
  onClose: () => void;
  autoPrint?: boolean;
  archive?: ArchiveHeader;
}) {
  const preparedBy = archive?.preparedBy?.trim();
  const [report, setReport] = useState<StudentReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);
  const [exportNote, setExportNote] = useState<string | null>(null);
  const printed = useRef(false);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    loadStudentReport(studentId)
      .then((value) => { if (active) setReport(value); })
      .catch((failure: unknown) => { if (active) setError(failure instanceof Error ? failure.message : String(failure)); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [studentId, retry]);

  // When opened from a "print" action, hand the sheet straight to the printer once loaded.
  useEffect(() => {
    if (!autoPrint || !report || printed.current) return;
    printed.current = true;
    const timer = window.setTimeout(() => window.print(), 400);
    return () => window.clearTimeout(timer);
  }, [autoPrint, report]);

  function handleExport() {
    if (!report) return;
    try {
      const fileName = exportStudentReportCsv(report);
      setExportNote(`تم تنزيل نسخة الجدول (CSV): ${fileName}`);
    } catch (failure) {
      setExportNote(`تعذر تصدير النسخة الجدولية: ${failure instanceof Error ? failure.message : String(failure)}`);
    }
  }

  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label="تقرير تقدم الطالب للفصل">
    <div className="assignment-sheet">
      <PrintLetterhead
        title="تقرير تقدم الطالب للفصل الدراسي"
        topic="المقررات والدرجات والحضور — نسخة ولي الأمر"
        meta={buildSheetMeta(archive)}
      />

      {loading && <p role="status">جارٍ تحميل التقرير...</p>}
      {error && <p className="error-box" role="alert">تعذر تحميل التقرير: {error} <button className="text-button" type="button" onClick={() => setRetry((v) => v + 1)}>إعادة المحاولة</button></p>}

      {report && !loading && !error && <>
        <div className="sheet-summary">
          <div><span>الطالب</span><strong>{report.student.full_name}</strong></div>
          <div><span>رقم القبول</span><strong dir="ltr">{report.student.admission_no}</strong></div>
          <div><span>الصف / الفرع</span><strong>{report.className ?? "بلا صف"} · {report.branchName ?? "—"}</strong></div>
          <div><span>تاريخ التقرير</span><strong>{printDate()}</strong></div>
          <div><span>نسبة الإنجاز العامة</span><strong>{report.overallPercent}%</strong></div>
          <div><span>المعدل العام للدرجات</span><strong>{report.averageGrade === null ? "—" : `${report.averageGrade}%`}</strong></div>
        </div>

        <div className="sheet-body">
          <div className="report-section">
            <strong className="report-heading">المقررات ونسبة التقدم</strong>
            {report.courses.length === 0 ? <p className="muted">لا توجد مقررات مرتبطة بصف الطالب.</p> : <table className="sheet-table">
              <thead><tr><th>المقرر</th><th>المستوى</th><th>الدروس</th><th>المكتملة</th><th>النسبة</th></tr></thead>
              <tbody>{report.courses.map((c) => <tr key={c.id}>
                <td><strong>{c.title}</strong></td><td>{c.level ?? "—"}</td><td>{c.totalLessons}</td><td>{c.completed}</td><td>{c.percent}%</td>
              </tr>)}</tbody>
            </table>}
          </div>

          <div className="report-section">
            <strong className="report-heading">الواجبات — المنجز مقابل المستحق ({report.homeworkDone} منجز · {report.homeworkPending} مستحق)</strong>
            {report.homework.length === 0 ? <p className="muted">لا توجد واجبات منشورة.</p> : <table className="sheet-table">
              <thead><tr><th>الواجب</th><th>المقرر</th><th>موعد التسليم</th><th>الحالة</th></tr></thead>
              <tbody>{report.homework.map((h, i) => <tr key={i}>
                <td>{h.title}</td><td>{h.courseTitle}</td><td>{formatDate(h.dueAt)}</td>
                <td>{h.statusLabel}</td>
              </tr>)}</tbody>
            </table>}
          </div>

          <div className="report-section">
            <strong className="report-heading">الدرجات المعتمدة وملاحظات المعلم</strong>
            {report.grades.length === 0 ? <p className="muted">لم تُعتمد درجات بعد.</p> : <table className="sheet-table">
              <thead><tr><th>الواجب</th><th>المقرر</th><th>الدرجة</th><th>النسبة</th><th>ملاحظة المعلم</th></tr></thead>
              <tbody>{report.grades.map((g, i) => <tr key={i}>
                <td>{g.homeworkTitle}</td><td>{g.courseTitle}</td><td dir="ltr">{g.score} / {g.maxScore}</td><td>{g.percent}%</td>
                <td>{g.feedback ?? "—"}</td>
              </tr>)}</tbody>
            </table>}
          </div>

          <div className="report-section">
            <strong className="report-heading">ملخص الحضور ({report.attendanceTotal} سجل)</strong>
            {report.attendanceTotal === 0 ? <p className="muted">لا توجد سجلات حضور لهذا الطالب بعد.</p> : <div className="sheet-summary">
              {report.attendance.map((a) => <div key={a.label}><span>{a.label}</span><strong>{a.count}</strong></div>)}
            </div>}
          </div>
        </div>

        <p className="sheet-note">
          يُوضّح هذا التقرير تقدّم الطالب حتى تاريخه. يُعدّ مرجعاً للقاء ولي الأمر، وأي تحديث لاحق يظهر عند إعادة الطباعة.
        </p>

        <div className="receipt-signatures">
          <div><span>{preparedBy ? `إعداد: ${preparedBy}` : "توقيع المعلم / إدارة الكلية"}</span></div>
          <div><span>توقيع ولي الأمر بالاستلام</span></div>
        </div>

        <PrintFooter />
      </>}
    </div>

    <div className="print-actions">
      <button className="button primary" type="button" onClick={() => window.print()} disabled={!report || loading || !!error}>
        <i className="ri-printer-line" aria-hidden="true"></i> طباعة التقرير لولي الأمر
      </button>
      <button className="button secondary" type="button" onClick={handleExport} disabled={!report || loading || !!error}>
        <i className="ri-file-excel-2-line" aria-hidden="true"></i> تصدير نسخة CSV
      </button>
      <button className="button secondary" type="button" onClick={onClose}>إغلاق</button>
      {exportNote && <p className="sheet-export-note" role="status">{exportNote}</p>}
    </div>
  </div>;
}