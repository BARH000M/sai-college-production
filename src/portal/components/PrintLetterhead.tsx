import logo from "@/portal/assets/saiLogo";
import { collegeIdentity, printDate } from "@/portal/lib/letterhead";

export type SheetMeta = { label: string; value: string };

/**
 * Official letterhead used by every printable sheet in the portal.
 * Guarantees the college name, address, phone, email and website appear
 * on the paper, followed by the document title and its topic.
 */
export function PrintLetterhead({ title, topic, meta }: {
  title: string;
  topic?: string;
  meta?: readonly SheetMeta[];
}) {
  const items = meta && meta.length ? meta : [{ label: "تاريخ الإصدار", value: printDate() }];
  return <header className="print-sheet-head">
    <div className="print-sheet-letterhead">
      <img className="print-sheet-logo" src={logo} alt="شعار كلية ساي" />
      <div className="print-sheet-identity">
        <p className="print-sheet-college">{collegeIdentity.nameAr}</p>
        <p className="print-sheet-college-en" dir="ltr">{collegeIdentity.nameEn}</p>
        <p className="print-sheet-contact">
          <span>{collegeIdentity.addressAr}</span>
          <span dir="ltr">هاتف: {collegeIdentity.phone}</span>
          <span dir="ltr">{collegeIdentity.email}</span>
          <span dir="ltr">{collegeIdentity.website}</span>
        </p>
      </div>
    </div>

    <div className="print-sheet-doc">
      <div className="print-sheet-title-wrap">
        <h2 className="print-sheet-title">{title}</h2>
        {topic && <p className="print-sheet-topic">{topic}</p>}
      </div>
      <p className="print-sheet-meta">
        {items.map((item) => <span key={item.label}>
          <b>{item.label}:</b> {item.value}
        </span>)}
      </p>
    </div>
  </header>;
}

/** Closing strip: repeats the official contact details at the bottom of the paper. */
export function PrintFooter({ note }: { note?: string }) {
  return <footer className="print-sheet-footer">
    {note && <p className="print-sheet-note">{note}</p>}
    <p className="print-sheet-contact print-sheet-contact-footer">
      <span>{collegeIdentity.nameAr}</span>
      <span>{collegeIdentity.addressAr}</span>
      <span dir="ltr">هاتف: {collegeIdentity.phone}</span>
      <span dir="ltr">{collegeIdentity.email}</span>
      <span dir="ltr">{collegeIdentity.website}</span>
    </p>
  </footer>;
}