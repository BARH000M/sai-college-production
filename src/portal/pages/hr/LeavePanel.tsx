import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "../../lib/supabase";
import { loadUnifiedBranches } from "../../lib/unifiedModules";

type Branch = { id: string; name: string };
type Employee = { id: string; title: string; employee_code: string };
type LeaveRequest = {
  id: string;
  employee_id: string;
  leave_type: string;
  starts_on: string;
  ends_on: string;
  days: number;
  reason: string | null;
  status: string;
  decision_note: string | null;
};

const LEAVE_TYPE_LABEL: Record<string, string> = {
  annual: "سنوية", sick: "مرضية", unpaid: "بدون راتب", maternity: "أمومة", emergency: "طارئة", other: "أخرى",
};
const STATUS_LABEL: Record<string, string> = {
  pending: "قيد المراجعة", approved: "معتمدة", rejected: "مرفوضة", cancelled: "ملغاة",
};

function formatDay(value: string): string {
  const date = new Date(`${value}T00:00:00`);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString("ar-EG", { dateStyle: "medium" });
}

export function LeavePanel({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const writable = roles.some((role) => role === "super_admin" || role === "admin");
  const [branches, setBranches] = useState<Branch[]>([]);
  const [branch, setBranch] = useState("");
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [requests, setRequests] = useState<LeaveRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [openForm, setOpenForm] = useState(false);
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [form, setForm] = useState({
    employee_id: "", leave_type: "annual", starts_on: "", ends_on: "", reason: "",
  });

  useEffect(() => {
    let active = true;
    void loadUnifiedBranches()
      .then((next) => {
        if (!active) return;
        setBranches(next);
        setBranch((current) => (next.some((item) => item.id === current) ? current : next[0]?.id ?? ""));
      })
      .catch((e: unknown) => { if (active) setError(e instanceof Error ? e.message : String(e)); });
    return () => { active = false; };
  }, []);

  const load = useCallback(async () => {
    if (!branch) { setRequests([]); setEmployees([]); setLoading(false); return; }
    setLoading(true);
    setError(null);
    try {
      const [employeeResult, requestResult] = await Promise.all([
        supabase.from("sai_hr_employees").select("id,title,employee_code")
          .eq("branch_id", branch).eq("employment_status", "active").order("title"),
        supabase.from("sai_hr_leave_requests")
          .select("id,employee_id,leave_type,starts_on,ends_on,days,reason,status,decision_note")
          .eq("branch_id", branch).order("starts_on", { ascending: false }).limit(200),
      ]);
      if (employeeResult.error) throw new Error(employeeResult.error.message);
      if (requestResult.error) throw new Error(requestResult.error.message);
      const nextEmployees = (employeeResult.data ?? []) as Employee[];
      setEmployees(nextEmployees);
      setRequests(((requestResult.data ?? []) as LeaveRequest[]).map((row) => ({ ...row, days: Number(row.days) })));
      setForm((current) => ({
        ...current,
        employee_id: nextEmployees.some((item) => item.id === current.employee_id) ? current.employee_id : (nextEmployees[0]?.id ?? ""),
      }));
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [branch]);

  useEffect(() => { void load(); }, [load]);

  const employeeById = useMemo(() => new Map(employees.map((item) => [item.id, item])), [employees]);
  const pending = requests.filter((row) => row.status === "pending");

  async function submit() {
    if (!form.employee_id) { setError("اختر الموظف."); return; }
    if (!form.starts_on || !form.ends_on) { setError("أدخل تاريخ البداية والنهاية."); return; }
    if (form.ends_on < form.starts_on) { setError("تاريخ النهاية يجب أن يكون بعد البداية."); return; }
    setBusy(true); setError(null); setNotice(null);
    try {
      const { error: insertError } = await supabase.from("sai_hr_leave_requests").insert({
        branch_id: branch,
        employee_id: form.employee_id,
        leave_type: form.leave_type,
        starts_on: form.starts_on,
        ends_on: form.ends_on,
        reason: form.reason || null,
        created_by: userId,
        updated_by: userId,
      });
      if (insertError) throw new Error(insertError.message);
      setNotice("تم تسجيل طلب الإجازة.");
      setOpenForm(false);
      setForm((current) => ({ ...current, starts_on: "", ends_on: "", reason: "" }));
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function decide(row: LeaveRequest, status: "approved" | "rejected") {
    const note = (notes[row.id] ?? "").trim();
    if (status === "rejected" && note.length < 3) { setError("أدخل سبباً للرفض (٣ أحرف على الأقل)."); return; }
    setBusy(true); setError(null); setNotice(null);
    try {
      const { error: updateError } = await supabase.from("sai_hr_leave_requests").update({
        status,
        decision_note: note || null,
        decided_by: userId,
        decided_at: new Date().toISOString(),
        updated_by: userId,
        updated_at: new Date().toISOString(),
      }).eq("id", row.id).eq("status", "pending");
      if (updateError) throw new Error(updateError.message);
      setNotice(status === "approved" ? "تم اعتماد الإجازة." : "تم رفض الإجازة.");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  return <section className="panel" style={{ marginTop: 18 }}>
    <div className="home-panel-head">
      <h2>طلبات الإجازة</h2>
      {writable && <button className="button" type="button" disabled={!employees.length} onClick={() => setOpenForm((v) => !v)}>
        {openForm ? "إغلاق النموذج" : "طلب إجازة جديد"}
      </button>}
    </div>

    <div className="actions" style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap", marginTop: 8 }}>
      <label htmlFor="leave-branch">الفرع</label>
      <select id="leave-branch" value={branch} onChange={(e) => setBranch(e.target.value)}>
        <option value="">اختر الفرع</option>
        {branches.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
      </select>
      <button className="button secondary" type="button" onClick={() => void load()} disabled={loading}>تحديث</button>
      <span className="data-note" style={{ margin: 0 }}>قيد المراجعة: {pending.length}</span>
    </div>

    {notice && <p role="status" className="data-note">{notice}</p>}
    {error && <p role="alert" className="error-box">{error}</p>}

    {openForm && writable && <div className="panel" style={{ marginTop: 14, display: "grid", gap: 10 }}>
      <div style={{ display: "grid", gap: 4 }}>
        <label htmlFor="leave-employee">الموظف</label>
        <select id="leave-employee" value={form.employee_id} onChange={(e) => setForm((v) => ({ ...v, employee_id: e.target.value }))}>
          <option value="">اختر الموظف</option>
          {employees.map((item) => <option key={item.id} value={item.id}>{item.title} — {item.employee_code}</option>)}
        </select>
      </div>
      <div style={{ display: "grid", gap: 4 }}>
        <label htmlFor="leave-type">نوع الإجازة</label>
        <select id="leave-type" value={form.leave_type} onChange={(e) => setForm((v) => ({ ...v, leave_type: e.target.value }))}>
          {Object.entries(LEAVE_TYPE_LABEL).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
        </select>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        <div style={{ display: "grid", gap: 4 }}>
          <label htmlFor="leave-start">من تاريخ</label>
          <input id="leave-start" type="date" value={form.starts_on} onChange={(e) => setForm((v) => ({ ...v, starts_on: e.target.value }))} />
        </div>
        <div style={{ display: "grid", gap: 4 }}>
          <label htmlFor="leave-end">إلى تاريخ</label>
          <input id="leave-end" type="date" value={form.ends_on} onChange={(e) => setForm((v) => ({ ...v, ends_on: e.target.value }))} />
        </div>
      </div>
      <div style={{ display: "grid", gap: 4 }}>
        <label htmlFor="leave-reason">السبب</label>
        <textarea id="leave-reason" maxLength={500} value={form.reason} onChange={(e) => setForm((v) => ({ ...v, reason: e.target.value }))} />
      </div>
      <div className="actions" style={{ display: "flex", gap: 8 }}>
        <button className="button" type="button" disabled={busy} onClick={() => void submit()}>تسجيل الطلب</button>
        <button className="button secondary" type="button" onClick={() => setOpenForm(false)}>إلغاء</button>
      </div>
    </div>}

    {loading && <p role="status">جارٍ تحميل الطلبات...</p>}
    {!loading && !requests.length && <p className="data-note">لا توجد طلبات إجازة مسجلة لهذا الفرع.</p>}

    {!loading && !!requests.length && <div className="table-scroll" style={{ marginTop: 14 }}>
      <table className="management-table">
        <thead>
          <tr><th>الموظف</th><th>النوع</th><th>الفترة</th><th>الأيام</th><th>الحالة</th><th>ملاحظة القرار</th></tr>
        </thead>
        <tbody>
          {requests.map((row) => {
            const employee = employeeById.get(row.employee_id);
            const isPending = row.status === "pending";
            return <tr key={row.id}>
              <td>{employee ? `${employee.title} — ${employee.employee_code}` : "موظف محذوف"}</td>
              <td>{LEAVE_TYPE_LABEL[row.leave_type] ?? row.leave_type}</td>
              <td dir="ltr">{formatDay(row.starts_on)} → {formatDay(row.ends_on)}</td>
              <td>{row.days}</td>
              <td><span className={`hr-status hr-status-${row.status}`}>{STATUS_LABEL[row.status] ?? row.status}</span></td>
              <td>
                {isPending && writable
                  ? <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                      <input className="input" placeholder="ملاحظة" value={notes[row.id] ?? ""}
                        style={{ maxWidth: 150 }}
                        onChange={(e) => setNotes((current) => ({ ...current, [row.id]: e.target.value }))} />
                      <button className="button" type="button" disabled={busy} onClick={() => void decide(row, "approved")}>اعتماد</button>
                      <button className="button secondary" type="button" disabled={busy} onClick={() => void decide(row, "rejected")}>رفض</button>
                    </div>
                  : (row.decision_note ?? "—")}
              </td>
            </tr>;
          })}
        </tbody>
      </table>
    </div>}

    <p className="data-note" style={{ marginTop: 12 }}>
      عدد الأيام يُحسب تلقائياً من تاريخي البداية والنهاية. الطلب المعتمد أو المرفوض لا يمكن إعادة تعديله من هنا
      (تُشترط حالة «قيد المراجعة» عند القرار) للحفاظ على سلامة السجل.
    </p>
  </section>;
}