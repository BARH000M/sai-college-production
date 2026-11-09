import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { loadManagementBranches, loadManagementOptions, type Option } from "../lib/management";
import {
  attendancePageSize, attendanceStatuses, attendanceToday, canCorrectAttendance, canManageAttendance,
  createAttendanceSession, isAttendanceStatus, loadAttendanceClasses, loadAttendanceHistory, loadAttendanceRoster,
  loadAttendanceSessions, saveAttendance, saveAttendanceBatch, setAttendanceSessionStatus,
  type AttendanceClass, type AttendanceFilters, type AttendanceRecord, type AttendanceSession,
  type AttendanceStatus, type RosterEntry,
} from "../lib/attendance";
import { AttendanceRegisterSheet, type RegisterEntry } from "./attendance/AttendanceRegisterSheet";

const initialFilters: AttendanceFilters = { branch: "", session: "", classId: "", date: "", page: 0 };
const errorText = (error: unknown) => error instanceof Error ? error.message : String(error);

export function Attendance({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const allowed = roles.some((role) => ["super_admin", "admin", "teacher", "receptionist", "student", "parent"].includes(role));
  const staff = roles.some((role) => ["super_admin", "admin", "teacher", "receptionist"].includes(role));
  const [searchParams] = useSearchParams();
  const [classes, setClasses] = useState<AttendanceClass[]>([]);
  const [branches, setBranches] = useState<Option[]>([]);
  const [sessions, setSessions] = useState<Option[]>([]);
  const [scope, setScope] = useState<string[]>([]);
  const [filters, setFilters] = useState<AttendanceFilters>(() => ({ ...initialFilters, classId: searchParams.get("class") ?? "" }));
  const [rows, setRows] = useState<AttendanceSession[]>([]);
  const [count, setCount] = useState(0);
  const [selected, setSelected] = useState<AttendanceSession | null>(null);
  const [roster, setRoster] = useState<RosterEntry[]>([]);
  const [history, setHistory] = useState<AttendanceRecord[]>([]);
  const [drafts, setDrafts] = useState<Record<string, { status: AttendanceStatus | ""; note: string }>>({});
  const [date, setDate] = useState(attendanceToday);
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [printing, setPrinting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [detailError, setDetailError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);
  const selectedClass = classes.find((item) => item.id === selected?.class_id);
  const chosenClass = classes.find((item) => item.id === filters.classId);
  const manager = !!selectedClass && canManageAttendance(roles, userId, scope, selectedClass);
  const corrector = !!selected && canCorrectAttendance(roles, scope, selected.branch_id);
  const canCreate = !!chosenClass && canManageAttendance(roles, userId, scope, chosenClass);

  useEffect(() => {
    if (!allowed) { setLoading(false); return; }
    let active = true;
    setLoading(true); setError(null);
    Promise.all([
      loadAttendanceClasses(),
      loadManagementOptions("", ""),
      staff && !roles.includes("super_admin") && userId ? loadManagementBranches(userId) : Promise.resolve([]),
      loadAttendanceSessions(filters),
    ]).then(([classRows, options, memberships, result]) => {
      if (!active) return;
      setClasses(classRows); setBranches(options.branches); setSessions(options.sessions);
      setScope(memberships); setRows(result.rows); setCount(result.count);
    }).catch((failure: unknown) => { if (active) { setRows([]); setError(errorText(failure)); } })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [allowed, staff, userId, roles, filters, retry]);

  useEffect(() => {
    if (!selected) { setRoster([]); setHistory([]); return; }
    let active = true;
    setDetailLoading(true); setDetailError(null);
    const request = manager || corrector
      ? loadAttendanceRoster(selected.id).then((value) => ({ roster: value, history: [] as AttendanceRecord[] }))
      : loadAttendanceHistory(selected.id).then((value) => ({ roster: [] as RosterEntry[], history: value }));
    request.then((value) => {
      if (!active) return;
      setRoster(value.roster); setHistory(value.history);
      setDrafts((current) => Object.fromEntries(value.roster.map((row) => [row.student_id,
        current[row.student_id] ?? { status: row.attendance_status ?? "", note: row.note ?? "" }])));
    }).catch((failure: unknown) => { if (active) { setRoster([]); setHistory([]); setDetailError(errorText(failure)); } })
      .finally(() => { if (active) setDetailLoading(false); });
    return () => { active = false; };
  }, [selected, manager, corrector, retry]);

  function filter(key: keyof AttendanceFilters, value: string) {
    setSelected(null); setDrafts({}); setMessage(null);
    setFilters((current) => ({ ...current, [key]: value, page: 0,
      ...(key === "branch" ? { session: "", classId: "" } : key === "session" ? { classId: "" } : {}) }));
  }
  async function mutate(action: () => Promise<void>, success: string, keepSelected = false) {
    if (saving) return;
    setSaving(true); setDetailError(null); setError(null); setMessage(null);
    try { await action(); setMessage(success); if (!keepSelected) { setSelected(null); setDrafts({}); } setRetry((value) => value + 1); }
    catch (failure) { setDetailError(errorText(failure)); }
    finally { setSaving(false); }
  }
  const branchName = (id: string) => branches.find((item) => item.id === id)?.name ?? id;
  const sessionName = (id: string) => sessions.find((item) => item.id === id)?.name ?? id;
  const className = (id: string) => classes.find((item) => item.id === id)?.name ?? id;
  const availableClasses = classes.filter((item) => (!filters.branch || item.branch_id === filters.branch)
    && (!filters.session || item.academic_session_id === filters.session));
  const branchIds = [...new Set(classes.map((item) => item.branch_id))];
  const sessionIds = [...new Set(classes.filter((item) => !filters.branch || item.branch_id === filters.branch).map((item) => item.academic_session_id))];
  const sessionLabels = { open: "مفتوحة", closed: "مغلقة", cancelled: "ملغاة" };
  const visibleStatuses = manager || corrector ? roster.map((row) => row.attendance_status) : history.map((row) => row.status);

  const editableRows = roster.filter((row) => selected?.status === "open" && (manager || (corrector && !!row.record_id)));
  const pendingDrafts = editableRows.filter((row) => !!drafts[row.student_id]?.status);
  const registerEntries: RegisterEntry[] = roster.map((row) => {
    const draft = drafts[row.student_id];
    return {
      key: row.student_id,
      name: row.full_name,
      status: (draft?.status || row.attendance_status || null) as AttendanceStatus | null,
      note: draft?.note ?? row.note,
      saved: !!row.record_id,
    };
  });

  /** Fills the whole register with one status so the teacher only edits exceptions. */
  function markAll(status: AttendanceStatus) {
    setDrafts((current) => Object.fromEntries(editableRows.map((row) => [row.student_id,
      { status, note: current[row.student_id]?.note ?? row.note ?? "" }])));
  }

  function clearDrafts() {
    setDrafts((current) => Object.fromEntries(roster.map((row) => [row.student_id,
      { status: row.attendance_status ?? "", note: row.note ?? "" }])));
  }

  function saveAllDrafts() {
    if (!selected || !pendingDrafts.length) return;
    const items = pendingDrafts.map((row) => ({
      row,
      status: drafts[row.student_id].status as AttendanceStatus,
      note: drafts[row.student_id].note,
    }));
    void mutate(
      async () => { await saveAttendanceBatch(selected.id, items); },
      `حُفظ ${items.length} سجل حضور للصف.`,
      true,
    );
  }

  if (!allowed) return <main className="workspace"><section className="panel" role="alert"><h1>الوصول غير متاح</h1><p>لا يتيح دورك الوصول إلى سجلات الحضور.</p></section></main>;
  return <main className="workspace">
    <div className="page-heading"><div><p className="eyebrow">إدارة الأكاديمية</p><h1>الحضور والغياب</h1></div></div>
    <p className="data-note">تاريخ الحضور حسب توقيت عدن. تظهر البيانات المسموح بها فقط؛ لا يمكن تعديل الجلسات المغلقة أو الملغاة.</p>
    <fieldset className="context-card" disabled={saving}>
      <label>الفرع<select value={filters.branch} onChange={(e) => filter("branch", e.target.value)}><option value="">كل الفروع المتاحة</option>{branchIds.map((id) => <option key={id} value={id}>{branchName(id)}</option>)}</select></label>
      <label>الجلسة الأكاديمية<select value={filters.session} onChange={(e) => filter("session", e.target.value)}><option value="">كل الجلسات المتاحة</option>{sessionIds.map((id) => <option key={id} value={id}>{sessionName(id)}</option>)}</select></label>
      <label>الصف<select value={filters.classId} onChange={(e) => filter("classId", e.target.value)}><option value="">كل الصفوف المتاحة</option>{availableClasses.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
      <label>التاريخ<input type="date" value={filters.date} onChange={(e) => filter("date", e.target.value)} /></label>
    </fieldset>
    {canCreate && <section className="panel"><h2>فتح جلسة حضور</h2><div className="actions"><label>تاريخ الحضور<input type="date" value={date} max={attendanceToday()} onChange={(e) => setDate(e.target.value)} /></label><button className="button primary" disabled={saving} onClick={() => void mutate(() => createAttendanceSession(chosenClass, date), "تم فتح جلسة الحضور.")}>فتح الجلسة</button></div></section>}
    {loading && <p role="status">جارٍ تحميل الحضور...</p>}
    {error && <p className="error-box" role="alert">تعذر تحميل الحضور: {error} <button className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}
    {message && <p className="success-box" role="status">{message}</p>}
    {detailError && <p className="error-box" role="alert">تعذر تنفيذ الطلب: {detailError} <button className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}
    {!loading && !error && <section className="panel management-detail"><h2>جلسات الحضور</h2>
      {!rows.length ? <p className="muted">لا توجد جلسات متاحة تطابق التصفية.</p> : <div className="table-scroll"><table className="management-table"><thead><tr><th>التاريخ</th><th>الفرع</th><th>الصف</th><th>الحالة</th><th>التفاصيل</th></tr></thead><tbody>
        {rows.map((row) => <tr key={row.id}><td>{row.attendance_date}</td><td>{branchName(row.branch_id)}</td><td>{className(row.class_id)}</td><td>{sessionLabels[row.status]}</td><td><button className="button secondary" disabled={saving} onClick={() => { setSelected(row); setDrafts({}); setPrinting(false); setMessage(null); }}>عرض</button></td></tr>)}
      </tbody></table></div>}
      <div className="pagination"><button className="button secondary" disabled={filters.page === 0 || saving} onClick={() => setFilters((value) => ({ ...value, page: value.page - 1 }))}>السابق</button><span>صفحة {filters.page + 1} · {count} جلسة</span><button className="button secondary" disabled={(filters.page + 1) * attendancePageSize >= count || saving} onClick={() => setFilters((value) => ({ ...value, page: value.page + 1 }))}>التالي</button></div>
    </section>}
    {selected && <section className="panel management-detail"><div className="page-heading"><h2>تفاصيل الحضور · {selected.attendance_date}</h2><div className="actions"><button className="button secondary" disabled={saving} onClick={() => setPrinting(true)}><i className="ri-printer-line" aria-hidden="true"></i> طباعة الكشف</button><button className="button secondary" disabled={saving} onClick={() => setSelected(null)}>إغلاق التفاصيل</button></div></div>
      {detailLoading ? <p role="status">جارٍ تحميل السجل...</p> : !detailError && <>
        <p>ملخص السجلات المعروضة: {Object.entries(attendanceStatuses).map(([key, label]) => `${label}: ${visibleStatuses.filter((status) => status === key).length}`).join(" · ")}</p>
        {manager && selected.status === "open" && <div className="actions"><button className="button primary" disabled={saving} onClick={() => void mutate(() => setAttendanceSessionStatus(selected.id, "closed"), "تم إغلاق الجلسة.")}>إغلاق الجلسة</button><button className="button secondary" disabled={saving} onClick={() => void mutate(() => setAttendanceSessionStatus(selected.id, "cancelled"), "تم إلغاء الجلسة دون حذفها.")}>إلغاء الجلسة</button></div>}
        {(manager || corrector) && selected.status === "open" && !!editableRows.length && <div className="attendance-bulk">
          <div className="attendance-bulk-head">
            <strong><i className="ri-group-line" aria-hidden="true"></i> تسجيل سريع للصف</strong>
            <small className="data-note">حدّد الكل ثم غيّر حالات الغياب والتأخر فقط، واحفظ الجميع بضغطة واحدة.</small>
          </div>
          <div className="actions">
            <button className="button secondary" type="button" disabled={saving} onClick={() => markAll("present")}>
              <i className="ri-checkbox-circle-line" aria-hidden="true"></i> الكل حاضر
            </button>
            <button className="button secondary" type="button" disabled={saving} onClick={() => markAll("absent")}>
              <i className="ri-close-circle-line" aria-hidden="true"></i> الكل غائب
            </button>
            <button className="button secondary" type="button" disabled={saving} onClick={clearDrafts}>
              <i className="ri-arrow-go-back-line" aria-hidden="true"></i> استرجاع المحفوظ
            </button>
            <button className="button primary" type="button" disabled={saving || !pendingDrafts.length} onClick={saveAllDrafts}>
              <i className="ri-save-3-line" aria-hidden="true"></i> {saving ? "جارٍ الحفظ..." : `حفظ الكل (${pendingDrafts.length})`}
            </button>
          </div>
        </div>}
        {(manager || corrector) ? (!roster.length ? <p className="muted">لا توجد سجلات أو طلاب متاحون.</p> : <div className="table-scroll"><table className="management-table"><thead><tr><th>الطالب</th><th>الحضور</th><th>ملاحظة</th><th>الحفظ</th></tr></thead><tbody>
          {roster.map((row) => {
            const draft = drafts[row.student_id] ?? { status: "", note: "" };
            const editable = selected.status === "open" && (manager || (corrector && !!row.record_id));
            return <tr key={row.student_id}><td>{row.full_name}</td><td><select aria-label={`حالة ${row.full_name}`} disabled={!editable || saving} value={draft.status} onChange={(e) => { const status = e.target.value; if (status === "" || isAttendanceStatus(status)) setDrafts((value) => ({ ...value, [row.student_id]: { ...draft, status } })); }}><option value="">لم يسجل</option>{Object.entries(attendanceStatuses).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></td><td><input aria-label={`ملاحظة ${row.full_name}`} disabled={!editable || saving} value={draft.note} onChange={(e) => setDrafts((value) => ({ ...value, [row.student_id]: { ...draft, note: e.target.value } }))} /></td><td>{editable && <button className="button primary" disabled={saving || !draft.status} onClick={() => { const status = draft.status; if (status) void mutate(() => saveAttendance(selected.id, row, status, draft.note), "تم حفظ سجل الحضور.", true); }}>حفظ</button>}</td></tr>;
          })}
        </tbody></table></div>) : (!history.length ? <p className="muted">لا يوجد سجل حضور متاح.</p> : <div className="table-scroll"><table className="management-table"><thead><tr><th>معرّف الطالب</th><th>الحالة</th><th>ملاحظة</th></tr></thead><tbody>{history.map((record) => <tr key={record.id}><td>{record.student_id}</td><td>{attendanceStatuses[record.status]}</td><td>{record.note ?? "—"}</td></tr>)}</tbody></table></div>)}
      </>}
    </section>}
    {printing && selected && <AttendanceRegisterSheet
      session={selected}
      className={className(selected.class_id)}
      branchName={branchName(selected.branch_id)}
      entries={registerEntries}
      onClose={() => setPrinting(false)}
    />}
  </main>;
}
