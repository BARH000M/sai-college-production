import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../lib/supabase";

type BackupRun = {
  id: string;
  provider: string;
  kind: string;
  status: string;
  retention_class: string;
  size_bytes: number | null;
  checksum: string | null;
  location: string | null;
  requested_by: string | null;
  started_at: string;
  finished_at: string | null;
  error: string | null;
  note: string | null;
  created_at: string;
};

type ListResponse = { ok?: boolean; runs?: BackupRun[]; message?: string };

function formatBytes(value: number | null): string {
  if (!value || value <= 0) return "—";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let size = value;
  let unit = 0;
  while (size >= 1024 && unit < units.length - 1) { size /= 1024; unit += 1; }
  return `${size.toFixed(1)} ${units[unit]}`;
}

function formatDate(value: string | null): string {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "—" : date.toLocaleString("ar-EG", { dateStyle: "medium", timeStyle: "short" });
}

const statusLabel: Record<string, string> = {
  requested: "مطلوبة",
  running: "قيد التنفيذ",
  completed: "مكتملة",
  failed: "فاشلة",
  verified: "مُتحقَّق منها",
};

function statusTone(status: string): string {
  if (status === "completed" || status === "verified") return "ok";
  if (status === "failed") return "bad";
  return "pending";
}

export function BackupManager({ roles }: { roles: readonly string[] }) {
  const isSuper = roles.includes("super_admin");
  const [runs, setRuns] = useState<BackupRun[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const call = useCallback(async (body: Record<string, unknown>) => {
    const { data, error: invokeError } = await supabase.functions.invoke<ListResponse>("backup-manager", { body });
    if (invokeError) throw new Error(invokeError.message);
    if (!data || data.ok !== true) throw new Error(data?.message ?? "تعذر تنفيذ الطلب.");
    return data;
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await call({ action: "list" });
      setRuns(data.runs ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [call]);

  useEffect(() => { void load(); }, [load]);

  async function run(action: string, body: Record<string, unknown> = {}, success: string) {
    setBusy(action);
    setError(null);
    setNotice(null);
    try {
      await call({ action, ...body });
      setNotice(success);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(null);
    }
  }

  async function download(location: string | null) {
    if (!location) { setError("هذه النسخة لا تحتوي مساراً قابلاً للتنزيل (نسخة قاعدة بيانات يسجّلها العامل الخارجي)."); return; }
    setBusy(`dl-${location}`);
    setError(null);
    try {
      const data = await call({ action: "sign-download", path: location });
      const url = (data as { url?: string }).url;
      if (!url) throw new Error("تعذر إنشاء رابط التنزيل.");
      window.open(url, "_blank", "noopener,noreferrer");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(null);
    }
  }

  async function requestRestore(backup: BackupRun) {
    if (!window.confirm("سيتم تسجيل طلب استعادة بمراجعة بشرية. لن تُطبَّق أي استعادة تلقائياً على الإنتاج. متابعة؟")) return;
    await run("request-restore", { backupId: backup.id, note: `طلب استعادة للنسخة ${backup.id}` }, "تم تسجيل طلب الاستعادة للمراجعة.");
  }

  if (!isSuper) {
    return <main className="workspace"><section className="panel">
      <h1>النسخ الاحتياطي والاستعادة</h1>
      <p role="alert">هذه الشاشة متاحة للمسؤول العام فقط.</p>
      <Link className="button secondary" to="/portal/dashboard">العودة للرئيسية</Link>
    </section></main>;
  }

  const completed = runs.filter((r) => r.status === "completed" || r.status === "verified");
  const failed = runs.filter((r) => r.status === "failed");
  const lastCompleted = completed[0] ?? null;
  const totalBytes = runs.reduce((sum, r) => sum + (r.size_bytes ?? 0), 0);

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">الإدارة العامة · الحماية والاستعادة</p>
        <h1>النسخ الاحتياطي والتعافي من الكوارث</h1>
        <p className="muted">تنسيق النسخ، حالة العمليات، والتنزيل الآمن. النسخ الكاملة لقاعدة البيانات تُنفَّذ بواسطة عامل pg_dump آمن خارجي.</p>
      </div>
      <div className="actions">
        <button className="button secondary" type="button" onClick={() => void load()} disabled={loading}>تحديث القائمة</button>
        <Link className="button secondary" to="/portal/modules/settings">إعدادات النظام</Link>
      </div>
    </div>

    <section className="panel">
      <div className="home-panel-head">
        <h2>طلب نسخ جديدة</h2>
      </div>
      <p className="data-note">
        «نسخة قاعدة البيانات» تُسجَّل كطلب ويُنفّذها عامل pg_dump الآمن المجدول (GitHub Actions) مع تشفير وضغط ورفع لمساحة خاصة.
        «نسخ كائنات التخزين» يُنفَّذ فعلياً الآن عبر الدالة الآمنة إلى حاوية نسخ خاصة. لا تُنفَّذ أي استعادة تلقائية على الإنتاج.
      </p>
      <div className="actions" style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
        <button className="button" type="button" disabled={busy !== null}
          onClick={() => void run("request", {}, "سُجّل طلب نسخة قاعدة بيانات؛ سينفّذها العامل المجدول.")}>
          {busy === "request" ? "جارٍ التسجيل..." : "طلب نسخة قاعدة بيانات"}
        </button>
        <button className="button secondary" type="button" disabled={busy !== null}
          onClick={() => void run("run-storage", {}, "اكتملت نسخة كائنات التخزين إلى الحاوية الخاصة.")}>
          {busy === "run-storage" ? "جارٍ نسخ التخزين..." : "نسخ كائنات التخزين الآن"}
        </button>
      </div>
      {notice && <p role="status" style={{ marginTop: 12 }}>{notice}</p>}
      {error && <p className="error-box" role="alert" style={{ marginTop: 12 }}>{error}</p>}
    </section>

    <div className="kpi-grid home-kpi-grid" style={{ marginTop: 16 }}>
      <div className="kpi-card"><span>إجمالي العمليات</span><strong>{runs.length}</strong><small>نسخ وطلبات استعادة</small></div>
      <div className="kpi-card"><span>نسخ مكتملة</span><strong>{completed.length}</strong><small>جاهزة</small></div>
      <div className="kpi-card"><span>عمليات فاشلة</span><strong>{failed.length}</strong><small>تحتاج مراجعة</small></div>
      <div className="kpi-card"><span>آخر نسخة ناجحة</span><strong style={{ fontSize: 18 }}>{lastCompleted ? formatDate(lastCompleted.finished_at ?? lastCompleted.created_at) : "—"}</strong><small>الحجم الكلي {formatBytes(totalBytes)}</small></div>
    </div>

    <section className="panel" style={{ marginTop: 16 }}>
      <div className="home-panel-head">
        <h2>سجل النسخ والاستعادة</h2>
      </div>
      {loading && <p role="status">جارٍ تحميل سجل النسخ...</p>}
      {!loading && !runs.length && <p className="data-note">لا توجد عمليات نسخ بعد. ابدأ بطلب نسخة أو نسخ التخزين.</p>}
      {!loading && !!runs.length && <div className="table-scroll">
        <table className="management-table">
          <thead>
            <tr>
              <th>التاريخ</th><th>النوع</th><th>المصدر</th><th>الحالة</th><th>الحجم</th><th>البصمة</th><th>إجراءات</th>
            </tr>
          </thead>
          <tbody>
            {runs.map((row) => <tr key={row.id}>
              <td>
                <strong>{formatDate(row.created_at)}</strong>
                {row.finished_at && <small className="learn-meta">اكتملت {formatDate(row.finished_at)}</small>}
              </td>
              <td>{row.kind === "storage" ? "تخزين" : row.kind === "restore" ? "استعادة" : "قاعدة بيانات"}</td>
              <td>{row.provider}</td>
              <td>
                <span style={{ display: "inline-block", padding: "2px 8px", borderRadius: 6, fontSize: 12, fontWeight: 600, ...(statusTone(row.status) === "ok" ? { background: "#e7f6ec", color: "#1a7f37" } : statusTone(row.status) === "bad" ? { background: "#fde8e8", color: "#b42318" } : { background: "#fff4e5", color: "#b25e09" }) }}>{statusLabel[row.status] ?? row.status}</span>
                {row.error && <small className="learn-meta" style={{ display: "block", color: "#b42318" }}>{row.error.slice(0, 120)}</small>}
              </td>
              <td dir="ltr">{formatBytes(row.size_bytes)}</td>
              <td dir="ltr" style={{ fontFamily: "monospace", fontSize: 12 }}>{row.checksum ? `${row.checksum.slice(0, 12)}…` : "—"}</td>
              <td>
                <div className="actions" style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                  {row.kind === "storage" && row.location && <button className="button secondary" type="button"
                    disabled={busy !== null} onClick={() => void download(row.location)}>تنزيل</button>}
                  {row.kind !== "restore" && <button className="button secondary" type="button"
                    disabled={busy !== null} onClick={() => void requestRestore(row)}>طلب استعادة</button>}
                </div>
              </td>
            </tr>)}
          </tbody>
        </table>
      </div>}
      <p className="data-note" style={{ marginTop: 14 }}>
        النسخ الكاملة لقاعدة البيانات (pg_dump) وPITR تُدار على مستوى Supabase؛ هذه اللوحة تتتبع الطلبات والعمليات وتضمن تسجيل الأحداث في سجل التدقيق.
        الاستعادة تتطلب مراجعة بشرية وتنفيذاً على بيئة معزولة قبل الإنتاج.
      </p>
    </section>

    <p><Link to="/portal/dashboard">العودة للرئيسية</Link></p>
  </main>;
}