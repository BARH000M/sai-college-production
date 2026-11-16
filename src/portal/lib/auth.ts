import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabase";
import type { OnboardingChecks } from "./onboarding";

export type AuthStatus = "loading" | "signed-out" | "signed-in";

export type AuthState = {
  status: AuthStatus;
  userId: string | null;
  email: string | null;
  emailConfirmed: boolean;
  profile: { fullName: string } | null;
  profileLoaded: boolean;
  profileError: string | null;
  roles: string[];
  rolesLoaded: boolean;
  rolesError: string | null;
  onboardingChecks: OnboardingChecks;
  onboardingError: string | null;
  authError: string | null;
};

type UserProfileResult = {
  profile: AuthState["profile"];
  error: string | null;
};

type UserRolesResult = {
  roles: string[];
  error: string | null;
};

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function getInitialAuthState(
  status: AuthStatus = "loading",
): AuthState {
  return {
    status,
    userId: null,
    email: null,
    emailConfirmed: false,
    profile: null,
    profileLoaded: false,
    profileError: null,
    roles: [],
    rolesLoaded: false,
    rolesError: null,
    onboardingChecks: {
      activeBranchMembership: null,
      studentRecordVisible: null,
      verifiedParentLinkVisible: null,
      assignedClassVisible: null,
    },
    onboardingError: null,
    authError: null,
  };
}

async function loadProfile(userId: string): Promise<UserProfileResult> {
  try {
    const { data, error } = await supabase
      .schema("public")
      .from("profiles")
      .select("full_name")
      .eq("id", userId)
      .maybeSingle();

    if (error) {
      return { profile: null, error: error.message };
    }

    return {
      profile: data ? { fullName: data.full_name } : null,
      error: null,
    };
  } catch (error) {
    return { profile: null, error: errorMessage(error) };
  }
}

async function loadRoles(userId: string): Promise<UserRolesResult> {
  try {
    const { data, error } = await supabase
      .schema("public")
      .from("user_roles")
      .select("role")
      .eq("user_id", userId);

    if (error) {
      return { roles: [], error: error.message };
    }

    return {
      roles: (data ?? []).map((assignment) => assignment.role),
      error: null,
    };
  } catch (error) {
    return { roles: [], error: errorMessage(error) };
  }
}

function appBasePath(): string {
  const raw = typeof __BASE_PATH__ === "string" ? __BASE_PATH__ : "";
  const clean = raw.split("/").filter(Boolean).join("/");
  return clean ? `/${clean}` : "";
}

/**
 * Creates the profile row for a fresh account when it is missing.
 *
 * Sign-up stores the name and preferred language in the auth metadata, so the
 * profile can be materialised on the first signed-in session even when the
 * visitor had to confirm their email before signing in.
 */
async function ensureProfileRow(user: Session["user"]): Promise<string | null> {
  try {
    const existing = await supabase
      .schema("public")
      .from("profiles")
      .select("id")
      .eq("id", user.id)
      .maybeSingle();
    if (existing.error) return existing.error.message;
    if (existing.data) return null;

    const metadata = (user.user_metadata ?? {}) as Record<string, unknown>;
    const metaName = typeof metadata.full_name === "string" ? metadata.full_name.trim() : "";
    const locale = metadata.preferred_locale === "en" ? "en" : "ar";
    const inserted = await supabase.schema("public").from("profiles").insert({
      id: user.id,
      full_name: metaName || user.email?.split("@")[0] || "مستخدم جديد",
      preferred_locale: locale,
    });
    return inserted.error?.message ?? null;
  } catch (error) {
    return errorMessage(error);
  }
}

type VisibleRecordResult = { visible: boolean | null; error: string | null };

async function visibleRecord(
  query: PromiseLike<{ data: unknown; error: { message: string } | null }>,
): Promise<VisibleRecordResult> {
  try {
    const result = await query;
    return { visible: result.error ? null : result.data !== null, error: result.error?.message ?? null };
  } catch (error) {
    return { visible: null, error: errorMessage(error) };
  }
}

async function loadOnboardingChecks(userId: string, roles: readonly string[]): Promise<{
  checks: OnboardingChecks;
  error: string | null;
}> {
  const branchScoped = roles.some((role) => [
    "admin", "teacher", "accountant", "receptionist", "librarian", "content_editor",
  ].includes(role));
  const [branch, student, parent, teacher] = await Promise.all([
    branchScoped
      ? visibleRecord(supabase.schema("public").from("branch_memberships").select("branch_id")
        .eq("user_id", userId).eq("is_active", true).limit(1).maybeSingle())
      : Promise.resolve({ visible: null, error: null }),
    roles.includes("student")
      ? visibleRecord(supabase.schema("public").from("students").select("id")
        .eq("user_id", userId).limit(1).maybeSingle())
      : Promise.resolve({ visible: null, error: null }),
    roles.includes("parent")
      ? visibleRecord(supabase.schema("public").from("parent_student_links").select("student_id")
        .eq("parent_user_id", userId).not("verified_at", "is", null).limit(1).maybeSingle())
      : Promise.resolve({ visible: null, error: null }),
    roles.includes("teacher")
      ? visibleRecord(supabase.schema("public").from("classes").select("id")
        .eq("teacher_id", userId).eq("is_active", true).limit(1).maybeSingle())
      : Promise.resolve({ visible: null, error: null }),
  ]);
  return {
    checks: {
      activeBranchMembership: branch.visible,
      studentRecordVisible: student.visible,
      verifiedParentLinkVisible: parent.visible,
      assignedClassVisible: teacher.visible,
    },
    error: [branch, student, parent, teacher].map((result) => result.error).filter(Boolean).join(" — ") || null,
  };
}

