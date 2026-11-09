import { PrintFooter, PrintLetterhead } from "@/portal/components/PrintLetterhead";
import { buildSheetMeta } from "@/portal/lib/letterhead";
import { printSheet } from "@/portal/lib/printDocument";
import { formatDate } from "@/portal/lib/learning";
import type { LibraryLoan } from "@/portal/lib/library";

export function StudentHistorySheet({
  studentName,
  admissionNo,
  branchName,
  loans,
  onClose,
}: {
  studentName: string;
  admissionNo: string;
  branchName: string;
  loans: readonly LibraryLoan[];
  onClose: () => void;
}) {
  const title = "كشف استعارة الطالب";
  const today = new Date().toISOString().slice(0, 10);
  const open = loans.filter((loan) => !loan.returned_at).length;
  const overdue = loans.filter((loan) => !loan.returned_at && loan.due_date < today).length;
  const returned = loans.length - open;

  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label={title}>
    <div className="assignment-sheet">
      <PrintLetterhead
        title={title}
        topic={`${studentName} · ${admissionNo}`}
        meta={buildSheetMeta()}
      />

      <div className="sheet-summary">
        <div><span>اسم الطالب</span><strong>{studentName}</strong></div>
        <div><span>الرقم الأكاديمي</span><strong>{admissionNo}</strong></div>
        <div><span>الفرع</span><strong>{branchName || "—"}</strong></div>
        <div><span>إجمالي الاستعارات</span><strong>{loans.length}</strong></div>
      </div>

      <div className="sheet-summary">
        <div><span>قيد الإعارة</span><strong>{open}</strong></div>
        <div><span>متأخرة</span><strong>{overdue}</strong></div>
        <div><span>أُعيدت</span><strong>{returned}</strong></div>
        <div><span>تاريخ الكشف</span><strong>{formatDate(new Date().toISOString())}</strong></div>
      </div>

      <div className="sheet-body">
        {loans.length
          ? <table className="management-table">
            <thead>
              <tr><th>#</th><th>الكتاب</th><th>تاريخ الإعارة</th><th>الاستحقاق</th><th>تاريخ الإرجاع</th><th>الحالة</th><th>ملاحظات</th></tr>
            </thead>
            <tbody>
              {loans.map((loan, index) => {
                const late = !loan.returned_at && loan.due_date < today;
                return <tr key={loan.id}>
                  <td>{index + 1}</td>
                  <td>{loan.itemTitle}</td>
                  <td>{formatDate(loan.issued_at)}</td>
                  <td>{formatDate(loan.due_date)}</td>
                  <td>{loan.returned_at ? formatDate(loan.returned_at) : "—"}</td>
                  <td>{loan.returned_at ? "أُعيد" : late ? "متأخر" : "قيد الإعارة"}</td>
                  <td>{loan.notes ?? "—"}</td>
                </tr>;
              })}
            </tbody>
          </table>
          : <p className="sheet-note">لا توجد استعارات مسجلة لهذا الطالب حتى تاريخ الكشف.</p>}
      </div>

      <p className="sheet-note">
        يعكس هذا الكشف جميع حركات الاستعارة المسجلة في نظام المكتبة، ويُستخدم عند طلب إخلاء الطرف أو مراجعة سجل الطالب.
      </p>

      <div className="receipt-signatures">
        <div><span>أمين المكتبة</span></div>
        <div><span>توقيع ولي الأمر / الطالب</span></div>
      </div>

      <PrintFooter />
    </div>

    <div className="print-actions">
      <button className="button primary" type="button" onClick={() => printSheet(title)}>طباعة الكشف</button>
      <button className="button secondary" type="button" onClick={onClose}>إغلاق</button>
    </div>
  </div>;
}