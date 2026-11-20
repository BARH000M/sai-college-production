import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "../../lib/supabase";
import { loadUnifiedBranches } from "../../lib/unifiedModules";

type Branch = { id: string; name: string };
type Employee = { id: string; title: string; employee_code: string; department: string };
type Entry = {
  id: string;
  employee_id: string;
  period_month: string;
  base_salary: number;
  allowances: number;
  deductions: number;
  net_amount: number;
  status: string;
};
type Draft = { base_salary: string; allowances: string; deductions: string };

const STATUS_LABEL: Record<string, string> = { draft: "مسودة", approved: "معتمد", paid: "مصروف" };

function currentMonth(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

function toNumber(value: string): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
}

function money(value: number): string {
  return Number(value).toLocaleString("ar-EG", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export function PayrollPanel({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const writable = roles.some((role) => role === "super_admin" || role === "admin");
  const [branches, setBranches] = useState<Branch[]>([]);
  const [branch, setBranch] = useState("");
  const [month, setMonth] = useState(currentMonth);
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [entries, setEntries] = useState<Entry[]>([]);
  const [drafts, setDrafts] = useState<Record<string, Draft>>({});
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

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
    if (!branch) { setEntries([]); setEmployees([]); setLoading(false); return; }
    setLoading(true);
    setError(null);
    try {
      const [employeeResult, entryResult] = await Promise.all([
        supabase.from("sai_hr_employees")
          .select("id,title,employee_code,department")
          .eq("branch_id", branch).eq("employment_status", "active").order("title"),
        supabase.from("sai_hr_payroll_entries")
          .select("id,employee_id,period_month,base_salary,allowances,deductions,net_amount,status")
          .eq("branch_id", branch).eq("period_month", `${month}-01`).order("created_at"),
      ]);
      if (employeeResult.error) throw new Error(employeeResult.error.message);
      if (entryResult.error) throw new Error(entryResult.error.message);
      const nextEmployees = (employeeResult.data ?? []) as Employee[];
      const nextEntries = ((entryResult.data ?? []) as Entry[]).map((row) => ({
        ...row,
        base_salary: Number(row.base_salary),
        allowances: Number(row.allowances),
        deductions: Number(row.deductions),
        net_amount: Number(row.net_amount),
      }));
      setEmployees(nextEmployees);
      setEntries(nextEntries);
      setDrafts(Object.fromEntries(nextEntries.map((row) => [row.id, {
        base_salary: String(row.base_salary),
        allowances: String(row.allowances),
        deductions: String(row.deductions),
      }])));
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [branch, month]);

  useEffect(() => { void load(); }, [load]);

  const employeeById = useMemo(() => new Map(employees.map((item) => [item.id, item])), [employees]);
  const covered = useMemo(() => new Set(entries.map((row) => row.employee_id)), [entries]);
  const missing = employees.filter((item) => !covered.has(item.id));
  const draftTotal = entries.reduce((sum, row) => {
    const draft = drafts[row.id];
    if (!draft) return sum + row.net_amount;
    return sum + toNumber(draft.base_salary) + toNumber(draft.allowances) - toNumber(draft.deductions);
  }, 0);
  const pendingCount = entries.filter((row) => row.status === "draft").length;

  async function generate() {
    if (!missing.length) return;
    setBusy(true); setError(null); setNotice(null);
    try {
      const stamp = userId;
      const payload = missing.map((employee) => ({
        branch_id: branch,
        employee_id: employee.id,
        period_month: `${month}-01`,
        base_salary: 0,
        allowances: 0,
        deductions: 0,
        status: "draft",
        created_by: stamp,
        updated_by: stamp,
      }));
      const { error: insertError } = await supabase.from("sai_hr_payroll_entries").insert(payload);
      if (insertError) throw new Error(insertError.message);
      setNotice(`تم توليد ${payload.length} صفاً في مسودة المسير. أدخل المبالغ ثم احفظ.`);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function saveDrafts() {
    const changed = entries.filter((row) => {
      const draft = drafts[row.id];
      if (!draft) return false;
      return toNumber(draft.base_salary) !== row.base_salary
        || toNumber(draft.allowances) !== row.allowances
        || toNumber(draft.deductions) !== row.deductions;
    });
    if (!changed.length) { setNotice("لا توجد تغييرات لحفظها."); return; }
    setBusy(true); setError(null); setNotice(null);
    try {
      for (const row of changed) {
        const draft = drafts[row.id];
        const { error: updateError } = await supabase.from("sai_hr_payroll_entries")
          .update({
            base_salary: toNumber(draft.base_salary),
            allowances: toNumber(draft.allowances),
            deductions: toNumber(draft.deductions),
            updated_by: userId,
            updated_at: new Date().toISOString(),
          })
          .eq("id", row.id);
        if (updateError) throw new Error(updateError.message);
      }
      setNotice(`تم حفظ ${changed.length} سجلاً.`);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  async function advance(target: "approved" | "paid") {
    const from = target === "approved" ? "draft" : "approved";
    setBusy(true); setError(null); setNotice(null);
    try {
      const { error: updateError } = await supabase.from("sai_hr_payroll_entries")
        .update({ status: target, updated_by: userId, updated_at: new Date().toISOString() })
        .eq("branch_id", branch).eq("period_month", `${month}-01`).eq("status", from);
      if (updateError) throw new Error(updateError.message);
      setNotice(target === "approved" ? "تم اعتماد المسير." : "تم تسجيل صرف المسير.");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }

  return <section className="panel" style={{ marginTop: 18 }}>
    <div className="home-panel-head">
      <h2>كشف رواتب الشهر</h2>
      {writable && <div className="actions" style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <button className="button secondary" type="button" disabled={busy || !missing.length} onClick={() => void generate()}>
          توليد المسير{missing.length ? ` (${missing.length})` : ""}
        </button>
        <button className="button secondary" type="button" disabled={busy || !entries.length} onClick={() => void saveDrafts()}>حفظ المبالغ</button>
        <button className="button" type="button" disabled={busy || !pendingCount} onClick={() => void advance("approved")}>اعتماد المسير</button>
        <button className="button secondary" type="button" disabled={busy} onClick={() => void advance("paid")}>تسجيل الصرف</button>
      </div>}
    </div>

    <div className="actions" style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap", marginTop: 8 }}>
      <label htmlFor="payroll-branch">الفرع</label>
      <select id="payroll-branch" value={branch} onChange={(e) => setBranch(e.target.value)}>
        <option value="">اختر الفرع</option>
        {branches.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
      </select>
      <label htmlFor="payroll-month">الشهر</label>
      <input id="payroll-month" type="month" value={month} onChange={(e) => setMonth(e.target.value || currentMonth())} />
      <button className="button secondary" type="button" onClick={() => void load()} disabled={loading}>تحديث</button>
    </div>

    {notice && <p role="status" className="data-note">{notice}</p>}
    {error && <p role="alert" className="error-box">{error}</p>}
    {loading && <p role="status">جارٍ تحميل المسير...</p>}

    {!loading && branch && !employees.length && <p className="data-note">لا يوجد موظفون نشطون في هذا الفرع بعد. أضفهم من تبويب دليل الموظفين.</p>}

    {!loading && !!entries.length && <div className="table-scroll" style={{ marginTop: 14 }}>
      <table className="management-table">
        <thead>
          <tr>
            <th>الموظف</th><th>القسم</th><th>الأساسي</th><th>البدلات</th><th>الاستقطاعات</th><th>الصافي</th><th>الحالة</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((row) => {
            const employee = employeeById.get(row.employee_id);
            const draft = drafts[row.id] ?? { base_salary: "0", allowances: "0", deductions: "0" };
            const net = toNumber(draft.base_salary) + toNumber(draft.allowances) - toNumber(draft.deductions);
            const editable = writable && row.status === "draft";
            const setField = (key: keyof Draft, value: string) => setDrafts((current) => ({ ...current, [row.id]: { ...draft, [key]: value } }));
            return <tr key={row.id}>
              <td>{employee ? `${employee.title} — ${employee.employee_code}` : "موظف محذوف"}</td>
              <td>{employee?.department ?? "—"}</td>
              {(["base_salary", "allowances", "deductions"] as const).map((key) => <td key={key}>
                {editable
                  ? <input className="input" type="number" min={0} step="0.01" value={draft[key]} aria-label={key}
                      style={{ maxWidth: 110 }} onChange={(e) => setField(key, e.target.value)} />
                  : money(toNumber(String(row[key])))}
              </td>)}
              <td><strong>{money(net)}</strong></td>
              <td><span className={`hr-status hr-status-${row.status}`}>{STATUS_LABEL[row.status] ?? row.status}</span></td>
            </tr>;
          })}
        </tbody>
        <tfoot>
          <tr>
            <td colSpan={5}><strong>إجمالي صافي المسير</strong></td>
            <td colSpan={2}><strong>{money(draftTotal)}</strong></td>
          </tr>
        </tfoot>
      </table>
    </div>}

    <p className="data-note" style={{ marginTop: 12 }}>
      الصافي يُحسب في قاعدة البيانات كعمود محسوب (الأساسي + البدلات − الاستقطاعات) ولا يمكن تخزين قيمة مختلفة عنه.
      اعتماد المسير يثبّت الصفوف، وتسجيل الصرف يؤرشفها.
    </p>
  </section>;
}