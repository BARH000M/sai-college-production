import { PrintFooter, PrintLetterhead } from "@/portal/components/PrintLetterhead";
import { buildSheetMeta } from "@/portal/lib/letterhead";
import { printSheet } from "@/portal/lib/printDocument";
import { formatDate } from "@/portal/lib/learning";
import { announcementAudiences, type Announcement } from "@/portal/lib/communications";

export function CircularSheet({ announcement, branchName, onClose }: {
  announcement: Announcement;
  branchName: string;
  onClose: () => void;
}) {
  const title = "تعميم إداري";
  const paragraphs = announcement.body.split(/\n{2,}/).map((part) => part.trim()).filter(Boolean);

  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label={title}>
    <div className="assignment-sheet">
      <PrintLetterhead
        title={title}
        topic={announcement.title}
        meta={buildSheetMeta(undefined, [
          { label: "الجهة", value: branchName || "كل الفروع" },
          { label: "الجمهور", value: announcementAudiences[announcement.audience] },
          { label: "تاريخ النشر", value: announcement.published_at ? formatDate(announcement.published_at) : "مسودة" },
        ])}
      />

      <div className="sheet-body">
        {paragraphs.length
          ? paragraphs.map((paragraph, index) => <p key={index} style={{ margin: "0 0 10px", lineHeight: 2 }}>{paragraph}</p>)
          : <p>—</p>}
      </div>

      {announcement.expires_at && <p className="sheet-note">
        يسري هذا التعميم حتى {formatDate(announcement.expires_at)}.
      </p>}

      <p className="sheet-note">
        يُبلّغ بهذا التعميم جميع المعنيين للعلم والعمل بموجبه من تاريخ صدوره. يُحفظ هذا المستند في سجل المراسلات الرسمية.
      </p>

      <div className="receipt-signatures">
        <div><span>إعداد / إدارة الكلية</span></div>
        <div><span>اعتماد مدير الكلية</span></div>
      </div>

      <PrintFooter />
    </div>

    <div className="print-actions">
      <button className="button primary" type="button" onClick={() => printSheet(`${title} - ${announcement.title}`)}>طباعة التعميم</button>
      <button className="button secondary" type="button" onClick={onClose}>إغلاق</button>
    </div>
  </div>;
}