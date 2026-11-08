import type { ReactNode } from "react";
import { formatDate } from "@/portal/lib/learning";
import { printDate, buildSheetMeta, type ArchiveHeader } from "@/portal/lib/letterhead";
import { printSheet } from "@/portal/lib/printDocument";
import { PrintFooter, PrintLetterhead } from "@/portal/components/PrintLetterhead";

export type SummaryItem = { label: string; value: string };

export function ReportSheet({ title, subtitle, summary, loading, error, onRetry, children, onClose, canPrint, onExportCsv, archive }: {
  title: string;
  subtitle: string;
  summary: SummaryItem[];
  loading: boolean;
  error: string | null;
  onRetry: () => void;
  children: ReactNode;
  onClose: () => void;
  canPrint: boolean;
  onExportCsv?: () => void;
  archive?: ArchiveHeader;
}) {
  const preparedBy = archive?.preparedBy?.trim();
  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label={title}>
    <div className="assignment-sheet">
      <PrintLetterhead
        title={title}
        topic={subtitle}
        meta={buildSheetMeta(archive)}
      />

      {loading && <p role="status">جارٍ تجهيز التقرير...</p>}
      {error && <p className="error-box" role="alert">{error} <button className="text-button" type="button" onClick={onRetry}>إعادة المحاولة</button></p>}

      {!loading && !error && <>
        {summary.length > 0 && <div className="sheet-summary">
          {summary.map((item) => <div key={item.label}><span>{item.label}</span><strong>{item.value}</strong></div>)}
          <div><span>تاريخ الطباعة</span><strong>{printDate()}</strong></div>
        </div>}
        <div className="sheet-body">{children}</div>
        <p className="sheet-note">
          صدر هذا التقرير من نظام كلية ساي بناءً على البيانات المسجلة حتى لحظة الطباعة. يعكس ما تسمح به صلاحيات حسابك فقط.
        </p>
        <div className="receipt-signatures">
          <div><span>{preparedBy ? `إعداد: ${preparedBy}` : "إعداد / إدارة الكلية"}</span></div>
          <div><span>اعتماد الإدارة الأكاديمية</span></div>
        </div>
        <PrintFooter />
      </>}
    </div>

    <div className="print-actions">
      {onExportCsv && <button className="button secondary" type="button" onClick={onExportCsv} disabled={loading || Boolean(error)}>تصدير CSV</button>}
      <button className="button primary" type="button" onClick={() => printSheet(title)} disabled={!canPrint}>طباعة التقرير</button>
      <button className="button secondary" type="button" onClick={onClose}>إغلاق</button>
    </div>
  </div>;
}

export function ReportPeriod({ from, to }: { from: string; to: string }) {
  return <p className="sheet-note" style={{ marginTop: 0 }}>الفترة: من {formatDate(from)} إلى {formatDate(to)}</p>;
}