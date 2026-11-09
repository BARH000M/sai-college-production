import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabase";

export type AuthStatus = "loading" | "signed-out" | "signed-in";

export type AuthState = {
  status: AuthStatus;
  userId: string | null;
  email: string | null;
  profile: { fullName: string } | null;
  profileLoaded: boolean;
  profileError: string | null;
  roles: string[];
  rolesLoaded: boolean;
  rolesError: string | null;
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
    profile: null,
    profileLoaded: false,
    profileError: null,
    roles: [],
    rolesLoaded: false,
    rolesError: null,
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

async function loadSignedInState(session: Session): Promise<AuthState> {
  const { user } = session;
  const [profileResult, rolesResult] = await Promise.all([
    loadProfile(user.id),
    loadRoles(user.id),
  ]);

  return {
    status: "signed-in",
    userId: user.id,
    email: user.email ?? null,
    profile: profileResult.profile,
    profileLoaded: profileResult.error === null,
    profileError: profileResult.error,
    roles: rolesResult.roles,
    rolesLoaded: rolesResult.error === null,
    rolesError: rolesResult.error,
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
