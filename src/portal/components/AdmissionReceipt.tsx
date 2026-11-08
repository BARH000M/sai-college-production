import logo from "../assets/saiLogo";
import { QRCodeCanvas } from "qrcode.react";
import { admissionStatuses, applicationStatusUrl, type Admission } from "../lib/admissions";

function formatDate(value: string | null): string {
  if (!value) return "—";
  return new Date(value).toLocaleString("ar-EG", {
    year: "numeric", month: "long", day: "numeric", hour: "2-digit", minute: "2-digit",
  });
}

function readableLabel(value: string): string {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-/i.test(value) ? "—" : value;
}

function statusPageUrl(reference: string): string {
  return applicationStatusUrl(reference);
}

export function AdmissionReceipt({ admission, branchLabel, sessionLabel, onClose }: {
  admission: Admission;
  branchLabel: string;
  sessionLabel: string;
  onClose: () => void;
}) {
  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label="إيصال استلام طلب قبول">
    <div className="print-receipt">
      <div className="receipt-head">
        <img src={logo} alt="شعار كلية ساي" className="receipt-logo" />
        <div>
          <p className="receipt-college">كلية ساي التعليمية اليمنية الصينية</p>
          <p className="receipt-college-en" dir="ltr">SAI Yemeni–Chinese College</p>
          <h2 className="receipt-title">إيصال استلام طلب قبول</h2>
          <p className="receipt-subtitle" dir="ltr">Admission Enquiry Receipt</p>
        </div>
      </div>

      <div className="receipt-reference">
        <span>رقم الطلب المرجعي / Reference No.</span>
        <strong dir="ltr">{admission.application_no}</strong>
      </div>

      <dl className="receipt-grid">
        <div><dt>اسم المتقدم</dt><dd>{admission.applicant_full_name}</dd></div>
        <div><dt>اسم ولي الأمر</dt><dd>{admission.guardian_name ?? "—"}</dd></div>
        <div><dt>الهاتف</dt><dd dir="ltr">{admission.phone ?? "—"}</dd></div>
        <div><dt>البريد الإلكتروني</dt><dd dir="ltr">{admission.email ?? "—"}</dd></div>
        <div><dt>البرنامج المطلوب</dt><dd>{admission.preferred_program ?? "—"}</dd></div>
        <div><dt>المستوى المطلوب</dt><dd>{admission.preferred_level ?? "—"}</dd></div>
        <div><dt>الفرع</dt><dd>{readableLabel(branchLabel)}</dd></div>
        <div><dt>الجلسة الأكاديمية</dt><dd>{readableLabel(sessionLabel)}</dd></div>
        <div><dt>الحالة الحالية</dt><dd>{admissionStatuses[admission.status] ?? admission.status}</dd></div>
        <div><dt>تاريخ الاستلام</dt><dd>{formatDate(admission.created_at)}</dd></div>
      </dl>

      <div className="receipt-qr">
        <QRCodeCanvas
          value={statusPageUrl(admission.application_no)}
          size={128}
          level="M"
          marginSize={1}
          bgColor="#ffffff"
          fgColor="#111111"
          aria-label={`رمز متابعة حالة الطلب ${admission.application_no}`}
        />
        <div className="receipt-qr-text">
          <strong>امسح الرمز لمتابعة حالة الطلب</strong>
          <span>يفتح صفحة المتابعة والرقم المرجعي مُدخل تلقائيًا.</span>
          <code dir="ltr">scan to track {admission.application_no}</code>
        </div>
      </div>

      <p className="receipt-note">
        هذا الإيصال يثبت استلام طلب القبول فقط ولا يُعد قبولًا نهائيًا. يُرجى الاحتفاظ بهذا الرقم
        لمتابعة حالة الطلب عبر بوابة الكلية أو بالتواصل مع مكتب القبول.
      </p>

      <div className="receipt-signatures">
        <div><span>توقيع الموظف المستلم</span></div>
        <div><span>توقيع المتقدم / ولي الأمر</span></div>
      </div>

      <p className="receipt-footer" dir="ltr">info@saicollege.com · Sana'a, Republic of Yemen · SAI College</p>
    </div>

    <div className="print-actions">
      <button className="button primary" onClick={() => window.print()}>طباعة الإيصال</button>
      <button className="button secondary" onClick={onClose}>إغلاق</button>
    </div>
  </div>;
}