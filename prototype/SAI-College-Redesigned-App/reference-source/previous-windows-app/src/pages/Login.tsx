import { useState } from "react";
import { Link } from "react-router";
import { GraduationCap, LogIn, ShieldCheck } from "lucide-react";

export default function Login() {
  const [error, setError] = useState("");
  const authUrl = import.meta.env.VITE_KIMI_AUTH_URL;
  const appId = import.meta.env.VITE_APP_ID;
  const configured = Boolean(authUrl && appId);
  function login() {
    try {
      const url = new URL(`${authUrl}/api/oauth/authorize`);
      if (url.protocol !== "https:" && url.hostname !== "localhost") throw new Error("Invalid auth URL");
      const redirectUri = `${window.location.origin}/api/oauth/callback`;
      url.searchParams.set("client_id", appId);
      url.searchParams.set("redirect_uri", redirectUri);
      url.searchParams.set("response_type", "code");
      url.searchParams.set("scope", "profile");
      url.searchParams.set("state", btoa(redirectUri));
      window.location.assign(url.toString());
    } catch {
      setError("تعذّر فتح خدمة الدخول. راجع إعدادات الاتصال مع مسؤول النظام.");
    }
  }
  return <div className="page page--narrow"><section className="sai-login">
    <div className="sai-login__mark"><GraduationCap size={34} /></div>
    <span className="eyebrow">كلية ساي التعليمية اليمنية الصينية</span>
    <h1>أهلاً بعودتك</h1><p>حسابك هو بداية رحلتك التعليمية.</p>
    <div className="sai-login__notice"><ShieldCheck size={20} /><span>استخدم حسابك المرتبط بخدمة الدخول الحالية لهذا التطبيق.</span></div>
    {!configured && <div className="form-error" role="alert">خدمة تسجيل الدخول غير مهيأة في هذه النسخة. يرجى ضبط إعدادات الخادم أولاً.</div>}
    {error && <div className="form-error" role="alert">{error}</div>}
    <button className="button button--primary button--wide" disabled={!configured} onClick={login}><LogIn size={19} /> تسجيل الدخول الآمن</button>
    <Link to="/" className="text-link">تصفح الكلية كزائر</Link>
  </section></div>;
}
