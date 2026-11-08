import { useEffect, useState, type FormEvent } from "react";
import {
  loadManagementBranches, loadManagementOptions, loadManagementRows, loadStudentRecordsForExport, managementAccess,
  pageSize, saveManagementRow, type ManagementFilters, type ManagementKind, type ManagementRow, type Option,
} from "../lib/management";
import { exportStudentRecordsCsv } from "../lib/reportExport";
import { isAvailableStudentClass, makeDraft, managementPayload, validateManagementDraft, type Draft } from "../lib/managementForms";
import { StudentAccountLink } from "./students/StudentAccountLink";
import { StudentProgressReport } from "./students/StudentProgressReport";
import { StudentRecordsPrintSheet, type RecordsPrintScope } from "./students/StudentRecordsPrintSheet";

const titles: Record<ManagementKind, string> = {
  branches: "الفروع", sessions: "الجلسات الأكاديمية", classes: "الصفوف", students: "سجلات الطلاب",
};
const labels: Record<string, string> = {
  id: "المعرّف", name: "الاسم", code: "الرمز", address: "العنوان", is_active: "الحالة",
  starts_on: "تاريخ البدء", ends_on: "تاريخ الانتهاء", branch_id: "الفرع",
  session_id: "الجلسة", program: "البرنامج", capacity: "السعة", teacher_id: "معرّف المعلم",
  user_id: "معرّف حساب الطالب", admission_no: "رقم القبول", full_name: "الاسم الكامل",
  date_of_birth: "تاريخ الميلاد", class_id: "الصف", status: "الحالة",
};
const statuses: Record<string, string> = {
  active: "نشط", inactive: "غير نشط", graduated: "متخرج", withdrawn: "منسحب",
};
type Options = { branches: Option[]; sessions: Option[]; classes: Option[] };
const emptyOptions: Options = { branches: [], sessions: [], classes: [] };
const initialFilters: ManagementFilters = { search: "", branch: "", session: "", classId: "", status: "", page: 0 };

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function ManagementPage({ kind, roles, userId }: { kind: ManagementKind; roles: readonly string[]; userId: string | null }) {
  const isSuperAdmin = roles.includes("super_admin");
  const access = managementAccess(kind, roles);
  const needsScope = !isSuperAdmin && roles.includes("admin") && kind !== "sessions";
  const [filters, setFilters] = useState<ManagementFilters>(initialFilters);
  const [options, setOptions] = useState<Options>(emptyOptions);
  const [formClasses, setFormClasses] = useState<Option[]>([]);
  const [rows, setRows] = useState<ManagementRow[]>([]);
  const [count, setCount] = useState(0);
  const [selected, setSelected] = useState<ManagementRow | null>(null);
  const [editing, setEditing] = useState<ManagementRow | null | undefined>(undefined);
  const [draft, setDraft] = useState<Draft>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [optionsError, setOptionsError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [formOptionsError, setFormOptionsError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);
  const [optionsLoading, setOptionsLoading] = useState(false);
  const [formLoading, setFormLoading] = useState(false);
  const [managedBranches, setManagedBranches] = useState<string[]>([]);
  const [scopeLoading, setScopeLoading] = useState(needsScope);
  const [scopeError, setScopeError] = useState<string | null>(null);
  const [reportStudent, setReportStudent] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState<string | null>(null);
  const [printScope, setPrintScope] = useState<{ filters: ManagementFilters; scope: RecordsPrintScope } | null>(null);

  useEffect(() => {
    if (!needsScope) { setScopeLoading(false); setScopeError(null); setManagedBranches([]); return; }
    if (!userId) { setScopeLoading(false); setScopeError("تعذر التحقق من هوية الحساب."); return; }
    let active = true;
    setScopeLoading(true);
    setScopeError(null);
    void loadManagementBranches(userId).then((value) => {
      if (active) setManagedBranches(value);
    }).catch((failure: unknown) => {
      if (active) { setManagedBranches([]); setScopeError(`تعذر التحقق من نطاق الإدارة: ${message(failure)}`); }
    }).finally(() => { if (active) setScopeLoading(false); });
    return () => { active = false; };
  }, [needsScope, userId, retry]);

  const canCreate = access.canCreate && (isSuperAdmin || (!scopeLoading && !scopeError && managedBranches.length > 0));
  function canEditRow(row: ManagementRow) {
    if (!access.canEdit) return false;
    if (isSuperAdmin) return true;
    if (scopeLoading || scopeError) return false;
    const branch = kind === "branches" ? row.id : row.branch_id;
    return !!branch && managedBranches.includes(branch);
  }

  useEffect(() => {
    let active = true;
    setOptionsLoading(true);
    setOptionsError(null);
    void loadManagementOptions(filters.branch, filters.session).then((value) => {
      if (active) setOptions(value);
    }).catch((failure: unknown) => {
      if (active) { setOptions(emptyOptions); setOptionsError(`تعذر تحميل خيارات التصفية: ${message(failure)}`); }
    }).finally(() => { if (active) setOptionsLoading(false); });
    return () => { active = false; };
  }, [filters.branch, filters.session, retry]);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    void loadManagementRows(kind, filters).then((result) => {
      if (active) { setRows(result.rows); setCount(result.count); }
    }).catch((failure: unknown) => {
      if (active) { setRows([]); setCount(0); setError(`تعذر تحميل السجلات: ${message(failure)}`); }
    }).finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [kind, filters, retry]);

  useEffect(() => {
    if (editing === undefined || kind !== "students" || !draft.branch_id || !draft.session_id) {
      setFormClasses([]);
      setFormLoading(false);
      setFormOptionsError(null);
      return;
    }
    let active = true;
    setFormLoading(true);
    setFormOptionsError(null);
    void loadManagementOptions(draft.branch_id, draft.session_id).then((value) => {
      if (active) setFormClasses(value.classes);
    }).catch((failure: unknown) => {
      if (active) { setFormClasses([]); setFormOptionsError(`تعذر تحميل الصفوف: ${message(failure)}`); }
    }).finally(() => { if (active) setFormLoading(false); });
    return () => { active = false; };
  }, [editing, kind, draft.branch_id, draft.session_id, retry]);

  function filter(key: keyof ManagementFilters, value: string) {
    setSelected(null);
    setFilters((current) => ({ ...current, [key]: value, page: 0, ...(key === "branch" || key === "session" ? { classId: "" } : {}) }));
  }
  function openForm(row: ManagementRow | null) {
    if (saving || editing !== undefined || (row ? !canEditRow(row) : !canCreate)) return;
    setEditing(row);
    const next = makeDraft(kind, row, filters);
    if (!row && !isSuperAdmin && next.branch_id && !managedBranches.includes(next.branch_id)) next.branch_id = "";
    setDraft(next);
    setFormError(null);
    setSuccess(null);
  }
  function change(key: string, value: string) {
    if (kind === "students" && (key === "session_id" || key === "branch_id")) {
      setFormClasses([]);
      setFormLoading(true);
    }
    setDraft((current) => ({ ...current, [key]: value, ...(key === "session_id" || key === "branch_id" ? { class_id: "" } : {}) }));
  }
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (saving || editing === undefined || (editing ? !canEditRow(editing) : !canCreate)) return;
    const validation = validateManagementDraft(kind, draft, !!editing);
    if (validation) { setFormError(validation); return; }
    if (kind === "students" && !isAvailableStudentClass(draft.class_id, formClasses, formLoading, formOptionsError)) {
      setFormError("الصف المحدد غير متاح ضمن الفرع والجلسة؛ أعد تحميل الصفوف أو اختر صفاً متاحاً.");
      return;
    }
    setSaving(true);
    setFormError(null);
    try {
      await saveManagementRow(kind, editing?.id ?? null, managementPayload(kind, draft, !!editing));
      setEditing(undefined);
      setSelected(null);
      setSuccess("تم حفظ السجل.");
      setRetry((value) => value + 1);
    } catch (failure) { setFormError(`تعذر حفظ السجل: ${message(failure)}`); }
    finally { setSaving(false); }
  }
  async function deactivate(row: ManagementRow) {
    if (!canEditRow(row) || !window.confirm("هل تريد إيقاف هذا السجل دون حذفه؟")) return;
    setSaving(true); setError(null); setSuccess(null);
    try {
      await saveManagementRow(kind, row.id, kind === "students" ? { status: "inactive" } : { is_active: false });
      setSelected(null);
      setSuccess("تم إيقاف السجل.");
      setRetry((value) => value + 1);
    } catch (failure) { setError(`تعذر إيقاف السجل: ${message(failure)}`); }
    finally { setSaving(false); }
  }
  async function exportRoster() {
    if (exporting) return;
    setExportError(null);
    if (!filters.branch || !filters.session) {
      setExportError("اختر الفرع والجلسة أولاً، ثم أعد التصدير. يُصدَّر الكشف التام وليس الصفحة المعروضة فقط.");
      return;
    }
    setExporting(true);
    try {
      const rows = await loadStudentRecordsForExport(filters);
      if (!rows.length) {
        setExportError("لا توجد سجلات طلاب مطابقة للتصفية الحالية لتصديرها.");
        return;
      }
      const scope = `${optionName(options.branches, filters.branch)} ${optionName(options.sessions, filters.session)}`;
      const fileName = exportStudentRecordsCsv(rows, scope);
      setSuccess(`تم تصدير كشف الطلاب (${rows.length} سجلاً) في الملف ${fileName}.`);
    } catch (failure) {
      setExportError(`تعذر تصدير كشف الطلاب: ${message(failure)}`);
    } finally {
      setExporting(false);
    }
  }
  async function openRosterPrint() {
    setExportError(null);
    if (!filters.branch || !filters.session) {
      setExportError("اختر الفرع والجلسة أولاً، ثم أعد المحاولة لطباعة كشف الطلاب الرسمي.");
      return;
    }
    setPrintScope({
      filters: { ...filters },
      scope: {
        branchLabel: optionName(options.branches, filters.branch),
        sessionLabel: filters.session === "unassigned" ? "طلاب بلا صف" : optionName(options.sessions, filters.session),
        classLabel: filters.classId ? optionName(options.classes, filters.classId) : "كل الصفوف المتاحة",
        statusLabel: filters.status ? statuses[filters.status] ?? filters.status : "كل الحالات",
      },
    });
  }
  const scoped = kind === "classes" || kind === "students";
  const optionName = (list: Option[], id: string) => list.find((item) => item.id === id)?.name ?? id;
  const display = (key: string, value: unknown) => {
    if (value == null || value === "") return "—";
    if (key === "is_active") return value ? "نشط" : "غير نشط";
    if (key === "status") return statuses[String(value)] ?? String(value);
    if (key === "branch_id") return optionName(options.branches, String(value));
    if (key === "session_id") return optionName(options.sessions, String(value));
    if (key === "class_id") return optionName(options.classes, String(value));
    return String(value);
  };

  return <main className="workspace">
    <div className="page-heading"><div><p className="eyebrow">إدارة الأكاديمية</p><h1>{titles[kind]}</h1></div>
      <div className="actions">
        {kind === "students" && <button className="button secondary" type="button" disabled={exporting || loading} onClick={() => void exportRoster()}>
          <i className="ri-file-excel-2-line" aria-hidden="true"></i> {exporting ? "جارٍ التصدير..." : "تصدير CSV"}
        </button>}
        {kind === "students" && <button className="button secondary" type="button" disabled={loading} onClick={() => void openRosterPrint()}>
          <i className="ri-printer-line" aria-hidden="true"></i> طباعة كشف الطلاب
        </button>}
        {canCreate && <button className="button primary" disabled={saving || editing !== undefined} onClick={() => openForm(null)}>إضافة سجل</button>}
      </div>
    </div>
    <p className="data-note">تظهر السجلات المسموح بها فقط، وتفرض قاعدة البيانات صلاحيات القراءة والكتابة.</p>
    {kind === "sessions" && !isSuperAdmin && <p className="notice">الجلسات مشتركة بين الفروع؛ إدارتها متاحة للإدارة العامة فقط.</p>}
    {scopeLoading && <p role="status">جارٍ التحقق من نطاق الإدارة...</p>}
    {scopeError && <p className="error-box" role="alert">{scopeError} <button className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}
    <fieldset className="context-card" disabled={editing !== undefined || saving}>
      <label>البحث بالاسم<input value={filters.search} onChange={(event) => filter("search", event.target.value)} /></label>
      {scoped && <label>الفرع<select value={filters.branch} onChange={(event) => filter("branch", event.target.value)}><option value="">اختر فرعاً</option>{options.branches.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>}
      {scoped && <label>الجلسة<select value={filters.session} onChange={(event) => filter("session", event.target.value)}><option value="">اختر جلسة</option>{options.sessions.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}{kind === "students" && <option value="unassigned">طلاب بلا صف</option>}</select></label>}
      {kind === "students" && filters.session !== "unassigned" && <label>الصف<select value={filters.classId} onChange={(event) => filter("classId", event.target.value)}><option value="">كل الصفوف المتاحة</option>{options.classes.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>}
      <label>الحالة<select value={filters.status} onChange={(event) => filter("status", event.target.value)}><option value="">كل الحالات</option>{(kind === "students" ? Object.entries(statuses) : Object.entries(statuses).slice(0, 2)).map(([value, name]) => <option key={value} value={value}>{name}</option>)}</select></label>
    </fieldset>
    {optionsLoading && <p className="muted" role="status">جارٍ تحميل خيارات التصفية...</p>}
    {kind === "students" && <p className="muted">تصدير CSV يُنزّل كشف الطلاب كاملاً حسب التصفية الحالية (كل الصفحات) مع حالة كل طالب وصفه وفرعه وجلسته.</p>}
    {success && <p className="success-box" role="status">{success}</p>}
    {exportError && <p className="error-box" role="alert">{exportError}</p>}
    {error && <div className="error-box" role="alert">{error} <button className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></div>}
    {optionsError && <div className="error-box" role="alert">{optionsError} <button className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></div>}
    <section className="panel">
      {loading ? <p role="status">جارٍ تحميل السجلات...</p> : error ? null : scoped && (!filters.branch || !filters.session) ? <p className="notice">اختر الفرع والجلسة لعرض السجلات ضمن النطاق.</p> : !rows.length ? <><p className="muted">لا توجد سجلات متاحة تطابق التصفية. قد تحد سياسات الوصول من النتائج.</p>{filters.page > 0 && <button className="button secondary" onClick={() => setFilters((current) => ({ ...current, page: current.page - 1 }))}>الصفحة السابقة</button>}</> :
        <><div className="table-scroll"><table className="management-table"><thead><tr><th>الاسم</th><th>التفاصيل</th><th>الحالة</th><th><span className="sr-only">الإجراءات</span></th></tr></thead><tbody>
          {rows.map((row) => <tr key={row.id}><td>{row.full_name ?? row.name}</td><td>{kind === "students" ? row.admission_no : kind === "classes" ? row.program : kind === "branches" ? row.code : `${row.starts_on} — ${row.ends_on}`}</td><td>{kind === "students" ? display("status", row.status) : display("is_active", row.is_active)}</td><td><button className="button secondary" disabled={saving || editing !== undefined} onClick={() => setSelected(row)}>التفاصيل</button></td></tr>)}
        </tbody></table></div><div className="pagination"><button className="button secondary" disabled={filters.page === 0 || saving || editing !== undefined} onClick={() => { setSelected(null); setFilters((current) => ({ ...current, page: current.page - 1 })); }}>السابق</button><span>صفحة {filters.page + 1} · {count} سجل</span><button className="button secondary" disabled={(filters.page + 1) * pageSize >= count || saving || editing !== undefined} onClick={() => { setSelected(null); setFilters((current) => ({ ...current, page: current.page + 1 })); }}>التالي</button></div></>}
    </section>
    {selected && editing === undefined && <section className="panel management-detail" aria-label="تفاصيل السجل"><div className="page-heading"><h2>تفاصيل السجل</h2><button className="button secondary" disabled={saving} onClick={() => setSelected(null)}>إغلاق</button></div>
      <dl>{Object.entries(selected).filter(([key]) => key in labels).map(([key, value]) => <div key={key}><dt>{labels[key]}</dt><dd>{display(key, value)}</dd></div>)}</dl>
      {canEditRow(selected) && <div className="actions"><button className="button primary" disabled={saving} onClick={() => openForm(selected)}>تعديل</button>{(kind === "students" ? selected.status === "active" : selected.is_active) && <button className="button secondary" disabled={saving} onClick={() => void deactivate(selected)}>إيقاف</button>}</div>}
      {kind === "students" && <>
        <div className="actions"><button className="button secondary" type="button" disabled={saving} onClick={() => setReportStudent(selected.id)}>طباعة تقرير الفصل لولي الأمر</button></div>
        {canEditRow(selected) && <StudentAccountLink studentId={selected.id} currentUserId={selected.user_id ?? null} onChanged={() => setRetry((value) => value + 1)} />}
      </>}
    </section>}
    {reportStudent && <StudentProgressReport studentId={reportStudent} onClose={() => setReportStudent(null)} />}
    {printScope && <StudentRecordsPrintSheet
      filters={printScope.filters}
      scope={printScope.scope}
      onClose={() => setPrintScope(null)}
    />}
    {editing !== undefined && <section className="panel management-detail" aria-label="نموذج السجل"><div className="page-heading"><h2>{editing ? "تعديل السجل" : "إضافة سجل"}</h2><button className="button secondary" disabled={saving} onClick={() => setEditing(undefined)}>إغلاق</button></div>
      <form className="management-form" onSubmit={(event) => void submit(event)}>
        {kind === "students" ? <><label>الاسم الكامل<input required value={draft.full_name} onChange={(event) => change("full_name", event.target.value)} /></label><label>رقم القبول<input required value={draft.admission_no} onChange={(event) => change("admission_no", event.target.value)} /></label><label>تاريخ الميلاد<input type="date" value={draft.date_of_birth} onChange={(event) => change("date_of_birth", event.target.value)} /></label></> : <label>الاسم<input required value={draft.name} onChange={(event) => change("name", event.target.value)} /></label>}
        {kind === "branches" && <><label>الرمز<input required value={draft.code} onChange={(event) => change("code", event.target.value)} /></label><label>العنوان<input value={draft.address} onChange={(event) => change("address", event.target.value)} /></label></>}
        {kind === "sessions" && <><label>تاريخ البدء<input type="date" required value={draft.starts_on} onChange={(event) => change("starts_on", event.target.value)} /></label><label>تاريخ الانتهاء<input type="date" required value={draft.ends_on} onChange={(event) => change("ends_on", event.target.value)} /></label></>}
        {scoped && <label>الفرع<select required disabled={!!editing} value={draft.branch_id} onChange={(event) => change("branch_id", event.target.value)}><option value="">اختر فرعاً</option>{options.branches.filter((item) => isSuperAdmin || managedBranches.includes(item.id)).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>}
        {(kind === "students" || kind === "classes") && <label>الجلسة<select required={kind === "classes"} disabled={kind === "classes" && !!editing} value={draft.session_id} onChange={(event) => change("session_id", event.target.value)}><option value="">اختر جلسة</option>{options.sessions.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>}
        {kind === "classes" && <><label>البرنامج<input required value={draft.program} onChange={(event) => change("program", event.target.value)} /></label><label>السعة<input type="number" min="1" step="1" required value={draft.capacity} onChange={(event) => change("capacity", event.target.value)} /></label>{!editing && <label>معرّف حساب المعلم (اختياري)<input dir="ltr" value={draft.teacher_id} onChange={(event) => change("teacher_id", event.target.value)} /></label>}</>}
        {kind === "students" && <>{!editing && <label>معرّف حساب الطالب (اختياري)<input dir="ltr" value={draft.user_id} onChange={(event) => change("user_id", event.target.value)} /></label>}<label>الصف<select disabled={!draft.session_id || formLoading} value={draft.class_id} onChange={(event) => change("class_id", event.target.value)}><option value="">بدون صف</option>{formClasses.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label><label>الحالة<select value={draft.status} onChange={(event) => change("status", event.target.value)}>{Object.entries(statuses).map(([value, name]) => <option key={value} value={value}>{name}</option>)}</select></label></>}
        {kind !== "students" && <label>الحالة<select value={draft.is_active} onChange={(event) => change("is_active", event.target.value)}><option value="true">نشط</option><option value="false">غير نشط</option></select></label>}
        {formLoading && <p role="status">جارٍ تحميل الصفوف...</p>}
        {formOptionsError && <p className="error-box" role="alert">{formOptionsError} <button type="button" className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}
        {formError && <p className="error-box" role="alert">{formError}</p>}
        <div className="actions"><button className="button primary" disabled={saving || formLoading || optionsLoading || !!optionsError || !!formOptionsError}>{saving ? "جارٍ الحفظ..." : "حفظ"}</button><button type="button" className="button secondary" disabled={saving} onClick={() => setEditing(undefined)}>إلغاء</button></div>
      </form>
    </section>}
  </main>;
}
