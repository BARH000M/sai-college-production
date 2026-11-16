import { useEffect, useState } from "react";
import {
  loadLinkableAccounts,
  loadParentStudentLinks,
  verifyParentStudent,
  type LinkableAccount,
  type ParentStudentLink,
} from "@/portal/lib/studentAccounts";

const errorText = (error: unknown) => error instanceof Error ? error.message : String(error);

export function StudentParentLink({
  studentId,
  canVerify,
}: {
  studentId: string;
  canVerify: boolean;
}) {
  const [accounts, setAccounts] = useState<LinkableAccount[]>([]);
  const [links, setLinks] = useState<ParentStudentLink[]>([]);
  const [selected, setSelected] = useState("");
  const [verified, setVerified] = useState(false);
  const [loading, setLoading] = useState(true);
  const [working, setWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    Promise.all([loadLinkableAccounts(), loadParentStudentLinks(studentId)])
      .then(([users, parentLinks]) => {
        if (active) {
          setAccounts(users);
          setLinks(parentLinks);
        }
      })
      .catch((failure: unknown) => {
        if (active) setError(errorText(failure));
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => { active = false; };
  }, [studentId, retry]);

  const parents = accounts.filter((account) => account.roles.includes("parent"));
  const alreadyVerified = new Set(links.filter((link) => link.is_verified).map((link) => link.parent_user_id));

  async function submit() {
    if (!selected || !verified || working || !canVerify) return;
    setWorking(true);
    setError(null);
    setSuccess(null);
    try {
      await verifyParentStudent(studentId, selected);
      setSuccess("تم توثيق العلاقة وربط حساب ولي الأمر بالسجل.");
      setSelected("");
      setVerified(false);
      setRetry((value) => value + 1);
    } catch (failure) {
      setError(errorText(failure));
    } finally {
      setWorking(false);
    }
  }

  return (
    <section className="account-link" aria-label="ربط حساب ولي الأمر">
      <div className="account-link-head">
        <div>
          <strong>حسابات أولياء الأمور المرتبطة</strong>
          <p className="muted">لا يمكن لولي الأمر الاطلاع على هذا السجل حتى يتحقق موظف مخوّل من العلاقة.</p>
        </div>
        <button className="button secondary" type="button" disabled={loading || working} onClick={() => setRetry((value) => value + 1)}>
          تحديث
        </button>
      </div>

      {loading && <p role="status">جارٍ تحميل الروابط والحسابات الموثقة...</p>}
      {error && <p className="error-box" role="alert">{error}</p>}
      {!loading && !error && (
        <>
          {links.length > 0 && (
            <ul>
              {links.map((link) => (
                <li key={link.parent_user_id}>
                  {link.full_name}{link.email ? ` · ${link.email}` : ""}
                  {link.is_verified ? " · موثق" : " · غير موثق"}
                </li>
              ))}
            </ul>
          )}
          {canVerify && (
            <div className="account-link-picker">
              <label>
                اختر حساب ولي الأمر
                <select value={selected} onChange={(event) => setSelected(event.target.value)} disabled={working}>
                  <option value="">— اختر حسابًا موثقًا —</option>
                  {parents.filter((parent) => !alreadyVerified.has(parent.id)).map((parent) => (
                    <option key={parent.id} value={parent.id}>
                      {parent.fullName || parent.email || parent.id}{parent.email ? ` · ${parent.email}` : ""}
                    </option>
                  ))}
                </select>
              </label>
              <label className="inline-flex items-start gap-2">
                <input type="checkbox" checked={verified} onChange={(event) => setVerified(event.target.checked)} disabled={working} />
                <span>أؤكد أنني تحققت من هوية ولي الأمر وعلاقته بهذا الطالب قبل اعتماد الربط.</span>
              </label>
              <button className="button primary" type="button" disabled={!selected || !verified || working} onClick={() => void submit()}>
                {working ? "جارٍ التوثيق..." : "توثيق وربط الحساب"}
              </button>
            </div>
          )}
        </>
      )}
      {success && <p className="success-box" role="status">{success}</p>}
    </section>
  );
}
