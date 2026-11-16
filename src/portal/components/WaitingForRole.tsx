import logo from "../assets/saiLogo";

export function WaitingForRole({ email, emailConfirmed, busy, onRefresh, onSignOut }: {
  email: string | null;
  emailConfirmed: boolean;
  busy: boolean;
  onRefresh: () => void;
  onSignOut: () => void;
}) {
  return <main className="centered">
    <section className="auth-card waiting-card">
      <img className="brand-logo" src={logo} alt="شعار كلية ساي" />
      <p className="eyebrow">كلية ساي التعليمية اليمنية الصينية</p>
      <h1>{emailConfirmed ? "حسابك جاهز — بانتظار الدور" : "يلزم تأكيد البريد الإلكتروني"}</h1>
      {!emailConfirmed && <p className="notice" role="status">
        لم تُظهر جلسة المصادقة تأكيد البريد الإلكتروني بعد. أكّد البريد أولاً؛ ثم يمكن للإدارة مراجعة طلب الوصول.
      </p>}
      <p className="muted">
        {emailConfirmed
          ? "لا يظهر للحساب دور بوابة مسند حالياً. بعد اعتماد دورك من الإدارة ستظهر اللوحة عند تحديث بيانات الجلسة."
          : "الحساب موجود، لكن لا يمكن منح الدور قبل تأكيد البريد. لا تنشئ حساباً آخر."}
      </p>
      {email && <p className="waiting-email" dir="ltr">{email}</p>}
      <p className="data-note">«تحقق مرة أخرى» يعيد تحميل الجلسة والأدوار من الخادم دون تسجيل خروج أو طلب كلمة المرور.</p>
      <div className="waiting-actions">
        <button type="button" className="button primary" onClick={onRefresh} disabled={busy}>
          {busy ? "جارٍ التحقق..." : "تحقق مرة أخرى"}
        </button>
        <button type="button" className="button secondary" onClick={onSignOut} disabled={busy}>
          تسجيل الخروج
        </button>
      </div>
    </section>
  </main>;
}