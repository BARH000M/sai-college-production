import { createClient } from "@supabase/supabase-js";

/**
 * The authorized SAI production project.
 *
 * This value is only used as a safe default. A deployment without environment
 * variables must still be able to render the public website, so configuration
 * problems are reported instead of thrown while the app is loading.
 */
const PRODUCTION_URL = "https://aeryusbrulqdxjdynwfh.supabase.co";
const PLACEHOLDER_KEY = "sb_publishable_unconfigured";

const configuredUrl = String(import.meta.env.VITE_PUBLIC_SUPABASE_URL ?? "").trim().replace(/\/+$/, "");
const configuredKey = String(import.meta.env.VITE_PUBLIC_SUPABASE_ANON_KEY ?? "").trim();
const saiTarget = import.meta.env.VITE_SAI_TARGET;

export const supabaseTarget = "production";

/**
 * Only public browser keys are allowed here. A secret/service key must never be
 * shipped to the client, so it is rejected instead of being used.
 */
function isPublicKey(value: string): boolean {
  if (!value) return false;
  if (value.startsWith("sb_publishable_")) return true;
  if (value.startsWith("sb_secret_")) return false;
  const parts = value.split(".");
  if (parts.length !== 3) return false;
  try {
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload.padEnd(payload.length + ((4 - (payload.length % 4)) % 4), "=");
    const claims = JSON.parse(atob(padded)) as { role?: string };
    return claims.role === "anon";
  } catch {
    return false;
  }
}

type ResolvedConfiguration = { url: string; key: string; error: string | null };

function resolveConfiguration(): ResolvedConfiguration {
  if (saiTarget && saiTarget !== "production") {
    return {
      url: PRODUCTION_URL,
      key: PLACEHOLDER_KEY,
      error: `Unsupported SAI target environment: ${saiTarget}.`,
    };
  }
  if (!configuredUrl || !configuredKey) {
    return {
      url: PRODUCTION_URL,
      key: PLACEHOLDER_KEY,
      error: "Supabase is not configured for this deployment.",
    };
  }
  if (!/^https?:\/\//i.test(configuredUrl)) {
    return {
      url: PRODUCTION_URL,
      key: PLACEHOLDER_KEY,
      error: "The Supabase URL is not a valid http(s) address.",
    };
  }
  if (!isPublicKey(configuredKey)) {
    return {
      url: PRODUCTION_URL,
      key: PLACEHOLDER_KEY,
      error: "A public anon or publishable key is required in the browser.",
    };
  }
  if (configuredUrl !== PRODUCTION_URL) {
    // Not fatal: the website keeps working, but the mismatch is worth surfacing.
    console.warn(`[SAI] Supabase is pointing at ${configuredUrl} instead of the authorized ${supabaseTarget} project.`);
  }
  return { url: configuredUrl, key: configuredKey, error: null };
}

const configuration = resolveConfiguration();

/** Human readable reason when the backend is unavailable, otherwise null. */
export const supabaseConfigurationError = configuration.error;
/** True when a usable public backend configuration was found. */
export const isSupabaseConfigured = configuration.error === null;

export const supabase = createClient(configuration.url, configuration.key, {
  auth: {
    autoRefreshToken: true,
    detectSessionInUrl: true,
    persistSession: true,
    // Preserve the existing Main session key across configuration changes.
    storageKey: `sai-${supabaseTarget}-auth`,
  },
});

export default supabase;