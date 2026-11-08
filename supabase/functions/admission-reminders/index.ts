import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

type Candidate = {
  enquiry_id: string;
  application_no: string;
  applicant_full_name: string;
  email: string | null;
  phone: string | null;
  preferred_program: string | null;
  preferred_level: string | null;
  branch_name: string | null;
  session_name: string | null;
  status: string;
  created_at: string;
  days_open: number;
};

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function formatDate(value: string | null): string {
  if (!value) return "—";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "—";
  return parsed.toLocaleDateString("ar-EG", { year: "numeric", month: "long", day: "numeric" });
}

function businessDate(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Riyadh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function layout(options: { accent: string; kicker: string; title: string; body: string }) {
  return `
  <div dir="rtl" style="font-family:'Segoe UI',Tahoma,Arial,sans-serif;background:#f6f7f4;padding:24px">
    <div style="max-width:600px;margin:0 auto;background:#ffffff;border:1px solid #e4e6e0;border-radius:12px;overflow:hidden">
      <div style="background:${options.accent};padding:22px 24px;color:#ffffff">
        <p style="margin:0;font-size:13px;opacity:.85">${options.kicker}</p>
        <h1 style="margin:6px 0 0;font-size:20px">${options.title}</h1>
      </div>
      <div style="padding:24px;color:#1f241f;font-size:14px;line-height:1.9">
        ${options.body}
      </div>
    </div>
  </div>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, message: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return json({ ok: false, message: "Server configuration is incomplete." }, 500);
  }

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

  let manual = false;
  try {
    const body = await req.json() as { mode?: unknown } | null;
    manual = body?.mode === "manual";
  } catch {
    manual = false;
  }

  if (manual) {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7).trim() : "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!token || !anonKey) return json({ ok: false, message: "Not authorized" }, 401);

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser(token);
    if (userError || !userData?.user) return json({ ok: false, message: "Not authorized" }, 401);

    const roleCheck = await admin.from("user_roles")
      .select("role")
      .eq("user_id", userData.user.id)
      .eq("role", "super_admin")
      .maybeSingle();
    if (roleCheck.error) return json({ ok: false, message: roleCheck.error.message }, 500);
    if (!roleCheck.data) {
      return json({ ok: false, message: "Only super administrators can run reminders manually." }, 403);
    }
  }

  const runDate = businessDate();
  if (!manual) {
    const lock = await admin.from("admission_reminder_runs").insert({ run_date: runDate }).select("run_date");
    if (lock.error) {
      if (lock.error.code === "23505") return json({ ok: true, skipped: true, reason: "ALREADY_RAN_TODAY" });
      return json({ ok: false, message: lock.error.message }, 500);
    }
  }

  const releaseLock = async () => {
    if (manual) return;
    await admin.from("admission_reminder_runs").delete().eq("run_date", runDate);
  };

  const candidates = await admin.rpc("sai_admission_reminder_candidates");
  if (candidates.error) {
    await releaseLock();
    return json({ ok: false, message: candidates.error.message }, 500);
  }

  const rows = (Array.isArray(candidates.data) ? candidates.data : []) as Candidate[];
  if (!rows.length) {
    if (!manual) {
      await admin.from("admission_reminder_runs").update({ finished_at: new Date().toISOString(), sent_count: 0 }).eq("run_date", runDate);
    }
    return json({ ok: true, mode: manual ? "manual" : "scheduled", candidates: 0, sent: 0 });
  }

  const apiKey = Deno.env.get("RESEND_API_KEY");
  const fromDomain = Deno.env.get("RESEND_FROM_DOMAIN");
  if (!apiKey || !fromDomain) {
    await releaseLock();
    return json({ ok: true, skipped: false, reason: "EMAIL_NOT_CONFIGURED", candidates: rows.length, sent: 0 });
  }

  const from = `SAI College Admissions <admissions@${fromDomain}>`;
  const teamInbox = Deno.env.get("ADMISSIONS_TEAM_EMAIL") ?? "info@saicollege.com";

  async function sendEmail(to: string, subject: string, html: string): Promise<boolean> {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from, to: [to], subject, html }),
    });
    if (!response.ok) {
      const detail = await response.text();
      console.error("Resend error", response.status, detail.slice(0, 300));
      return false;
    }
    return true;
  }

  const handled: string[] = [];
  let applicantSent = 0;

  for (const row of rows) {
    if (!row.email) {
      handled.push(row.enquiry_id);
      continue;
    }
    const name = escapeHtml(row.applicant_full_name);
    const ref = escapeHtml(row.application_no);
    const html = layout({
      accent: "#6b4f1d",
      kicker: "كلية ساي التعليمية اليمنية الصينية — مكتب القبول",
      title: "طلبك لا يزال قيد المراجعة",
      body: `
        <p style="margin:0">مرحباً ${name}،</p>
        <p style="margin:10px 0 0">نود تذكيرك بأن طلب القبول رقم <strong style="direction:ltr;display:inline-block">${ref}</strong> لا يزال قيد المراجعة الأولية في مكتب القبول منذ ${escapeHtml(String(row.days_open))} يوماً.</p>
        <p style="margin:12px 0 0">لا يلزمك أي إجراء في الوقت الحالي. سيتواصل معك فريق القبول هاتفياً أو عبر البريد عند بدء مراجعة طلبك.</p>
        <table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:14px">
          <tr><td style="padding:8px 0;color:#5b6159">البرنامج</td><td style="padding:8px 0;font-weight:600">${escapeHtml(row.preferred_program ?? "—")}</td></tr>
          <tr><td style="padding:8px 0;color:#5b6159">المستوى</td><td style="padding:8px 0;font-weight:600">${escapeHtml(row.preferred_level ?? "—")}</td></tr>
          <tr><td style="padding:8px 0;color:#5b6159">الفرع</td><td style="padding:8px 0;font-weight:600">${escapeHtml(row.branch_name ?? "—")}</td></tr>
          <tr><td style="padding:8px 0;color:#5b6159">الجلسة</td><td style="padding:8px 0;font-weight:600">${escapeHtml(row.session_name ?? "—")}</td></tr>
          <tr><td style="padding:8px 0;color:#5b6159">تاريخ التقديم</td><td style="padding:8px 0;font-weight:600">${escapeHtml(formatDate(row.created_at))}</td></tr>
        </table>
        <p style="margin:20px 0 0;color:#5b6159;font-size:12px">تصلك هذه الرسالة مرة واحدة فقط لكل طلب. للاستفسار تواصل مع مكتب القبول.</p>`,
    });
    const ok = await sendEmail(row.email, `تذكير بشأن طلب القبول ${row.application_no}`, html);
    if (ok) {
      applicantSent += 1;
      handled.push(row.enquiry_id);
    }
  }

  const digestRows = rows.map((row) => `
    <tr>
      <td style="padding:8px 6px;border-bottom:1px solid #eceee9;direction:ltr">${escapeHtml(row.application_no)}</td>
      <td style="padding:8px 6px;border-bottom:1px solid #eceee9">${escapeHtml(row.applicant_full_name)}</td>
      <td style="padding:8px 6px;border-bottom:1px solid #eceee9">${escapeHtml(row.preferred_program ?? "—")}</td>
      <td style="padding:8px 6px;border-bottom:1px solid #eceee9">${escapeHtml(row.branch_name ?? "—")}</td>
      <td style="padding:8px 6px;border-bottom:1px solid #eceee9;text-align:center">${escapeHtml(String(row.days_open))}</td>
    </tr>`).join("");

  const teamHtml = layout({
    accent: "#0f5132",
    kicker: "كلية ساي — مكتب القبول",
    title: "طلبات بانتظار أول تواصل منذ أكثر من ثلاثة أيام",
    body: `
      <p style="margin:0">هذه الطلبات ما زالت في حالة «جديد» ولم يُسجّل لها أي تواصل. يرجى مراجعتها وتعيينها اليوم.</p>
      <table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:14px">
        <thead>
          <tr style="text-align:right;color:#5b6159">
            <th style="padding:6px">رقم الطلب</th><th style="padding:6px">المتقدم</th>
            <th style="padding:6px">البرنامج</th><th style="padding:6px">الفرع</th><th style="padding:6px">أيام</th>
          </tr>
        </thead>
        <tbody>${digestRows}</tbody>
      </table>
      <p style="margin:20px 0 0;color:#5b6159;font-size:12px">أُرسلت هذه الرسالة تلقائياً مرة واحدة يومياً. سيُذكَّر كل طلب مرة واحدة فقط.</p>`,
  });

  const teamSent = await sendEmail(
    teamInbox,
    `تذكير: ${rows.length} طلب قبول بانتظار أول تواصل`,
    teamHtml,
  );

  let logged = 0;
  if (handled.length) {
    const log = await admin.from("admission_reminder_log").insert(
      handled.map((id) => ({ enquiry_id: id, reminder_kind: "stale_new" })),
    );
    if (log.error) console.error("reminder log error", log.error.message);
    else logged = handled.length;
  }

  if (!manual) {
    await admin.from("admission_reminder_runs")
      .update({ finished_at: new Date().toISOString(), sent_count: applicantSent })
      .eq("run_date", runDate);
  }

  return json({
    ok: true,
    mode: manual ? "manual" : "scheduled",
    candidates: rows.length,
    applicantEmails: applicantSent,
    teamDigest: teamSent,
    logged,
  });
});
