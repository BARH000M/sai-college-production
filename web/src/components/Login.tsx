import { useState, type FormEvent } from "react";
import logo from "../assets/sai-logo.png";

export function Login({ onSignIn, busy, error }: {
  onSignIn: (email: string, password: string) => Promise<void>; busy: boolean; error: string | null;
}) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void onSignIn(email, password);
    setPassword("");
  }
  return <main className="centered"><section className="auth-card">
    <img className="brand-logo" src={logo} alt="شعار كلية ساي" />
    <p className="eyebrow">كلية ساي التعليمية اليمنية الصينية</p>
    <h1>تسجيل الدخول</h1>
    <p className="muted">أدخل بيانات حسابك للوصول إلى النظام.</p>
    <form className="login-form" onSubmit={submit}>
      <label>البريد الإلكتروني<input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required disabled={busy} /></label>
      <label>كلمة المرور<input type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required disabled={busy} /></label>
      {error && <p className="error-box" role="alert">{error}</p>}
      <button className="button primary" disabled={busy}>{busy ? "جارٍ تسجيل الدخول..." : "دخول"}</button>
    </form>
  </section></main>;
}
