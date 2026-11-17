import { PrintDoc } from "@/portal/pages/academics/PrintDoc";
import { printReference } from "@/portal/lib/letterhead";
import { gradeLabels, type FamilyResult } from "@/portal/lib/examinations";

/** Printable published-result card for a student or verified parent. */
export function FamilyResultSheet({ result, studentName, onClose }: {
  result: FamilyResult;
  studentName: string;
  onClose: () => void;
}) {
  return <PrintDoc
    title="إشعار نتيجة اختبار"
    subtitle={`${result.exam?.title ?? "اختبار"} · ${result.exam?.exam_date ?? ""}`}
    onClose={onClose}
  >
    <div className="sheet-summary">
      <div><span>الطالب</span><strong>{studentName}</strong></div>
      <div><span>الاختبار</span><strong>{result.exam?.title ?? "—"}</strong></div>
      <div><span>المادة</span><strong>{result.exam?.subject ?? "—"}</strong></div>
      <div><span>التاريخ</span><strong>{result.exam?.exam_date ?? "—"}</strong></div>
      <div><span>الدرجة</span><strong>{result.score === null ? "—" : `${result.score} / ${result.exam?.max_score ?? "—"}`}</strong></div>
      <div><span>التقدير</span><strong>{result.grade ? gradeLabels[result.grade] : "—"}</strong></div>
      {result.note && <div><span>ملاحظة</span><strong>{result.note}</strong></div>}
    </div>

    <p className="sheet-note">
      تصدر هذه النتيجة من السجلات المنشورة والمعتمدة في نظام كلية ساي.
      مرجع المستند: {printReference("EXR")}.
    </p>

    <div className="receipt-signatures">
      <div><span>ولي الأمر / الطالب</span></div>
      <div><span>الشؤون الأكاديمية</span></div>
    </div>
  </PrintDoc>;
}
