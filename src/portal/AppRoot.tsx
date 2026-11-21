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
import { ModuleDirectory } from "./pages/ModuleDirectory";
import { ControlCenter } from "./pages/ControlCenter";
import { PortalLanguageProvider, usePortalLang } from "./lib/portalLangContext";
import { isAppRole } from "./lib/navigation";
import { useModuleToggles } from "./lib/moduleToggles";
import { useSidebarLayout } from "./hooks/useSidebarLayout";
import { onboardingNotices } from "./lib/onboarding";
import { canAccessOperations } from "./lib/studentLearning";
import { accountErrorMessage } from "./lib/accountError";
import {
  getInitialAuthState, restoreAuthState, signIn, signOut,
  subscribeToAuthChanges, type AuthState,
} from "./lib/auth";
import "./styles.css";
import "./components/workspace-modules.css";

const HOME = "/portal/dashboard";

/**
 * The single element that owns the portal writing direction.
 *
 * Arabic renders right-to-left; English and Chinese render left-to-right with the
 * sidebar on the left. Every layout rule underneath uses logical properties, so
 * switching language mirrors the whole shell without a duplicated stylesheet.
 */
function PortalSurface({ children }: { children: ReactNode }) {
  const { dir, lang } = usePortalLang();
  return <div className="portal-root" dir={dir} lang={lang}>{children}</div>;
}

function PortalAppInner() {
  const [auth, setAuth] = useState<AuthState>(getInitialAuthState);
  const [busy, setBusy] = useState(false);
  const [signOutError, setSignOutError] = useState<string | null>(null);
  const version = useRef(0);
  const location = useLocation();
  const { t } = usePortalLang();
  const moduleToggles = useModuleToggles();
  const sidebarLayout = useSidebarLayout();

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
  const accountNotices = onboardingNotices(
    auth.roles,
    auth.emailConfirmed,
    auth.onboardingChecks,
    auth.onboardingError,
  );

  const signOutButton = (
    <>
      <button className="button secondary" onClick={handleSignOut} disabled={busy}>
        {busy ? t("signingOut") : t("signOut")}
      </button>
      {signOutError && <p className="error-box" role="alert">{t("signOutFailed")}: {signOutError}</p>}
    </>
  );

  function protectedPage(content: ReactNode) {
    return auth.status === "loading" ? (
      <StatusCard title={t("checkingAccount")} message={t("checkingAccountBody")} />
    ) : auth.status === "signed-out" ? (
      <Navigate to={signInPath} replace />
    ) : auth.profileError || auth.rolesError ? (
      <StatusCard
        title={t("accountLoadFailed")}
        message={accountErrorMessage([auth.profileError, auth.rolesError])}
        onRetry={refresh}
      >
        {signOutButton}
      </StatusCard>
    ) : !auth.roles.some(isAppRole) ? (
      <WaitingForRole
        email={auth.email}
        emailConfirmed={auth.emailConfirmed}
        busy={busy}
        onRefresh={() => void refresh()}
        onSignOut={handleSignOut}
      />
    ) : !auth.profile ? (
      <StatusCard title={t("profileUnavailable")} message={t("profileUnavailableBody")} onRetry={refresh}>
        {signOutButton}
      </StatusCard>
    ) : (
      <AppShell
        profileName={auth.profile.fullName}
        email={auth.email}
        roles={auth.roles}
        onSignOut={handleSignOut}
        busy={busy}
        signOutError={signOutError}
        onboardingNotices={accountNotices}
      >
        {content}
      </AppShell>
    );
  }

  if (!moduleToggles.ready || !sidebarLayout.ready) {
    return (
      <PortalSurface>
        <StatusCard title={t("loadingPortalSettings")} message={t("loadingPortalSettingsBody")} />
      </PortalSurface>
    );
  }

  return (
    <PortalSurface>
      <Routes>
        {/* The old portal login keeps working, but the real screen lives at /auth. */}
        <Route path="login" element={<Navigate to={HOME} replace />} />
        <Route path="dashboard" element={protectedPage(<PortalHome roles={auth.roles} userId={auth.userId} />)} />
        <Route path="directory" element={protectedPage(<ModuleDirectory roles={auth.roles} />)} />
        <Route path="control-center" element={protectedPage(<ControlCenter roles={auth.roles} />)} />
        <Route path="profile" element={protectedPage(<Profile userId={auth.userId ?? ""} email={auth.email} roles={auth.roles} />)} />
        <Route path="operations" element={protectedPage(
          canAccessOperations(auth.roles)
            ? <Dashboard />
            : <StatusCard title={t("accessUnavailableTitle")} message={t("accessUnavailableBody")} link={HOME} />
        )} />
        <Route path="modules/:moduleId" element={protectedPage(<ModuleEntry roles={auth.roles} userId={auth.userId} />)} />
        <Route path="" element={<Navigate to={HOME} replace />} />
        <Route path="*" element={<StatusCard title={t("pageNotFoundTitle")} message={t("pageNotFoundBody")} link={HOME} />} />
      </Routes>
    </PortalSurface>
  );
}

export default function PortalApp() {
  return (
    <ErrorBoundary>
      <PortalLanguageProvider>
        <PortalAppInner />
      </PortalLanguageProvider>
    </ErrorBoundary>
  );
}