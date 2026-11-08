import { admissionStatuses, type Admission } from "@/portal/lib/admissions";
import { formatDate } from "@/portal/lib/learning";
import { loadLastArchive } from "@/portal/lib/archiveHeader";
import { ReportSheet } from "@/portal/pages/reports/ReportShell";

/**
 * Formal printable application form for a single admission enquiry.
 * Used from the admission detail drawer so staff can hand the applicant a
 * signed paper copy of exactly what is stored in the system.
 */
export function AdmissionApplicationSheet({ admission, branchLabel, sessionLabel, onClose }: {
  admission: Admission;
  branchLabel: string;
  sessionLabel: string;
  onClose: () => void;
}) {
  const archive = loadLastArchive() ?? undefined;
  const status = admissionStatuses[admission.status] ?? admission.status;

  return <ReportSheet
    title="نموذج طلب قبول"
    subtitle="نسخة رسمية من بيانات الطلب المسجلة في نظام القبول"
    summary={[
      { label: "الرقم المرجعي", value: admission.application_no },
      { label: "الحالة الحالية", value: status },
      { label: "الفرع", value: branchLabel },
      { label: "تاريخ التقديم", value: formatDate(admission.created_at) },
    ]}
    loading={false}
    error={null}
    onRetry={() => undefined}
    onClose={onClose}
    canPrint
    archive={archive}
  >
    <div className="report-section">
      <strong className="report-heading">بيانات المتقدم</strong>
      <dl className="receipt-grid">
        <div><dt>اسم المتقدم</dt><dd>{admission.applicant_full_name}</dd></div>
        <div><dt>اسم ولي الأمر</dt><dd>{admission.guardian_name ?? "—"}</dd></div>
        <div><dt>الهاتف</dt><dd dir="ltr">{admission.phone ?? "—"}</dd></div>
        <div><dt>البريد الإلكتروني</dt><dd dir="ltr">{admission.email ?? "—"}</dd></div>
        <div><dt>البرنامج المطلوب</dt><dd>{admission.preferred_program ?? "—"}</dd></div>
        <div><dt>المستوى المطلوب</dt><dd>{admission.preferred_level ?? "—"}</dd></div>
      </dl>
    </div>

    <div className="report-section">
      <strong className="report-heading">بيانات التسجيل</strong>
      <dl className="receipt-grid">
        <div><dt>الفرع</dt><dd>{branchLabel}</dd></div>
        <div><dt>الجلسة الأكاديمية</dt><dd>{sessionLabel}</dd></div>
        <div><dt>مصدر الطلب</dt><dd>{admission.source ?? "—"}</dd></div>
        <div><dt>الحالة</dt><dd>{status}</dd></div>
        <div><dt>تاريخ الإنشاء</dt><dd>{formatDate(admission.created_at)}</dd></div>
        <div><dt>تاريخ الإغلاق</dt><dd>{admission.closed_at ? formatDate(admission.closed_at) : "—"}</dd></div>
      </dl>
    </div>

    <div className="report-section">
      <strong className="report-heading">ملاحظات مكتب القبول</strong>
      <p className="sheet-note" style={{ marginTop: 6 }}>{admission.notes?.trim() || "لا توجد ملاحظات مسجلة على هذا الطلب."}</p>
    </div>

    <p className="sheet-note">
      أقرّ بأن البيانات أعلاه مطابقة لما قدّمته، وأتحمل مسؤولية صحتها. يبقى هذا الطلب قيد المراجعة حتى
      صدور القرار الرسمي من مكتب القبول، ولا يُعد إيصال التسليم قبولاً نهائياً.
    </p>

    <div className="receipt-signatures">
      <div><span>توقيع المتقدم / ولي الأمر</span></div>
      <div><span>الموظف المستلم</span></div>
      <div><span>اعتماد مكتب القبول</span></div>
    </div>
  </ReportSheet>;
}