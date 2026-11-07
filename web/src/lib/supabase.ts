import { createClient } from "@supabase/supabase-js";
import { SupabaseInitializationError } from "./initializationError";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new SupabaseInitializationError("Supabase environment variables are missing.");
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
