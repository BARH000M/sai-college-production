import { useEffect, useState } from "react";
import {
  loadLinkableAccounts, linkStudentAccount, unlinkStudentAccount, type LinkableAccount,
} from "@/portal/lib/studentAccounts";

const msg = (error: unknown) => (error instanceof Error ? error.message : String(error));

export function StudentAccountLink({
  studentId, currentUserId, onChanged,
}: {
  studentId: string;
  currentUserId: string | null;
  onChanged: () => void;
}) {
  const [open, setOpen] = useState(false);
  const [accounts, setAccounts] = useState<LinkableAccount[]>([]);
  const [selected, setSelected] = useState("");
  const [loading, setLoading] = useState(false);
  const [working, setWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    let active = true;
    setLoading(true);
    setError(null);
    loadLinkableAccounts()
      .then((rows) => { if (active) setAccounts(rows); })
      .catch((failure: unknown) => { if (active) setError(msg(failure)); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [open]);

  const linkedAccount = accounts.find((a) => a.id === currentUserId);
  // Accounts available to attach: not linked to any other student.
  const selectable = accounts.filter((a) => !a.linkedStudentId || a.linkedStudentId === studentId);

  async function doLink() {
    if (!selected || working) return;
    setWorking(true); setError(null); setSuccess(null);
    try {
      const email = await linkStudentAccount(studentId, selected);
      setSuccess(`تم ربط الحساب${email ? ` (${email})` : ""} ومنحه دور الطالب.`);
      setSelected("");
      onChanged();
    } catch (failure) { setError(msg(failure)); }
    finally { setWorking(false); }
  }

  async function doUnlink() {
    if (working || !window.confirm("هل تريد فك ربط حساب الدخول عن هذا الطالب؟")) return;
    setWorking(true); setError(null); setSuccess(null);
    try {
      await unlinkStudentAccount(studentId);
      setSuccess("تم فك ربط الحساب عن الطالب.");
      onChanged();
    } catch (failure) { setError(msg(failure)); }
    finally { setWorking(false); }
  }

  return <div className="account-link">
    <div className="account-link-head">
      <div>
        <strong>حساب الدخول المرتبط</strong>
        <p className="muted">
          {currentUserId
            ? `مرتبط${linkedAccount ? ` · ${linkedAccount.email || linkedAccount.fullName}` : ` (${currentUserId})`}`
            : "لا يوجد حساب دخول مرتبط بهذا الطالب."}
        </p>
      </div>
      <div className="actions">
        {!open && <button className="button secondary" type="button" onClick={() => { setOpen(true); setSuccess(null); setError(null); }}>
          {currentUserId ? "تغيير الحساب المرتبط" : "ربط حساب دخول"}
        </button>}
        {currentUserId && <button className="button secondary" type="button" disabled={working} onClick={() => void doUnlink()}>فك الربط</button>}
      </div>
    </div>

    {open && <div className="account-link-picker">
      {loading && <p role="status">جارٍ تحميل الحسابات...</p>}
      {error && <p className="error-box" role="alert">{error}</p>}
      {!loading && !error && <>
        {!selectable.length && <p className="notice">
          لا يوجد حساب جاهز للربط. أنشئ حساب دخول للطالب من صفحة «الأدوار» ← «حسابات بوابة التعلّم»
          بزر «حساب طالب»؛ فهي تُنشئ الحساب وتربطه بالسجل وتُمنحه دور الطالب في خطوة واحدة.
        </p>}
        <label>اختر حساب الدخول
          <select value={selected} onChange={(e) => setSelected(e.target.value)} disabled={working}>
            <option value="">— اختر حساباً —</option>
            {selectable.map((a) => <option key={a.id} value={a.id}>
              {(a.fullName || a.email || a.id)}{a.email ? ` · ${a.email}` : ""}{a.roles.length ? ` [${a.roles.join(", ")}]` : ""}
            </option>)}
          </select>
        </label>
        <p className="muted">سيُمنح الحساب دور «الطالب» تلقائياً عند الربط دون الحاجة لتعديل قاعدة البيانات.</p>
        <div className="actions">
          <button className="button primary" type="button" disabled={!selected || working} onClick={() => void doLink()}>
            {working ? "جارٍ الربط..." : "ربط الحساب"}
          </button>
          <button className="button secondary" type="button" disabled={working} onClick={() => { setOpen(false); setSelected(""); }}>إلغاء</button>
        </div>
      </>}
    </div>}

    {success && <p className="success-box" role="status">{success}</p>}
  </div>;
}