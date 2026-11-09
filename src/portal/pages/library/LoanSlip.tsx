import { PrintFooter, PrintLetterhead } from "@/portal/components/PrintLetterhead";
import { buildSheetMeta } from "@/portal/lib/letterhead";
import { printSheet } from "@/portal/lib/printDocument";
import { formatDate } from "@/portal/lib/learning";
import type { LibraryLoan } from "@/portal/lib/library";

export function LoanSlip({ loan, onClose }: { loan: LibraryLoan; onClose: () => void }) {
  const title = "إيصال إعارة كتاب";
  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label={title}>
    <div className="assignment-sheet">
      <PrintLetterhead
        title={title}
        topic={`رقم الإعارة: ${loan.id.slice(0, 8).toUpperCase()}`}
        meta={buildSheetMeta()}
      />

      <div className="sheet-summary">
        <div><span>اسم الطالب</span><strong>{loan.studentName}</strong></div>
        <div><span>الرقم الأكاديمي</span><strong>{loan.admissionNo}</strong></div>
        <div><span>تاريخ الإعارة</span><strong>{formatDate(loan.issued_at)}</strong></div>
        <div><span>تاريخ الإرجاع المستحق</span><strong>{formatDate(loan.due_date)}</strong></div>
      </div>

      <div className="sheet-body">
        <table className="management-table">
          <thead>
            <tr><th>الكتاب</th><th>ملاحظات</th><th>حالة الإعارة</th></tr>
          </thead>
          <tbody>
            <tr>
              <td>{loan.itemTitle}</td>
              <td>{loan.notes ?? "—"}</td>
              <td>{loan.returned_at ? `أُعيد في ${formatDate(loan.returned_at)}` : "قيد الإعارة"}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <p className="sheet-note">
        يلتزم الطالب بإعادة الكتاب في التاريخ المحدد أو تجديد الإعارة قبل انقضاء المدة. تُحتسب النسخة المفقودة أو التالفة وفق لائحة المكتبة.
      </p>

      <div className="receipt-signatures">
        <div><span>توقيع أمين المكتبة</span></div>
        <div><span>توقيع الطالب / ولي الأمر</span></div>
      </div>

      <PrintFooter />
    </div>

    <div className="print-actions">
      <button className="button primary" type="button" onClick={() => printSheet(title)}>طباعة الإيصال</button>
      <button className="button secondary" type="button" onClick={onClose}>إغلاق</button>
    </div>
  </div>;
}