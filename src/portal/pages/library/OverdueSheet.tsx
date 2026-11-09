import { PrintFooter, PrintLetterhead } from "@/portal/components/PrintLetterhead";
import { buildSheetMeta } from "@/portal/lib/letterhead";
import { printSheet } from "@/portal/lib/printDocument";
import { formatDate } from "@/portal/lib/learning";
import type { LibraryLoan } from "@/portal/lib/library";

function daysOverdue(due: string): number {
  const today = new Date().toISOString().slice(0, 10);
  const diff = Date.parse(`${today}T00:00:00Z`) - Date.parse(`${due}T00:00:00Z`);
  return Math.max(Math.round(diff / 86400000), 0);
}

export function OverdueSheet({
  branchName,
  loans,
  onClose,
}: {
  branchName: string;
  loans: readonly LibraryLoan[];
  onClose: () => void;
}) {
  const title = "قائمة الكتب المتأخرة";
  const students = new Set(loans.map((loan) => loan.student_id)).size;
  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label={title}>
    <div className="assignment-sheet">
      <PrintLetterhead
        title={title}
        topic={`${branchName || "كل الفروع"} · ${loans.length} إعارة متأخرة`}
        meta={buildSheetMeta()}
      />

      <div className="sheet-summary">
        <div><span>عدد الإعارات المتأخرة</span><strong>{loans.length}</strong></div>
        <div><span>عدد الطلاب</span><strong>{students}</strong></div>
        <div><span>الفرع</span><strong>{branchName || "كل الفروع"}</strong></div>
        <div><span>تاريخ الكشف</span><strong>{formatDate(new Date().toISOString())}</strong></div>
      </div>

      <div className="sheet-body">
        {loans.length
          ? <table className="management-table">
            <thead>
              <tr><th>#</th><th>الطالب</th><th>الرقم الأكاديمي</th><th>الكتاب</th><th>تاريخ الإعارة</th><th>الاستحقاق</th><th>أيام التأخير</th></tr>
            </thead>
            <tbody>
              {loans.map((loan, index) => <tr key={loan.id}>
                <td>{index + 1}</td>
                <td>{loan.studentName}</td>
                <td>{loan.admissionNo}</td>
                <td>{loan.itemTitle}</td>
                <td>{formatDate(loan.issued_at)}</td>
                <td>{formatDate(loan.due_date)}</td>
                <td><strong>{daysOverdue(loan.due_date)}</strong></td>
              </tr>)}
            </tbody>
          </table>
          : <p className="sheet-note">لا توجد إعارات متأخرة في هذا الفرع حتى تاريخ الكشف.</p>}
      </div>

      <p className="sheet-note">
        يُرجى من أولياء الأمور متابعة إعادة الكتب المتأخرة مع أبنائهم خلال أسبوع من تاريخ هذا الكشف، أو التواصل مع أمين المكتبة لتجديد الإعارة.
      </p>

      <div className="receipt-signatures">
        <div><span>أمين المكتبة</span></div>
        <div><span>مدير الشؤون الأكاديمية</span></div>
      </div>

      <PrintFooter />
    </div>

    <div className="print-actions">
      <button className="button primary" type="button" onClick={() => printSheet(title)}>طباعة الكشف</button>
      <button className="button secondary" type="button" onClick={onClose}>إغلاق</button>
    </div>
  </div>;
}