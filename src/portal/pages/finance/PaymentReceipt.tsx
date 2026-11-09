import { PrintFooter, PrintLetterhead } from "@/portal/components/PrintLetterhead";
import { buildSheetMeta } from "@/portal/lib/letterhead";
import { printSheet } from "@/portal/lib/printDocument";
import { formatYER } from "@/portal/lib/finance";
import { formatDate } from "@/portal/lib/learning";
import type { FeeAssignment, FeeGroup, FinancePayment } from "@/portal/lib/financeApi";

const methodLabels: Record<string, string> = {
  cash: "نقداً",
  bank_transfer: "تحويل بنكي",
  wallet: "محفظة إلكترونية",
  card: "بطاقة",
};

export function PaymentReceipt({
  payment,
  assignment,
  studentName,
  admissionNo,
  group,
  branchName,
  onClose,
}: {
  payment: FinancePayment;
  assignment: FeeAssignment;
  studentName: string;
  admissionNo: string;
  group: FeeGroup | null;
  branchName: string;
  onClose: () => void;
}) {
  const title = "إيصال سداد رسوم";
  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label={title}>
    <div className="assignment-sheet">
      <PrintLetterhead
        title={title}
        topic={`رقم الإيصال: ${payment.receipt_number}`}
        meta={buildSheetMeta()}
      />

      <div className="sheet-summary">
        <div><span>اسم الطالب</span><strong>{studentName}</strong></div>
        <div><span>الرقم الأكاديمي</span><strong>{admissionNo}</strong></div>
        <div><span>الفرع</span><strong>{branchName || "—"}</strong></div>
        <div><span>تاريخ السداد</span><strong>{formatDate(payment.posted_at)}</strong></div>
      </div>

      <div className="sheet-body">
        <table className="management-table">
          <thead>
            <tr><th>البيان</th><th>طريقة الدفع</th><th>المرجع</th><th>المبلغ</th></tr>
          </thead>
          <tbody>
            <tr>
              <td>{group?.name ?? "رسوم دراسية"}
                <span className="learn-meta">تاريخ الاستحقاق: {formatDate(assignment.due_date)}</span>
              </td>
              <td>{methodLabels[payment.method] ?? payment.method}</td>
              <td dir="ltr">{payment.transaction_reference ?? "—"}</td>
              <td><strong>{formatYER(String(payment.amount))}</strong></td>
            </tr>
          </tbody>
        </table>
        <p className="sheet-note">
          حالة الدفعة: {payment.voided_at ? `ملغاة — ${payment.void_reason ?? "بدون سبب مسجل"}` : "مرحّلة"}.
          الرصيد المتبقي على هذا الإسناد بعد العملية: {formatYER(String(Math.max(assignment.balance, 0)))}.
        </p>
      </div>

      <div className="receipt-signatures">
        <div><span>توقيع المحاسب</span></div>
        <div><span>توقيع ولي الأمر / الطالب</span></div>
      </div>

      <PrintFooter note="هذا الإيصال صادر إلكترونياً من نظام كلية ساي ويُعتمد عند مراجعة السداد." />
    </div>

    <div className="print-actions">
      <button className="button primary" type="button" onClick={() => printSheet(title)}>طباعة الإيصال</button>
      <button className="button secondary" type="button" onClick={onClose}>إغلاق</button>
    </div>
  </div>;
}