async function loadSignedInState(session: Session): Promise<AuthState> {
  const { user } = session;
  const profileCreationError = await ensureProfileRow(user);
  const [profileResult, rolesResult] = await Promise.all([
    loadProfile(user.id),
    loadRoles(user.id),
  ]);
  const onboardingResult = rolesResult.error
    ? { checks: getInitialAuthState().onboardingChecks, error: null }
    : await loadOnboardingChecks(user.id, rolesResult.roles);

  return {
    status: "signed-in",
    userId: user.id,
    email: user.email ?? null,
    emailConfirmed: !!user.email_confirmed_at,
    profile: profileResult.profile,
    profileLoaded: profileResult.error === null,
    profileError: profileResult.error ?? (!profileResult.profile ? profileCreationError : null),
    roles: rolesResult.roles,
    rolesLoaded: rolesResult.error === null,
    rolesError: rolesResult.error,
    onboardingChecks: onboardingResult.checks,
    onboardingError: onboardingResult.error,
    authError: null,
  };
}

async function loadSessionState(session: Session | null): Promise<AuthState> {
  if (!session) {
    return getInitialAuthState("signed-out");
  }

  return loadSignedInState(session);
}

export async function restoreAuthState(): Promise<AuthState> {
  try {
    const { data, error } = await supabase.auth.getSession();
    if (error) {
      return {
        ...getInitialAuthState("signed-out"),
        authError: error.message,
      };
    }

    return await loadSessionState(data.session);
  } catch (error) {
    return {
      ...getInitialAuthState("signed-out"),
      authError: `Session restore failed: ${errorMessage(error)}`,
    };
  }
}

export async function signIn(email: string, password: string): Promise<AuthState> {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      return {
        ...getInitialAuthState("signed-out"),
        authError: error.message,
      };
    }

    return await loadSessionState(data.session);
  } catch (error) {
    return {
      ...getInitialAuthState("signed-out"),
      authError: `Sign-in failed: ${errorMessage(error)}`,
    };
  }
}

export type SignUpInput = {
  fullName: string;
  email: string;
  password: string;
  locale: "ar" | "en";
};

export type SignUpResult = {
  state: AuthState;
  confirmationRequired: boolean;
};

export async function signUpAccount(input: SignUpInput): Promise<SignUpResult> {
  try {
    const { data, error } = await supabase.auth.signUp({
      email: input.email.trim(),
      password: input.password,
      options: {
        data: {
          full_name: input.fullName.trim(),
          preferred_locale: input.locale,
        },
        emailRedirectTo: `${window.location.origin}${appBasePath()}/portal`,
      },
    });

    if (error) {
      return {
        state: { ...getInitialAuthState("signed-out"), authError: error.message },
        confirmationRequired: false,
      };
    }

    if (!data.session) {
      return { state: getInitialAuthState("signed-out"), confirmationRequired: true };
    }

    await ensureProfileRow(data.session.user);
    return { state: await loadSessionState(data.session), confirmationRequired: false };
  } catch (error) {
    return {
      state: { ...getInitialAuthState("signed-out"), authError: `Sign-up failed: ${errorMessage(error)}` },
      confirmationRequired: false,
    };
  }
}

export async function signOut(): Promise<{ error: string | null }> {
  try {
    const { error } = await supabase.auth.signOut();
    return { error: error?.message ?? null };
  } catch (error) {
    return { error: errorMessage(error) };
  }
}

export function subscribeToAuthChanges(
  onChange: (state: AuthState) => void,
): () => void {
  let active = true;
  let version = 0;
  const {
    data: { subscription },
  } = supabase.auth.onAuthStateChange((event, session) => {
    if (event === "INITIAL_SESSION") {
      return;
    }

    const currentVersion = ++version;
    if (!session) {
      onChange(getInitialAuthState("signed-out"));
      return;
    }

    onChange(getInitialAuthState());
    window.setTimeout(() => {
      void loadSessionState(session).then((state) => {
        if (active && currentVersion === version) {
          onChange(state);
        }
      });
    }, 0);
  });

  return () => {
    active = false;
    subscription.unsubscribe();
  };
}
