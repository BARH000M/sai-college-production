import type { ReactNode } from "react";
import logo from "@/portal/assets/saiLogo";
import { formatDate } from "@/portal/lib/learning";

function today(): string {
  return new Date().toLocaleDateString("ar-EG", { year: "numeric", month: "long", day: "numeric" });
}

export type SummaryItem = { label: string; value: string };

export function ReportSheet({ title, subtitle, summary, loading, error, onRetry, children, onClose, canPrint }: {
  title: string;
  subtitle: string;
  summary: SummaryItem[];
  loading: boolean;
  error: string | null;
  onRetry: () => void;
  children: ReactNode;
  onClose: () => void;
  canPrint: boolean;
}) {
  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label={title}>
    <div className="assignment-sheet">
      <div className="receipt-head">
        <img src={logo} alt="شعار كلية ساي" className="receipt-logo" />
        <div>
          <p className="receipt-college">كلية ساي التعليمية اليمنية الصينية</p>
          <p className="receipt-college-en" dir="ltr">SAI Yemeni–Chinese College</p>
          <h2 className="receipt-title">{title}</h2>
          <p className="receipt-subtitle">{subtitle}</p>
        </div>
      </div>

      {loading && <p role="status">جارٍ تجهيز التقرير...</p>}
      {error && <p className="error-box" role="alert">{error} <button className="text-button" type="button" onClick={onRetry}>إعادة المحاولة</button></p>}

      {!loading && !error && <>
        <div className="sheet-summary">
          {summary.map((item) => <div key={item.label}><span>{item.label}</span><strong>{item.value}</strong></div>)}
          <div><span>تاريخ الطباعة</span><strong>{today()}</strong></div>
        </div>
        {children}
        <p className="sheet-note">
          صدر هذا التقرير من نظام كلية ساي بناءً على البيانات المسجلة حتى لحظة الطباعة. يعكس ما تسمح به صلاحيات حسابك فقط.
        </p>
        <div className="receipt-signatures">
          <div><span>إعداد / إدارة الكلية</span></div>
          <div><span>اعتماد الإدارة الأكاديمية</span></div>
        </div>
        <p className="receipt-footer" dir="ltr">info@saicollege.com · Sana&apos;a, Republic of Yemen · SAI College</p>
      </>}
    </div>

    <div className="print-actions">
      <button className="button primary" type="button" onClick={() => window.print()} disabled={!canPrint}>طباعة التقرير</button>
      <button className="button secondary" type="button" onClick={onClose}>إغلاق</button>
    </div>
  </div>;
}

export function ReportPeriod({ from, to }: { from: string; to: string }) {
  return <p className="sheet-note" style={{ marginTop: 0 }}>الفترة: من {formatDate(from)} إلى {formatDate(to)}</p>;
}