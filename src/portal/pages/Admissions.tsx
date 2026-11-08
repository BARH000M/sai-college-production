import { useEffect, useState, type FormEvent } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { loadManagementBranches, loadManagementOptions, type Option } from "../lib/management";
import { AdmissionReceipt } from "../components/AdmissionReceipt";
import { exportAdmissionHistoryCsv, exportAdmissionRosterCsv } from "../lib/admissionExport";
import {
  admissionDraft, admissionStatuses, admissionsPageSize, applicationStatusUrl, canManageAdmissions, isAdmissionStatus,
  loadAdmissionByReference, loadAdmissions, loadAdmissionHistory, loadAdmissionSessions, loadAdmissionStaff,
  notifyAdmissionStatusChange, saveAdmission, validateAdmission,
  type Admission, type AdmissionDraft, type AdmissionFilters, type AdmissionHistoryEntry, type StaffOption,
} from "../lib/admissions";

const initialFilters: AdmissionFilters = { branch: "", session: "", status: "", assignee: "", search: "", page: 0, stale: false };
const textFields: { key: "applicant_full_name" | "guardian_name" | "phone" | "email" | "preferred_program" | "preferred_level" | "source" | "notes"; label: string }[] = [
  { key: "applicant_full_name", label: "اسم المتقدم" }, { key: "guardian_name", label: "اسم ولي الأمر" },
  { key: "phone", label: "الهاتف" }, { key: "email", label: "البريد الإلكتروني" },
  { key: "preferred_program", label: "البرنامج المطلوب" }, { key: "preferred_level", label: "المستوى المطلوب" },
  { key: "source", label: "مصدر الطلب" }, { key: "notes", label: "الملاحظات" },
];
function errorText(error: unknown) { return error instanceof Error ? error.message : String(error); }

const extraColumnLabels: Record<string, string> = {
  status: "الحالة", assigned_to: "الموظف المسند إليه", academic_session_id: "الجلسة الأكاديمية",
};
function columnLabel(key: string): string {
  return textFields.find((field) => field.key === key)?.label ?? extraColumnLabels[key] ?? key;
}
function historyTitle(entry: AdmissionHistoryEntry): string {
  if (entry.action === "insert") return "تسجيل الطلب";
  if (entry.action === "status_change") return "تغيير حالة الطلب";
  if (entry.changed_columns.includes("assigned_to")) return "تحديث الموظف المسند إليه";
  return "تحديث بيانات الطلب";
}
function historyDetail(entry: AdmissionHistoryEntry): string {
  if (entry.action === "status_change") {
    const from = entry.old_status ? admissionStatuses[entry.old_status as keyof typeof admissionStatuses] ?? entry.old_status : "—";
    const to = entry.new_status ? admissionStatuses[entry.new_status as keyof typeof admissionStatuses] ?? entry.new_status : "—";
    return `${from} ← ${to}`;
  }
  if (entry.action === "insert") return entry.new_status ? admissionStatuses[entry.new_status as keyof typeof admissionStatuses] ?? entry.new_status : "تم الاستلام";
  const columns = entry.changed_columns.filter((key) => key !== "updated_at").map(columnLabel);
  return columns.length ? columns.join("، ") : "تحديث سجل الطلب";
}

