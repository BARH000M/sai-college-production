/** Pill shown next to a CMS field whose value changed but has not been published yet. */
export function CmsDirtyBadge({ show }: { show: boolean }) {
  if (!show) return null;
  return <span className="cms-dirty-badge" title="هذا التعديل لم يُحفظ ولم يُنشر بعد">
    <i className="ri-error-warning-line" aria-hidden="true"></i>
    تعديل غير محفوظ
  </span>;
}