import { useEffect, useRef, useState, type ReactNode } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AppShell } from "./components/AppShell";
import { Login } from "./components/Login";
import { StatusCard } from "./components/StatusCard";
import { Dashboard } from "./pages/Dashboard";
import { RoleDashboard } from "./pages/RoleDashboard";
import { ModuleEntry } from "./pages/ModuleEntry";
import { isAppRole } from "./lib/navigation";
import {
  getInitialAuthState, restoreAuthState, signIn, signOut,
  subscribeToAuthChanges, type AuthState,
} from "./lib/auth";
import "./styles.css";

export default function App() {
  const [auth, setAuth] = useState<AuthState>(getInitialAuthState);
  const [busy, setBusy] = useState(false);
  const [signOutError, setSignOutError] = useState<string | null>(null);
  const version = useRef(0);

  async function refresh() {
    const request = ++version.current;
    setAuth(getInitialAuthState());
    const next = await restoreAuthState();
    if (version.current === request) setAuth(next);
  }

  useEffect(() => {
    let active = true;
    const request = ++version.current;
    const unsubscribe = subscribeToAuthChanges((next) => {
      if (active) {
        version.current += 1;
        setAuth(next);
      }
    });
    void restoreAuthState().then((next) => {
      if (active && request === version.current) setAuth(next);
    });
    return () => { active = false; unsubscribe(); };
  }, []);

  async function handleSignIn(email: string, password: string) {
    setBusy(true);
    const request = ++version.current;
    setAuth(getInitialAuthState());
    const next = await signIn(email, password);
    if (version.current === request) setAuth(next);
    setBusy(false);
  }

  async function handleSignOut() {
    setBusy(true);
    setSignOutError(null);
    const result = await signOut();
    setBusy(false);
    if (result.error) {
      setSignOutError(result.error);
    } else {
      version.current += 1;
      setAuth(getInitialAuthState("signed-out"));
    }
  }

  const signOutButton = (
    <>
      <button className="button secondary" onClick={handleSignOut} disabled={busy}>
        {busy ? "جارٍ تسجيل الخروج..." : "تسجيل الخروج"}
      </button>
      {signOutError && <p className="error-box" role="alert">تعذر تسجيل الخروج: {signOutError}</p>}
    </>
  );
  function protectedPage(content: ReactNode) {
    return auth.status === "loading" ? (
    <StatusCard title="جارٍ التحقق من الحساب" message="يرجى الانتظار أثناء تحميل الجلسة والبيانات." />
  ) : auth.status === "signed-out" ? (
    <Navigate to="/login" replace />
  ) : auth.profileError || auth.rolesError ? (
    <StatusCard title="تعذر تحميل بيانات الحساب" message={[auth.profileError, auth.rolesError].filter(Boolean).join(" — ")} onRetry={refresh}>
      {signOutButton}
    </StatusCard>
  ) : !auth.profile ? (
    <StatusCard title="الملف الشخصي غير متاح" message="لم يتم العثور على ملفك الشخصي أو لا تسمح سياسات الوصول بعرضه. تواصل مع مسؤول النظام." onRetry={refresh}>
      {signOutButton}
    </StatusCard>
  ) : !auth.roles.some(isAppRole) ? (
    <StatusCard title="الوصول غير متاح" message={auth.roles.length ? "لا يتضمن حسابك دوراً مدعوماً في هذا التطبيق. تواصل مع مسؤول النظام." : "لم تُعرض أدوار لهذا الحساب. قد يكون السبب عدم وجود دور أو سياسات الوصول؛ تواصل مع مسؤول النظام."} onRetry={refresh}>
      {signOutButton}
    </StatusCard>
  ) : (
    <AppShell profileName={auth.profile.fullName} email={auth.email} roles={auth.roles} onSignOut={handleSignOut} busy={busy} signOutError={signOutError}>
      {content}
    </AppShell>
  );
  }

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={auth.status === "signed-in" ? <Navigate to="/dashboard" replace /> : auth.status === "loading" ? <StatusCard title="جارٍ استعادة الجلسة" message="يرجى الانتظار." /> : <Login onSignIn={handleSignIn} error={auth.authError} busy={busy} />} />
        <Route path="/dashboard" element={protectedPage(auth.roles.includes("super_admin") ? <Dashboard /> : <RoleDashboard roles={auth.roles} />)} />
        <Route path="/modules/:moduleId" element={protectedPage(<ModuleEntry roles={auth.roles} userId={auth.userId} />)} />
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="*" element={<StatusCard title="الصفحة غير موجودة" message="العنوان المطلوب غير متاح." link="/dashboard" />} />
      </Routes>
    </BrowserRouter>
  );
}
