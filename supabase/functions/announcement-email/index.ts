// Sends a published announcement to the people its audience and branch allow,
// using Resend from the server only. The caller's JWT is verified with the anon
// client; all data reads and delivery logging use the service-role client.
// Every attempt is written to public.announcement_deliveries, and people who
// already received the announcement are never sent it twice.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_RECIPIENTS = 200;

const AUDIENCE_ROLES: Record<string, string[]> = {
  all: ["super_admin", "admin", "teacher", "accountant", "receptionist", "librarian", "content_editor", "parent", "student"],
  staff: ["super_admin", "admin", "teacher", "accountant", "receptionist", "librarian", "content_editor"],
  teachers: ["teacher"],
  parents: ["parent"],
  students: ["student"],
};

type Announcement = {
  id: string;
  branch_id: string | null;
  title: string;
  body: string;
  audience: string;
  is_published: boolean;
  published_at: string | null;
  expires_at: string | null;
};

type Profile = { id: string; email: string | null; full_name: string | null };

type DeliveryRow = {
  announcement_id: string;
  recipient_user_id: string;
  recipient_email: string;
  status: "sent" | "failed" | "skipped";
  provider_message_id: string | null;
  error: string | null;
  attempted_at: string;
  sent_at: string | null;
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function failure(status: number, error: string, message: string): Response {
  return json({ error, message }, status);
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function buildHtml(announcement: Announcement): string {
  const paragraphs = announcement.body
    .split(/\n{2,}/)
    .map((block) => `<p style="margin:0 0 14px;line-height:1.9">${escapeHtml(block).replace(/\n/g, "<br/>")}</p>`)
    .join("");
  return `<div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;background:#f6f5f1;padding:28px">
    <div style="max-width:640px;margin:0 auto;background:#ffffff;border:1px solid #e6e3da;border-radius:10px;padding:26px">
      <p style="margin:0 0 6px;color:#7a776e;font-size:12px">SAI College · كلية ساي</p>
      <h1 style="margin:0 0 18px;font-size:20px;color:#20211d">${escapeHtml(announcement.title)}</h1>
      ${paragraphs}
      <hr style="border:none;border-top:1px solid #eee9df;margin:22px 0 14px" />
      <p style="margin:0;color:#7a776e;font-size:12px">هذه رسالة إدارية من كلية ساي. لا ترد على هذا البريد.</p>
    </div>
  </div>`;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return failure(405, "method_not_allowed", "استخدم طلب POST.");

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return failure(500, "server_misconfigured", "لم تُضبط مفاتيح الخادم.");
  }

  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return failure(401, "unauthorized", "يلزم تسجيل الدخول.");

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await authClient.auth.getUser(token);
  const caller = userData?.user;
  if (userError || !caller) return failure(401, "unauthorized", "جلسة الدخول غير صالحة.");

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return failure(400, "invalid_request", "طلب غير صالح.");
  }
  const announcementId = typeof payload === "object" && payload !== null && "announcementId" in payload
    ? (payload as { announcementId?: unknown }).announcementId
    : undefined;
  if (typeof announcementId !== "string" || !announcementId) {
    return failure(400, "invalid_request", "معرّف الإعلان مطلوب.");
  }

  const db = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: announcementData, error: announcementError } = await db
    .from("announcements")
    .select("id,branch_id,title,body,audience,is_published,published_at,expires_at")
    .eq("id", announcementId)
    .maybeSingle();
  if (announcementError) return failure(500, "lookup_failed", announcementError.message);
  if (!announcementData) return failure(404, "not_found", "الإعلان غير موجود.");
  const announcement = announcementData as Announcement;

  const { data: callerRoles, error: roleError } = await db
    .from("user_roles").select("role").eq("user_id", caller.id);
  if (roleError) return failure(500, "lookup_failed", roleError.message);
  const roles = new Set(((callerRoles ?? []) as { role: string }[]).map((row) => row.role));
  const isSuper = roles.has("super_admin");
  if (!isSuper && !roles.has("admin") && !roles.has("content_editor")) {
    return failure(403, "forbidden", "لا تملك صلاحية إرسال هذا الإعلان.");
  }
  if (announcement.branch_id && !isSuper) {
    const { data: membership } = await db.from("branch_memberships")
      .select("user_id").eq("user_id", caller.id)
      .eq("branch_id", announcement.branch_id).eq("is_active", true).maybeSingle();
    if (!membership) return failure(403, "forbidden_branch", "هذا الإعلان يخص فرعاً آخر.");
  }
  if (!announcement.is_published) return failure(400, "not_published", "انشر الإعلان قبل إرساله.");
  if (announcement.expires_at && new Date(announcement.expires_at).getTime() <= Date.now()) {
    return failure(400, "expired", "انتهت صلاحية الإعلان.");
  }

  const audience = AUDIENCE_ROLES[announcement.audience] ?? AUDIENCE_ROLES.all;
  const { data: audienceRoles, error: audienceError } = await db
    .from("user_roles").select("user_id,role").in("role", audience).limit(5000);
  if (audienceError) return failure(500, "lookup_failed", audienceError.message);

  let recipientIds = new Set(
    ((audienceRoles ?? []) as { user_id: string }[])
      .map((row) => row.user_id)
      .filter((id) => id !== caller.id),
  );

  if (announcement.branch_id) {
    const branchUsers = new Set<string>();
    const { data: members } = await db.from("branch_memberships")
      .select("user_id").eq("branch_id", announcement.branch_id).eq("is_active", true).limit(5000);
    ((members ?? []) as { user_id: string }[]).forEach((row) => branchUsers.add(row.user_id));

    const { data: studentRows } = await db.from("students")
      .select("id,user_id").eq("branch_id", announcement.branch_id).limit(5000);
    const studentIds: string[] = [];
    ((studentRows ?? []) as { id: string; user_id: string | null }[]).forEach((row) => {
      studentIds.push(row.id);
      if (row.user_id) branchUsers.add(row.user_id);
    });

    if (studentIds.length) {
      const { data: links } = await db.from("parent_student_links")
        .select("parent_user_id").in("student_id", studentIds)
        .not("verified_at", "is", null).limit(5000);
      ((links ?? []) as { parent_user_id: string }[]).forEach((row) => branchUsers.add(row.parent_user_id));
    }

    recipientIds = new Set([...recipientIds].filter((id) => branchUsers.has(id)));
  }

  const { data: deliveredRows } = await db.from("announcement_deliveries")
    .select("recipient_user_id,status").eq("announcement_id", announcement.id).eq("status", "sent");
  const alreadySent = new Set(
    ((deliveredRows ?? []) as { recipient_user_id: string }[]).map((row) => row.recipient_user_id),
  );

  const candidates = [...recipientIds].filter((id) => !alreadySent.has(id)).slice(0, MAX_RECIPIENTS);

  if (!candidates.length) {
    return json({
      announcementId: announcement.id,
      total: 0, sent: 0, failed: 0, skipped: 0, configured: true,
      message: "لا يوجد مستلمون جدد لهذا الإعلان.",
    });
  }

  const { data: profileRows, error: profileError } = await db.from("profiles")
    .select("id,email,full_name").in("id", candidates);
  if (profileError) return failure(500, "lookup_failed", profileError.message);
  const profiles = (profileRows ?? []) as Profile[];

  const resendKey = Deno.env.get("RESEND_API_KEY");
  const fromDomain = Deno.env.get("RESEND_FROM_DOMAIN");
  const fromAddress = fromDomain ? `SAI College <noreply@${fromDomain}>` : "";
  const configured = Boolean(resendKey && fromAddress);
  const attemptedAt = new Date().toISOString();

  const logRows: DeliveryRow[] = [];
  let sent = 0;
  let failed = 0;
  let skipped = 0;

  if (!configured) {
    for (const profile of profiles) {
      logRows.push({
        announcement_id: announcement.id,
        recipient_user_id: profile.id,
        recipient_email: profile.email ?? "",
        status: "skipped",
        provider_message_id: null,
        error: "email_not_configured",
        attempted_at: attemptedAt,
        sent_at: null,
      });
      skipped += 1;
    }
  } else {
    const html = buildHtml(announcement);
    for (const profile of profiles) {
      const email = (profile.email ?? "").trim();
      if (!email || !email.includes("@")) {
        logRows.push({
          announcement_id: announcement.id,
          recipient_user_id: profile.id,
          recipient_email: email,
          status: "skipped",
          provider_message_id: null,
          error: "missing_email",
          attempted_at: attemptedAt,
          sent_at: null,
        });
        skipped += 1;
        continue;
      }
      try {
        const response = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: fromAddress,
            to: [email],
            subject: announcement.title,
            html,
          }),
        });
        const text = await response.text();
        let parsed: { id?: string; message?: string; error?: { message?: string } } | null = null;
        try {
          parsed = JSON.parse(text) as { id?: string; message?: string; error?: { message?: string } };
        } catch {
          parsed = null;
        }
        if (!response.ok) {
          throw new Error(parsed?.message ?? parsed?.error?.message ?? text ?? `HTTP ${response.status}`);
        }
        sent += 1;
        logRows.push({
          announcement_id: announcement.id,
          recipient_user_id: profile.id,
          recipient_email: email,
          status: "sent",
          provider_message_id: parsed?.id ?? null,
          error: null,
          attempted_at: attemptedAt,
          sent_at: new Date().toISOString(),
        });
      } catch (error) {
        failed += 1;
        logRows.push({
          announcement_id: announcement.id,
          recipient_user_id: profile.id,
          recipient_email: email,
          status: "failed",
          provider_message_id: null,
          error: (error instanceof Error ? error.message : String(error)).slice(0, 500),
          attempted_at: attemptedAt,
          sent_at: null,
        });
      }
    }
  }

  if (logRows.length) {
    const { error: logError } = await db
      .from("announcement_deliveries")
      .upsert(logRows, { onConflict: "announcement_id,recipient_user_id" });
    if (logError) {
      return json({
        error: "log_failed",
        message: `تعذر تسجيل حالة الإرسال: ${logError.message}`,
        total: profiles.length, sent, failed, skipped, configured,
      }, 500);
    }
  }

  return json({
    announcementId: announcement.id,
    total: profiles.length,
    sent,
    failed,
    skipped,
    configured,
    message: configured
      ? `تم إرسال ${sent} رسالة.`
      : "البريد غير مضبوط: أضف RESEND_API_KEY و RESEND_FROM_DOMAIN إلى أسرار Supabase.",
  });
});