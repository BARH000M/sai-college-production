import type { ReactNode } from "react";
import { PrintFooter, PrintLetterhead } from "@/portal/components/PrintLetterhead";
import { buildSheetMeta, type ArchiveHeader } from "@/portal/lib/letterhead";
import { printSheet } from "@/portal/lib/printDocument";

/**
 * Simple official print sheet used by the timetable and academic-affairs screens.
 * Reuses the shared letterhead and the portal print overlay so it prints on A4
 * with the college identity, issue date and optional archive header.
 */
export function PrintDoc({ title, subtitle, archive, children, onClose }: {
  title: string;
  subtitle: string;
  archive?: ArchiveHeader;
  children: ReactNode;
  onClose: () => void;
}) {
  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label={title}>
    <div className="assignment-sheet">
      <PrintLetterhead title={title} topic={subtitle} meta={buildSheetMeta(archive)} />
      <div className="sheet-body" style={{ marginTop: 14 }}>{children}</div>
      <PrintFooter note="صدر هذا المستند من نظام كلية ساي، ويعتمد البيانات المسجلة حتى لحظة الطباعة." />
    </div>
    <div className="print-actions">
      <button className="button primary" type="button" onClick={() => printSheet(title)}>طباعة</button>
      <button className="button secondary" type="button" onClick={onClose}>إغلاق</button>
    </div>
  </div>;
}