export function Admissions({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const isSuper = roles.includes("super_admin");
  const manager = canManageAdmissions(roles);
  const needsScope = manager && !isSuper;
  const [scope, setScope] = useState<string[]>([]);
  const [scopeLoading, setScopeLoading] = useState(needsScope);
  const [scopeError, setScopeError] = useState<string | null>(null);
  const [branches, setBranches] = useState<Option[]>([]);
  const [sessions, setSessions] = useState<Option[]>([]);
  const [staff, setStaff] = useState<StaffOption[]>([]);
  const [staffLoading, setStaffLoading] = useState(false);
  const [staffError, setStaffError] = useState<string | null>(null);
  const [optionsLoading, setOptionsLoading] = useState(true);
  const [optionsError, setOptionsError] = useState<string | null>(null);
  const [sessionLoading, setSessionLoading] = useState(false);
  const [sessionError, setSessionError] = useState<string | null>(null);
  const [searchParams, setSearchParams] = useSearchParams();
  const [filters, setFilters] = useState<AdmissionFilters>(() => ({
    ...initialFilters,
    branch: (searchParams.get("branch") ?? "").trim(),
    status: (searchParams.get("status") ?? "").trim(),
    stale: searchParams.get("stale") === "1",
  }));
  const [rows, setRows] = useState<Admission[]>([]);
  const [count, setCount] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<Admission | null>(null);
  const [editing, setEditing] = useState<Admission | null | undefined>(undefined);
  const [draft, setDraft] = useState<AdmissionDraft>(() => admissionDraft(null, "", ""));
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);
  const [receiptOpen, setReceiptOpen] = useState(false);
  const [scanLoading, setScanLoading] = useState(false);
  const [scanError, setScanError] = useState<string | null>(null);
  const [exportFrom, setExportFrom] = useState("");
  const [exportTo, setExportTo] = useState("");
  const [exporting, setExporting] = useState<false | "range" | "enquiry" | "roster">(false);
  const [exportError, setExportError] = useState<string | null>(null);
  const [exportNote, setExportNote] = useState<string | null>(null);
  const [rosterError, setRosterError] = useState<string | null>(null);
  const [rosterNote, setRosterNote] = useState<string | null>(null);
  const [enquiryError, setEnquiryError] = useState<string | null>(null);
  const [enquiryNote, setEnquiryNote] = useState<string | null>(null);
  const [history, setHistory] = useState<AdmissionHistoryEntry[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyError, setHistoryError] = useState<string | null>(null);
  const canEditBranch = (branch: string) => manager && (isSuper || (!scopeLoading && !scopeError && scope.includes(branch)));
  const staffBranch = editing === undefined ? filters.branch : draft.branch_id;

  useEffect(() => {
    if (!needsScope) { setScope([]); setScopeLoading(false); setScopeError(null); return; }
    if (!userId) { setScopeLoading(false); setScopeError("تعذر التحقق من الحساب."); return; }
    let active = true;
    setScopeLoading(true); setScopeError(null);
    void loadManagementBranches(userId).then((value) => { if (active) setScope(value); })
      .catch((failure: unknown) => { if (active) { setScope([]); setScopeError(errorText(failure)); } })
      .finally(() => { if (active) setScopeLoading(false); });
    return () => { active = false; };
  }, [needsScope, userId, retry]);

  useEffect(() => {
    let active = true;
    setOptionsLoading(true); setOptionsError(null);
    void loadManagementOptions("", "").then((value) => {
      if (active) { setBranches(value.branches); if (!manager) setSessions(value.sessions); }
    }).catch((failure: unknown) => {
      if (active) { setBranches([]); setSessions([]); setOptionsError(errorText(failure)); }
    }).finally(() => { if (active) setOptionsLoading(false); });
    return () => { active = false; };
  }, [retry, manager]);

  useEffect(() => {
    if (!manager) { setSessionLoading(false); setSessionError(null); return; }
    setSessions([]); setSessionError(null);
    if (!staffBranch || !canEditBranch(staffBranch)) { setSessionLoading(false); return; }
    let active = true;
    setSessionLoading(true);
    void loadAdmissionSessions(staffBranch).then((value) => { if (active) setSessions(value); })
      .catch((failure: unknown) => { if (active) setSessionError(errorText(failure)); })
      .finally(() => { if (active) setSessionLoading(false); });
    return () => { active = false; };
  }, [staffBranch, isSuper, manager, scope, scopeLoading, scopeError, retry]);

  useEffect(() => {
    let active = true;
    setLoading(true); setError(null);
    void loadAdmissions(filters).then((value) => {
      if (active) { setRows(value.rows); setCount(value.count); }
    }).catch((failure: unknown) => {
      if (active) { setRows([]); setCount(0); setError(errorText(failure)); }
    }).finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [filters, retry]);

  useEffect(() => {
    if (!staffBranch || !canEditBranch(staffBranch)) {
      setStaff([]); setStaffError(null); setStaffLoading(false); return;
    }
    let active = true;
    setStaff([]); setStaffLoading(true); setStaffError(null);
    void loadAdmissionStaff(staffBranch).then((value) => { if (active) setStaff(value); })
      .catch((failure: unknown) => { if (active) setStaffError(errorText(failure)); })
      .finally(() => { if (active) setStaffLoading(false); });
    return () => { active = false; };
  }, [staffBranch, isSuper, manager, scope, scopeLoading, scopeError, retry]);

  useEffect(() => {
    const enquiryId = selected?.id ?? null;
    if (!enquiryId) {
      setHistory([]); setHistoryError(null); setHistoryLoading(false); return;
    }
    let active = true;
    setHistory([]); setHistoryLoading(true); setHistoryError(null);
    void loadAdmissionHistory(enquiryId).then((value) => { if (active) setHistory(value); })
      .catch((failure: unknown) => { if (active) setHistoryError(errorText(failure)); })
      .finally(() => { if (active) setHistoryLoading(false); });
    return () => { active = false; };
  }, [selected?.id, retry]);

  useEffect(() => {
    const wanted = (searchParams.get("ref") ?? "").trim();
    if (!wanted) return;
    let active = true;
    setScanLoading(true); setScanError(null);
    void loadAdmissionByReference(wanted).then((row) => {
      if (!active) return;
      if (!row) {
        setScanError(`لم نعثر على طلب بالرقم ${wanted} ضمن الطلبات المتاحة لحسابك.`);
        return;
      }
      setSelected(row);
      setFilters((current) => (current.branch === row.branch_id ? current : { ...current, branch: row.branch_id, page: 0 }));
    }).catch((failure: unknown) => {
      if (active) setScanError(`تعذّر فتح الطلب الممسوح: ${errorText(failure)}`);
    }).finally(() => {
      if (active) { setScanLoading(false); setSearchParams({}, { replace: true }); }
    });
    return () => { active = false; };
  }, [searchParams, setSearchParams]);

  async function exportRange() {
    if (exporting) return;
    setExportError(null); setExportNote(null);
    const branch = isSuper ? (filters.branch || null) : filters.branch;
    if (!isSuper && !branch) { setExportError("اختر الفرع أولًا قبل تصدير السجل."); return; }
    if (exportFrom && exportTo && exportFrom > exportTo) { setExportError("تاريخ البداية يجب أن يسبق تاريخ النهاية."); return; }
    setExporting("range");
    try {
      const count = await exportAdmissionHistoryCsv({ branch, from: exportFrom || null, to: exportTo || null, enquiryId: null });
      setExportNote(count ? `تم تصدير ${count} حركة إلى ملف CSV.` : "لا توجد حركات مسجّلة ضمن هذا النطاق.");
    } catch (failure) {
      setExportError(`تعذّر تصدير السجل: ${errorText(failure)}`);
    } finally { setExporting(false); }
  }

  async function exportRoster() {
    if (exporting) return;
    setRosterError(null); setRosterNote(null);
    const branch = isSuper ? (filters.branch || null) : filters.branch;
    if (!isSuper && !branch) { setRosterError("اختر الفرع أولًا قبل تصدير كشف الطلبات."); return; }
    if (exportFrom && exportTo && exportFrom > exportTo) { setRosterError("تاريخ البداية يجب أن يسبق تاريخ النهاية."); return; }
    setExporting("roster");
    try {
      const count = await exportAdmissionRosterCsv({
        branch,
        session: filters.session || null,
        status: filters.status || null,
        from: exportFrom || null,
        to: exportTo || null,
      });
      setRosterNote(count ? `تم تصدير ${count} طلب إلى ملف CSV.` : "لا توجد طلبات تطابق هذه التصفية.");
    } catch (failure) {
      setRosterError(`تعذّر تصدير كشف الطلبات: ${errorText(failure)}`);
    } finally { setExporting(false); }
  }

  async function exportEnquiry() {
    if (!selected || exporting) return;
    setEnquiryError(null); setEnquiryNote(null);
    setExporting("enquiry");
    try {
      const count = await exportAdmissionHistoryCsv({ branch: null, from: null, to: null, enquiryId: selected.id });
      setEnquiryNote(count ? `تم تصدير ${count} حركة لهذا الطلب.` : "لا توجد حركات مسجّلة لهذا الطلب بعد.");
    } catch (failure) {
      setEnquiryError(`تعذّر تصدير سجل الطلب: ${errorText(failure)}`);
    } finally { setExporting(false); }
  }

  function filter(key: keyof AdmissionFilters, value: string) {
    setSelected(null);
    setFilters((current) => ({ ...current, [key]: value, page: 0, ...(key === "branch" ? { assignee: "", session: "" } : {}) }));
  }
  function toggleStale(next: boolean) {
    setSelected(null);
    setFilters((current) => ({ ...current, stale: next, status: next ? "new" : current.status, page: 0 }));
  }
  function openForm(row: Admission | null) {
    const branch = row?.branch_id ?? filters.branch;
    if (saving || editing !== undefined || !canEditBranch(branch)) return;
    setDraft(admissionDraft(row, branch, filters.session));
    setEditing(row); setFormError(null); setSuccess(null);
  }
  function change<K extends keyof AdmissionDraft>(key: K, value: AdmissionDraft[K]) {
    setDraft((current) => ({ ...current, [key]: value }));
  }
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (saving || editing === undefined || !canEditBranch(draft.branch_id)) return;
    const validation = validateAdmission(draft);
    if (validation) { setFormError(validation); return; }
    if (sessionLoading || sessionError || (draft.academic_session_id !== editing?.academic_session_id
      && !sessions.some((session) => session.id === draft.academic_session_id))) {
      setFormError("تعذر التحقق من الجلسة النشطة؛ أعد تحميل قائمة الجلسات."); return;
    }
    if (staffLoading || staffError || (draft.assigned_to && draft.assigned_to !== editing?.assigned_to && !staff.some((person) => person.user_id === draft.assigned_to))) {
      setFormError("تعذر التحقق من الموظف المسند إليه الطلب؛ أعد تحميل القائمة."); return;
    }
    setSaving(true); setFormError(null);
    const target = editing;
    try {
      await saveAdmission(draft, target?.id ?? null);
      setEditing(undefined); setSelected(null); setSuccess("تم حفظ الطلب.");
      setRetry((value) => value + 1);
      if (target && target.status !== draft.status) {
        const notice = await notifyAdmissionStatusChange(target.id, applicationStatusUrl(target.application_no));
        if (notice.sent) {
          setSuccess("تم حفظ الطلب وإرسال رسالة تحديث الحالة إلى بريد المتقدم.");
        } else if (notice.reason === "NO_EMAIL") {
          setSuccess("تم حفظ الطلب. لا يوجد بريد إلكتروني مسجّل للمتقدم، لذلك لم تُرسل رسالة تحديث.");
        } else if (notice.reason === "EMAIL_NOT_CONFIGURED") {
          setSuccess("تم حفظ الطلب، لكن إعداد البريد على الخادم غير مكتمل فلم تُرسل رسالة التحديث.");
        } else {
          setSuccess("تم حفظ الطلب، لكن تعذّر إرسال رسالة التحديث للمتقدم.");
        }
      }
    } catch (failure) { setFormError(`تعذر حفظ الطلب: ${errorText(failure)}`); }
    finally { setSaving(false); }
  }
  const branchName = (id: string) => branches.find((item) => item.id === id)?.name ?? id;
  const sessionName = (id: string) => sessions.find((item) => item.id === id)?.name ?? id;
  const assigneeName = (id: string | null) => id ? staff.find((item) => item.user_id === id)?.full_name ?? id : "غير مسند";
  const canCreate = !!filters.branch && canEditBranch(filters.branch);

  return <main className="workspace">
    <div className="page-heading"><div><p className="eyebrow">إدارة الأكاديمية</p><h1>القبول والتسجيل</h1></div>
      <div className="actions">
        {manager && <Link className="button secondary" to="/portal/modules/scanner">مسح إيصال الاستقبال</Link>}
        {canCreate && <button className="button primary" disabled={saving || editing !== undefined || optionsLoading || !!optionsError} onClick={() => openForm(null)}>إضافة طلب</button>}
      </div>
    </div>
    <p className="data-note">تظهر الطلبات التي تسمح بها قاعدة البيانات فقط. اختيار الجلسة يخضع للصلاحيات الحالية.</p>
    {!manager && <p className="notice">يمكنك عرض الطلبات المسندة إليك فقط؛ لا تتوفر صلاحية التعديل.</p>}
    {scopeLoading && <p role="status">جارٍ التحقق من نطاق الفروع...</p>}
    {scopeError && <p className="error-box" role="alert">تعذر التحقق من نطاق الفروع: {scopeError} <button className="text-button" onClick={() => setRetry((v) => v + 1)}>إعادة المحاولة</button></p>}
    <fieldset className="context-card" disabled={editing !== undefined || saving}>
      <label>الفرع<select value={filters.branch} onChange={(e) => filter("branch", e.target.value)}><option value="">اختر فرعاً</option>{branches.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
      <label>الجلسة<select value={filters.session} onChange={(e) => filter("session", e.target.value)}><option value="">كل الجلسات المتاحة</option>{sessions.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
      <label>الحالة<select value={filters.status} onChange={(e) => filter("status", e.target.value)}><option value="">كل الحالات</option>{Object.entries(admissionStatuses).map(([id, name]) => <option key={id} value={id}>{name}</option>)}</select></label>
      {canEditBranch(filters.branch) && <label>الموظف المسند إليه<select value={filters.assignee} disabled={staffLoading || !!staffError} onChange={(e) => filter("assignee", e.target.value)}><option value="">الكل</option><option value="unassigned">غير مسند</option>{staff.map((person) => <option key={person.user_id} value={person.user_id}>{person.full_name}</option>)}</select></label>}
      <label>بحث بالاسم أو ولي الأمر أو الهاتف أو رقم الطلب<input value={filters.search} onChange={(e) => filter("search", e.target.value)} /></label>
      <label className="checkbox-field"><input type="checkbox" checked={!!filters.stale} onChange={(e) => toggleStale(e.target.checked)} /><span>بانتظار أول تواصل (أكثر من ٣ أيام)</span></label>
    </fieldset>
    {filters.stale && <p className="notice stale-notice">تعرض القائمة الطلبات التي بقيت في حالة «جديد» أكثر من ثلاثة أيام دون تسجيل أي تواصل. <button className="text-button" onClick={() => toggleStale(false)}>إلغاء هذه التصفية</button></p>}
    {optionsLoading && <p role="status">جارٍ تحميل الفروع والجلسات...</p>}
    {staffLoading && <p role="status">جارٍ تحميل الموظفين...</p>}
    {sessionLoading && <p role="status">جارٍ تحميل الجلسات النشطة...</p>}
    {!sessionLoading && !sessionError && !!filters.branch && canEditBranch(filters.branch) && !sessions.length && <p className="notice">
      لا توجد جلسات أكاديمية نشطة متاحة لهذا الحساب بعد. أضف جلسة من قسم «الجلسات الأكاديمية» أو راجع صلاحية الفرع، ثم أعد المحاولة.
      <button className="text-button" onClick={() => setRetry((v) => v + 1)}>إعادة المحاولة</button>
    </p>}
    {optionsError && <p className="error-box" role="alert">تعذر تحميل الفروع والجلسات: {optionsError} <button className="text-button" onClick={() => setRetry((v) => v + 1)}>إعادة المحاولة</button></p>}
    {staffError && <p className="error-box" role="alert">تعذر تحميل الموظفين: {staffError} <button className="text-button" onClick={() => setRetry((v) => v + 1)}>إعادة المحاولة</button></p>}
    {sessionError && <p className="error-box" role="alert">تعذر تحميل الجلسات النشطة: {sessionError} <button className="text-button" onClick={() => setRetry((v) => v + 1)}>إعادة المحاولة</button></p>}
    {error && <p className="error-box" role="alert">تعذر تحميل الطلبات: {error} <button className="text-button" onClick={() => setRetry((v) => v + 1)}>إعادة المحاولة</button></p>}
    {success && <p className="success-box" role="status">{success}</p>}
    <section className="panel">
      {loading ? <p role="status">جارٍ تحميل الطلبات...</p> : error ? null : !filters.branch ? <p className="notice">اختر فرعاً لعرض الطلبات أو إضافتها.</p> : !rows.length ? <><p className="muted">لا توجد طلبات متاحة تطابق التصفية؛ قد تحد سياسات الوصول من النتائج.</p>{filters.page > 0 && <button className="button secondary" onClick={() => setFilters((v) => ({ ...v, page: v.page - 1 }))}>السابق</button>}</> :
        <><div className="table-scroll"><table className="management-table"><thead><tr><th>رقم الطلب</th><th>المتقدم</th><th>ولي الأمر</th><th>الهاتف</th><th>الحالة</th><th><span className="sr-only">التفاصيل</span></th></tr></thead><tbody>
          {rows.map((row) => <tr key={row.id}><td>{row.application_no}</td><td>{row.applicant_full_name}</td><td>{row.guardian_name ?? "—"}</td><td>{row.phone ?? "—"}</td><td>{admissionStatuses[row.status] ?? row.status}</td><td><button className="button secondary" disabled={saving || editing !== undefined} onClick={() => setSelected(row)}>التفاصيل</button></td></tr>)}
        </tbody></table></div><div className="pagination"><button className="button secondary" disabled={!filters.page || saving || editing !== undefined} onClick={() => { setSelected(null); setFilters((v) => ({ ...v, page: v.page - 1 })); }}>السابق</button><span>صفحة {filters.page + 1} · {count} طلب</span><button className="button secondary" disabled={(filters.page + 1) * admissionsPageSize >= count || saving || editing !== undefined} onClick={() => { setSelected(null); setFilters((v) => ({ ...v, page: v.page + 1 })); }}>التالي</button></div></>}
    </section>
    {selected && editing === undefined && <aside className="panel admissions-drawer management-detail" aria-label="تفاصيل الطلب"><div className="page-heading"><h2>تفاصيل الطلب</h2><button className="button secondary" onClick={() => setSelected(null)}>إغلاق</button></div>
      <dl><div><dt>رقم الطلب</dt><dd>{selected.application_no}</dd></div><div><dt>الفرع</dt><dd>{branchName(selected.branch_id)}</dd></div><div><dt>الجلسة</dt><dd>{sessionName(selected.academic_session_id)}</dd></div>
        {textFields.map((field) => <div key={field.key}><dt>{field.label}</dt><dd>{selected[field.key] || "—"}</dd></div>)}
        <div><dt>الحالة</dt><dd>{admissionStatuses[selected.status] ?? selected.status}</dd></div><div><dt>المسند إليه</dt><dd>{assigneeName(selected.assigned_to)}</dd></div><div><dt>تاريخ الإنشاء</dt><dd>{new Date(selected.created_at).toLocaleString("ar")}</dd></div><div><dt>تاريخ الإغلاق</dt><dd>{selected.closed_at ? new Date(selected.closed_at).toLocaleString("ar") : "—"}</dd></div></dl>
      <section className="audit-panel" aria-label="سجل تغييرات حالة الطلب">
        <h3 className="history-title">سجل الحالة والتحديثات</h3>
        <p className="data-note">كل تغيير في الحالة أو الإسناد يُسجّل تلقائيًا مع اسم الموظف ووقت التغيير.</p>
        {historyLoading && <p role="status">جارٍ تحميل السجل...</p>}
        {historyError && <p className="error-box" role="alert">تعذر تحميل سجل الطلب: {historyError} <button className="text-button" onClick={() => setRetry((v) => v + 1)}>إعادة المحاولة</button></p>}
        {!historyLoading && !historyError && !history.length && <p className="muted">لا توجد تعديلات مسجّلة بعد.</p>}
        {!historyLoading && !historyError && !!history.length && <ol className="history-list">
          {history.map((entry) => <li key={entry.entry_id}>
            <span className={`history-dot${entry.action === "status_change" ? " accent" : ""}`} aria-hidden="true"></span>
            <div className="history-body">
              <p className="history-head"><strong>{historyTitle(entry)}</strong><time dateTime={entry.occurred_at}>{new Date(entry.occurred_at).toLocaleString("ar")}</time></p>
              <p className="history-detail">{historyDetail(entry)}</p>
              <p className="history-actor">بواسطة: {entry.actor_name}</p>
            </div>
          </li>)}
        </ol>}
      </section>
      {canEditBranch(selected.branch_id) && <button className="button primary" onClick={() => openForm(selected)}>تعديل الطلب والحالة</button>}
      <div className="actions receipt-actions">
        <button className="button secondary" onClick={() => setReceiptOpen(true)}>طباعة إيصال الاستلام</button>
        <button className="button secondary" disabled={exporting !== false} onClick={() => void exportEnquiry()}>{exporting === "enquiry" ? "جارٍ التصدير..." : "تصدير سجل الطلب CSV"}</button>
      </div>
      {enquiryError && <p className="error-box" role="alert">{enquiryError}</p>}
      {enquiryNote && <p className="success-box" role="status">{enquiryNote}</p>}
    </aside>}
    <section className="panel export-panel" aria-label="تصدير السجلات">
      <h2>التصدير للتدقيق والتقارير</h2>
      <p className="data-note">اختر الفترة (تاريخ تقديم الطلب أو تاريخ الحركة) ثم اختر نوع الملف. يُصدّر الملف بترميز UTF-8 ليفتح بصورة صحيحة في Excel وGoogle Sheets مع النص العربي.</p>
      {scanLoading && <p role="status">جارٍ فتح الطلب الممسوح...</p>}
      {scanError && <p className="error-box" role="alert">تعذّر فتح الطلب الممسوح: {scanError}</p>}
      <div className="export-controls">
        <label>من تاريخ<input type="date" value={exportFrom} onChange={(e) => setExportFrom(e.target.value)} /></label>
        <label>إلى تاريخ<input type="date" value={exportTo} onChange={(e) => setExportTo(e.target.value)} /></label>
      </div>
      <p className="data-note">
        {isSuper
          ? (filters.branch ? `النطاق: ${branchName(filters.branch)}` : "النطاق: كل الفروع")
          : filters.branch ? `النطاق: ${branchName(filters.branch)}` : "اختر فرعًا لتفعيل التصدير."}
        {exportFrom || exportTo ? ` · ${exportFrom || "البداية"} ← ${exportTo || "اليوم"}` : " · كل التواريخ"}
      </p>
      <div className="export-blocks">
        <div className="export-block">
          <h3>سجل تغييرات الحالات</h3>
          <p className="data-note">كل تغيير حالة أو إسناد أو تعديل بيانات، مع اسم الموظف ووقت التغيير.</p>
          <button className="button primary" disabled={exporting !== false} onClick={() => void exportRange()}>{exporting === "range" ? "جارٍ التصدير..." : "تصدير سجل الحالات CSV"}</button>
          {exportError && <p className="error-box" role="alert">{exportError}</p>}
          {exportNote && <p className="success-box" role="status">{exportNote}</p>}
        </div>
        <div className="export-block">
          <h3>كشف الطلبات والحالة الحالية</h3>
          <p className="data-note">
            بيانات المتقدمين كاملة مع الحالة الحالية والموظف المسند إليه.
            {filters.session || filters.status ? " يخضع الكشف لتصفية الجلسة والحالة الحالية أعلى الصفحة." : ""}
          </p>
          <button className="button secondary" disabled={exporting !== false} onClick={() => void exportRoster()}>{exporting === "roster" ? "جارٍ التصدير..." : "تصدير كشف الطلبات CSV"}</button>
          {rosterError && <p className="error-box" role="alert">{rosterError}</p>}
          {rosterNote && <p className="success-box" role="status">{rosterNote}</p>}
        </div>
      </div>
    </section>
    {editing !== undefined && <section className="panel management-detail" aria-label="نموذج الطلب"><div className="page-heading"><h2>{editing ? "تعديل الطلب" : "إضافة طلب"}</h2><button className="button secondary" disabled={saving} onClick={() => setEditing(undefined)}>إغلاق</button></div>
      <form className="management-form" onSubmit={(event) => void submit(event)}>
        <label>الفرع<input value={branchName(draft.branch_id)} disabled /></label>
        <label>الجلسة<select required value={draft.academic_session_id} disabled={sessionLoading || !!sessionError} onChange={(e) => change("academic_session_id", e.target.value)}><option value="">اختر جلسة</option>{editing?.academic_session_id && !sessions.some((item) => item.id === editing.academic_session_id) && <option value={editing.academic_session_id}>الجلسة الحالية غير متاحة في القائمة</option>}{sessions.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
        {textFields.map((field) => <label key={field.key}>{field.label}{field.key === "notes" ? <textarea value={draft.notes} onChange={(e) => change("notes", e.target.value)} /> : <input required={field.key === "applicant_full_name"} type={field.key === "email" ? "email" : field.key === "phone" ? "tel" : "text"} value={draft[field.key]} onChange={(e) => change(field.key, e.target.value)} />}</label>)}
        <label>المسند إليه<select value={draft.assigned_to} disabled={staffLoading || !!staffError} onChange={(e) => change("assigned_to", e.target.value)}><option value="">غير مسند</option>{editing?.assigned_to && !staff.some((item) => item.user_id === editing.assigned_to) && <option value={editing.assigned_to}>الموظف الحالي غير متاح في القائمة</option>}{staff.map((person) => <option key={person.user_id} value={person.user_id}>{person.full_name}</option>)}</select></label>
        {editing && <label>الحالة<select value={draft.status} onChange={(e) => { if (isAdmissionStatus(e.target.value)) change("status", e.target.value); }} >{Object.entries(admissionStatuses).map(([id, name]) => <option key={id} value={id}>{name}</option>)}</select></label>}
        {formError && <p className="error-box" role="alert">{formError}</p>}
        <div className="actions"><button className="button primary" disabled={saving || staffLoading || !!staffError || optionsLoading || !!optionsError || sessionLoading || !!sessionError}>{saving ? "جارٍ الحفظ..." : "حفظ"}</button><button type="button" className="button secondary" disabled={saving} onClick={() => setEditing(undefined)}>إلغاء</button></div>
      </form>
    </section>}
    {receiptOpen && selected && <AdmissionReceipt admission={selected} branchLabel={branchName(selected.branch_id)} sessionLabel={sessionName(selected.academic_session_id)} onClose={() => setReceiptOpen(false)} />}
  </main>;
}