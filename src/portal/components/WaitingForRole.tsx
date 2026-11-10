import logo from "../assets/saiLogo";

export function WaitingForRole({ email, busy, onRefresh, onSignOut }: {
  email: string | null;
  busy: boolean;
  onRefresh: () => void;
  onSignOut: () => void;
}) {
  return <main className="centered">
    <section className="auth-card waiting-card">
      <img className="brand-logo" src={logo} alt="شعار كلية ساي" />
      <p className="eyebrow">كلية ساي التعليمية اليمنية الصينية</p>
      <h1>حسابك جاهز — بانتظار الدور</h1>
      <p className="muted">
        تم إنشاء حسابك بنجاح، لكن لم يُمنح بعد دوراً في البوابة. هذا أمر طبيعي للحسابات الجديدة.
        بعد أن تعتمد الإدارة دورك (معلم، طالب، ولي أمر أو موظف) ستظهر لوحتك تلقائياً.
      </p>
      {email && <p className="waiting-email" dir="ltr">{email}</p>}
      <p className="data-note">لا تحتاج إلى إنشاء حساب آخر. اضغط «تحقق مرة أخرى» بعد أن تخبرك الإدارة باعتماد دورك.</p>
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