import { PrintDoc } from "@/portal/pages/academics/PrintDoc";
import { printReference } from "@/portal/lib/letterhead";
import {
  examStatuses, gradeLabels, type Exam, type GradeCode,
} from "@/portal/lib/examinations";

export type ExamReportRow = {
  key: string;
  name: string;
  admissionNo: string;
  score: number | null;
  grade: GradeCode | null;
  note: string | null;
};

/**
 * Printable examination results sheet for one exam, on the shared letterhead.
 * Only saved results are printed; the sheet states the exam status so a draft
 * or review copy is never mistaken for a published result.
 */
export function ExamReportSheet({
  exam, className, branchName, sessionName, courseTitle, rows, onClose,
}: {
  exam: Exam;
  className: string;
  branchName: string;
  sessionName: string;
  courseTitle: string | null;
  rows: readonly ExamReportRow[];
  onClose: () => void;
}) {
  const recorded = rows.filter((row) => row.score !== null);
  const average = recorded.length
    ? Math.round((recorded.reduce((sum, row) => sum + (row.score ?? 0), 0) / recorded.length) * 100) / 100
    : null;
  const passed = recorded.filter((row) => row.grade !== null && row.grade !== "fail").length;

  return <PrintDoc
    title="كشف نتائج اختبار"
    subtitle={`${exam.title} · ${className} · ${exam.exam_date}`}
    onClose={onClose}
  >
    <div className="sheet-summary">
      <div><span>الاختبار</span><strong>{exam.title}</strong></div>
      <div><span>المادة</span><strong>{exam.subject}</strong></div>
      <div><span>الصف</span><strong>{className}</strong></div>
      <div><span>الفرع</span><strong>{branchName}</strong></div>
      <div><span>الجلسة الأكاديمية</span><strong>{sessionName}</strong></div>
      {courseTitle && <div><span>المقرر</span><strong>{courseTitle}</strong></div>}
      <div><span>التاريخ</span><strong>{exam.exam_date}</strong></div>
      {exam.room && <div><span>القاعة</span><strong>{exam.room}</strong></div>}
      <div><span>الحالة</span><strong>{examStatuses[exam.status]}</strong></div>
      <div><span>الدرجة العظمى</span><strong>{exam.max_score}</strong></div>
    </div>

    <div className="sheet-summary">
      <div><span>الطلاب</span><strong>{rows.length}</strong></div>
      <div><span>المُرصَّدون</span><strong>{recorded.length}</strong></div>
      <div><span>الناجحون</span><strong>{passed}</strong></div>
      <div><span>المتوسط</span><strong>{average === null ? "—" : `${average} / ${exam.max_score}`}</strong></div>
    </div>

    <div className="report-section">
      <strong className="report-heading">نتائج الطلاب ({rows.length})</strong>
      <div className="table-scroll">
        <table className="sheet-table attendance-sheet-table">
          <thead>
            <tr>
              <th className="sheet-col-index">#</th>
              <th>اسم الطالب</th>
              <th>الرقم الأكاديمي</th>
              <th>الدرجة</th>
              <th>التقدير</th>
              <th>ملاحظة</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => <tr key={row.key}>
              <td className="sheet-col-index">{index + 1}</td>
              <td><strong>{row.name}</strong></td>
              <td>{row.admissionNo}</td>
              <td>{row.score === null ? "—" : `${row.score} / ${exam.max_score}`}</td>
              <td>{row.grade ? gradeLabels[row.grade] : "—"}</td>
              <td>{row.note?.trim() || "—"}</td>
            </tr>)}
          </tbody>
        </table>
      </div>
    </div>

    <p className="sheet-note">
      {exam.status === "published"
        ? "هذه النتائج معتمدة ومنشورة للطلاب وأولياء الأمور."
        : "هذه النتائج غير منشورة؛ النسخة للمراجعة الداخلية فقط ولا تُعتمد للطلاب."}
      {" "}مرجع الكشف: {printReference("EXM")}.
    </p>

    <div className="receipt-signatures">
      <div><span>معلم المادة</span></div>
      <div><span>اعتماد الشؤون الأكاديمية</span></div>
    </div>
  </PrintDoc>;
}
