import { useEffect, useRef, useState, type ReactNode } from "react";
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import { AppShell } from "./components/AppShell";
import { ErrorBoundary } from "./components/ErrorBoundary";
import { StatusCard } from "./components/StatusCard";
import { WaitingForRole } from "./components/WaitingForRole";
import { Dashboard } from "./pages/Dashboard";
import { PortalHome } from "./pages/PortalHome";
import { Profile } from "./pages/Profile";
import { ModuleEntry } from "./pages/ModuleEntry";
import { isAppRole } from "./lib/navigation";
import { canAccessOperations } from "./lib/studentLearning";
import {
  getInitialAuthState, restoreAuthState, signIn, signOut,
  subscribeToAuthChanges, type AuthState,
} from "./lib/auth";
import "./styles.css";

const HOME = "/portal/dashboard";

export default function PortalApp() {
  const [auth, setAuth] = useState<AuthState>(getInitialAuthState);
  const [busy, setBusy] = useState(false);
  const [signOutError, setSignOutError] = useState<string | null>(null);
  const version = useRef(0);
  const location = useLocation();

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

  const signInPath = `/auth?next=${encodeURIComponent(`${location.pathname}${location.search}`)}`;

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
      <Navigate to={signInPath} replace />
    ) : auth.profileError || auth.rolesError ? (
      <StatusCard title="تعذر تحميل بيانات الحساب" message={[auth.profileError, auth.rolesError].filter(Boolean).join(" — ")} onRetry={refresh}>
        {signOutButton}
      </StatusCard>
    ) : !auth.roles.some(isAppRole) ? (
      <WaitingForRole
        email={auth.email}
        busy={busy}
        onRefresh={() => void refresh()}
        onSignOut={handleSignOut}
      />
    ) : !auth.profile ? (
      <StatusCard title="الملف الشخصي غير متاح" message="لم يتم العثور على ملفك الشخصي أو لا تسمح سياسات الوصول بعرضه. تواصل مع مسؤول النظام." onRetry={refresh}>
        {signOutButton}
      </StatusCard>
    ) : (
      <AppShell profileName={auth.profile.fullName} email={auth.email} roles={auth.roles} onSignOut={handleSignOut} busy={busy} signOutError={signOutError}>
        {content}
      </AppShell>
    );
  }

  return (
    <ErrorBoundary>
      <div className="portal-root">
        <Routes>
          {/* The old portal login keeps working, but the real screen lives at /auth. */}
          <Route path="login" element={<Navigate to={HOME} replace />} />
          <Route path="dashboard" element={protectedPage(<PortalHome roles={auth.roles} userId={auth.userId} />)} />
          <Route path="profile" element={protectedPage(<Profile userId={auth.userId ?? ""} email={auth.email} roles={auth.roles} />)} />
          <Route path="operations" element={protectedPage(
            canAccessOperations(auth.roles)
              ? <Dashboard />
              : <StatusCard title="الوصول غير متاح" message="لوحة الإدارة غير متاحة لأدوار حسابك." link={HOME} />
          )} />
          <Route path="modules/:moduleId" element={protectedPage(<ModuleEntry roles={auth.roles} userId={auth.userId} />)} />
          <Route path="" element={<Navigate to={HOME} replace />} />
          <Route path="*" element={<StatusCard title="الصفحة غير موجودة" message="العنوان المطلوب غير متاح." link={HOME} />} />
        </Routes>
      </div>
    </ErrorBoundary>
  );
}