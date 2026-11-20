import { useCallback, useEffect, useState } from "react";
import { supabase } from "../../lib/supabase";

type AuditRow = {
  id: string;
  actor_user_id: string | null;
  action: string;
  entity_type: string | null;
  entity_id: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
};

function formatDate(value: string): string {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "—" : date.toLocaleString("ar-EG", { dateStyle: "medium", timeStyle: "short" });
}

export function AuditLogPanel({ roles }: { roles: readonly string[] }) {
  const canView = roles.includes("super_admin");
  const [rows, setRows] = useState<AuditRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState("");

  const load = useCallback(async () => {
    if (!canView) { setLoading(false); return; }
    setLoading(true);
    setError(null);
    try {
      const { data, error: queryError } = await supabase
        .from("audit_logs")
        .select("id,actor_user_id,action,entity_type,entity_id,metadata,created_at")
        .order("created_at", { ascending: false })
        .limit(150);
      if (queryError) throw new Error(queryError.message);
      setRows((data ?? []) as AuditRow[]);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [canView]);

  useEffect(() => { void load(); }, [load]);

  if (!canView) return null;

  const term = filter.trim().toLowerCase();
  const visible = term
    ? rows.filter((row) => `${row.action} ${row.entity_type ?? ""} ${JSON.stringify(row.metadata ?? "")}`.toLowerCase().includes(term))
    : rows;

  return <section className="panel" style={{ marginTop: 20 }}>
    <div className="home-panel-head">
      <h2>سجل التدقيق</h2>
      <button className="button secondary" type="button" onClick={() => void load()} disabled={loading}>تحديث</button>
    </div>
    <p className="data-note">آخر 150 حدثاً مسجلاً في سجل التدقيق الموحد. السجل للقراءة فقط ولا يمكن تعديله من الواجهة.</p>
    <input
      className="input"
      type="search"
      placeholder="بحث في نوع الإجراء أو الكيان..."
      value={filter}
      onChange={(e) => setFilter(e.target.value)}
      aria-label="تصفية سجل التدقيق"
      style={{ marginBlock: 12, maxWidth: 360 }}
    />
    {loading && <p role="status">جارٍ تحميل السجل...</p>}
    {error && <p className="error-box" role="alert">{error}</p>}
    {!loading && !visible.length && <p className="data-note">لا توجد أحداث مطابقة.</p>}
    {!loading && !!visible.length && <div className="table-scroll">
      <table className="management-table">
        <thead>
          <tr><th>التاريخ</th><th>الإجراء</th><th>الكيان</th><th>المستخدم</th><th>تفاصيل</th></tr>
        </thead>
        <tbody>
          {visible.map((row) => <tr key={row.id}>
            <td dir="ltr">{formatDate(row.created_at)}</td>
            <td><code>{row.action}</code></td>
            <td>{row.entity_type ?? "—"}</td>
            <td dir="ltr" style={{ fontSize: 12 }}>{row.actor_user_id ? `${row.actor_user_id.slice(0, 8)}…` : "نظام"}</td>
            <td dir="ltr" style={{ fontSize: 12, fontFamily: "monospace" }}>{row.metadata ? JSON.stringify(row.metadata).slice(0, 120) : "—"}</td>
          </tr>)}
        </tbody>
      </table>
    </div>}
  </section>;
}