import { useEffect, useState, type FormEvent } from "react";
import { loadManagementBranches, loadManagementOptions, type Option } from "../lib/management";
import {
  admissionDraft, admissionStatuses, admissionsPageSize, canManageAdmissions, isAdmissionStatus,
  loadAdmissions, loadAdmissionSessions, loadAdmissionStaff, saveAdmission, validateAdmission,
  type Admission, type AdmissionDraft, type AdmissionFilters, type StaffOption,
} from "../lib/admissions";

const initialFilters: AdmissionFilters = { branch: "", session: "", status: "", assignee: "", search: "", page: 0 };
const textFields: { key: "applicant_full_name" | "guardian_name" | "phone" | "email" | "preferred_program" | "preferred_level" | "source" | "notes"; label: string }[] = [
  { key: "applicant_full_name", label: "اسم المتقدم" }, { key: "guardian_name", label: "اسم ولي الأمر" },
  { key: "phone", label: "الهاتف" }, { key: "email", label: "البريد الإلكتروني" },
  { key: "preferred_program", label: "البرنامج المطلوب" }, { key: "preferred_level", label: "المستوى المطلوب" },
  { key: "source", label: "مصدر الطلب" }, { key: "notes", label: "الملاحظات" },
];
function errorText(error: unknown) { return error instanceof Error ? error.message : String(error); }

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
  const [filters, setFilters] = useState(initialFilters);
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

  function filter(key: keyof AdmissionFilters, value: string) {
    setSelected(null);
    setFilters((current) => ({ ...current, [key]: value, page: 0, ...(key === "branch" ? { assignee: "", session: "" } : {}) }));
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
    try {
      await saveAdmission(draft, editing?.id ?? null);
      setEditing(undefined); setSelected(null); setSuccess("تم حفظ الطلب.");
      setRetry((value) => value + 1);
    } catch (failure) { setFormError(`تعذر حفظ الطلب: ${errorText(failure)}`); }
    finally { setSaving(false); }
  }
  const branchName = (id: string) => branches.find((item) => item.id === id)?.name ?? id;
  const sessionName = (id: string) => sessions.find((item) => item.id === id)?.name ?? id;
  const assigneeName = (id: string | null) => id ? staff.find((item) => item.user_id === id)?.full_name ?? id : "غير مسند";
  const canCreate = !!filters.branch && canEditBranch(filters.branch);

  return <main className="workspace">
    <div className="page-heading"><div><p className="eyebrow">إدارة الأكاديمية</p><h1>القبول والتسجيل</h1></div>
      {canCreate && <button className="button primary" disabled={saving || editing !== undefined || optionsLoading || !!optionsError} onClick={() => openForm(null)}>إضافة طلب</button>}
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
    </fieldset>
    {optionsLoading && <p role="status">جارٍ تحميل الفروع والجلسات...</p>}
    {staffLoading && <p role="status">جارٍ تحميل الموظفين...</p>}
    {sessionLoading && <p role="status">جارٍ تحميل الجلسات النشطة...</p>}
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
      {canEditBranch(selected.branch_id) && <button className="button primary" onClick={() => openForm(selected)}>تعديل الطلب والحالة</button>}
    </aside>}
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
  </main>;
}
