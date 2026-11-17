import { trustedClientIp } from "../_shared/client-ip.ts";
import { mutationGateOpen } from "../_shared/mutation-gate.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.119.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const noStore = { "Cache-Control": "no-store" };

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, ...noStore, "Content-Type": "application/json" },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function rateKey(ip: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(ip)));
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, code: "METHOD_NOT_ALLOWED" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ ok: false, code: "SERVICE_UNAVAILABLE" }, 503);

  const ip = trustedClientIp(req.headers);
  if (!ip) return json({ ok: false, code: "SERVICE_UNAVAILABLE" }, 503);

  let body: Record<string, unknown>;
  try {
    const parsed: unknown = await req.json();
    if (!isRecord(parsed)) return json({ ok: false, code: "INVALID_REQUEST" }, 400);
    body = parsed;
  } catch {
    return json({ ok: false, code: "INVALID_REQUEST" }, 400);
  }

  const mode = body.mode;
  if (mode !== "submit" && mode !== "status" && mode !== "history") {
    return json({ ok: false, code: "INVALID_REQUEST" }, 400);
  }

  const clientKey = await rateKey(ip, serviceKey);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  if (!await mutationGateOpen(admin)) {
    return json({ ok: false, code: "MAINTENANCE" }, 503);
  }

  const { data: allowed, error: limitError } = await admin.rpc("admissions_public_rate_limit", {
    p_client_key: clientKey,
    p_scope: mode === "submit" ? "submit" : "track",
  });
  if (limitError) {
    console.error("Admission tracking rate limit failed", limitError.code);
    return json({ ok: false, code: "SERVICE_UNAVAILABLE" }, 503);
  }
  if (allowed !== true) return json({ ok: false, code: "RATE_LIMITED" }, 429);

  if (mode === "submit") {
    const { data, error } = await admin.rpc("admissions_public_submit", {
      p_full_name: body.fullName,
      p_phone: body.phone,
      p_email: body.email,
      p_program: body.program,
      p_message: body.message,
    });
    if (error) {
      if (error.code === "22023") {
        const code = ["INVALID_NAME", "INVALID_CONTACT", "INVALID_EMAIL", "MESSAGE_TOO_LONG"].includes(error.message)
          ? error.message : "INVALID_REQUEST";
        return json({ ok: false, code }, 400);
      }
      if (error.code === "P0001") {
        const code = ["NO_ACTIVE_TERM", "NO_ADMISSIONS_OWNER"].includes(error.message)
          ? error.message : "SERVICE_UNAVAILABLE";
        return json({ ok: false, code }, 503);
      }
      console.error("Admission submission failed", error.code);
      return json({ ok: false, code: "SUBMISSION_FAILED" }, 500);
    }
    if (!isRecord(data) || typeof data.reference !== "string"
      || typeof data.tracking_token !== "string" || !/^[0-9a-f]{64}$/.test(data.tracking_token)) {
      console.error("Admission submission returned an invalid response");
      return json({ ok: false, code: "SUBMISSION_FAILED" }, 500);
    }
    return json({ ok: true, reference: data.reference, trackingToken: data.tracking_token });
  }

  const reference = typeof body.reference === "string" ? body.reference.trim() : "";
  const trackingToken = typeof body.trackingToken === "string" ? body.trackingToken.trim() : "";
  if (reference.length < 6 || reference.length > 80 || !/^[0-9a-f]{64}$/.test(trackingToken)) {
    return json({ ok: false, code: "INVALID_REQUEST" }, 400);
  }

  if (mode === "status") {
    const { data, error } = await admin.rpc("admissions_public_status", {
      p_reference: reference,
      p_tracking_token: trackingToken,
    });
    if (error) {
      console.error("Admission status lookup failed", error.code);
      return json({ ok: false, code: "LOOKUP_FAILED" }, 500);
    }
    if (!isRecord(data)) return json({ ok: true, result: null });
    const result = {
      status: typeof data.status === "string" ? data.status : "",
      submitted_at: typeof data.submitted_at === "string" ? data.submitted_at : "",
      status_updated_at: typeof data.status_updated_at === "string" ? data.status_updated_at : "",
    };
    if (!result.status || !result.submitted_at || !result.status_updated_at) {
      console.error("Admission status lookup returned an invalid response");
      return json({ ok: false, code: "LOOKUP_FAILED" }, 500);
    }
    return json({ ok: true, result });
  }

  const { data, error } = await admin.rpc("admissions_public_history", {
    p_reference: reference,
    p_tracking_token: trackingToken,
  });
  if (error) {
    console.error("Admission history lookup failed", error.code);
    return json({ ok: false, code: "LOOKUP_FAILED" }, 500);
  }
  if (!Array.isArray(data)) return json({ ok: true, history: null });
  const history: { action: string; status: string; occurred_at: string }[] = [];
  for (const item of data) {
    if (!isRecord(item) || (item.action !== "insert" && item.action !== "status_change"
      && item.action !== "current_status_snapshot") || typeof item.status !== "string"
      || typeof item.occurred_at !== "string") {
      console.error("Admission history lookup returned an invalid response");
      return json({ ok: false, code: "LOOKUP_FAILED" }, 500);
    }
    history.push({ action: item.action, status: item.status, occurred_at: item.occurred_at });
  }
  return json({ ok: true, history });
});
