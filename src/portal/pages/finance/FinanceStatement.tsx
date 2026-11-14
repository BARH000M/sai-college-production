import { PrintFooter, PrintLetterhead } from "../../components/PrintLetterhead";
import { buildSheetMeta } from "../../lib/letterhead";
import { printSheet } from "../../lib/printDocument";
import { formatYER, type FinanceFilters } from "../../lib/finance";
import type { FeeAssignment, FinanceStudent, FinanceOption } from "../../lib/financeApi";

export function FinanceStatement({ rows, students, groups, totals, filters, onClose, invoice = false }: {
  rows: FeeAssignment[]; students: FinanceStudent[]; groups: FinanceOption[];
  totals: { invoiced: string; outstanding: string; overdue: string }; filters: FinanceFilters; onClose: () => void; invoice?: boolean;
}) {
  const title = invoice ? "فاتورة رسوم الطالب" : "كشف فواتير الرسوم والأرصدة";
  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label={title}>
    <div className="assignment-sheet">
      <PrintLetterhead title={title} topic="الفواتير المسندة في نطاق صلاحيات الحساب" meta={buildSheetMeta()} />
      {!invoice && <p>الاستحقاق: {filters.from || "البداية"} — {filters.to || "النهاية"} · الحالة: {filters.status || "الكل"} · البحث: {filters.search || "الكل"}</p>}
      <table className="management-table"><thead><tr><th>مرجع الفاتورة</th><th>الطالب</th><th>الرسوم</th><th>الاستحقاق</th><th>الأصل</th><th>الخصم</th><th>الصافي</th><th>الرصيد</th><th>الحالة</th></tr></thead>
        <tbody>{rows.map((row) => <tr key={row.id}>
          <td dir="ltr">{row.id}</td><td>{students.find((s) => s.id === row.student_id)?.full_name}<span className="learn-meta">{students.find((s) => s.id === row.student_id)?.admission_no}</span></td>
          <td>{groups.find((g) => g.id === row.fee_group_id)?.name}</td><td>{row.due_date}</td>
          <td>{formatYER(String(row.original_amount))}</td><td>{formatYER(String(row.discount_amount))}</td>
          <td>{formatYER(String(row.final_amount))}</td><td>{formatYER(String(row.balance))}</td>
          <td>{{ unpaid: "غير مدفوع", partial: "جزئي", paid: "مدفوع", waived: "معفى", cancelled: "ملغى" }[row.status] ?? row.status}</td>
        </tr>)}</tbody></table>
      <p>صافي الرسوم: {totals.invoiced} ر.ي · المستحق: {totals.outstanding} ر.ي · المتأخر: {totals.overdue} ر.ي</p>
      <PrintFooter note="هذا كشف أرصدة حالي وليس إيصال سداد. الإجماليات تستبعد الفواتير الملغاة." />
    </div>
    <div className="print-actions"><button type="button" className="button primary" onClick={() => printSheet(title)}>طباعة</button><button type="button" className="button secondary" onClick={onClose}>إغلاق</button></div>
  </div>;
}
