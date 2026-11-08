import { Component, type ErrorInfo, type ReactNode } from "react";
import logo from "../assets/saiLogo";
import { SupabaseInitializationError } from "../lib/initializationError";

type Props = { children: ReactNode };
type State = { hasError: boolean; error: unknown };

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, error: null };

  static getDerivedStateFromError(error: unknown): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: unknown, info: ErrorInfo) {
    console.error("Application rendering failed:", error, info.componentStack);
  }

  render() {
    if (this.state.hasError) {
      const isConfigurationError = this.state.error instanceof SupabaseInitializationError;
      return <main className="centered"><section className="auth-card" role="alert">
        <img className="brand-logo" src={logo} alt="شعار كلية ساي" />
        <p className="eyebrow">كلية ساي التعليمية اليمنية الصينية</p>
        <h1>{isConfigurationError ? "تعذر إعداد الاتصال بالنظام" : "تعذر عرض الصفحة"}</h1>
        <p className="muted">{isConfigurationError
          ? "تحقق من إعدادات Supabase للتطبيق وأعد تشغيل خادم التطوير، ثم أعد تحميل الصفحة. تواصل مع مسؤول النظام إذا استمرت المشكلة."
          : "حدث خطأ غير متوقع. أعد تحميل الصفحة، أو تواصل مع مسؤول النظام إذا استمرت المشكلة."}</p>
        <button className="button primary" onClick={() => window.location.reload()}>إعادة تحميل الصفحة</button>
      </section></main>;
    }

    return this.props.children;
  }
}
