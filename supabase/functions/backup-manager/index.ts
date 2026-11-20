// Backup & Disaster Recovery coordinator.
// AUTHORIZES + COORDINATES. Full pg_dump backups run in the secure external worker
// (.github/workflows/db-backup.yml). This function performs a REAL storage-object
// backup, records metadata/audit, and issues short-lived signed download URLs.
// Never exposes the service-role key and never executes a destructive restore.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BACKUP_BUCKET = "backups";
const MAX_FILES = 5000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function authorizeSuperAdmin(req: Request): Promise<{ userId: string } | Response> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return json({ ok: false, message: "مطلوب تسجيل الدخول." }, 401);

  const authClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data, error } = await authClient.auth.getUser();
  if (error || !data.user) return json({ ok: false, message: "جلسة غير صالحة." }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
  const { data: roles, error: roleError } = await admin
    .from("user_roles")
    .select("role")
    .eq("user_id", data.user.id);
  if (roleError) return json({ ok: false, message: `تعذر التحقق من الصلاحيات: ${roleError.message}` }, 500);
  const isSuper = (roles ?? []).some((r: { role: string }) => r.role === "super_admin");
  if (!isSuper) return json({ ok: false, message: "هذه العملية متاحة للمسؤول العام فقط." }, 403);

  return { userId: data.user.id };
}

type StoredObject = { bucket: string; path: string; size: number };

async function walkBucket(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string,
  out: StoredObject[],
  errors: string[],
): Promise<void> {
  if (out.length >= MAX_FILES) return;
  const { data, error } = await admin.storage.from(bucket).list(prefix, { limit: 1000 });
  if (error) { errors.push(`${bucket}/${prefix}: ${error.message}`); return; }
  for (const entry of data ?? []) {
    if (out.length >= MAX_FILES) return;
    const path = prefix ? `${prefix}/${entry.name}` : entry.name;
    const isFolder = entry.id === null && (entry.metadata === null || entry.metadata === undefined);
    if (isFolder) {
      await walkBucket(admin, bucket, path, out, errors);
    } else {
      const size = Number((entry.metadata as { size?: number } | null)?.size ?? 0);
      out.push({ bucket, path, size });
    }
  }
}

async function ensureBackupBucket(admin: ReturnType<typeof createClient>): Promise<void> {
  const { data: buckets } = await admin.storage.listBuckets();
  const exists = (buckets ?? []).some((b) => b.name === BACKUP_BUCKET);
  if (!exists) {
    const { error } = await admin.storage.createBucket(BACKUP_BUCKET, { public: false });
    if (error && !/exist/i.test(error.message)) throw new Error(`تعذر إنشاء حاوية النسخ: ${error.message}`);
  }
}

