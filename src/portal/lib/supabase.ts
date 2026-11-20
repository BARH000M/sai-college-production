import { createClient } from "@supabase/supabase-js";

/**
 * The authorized SAI production project.
 *
 * This value is the only backend the browser may ever talk to. A deployment
 * without environment variables must still be able to render the public
 * website, so configuration problems are reported through
 * `supabaseConfigurationError` instead of being thrown while the app loads.
 * The client always falls back to this project with a non-usable placeholder
 * key, so a misconfigured build can never silently point at another backend.
 */
const PRODUCTION_URL = "https://aeryusbrulqdxjdynwfh.supabase.co";
const PRODUCTION_REF = "aeryusbrulqdxjdynwfh";
const PLACEHOLDER_KEY = "sb_publishable_unconfigured";

const configuredUrl = String(import.meta.env.VITE_PUBLIC_SUPABASE_URL ?? "").trim().replace(/\/+$/, "");
const configuredKey = String(import.meta.env.VITE_PUBLIC_SUPABASE_ANON_KEY ?? "").trim();
const saiTarget = import.meta.env.VITE_SAI_TARGET;

export const supabaseTarget = "production";

/** Project reference embedded in a legacy anon JWT, or null when not a JWT. */
function keyProjectRef(value: string): string | null {
  const parts = value.split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload.padEnd(payload.length + ((4 - (payload.length % 4)) % 4), "=");
    const claims = JSON.parse(atob(padded)) as { ref?: unknown };
    return typeof claims.ref === "string" ? claims.ref : null;
  } catch {
    return null;
  }
}

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

/** Every rejected configuration resolves to the authorized project with no usable key. */
function rejected(error: string): ResolvedConfiguration {
  return { url: PRODUCTION_URL, key: PLACEHOLDER_KEY, error };
}

function resolveConfiguration(): ResolvedConfiguration {
  if (saiTarget !== undefined && saiTarget !== "production") {
    return rejected(`Unsupported SAI target environment: ${saiTarget || "(empty)"}.`);
  }
  if (!configuredUrl || !configuredKey) {
    return rejected("Supabase is not configured for this deployment.");
  }
  if (!/^https?:\/\//i.test(configuredUrl)) {
    return rejected("The Supabase URL is not a valid http(s) address.");
  }
  let origin = "";
  try {
    origin = new URL(configuredUrl).origin;
  } catch {
    return rejected("The Supabase URL is not a valid http(s) address.");
  }
  if (origin !== new URL(PRODUCTION_URL).origin) {
    return rejected(`The Supabase URL must be the authorized ${supabaseTarget} project.`);
  }
  if (!isPublicKey(configuredKey)) {
    return rejected("A public anon or publishable key is required in the browser.");
  }
  const keyRef = keyProjectRef(configuredKey);
  if (keyRef !== null && keyRef !== PRODUCTION_REF) {
    return rejected("The Supabase key belongs to a different project.");
  }
  return { url: PRODUCTION_URL, key: configuredKey, error: null };
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