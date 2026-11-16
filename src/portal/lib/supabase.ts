import { createClient } from "@supabase/supabase-js";
import { SupabaseInitializationError } from "./initializationError";

const supabaseUrl = import.meta.env.VITE_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_PUBLIC_SUPABASE_ANON_KEY;
const saiTarget = import.meta.env.VITE_SAI_TARGET;

const targets = {
  production: { url: "https://aeryusbrulqdxjdynwfh.supabase.co", ref: "aeryusbrulqdxjdynwfh" },
  preview: { url: "https://mgibjusuglafbnlrkbep.supabase.co", ref: "mgibjusuglafbnlrkbep" },
} as const;

if (saiTarget !== undefined && saiTarget !== "production" && saiTarget !== "preview") {
  throw new SupabaseInitializationError("Unsupported SAI target environment.");
}
export const supabaseTarget = saiTarget === "preview" ? "preview" : "production";
const expected = targets[supabaseTarget];

if (!supabaseUrl || !supabaseAnonKey) {
  throw new SupabaseInitializationError("Supabase environment variables are missing.");
}

if (supabaseUrl.replace(/\/$/, "") !== expected.url) {
  throw new SupabaseInitializationError(`Supabase must use the authorized SAI ${supabaseTarget} project.`);
}
if (supabaseAnonKey.startsWith("sb_secret_")) {
  throw new SupabaseInitializationError("Use a public Supabase key in the browser.");
}
if (!supabaseAnonKey.startsWith("sb_publishable_")) {
  try {
    const claims = JSON.parse(atob(supabaseAnonKey.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    if (claims.role !== "anon" || claims.ref !== expected.ref) throw new Error("Invalid public key");
  } catch {
    throw new SupabaseInitializationError(`Use the authorized ${supabaseTarget} project's anon or publishable key.`);
  }
}

function initializeSupabase() {
  try {
    return createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: true,
        detectSessionInUrl: true,
        persistSession: true,
        // Environment-scoped storage key prevents reusing a Production session
        // in a Preview build (and vice versa) in the same browser profile.
        storageKey: `sai-${supabaseTarget}-auth`,
      },
    });
  } catch (error) {
    throw new SupabaseInitializationError("Supabase client initialization failed.", error);
  }
}

export const supabase = initializeSupabase();