async function runStorageBackup(admin: ReturnType<typeof createClient>, userId: string) {
  await ensureBackupBucket(admin);
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const { data: created, error: createError } = await admin
    .from("sai_backup_runs")
    .insert({
      provider: "edge-function",
      kind: "storage",
      status: "running",
      retention_class: "manual",
      requested_by: userId,
      note: "نسخة كائنات التخزين (Storage objects)",
      location: `${stamp}/`,
    })
    .select("id")
    .single();
  if (createError) throw new Error(createError.message);
  const runId = (created as { id: string }).id;

  const errors: string[] = [];
  const objects: StoredObject[] = [];
  try {
    const { data: buckets, error: bucketError } = await admin.storage.listBuckets();
    if (bucketError) throw new Error(bucketError.message);
    const sources = (buckets ?? []).filter((b) => b.name !== BACKUP_BUCKET);
    for (const bucket of sources) {
      await walkBucket(admin, bucket.name, "", objects, errors);
    }

    let copied = 0;
    let totalBytes = 0;
    for (const obj of objects) {
      try {
        const { data: blob, error: dlError } = await admin.storage.from(obj.bucket).download(obj.path);
        if (dlError || !blob) { errors.push(`${obj.bucket}/${obj.path}: ${dlError?.message ?? "فارغ"}`); continue; }
        const dest = `${stamp}/${obj.bucket}/${obj.path}`;
        const { error: upError } = await admin.storage.from(BACKUP_BUCKET).upload(dest, blob, {
          upsert: true,
          contentType: blob.type || "application/octet-stream",
        });
        if (upError) { errors.push(`${dest}: ${upError.message}`); continue; }
        copied += 1;
        totalBytes += obj.size;
      } catch (e) {
        errors.push(`${obj.bucket}/${obj.path}: ${e instanceof Error ? e.message : String(e)}`);
      }
    }

    const manifest = {
      stamp,
      sourceBuckets: sources.map((b) => b.name),
      listedObjects: objects.length,
      copiedObjects: copied,
      totalBytes,
      errors,
    };
    const checksum = await sha256Hex(JSON.stringify(manifest));

    await admin.from("sai_backup_runs").update({
      status: errors.length && copied === 0 ? "failed" : "completed",
      size_bytes: totalBytes,
      checksum,
      manifest,
      finished_at: new Date().toISOString(),
      error: errors.length ? errors.slice(0, 20).join(" | ") : null,
    }).eq("id", runId);

    await admin.from("audit_logs").insert({
      actor_user_id: userId,
      action: "backup.storage.run",
      entity_type: "sai_backup_runs",
      entity_id: runId,
      metadata: { copiedObjects: copied, listedObjects: objects.length, totalBytes, errorCount: errors.length },
    });

    return { runId, copiedObjects: copied, listedObjects: objects.length, totalBytes, checksum, errors };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await admin.from("sai_backup_runs").update({
      status: "failed",
      finished_at: new Date().toISOString(),
      error: message,
    }).eq("id", runId);
    throw new Error(message);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ ok: false, message: "الطريقة غير مدعومة." }, 405);

  const auth = await authorizeSuperAdmin(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { body = {}; }
  const action = String(body.action ?? "");
  const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

  try {
    if (action === "list") {
      const { data, error } = await admin
        .from("sai_backup_runs")
        .select("id, provider, kind, status, retention_class, size_bytes, checksum, location, requested_by, started_at, finished_at, error, note, created_at")
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) throw new Error(error.message);
      return json({ ok: true, runs: data ?? [] });
    }

    if (action === "request") {
      const { data, error } = await admin.from("sai_backup_runs").insert({
        provider: "manual",
        kind: "database",
        status: "requested",
        retention_class: "manual",
        requested_by: userId,
        note: "طلب نسخة احتياطية يدوية — ينفّذها عامل pg_dump الآمن (GitHub Actions).",
      }).select("id").single();
      if (error) throw new Error(error.message);
      await admin.from("audit_logs").insert({
        actor_user_id: userId,
        action: "backup.database.request",
        entity_type: "sai_backup_runs",
        entity_id: (data as { id: string }).id,
        metadata: { provider: "manual" },
      });
      return json({ ok: true, runId: (data as { id: string }).id });
    }

    if (action === "run-storage") {
      const result = await runStorageBackup(admin, userId);
      return json({ ok: true, ...result });
    }

    if (action === "sign-download") {
      const path = String(body.path ?? "");
      if (!path) return json({ ok: false, message: "مسار النسخة مطلوب." }, 400);
      const { data, error } = await admin.storage.from(BACKUP_BUCKET).createSignedUrl(path, 120);
      if (error) throw new Error(error.message);
      return json({ ok: true, url: data?.signedUrl ?? "" });
    }

    if (action === "request-restore") {
      const backupId = body.backupId ? String(body.backupId) : null;
      const note = String(body.note ?? "");
      const { data, error } = await admin.from("sai_backup_runs").insert({
        provider: "manual",
        kind: "restore",
        status: "requested",
        retention_class: "restore",
        requested_by: userId,
        external_ref: backupId,
        note: note || "طلب استعادة — يتطلب مراجعة وتنفيذ عامل مؤهل ضد بيئة معزولة أولاً.",
      }).select("id").single();
      if (error) throw new Error(error.message);
      await admin.from("audit_logs").insert({
        actor_user_id: userId,
        action: "backup.restore.request",
        entity_type: "sai_backup_runs",
        entity_id: (data as { id: string }).id,
        metadata: { backupId, note },
      });
      return json({ ok: true, runId: (data as { id: string }).id });
    }

    return json({ ok: false, message: "إجراء غير معروف." }, 400);
  } catch (error) {
    return json({ ok: false, message: error instanceof Error ? error.message : String(error) }, 500);
  }
});
