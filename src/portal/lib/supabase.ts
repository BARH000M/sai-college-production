import { createClient } from "@supabase/supabase-js";
import { SupabaseInitializationError } from "./initializationError";

const supabaseUrl = import.meta.env.VITE_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new SupabaseInitializationError("Supabase environment variables are missing.");
}

if (supabaseUrl.replace(/\/$/, "") !== "https://aeryusbrulqdxjdynwfh.supabase.co") {
  throw new SupabaseInitializationError("Supabase must use the authorized SAI project.");
}
if (supabaseAnonKey.startsWith("sb_secret_")) {
  throw new SupabaseInitializationError("Use a public Supabase key in the browser.");
}
if (!supabaseAnonKey.startsWith("sb_publishable_")) {
  try {
    const claims = JSON.parse(atob(supabaseAnonKey.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    if (claims.role !== "anon" || claims.ref !== "aeryusbrulqdxjdynwfh") throw new Error("Invalid public key");
  } catch {
    throw new SupabaseInitializationError("Use the authorized project's anon or publishable key.");
  }
}

function initializeSupabase() {
  try {
    return createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: true,
        detectSessionInUrl: true,
        persistSession: true,
      },
    });
  } catch (error) {
    throw new SupabaseInitializationError("Supabase client initialization failed.", error);
  }
}

export const supabase = initializeSupabase();
