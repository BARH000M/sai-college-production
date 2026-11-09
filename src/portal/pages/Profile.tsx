import { useEffect, useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { loadMyProfile, saveMyProfile, type ProfileRecord } from "../lib/profile";
import { isAppRole, roleLabels } from "../lib/navigation";

type State =
  | { status: "loading"; record: null; error: null }
  | { status: "ready"; record: ProfileRecord | null; error: null }
  | { status: "error"; record: null; error: string };

const failure = (error: unknown) => (error instanceof Error ? error.message : String(error));

export function Profile({ userId, email, roles }: {
  userId: string; email: string | null; roles: readonly string[];
}) {
  const [state, setState] = useState<State>({ status: "loading", record: null, error: null });
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [locale, setLocale] = useState<"ar" | "en">("ar");
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [saved, setSaved] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setState({ status: "loading", record: null, error: null });
    loadMyProfile(userId)
      .then((record) => {
        if (!active) return;
        setState({ status: "ready", record, error: null });
        if (record) {
          setFullName(record.fullName);
          setPhone(record.phone ?? "");
          setLocale(record.locale);
        }
      })
      .catch((error: unknown) => {
        if (active) setState({ status: "error", record: null, error: failure(error) });
      });
    return () => { active = false; };
  }, [userId, retry]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (saving) return;
    setSaving(true);
    setFormError(null);
    setSaved(null);
    try {
      await saveMyProfile(userId, { fullName, phone, locale });
      setSaved("تم حفظ ملفك الشخصي.");
      setRetry((value) => value + 1);
    } catch (error) {
      setFormError(failure(error));
    } finally {
      setSaving(false);
    }
  }

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">حسابي</p>
        <h1>ملفي الشخصي</h1>
        <p className="muted">حدّث اسمك ورقم هاتفك واللغة المفضلة للتنبيهات.</p>
      </div>
      <Link className="button secondary" to="/portal/dashboard">العودة للرئيسية</Link>
    </div>

    <section className="panel">
      <h2>بيانات الحساب</h2>
      <p className="data-note">يُستخدم بريدك الإلكتروني لتسجيل الدخول ولا يمكن تغييره من هنا.</p>
      <dl className="management-detail">
        <div><dt>البريد الإلكتروني</dt><dd dir="ltr">{email ?? "—"}</dd></div>
        <div>
          <dt>الأدوار</dt>
          <dd>
            <div className="role-chips">
              {roles.filter(isAppRole).length
                ? roles.filter(isAppRole).map((role) => <span className="role-chip" key={role}>{roleLabels[role]}</span>)
                : <span className="muted">لا توجد أدوار بعد</span>}
            </div>
          </dd>
        </div>
      </dl>
    </section>

    {state.status === "loading" && <p role="status">جارٍ تحميل ملفك الشخصي...</p>}
    {state.status === "error" && <p className="error-box" role="alert">
      تعذر تحميل الملف الشخصي: {state.error}
      <button type="button" className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button>
    </p>}

    {state.status === "ready" && <section className="panel">
      <h2>تعديل البيانات</h2>
      <form className="management-form" onSubmit={(event) => void submit(event)}>
        <label>الاسم الكامل
          <input value={fullName} onChange={(event) => setFullName(event.target.value)} autoComplete="name" required />
        </label>
        <label>رقم الهاتف
          <input value={phone} onChange={(event) => setPhone(event.target.value)} type="tel" dir="ltr" autoComplete="tel" placeholder="+967 7xx xxx xxx" />
        </label>
        <label>اللغة المفضلة
          <select value={locale} onChange={(event) => setLocale(event.target.value === "en" ? "en" : "ar")}>
            <option value="ar">العربية</option>
            <option value="en">English</option>
          </select>
        </label>
        {formError && <p className="error-box" role="alert">{formError}</p>}
        {saved && <p className="success-box" role="status">{saved}</p>}
        <div className="actions">
          <button className="button primary" disabled={saving}>{saving ? "جارٍ الحفظ..." : "حفظ التغييرات"}</button>
          <Link className="button secondary" to="/portal/dashboard">إلغاء</Link>
        </div>
      </form>
    </section>}
  </main>;
}

export default Profile;