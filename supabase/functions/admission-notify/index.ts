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

const STATUS_LABELS: Record<string, string> = {
  new: "تم استلام الطلب",
  contacted: "تم التواصل معك",
  assessment: "مرحلة التقييم",
  accepted: "تم القبول",
  enrolled: "تم التسجيل",
  rejected: "الطلب غير مقبول",
  withdrawn: "تم سحب الطلب",
};

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function safeUrl(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!/^https?:\/\/[^\s]+$/i.test(trimmed)) return null;
  return trimmed.slice(0, 500);
}

function formatDate(value: string | null): string {
  if (!value) return "—";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "—";
  return parsed.toLocaleDateString("ar-EG", { year: "numeric", month: "long", day: "numeric" });
}

type Enquiry = {
  application_no: string;
  applicant_full_name: string;
  guardian_name: string | null;
  phone: string | null;
  email: string | null;
  preferred_program: string | null;
  preferred_level: string | null;
  status: string;
  created_at: string;
  branch_id: string;
  academic_session_id: string;
};

type StatusContext = {
  application_no: string;
  applicant_full_name: string;
  email: string | null;
  status: string;
  previous_status: string | null;
  preferred_program: string | null;
  preferred_level: string | null;
  branch_name: string | null;
  session_name: string | null;
  occurrence: string | null;
};

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

function trackButton(statusUrl: string | null): string {
  if (!statusUrl) return "";
  return `<p style="margin:20px 0 0"><a href="${escapeHtml(statusUrl)}" style="display:inline-block;background:#0f5132;color:#ffffff;text-decoration:none;padding:11px 20px;border-radius:8px;font-size:14px">متابعة حالة الطلب</a></p>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, message: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !serviceKey) {
    return json({ ok: false, message: "إعداد الخادم غير مكتمل." }, 500);
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const mode = body.mode === "status_update" ? "status_update" : "submitted";
  const statusUrl = safeUrl(body.statusUrl);

  const apiKey = Deno.env.get("RESEND_API_KEY");
  const fromDomain = Deno.env.get("RESEND_FROM_DOMAIN");
  const from = fromDomain ? `SAI College Admissions <admissions@${fromDomain}>` : "";

  async function sendEmail(to: string, subject: string, html: string): Promise<boolean> {
    if (!apiKey || !fromDomain) return false;
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

  if (mode === "status_update") {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token || !anonKey) return json({ ok: false, message: "الجلسة غير صالحة." }, 401);

    const enquiryId = typeof body.enquiryId === "string" ? body.enquiryId.trim() : "";
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(enquiryId)) {
      return json({ ok: false, message: "معرّف الطلب غير صالح." }, 400);
    }

    const callerClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    const context = await callerClient.rpc("sai_admission_status_email_context", { p_enquiry_id: enquiryId });
    if (context.error) {
      const unauthorized = /not authorized|permission denied/i.test(context.error.message);
      return json({
        ok: false,
        sent: false,
        reason: unauthorized ? "NOT_AUTHORIZED" : "LOOKUP_FAILED",
        message: unauthorized ? "لا تملك صلاحية إشعار هذا الطلب." : "تعذر تحميل بيانات الطلب.",
      }, unauthorized ? 403 : 500);
    }

    const rows = Array.isArray(context.data) ? context.data as StatusContext[] : [];
    const record = rows[0];
    if (!record) return json({ ok: false, sent: false, reason: "NOT_FOUND", message: "الطلب غير موجود." }, 404);
    if (!record.email) return json({ ok: true, sent: false, reason: "NO_EMAIL" });
    if (!apiKey || !fromDomain) return json({ ok: true, sent: false, reason: "EMAIL_NOT_CONFIGURED" });

    const statusLabel = STATUS_LABELS[record.status] ?? record.status;
    const previousLabel = record.previous_status ? (STATUS_LABELS[record.previous_status] ?? record.previous_status) : null;
    const ref = escapeHtml(record.application_no);
    const name = escapeHtml(record.applicant_full_name);

    const html = layout({
      accent: "#0f5132",
      kicker: "كلية ساي التعليمية اليمنية الصينية — مكتب القبول",
      title: "تحديث على حالة طلب القبول",
      body: `
        <p style="margin:0">مرحباً ${name}،</p>
        <p style="margin:10px 0 0">نود إبلاغك بأنه تم تحديث حالة طلبك رقم <strong style="direction:ltr;display:inline-block">${ref}</strong>.</p>
        <p style="margin:16px 0;font-size:18px;font-weight:700;text-align:center;background:#eef3ee;border-radius:8px;padding:14px;color:#0f5132">${escapeHtml(statusLabel)}</p>
        ${previousLabel ? `<p style="margin:0;font-size:12px;color:#5b6159">الحالة السابقة: ${escapeHtml(previousLabel)}</p>` : ""}
        <table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:14px">
          <tr><td style="padding:8px 0;color:#5b6159">البرنامج</td><td style="padding:8px 0;font-weight:600">${escapeHtml(record.preferred_program ?? "—")}</td></tr>
          <tr><td style="padding:8px 0;color:#5b6159">الفرع</td><td style="padding:8px 0;font-weight:600">${escapeHtml(record.branch_name ?? "—")}</td></tr>
          <tr><td style="padding:8px 0;color:#5b6159">الجلسة</td><td style="padding:8px 0;font-weight:600">${escapeHtml(record.session_name ?? "—")}</td></tr>
          <tr><td style="padding:8px 0;color:#5b6159">تاريخ التحديث</td><td style="padding:8px 0;font-weight:600">${escapeHtml(formatDate(record.occurrence))}</td></tr>
        </table>
        ${trackButton(statusUrl)}
        <p style="margin:20px 0 0;color:#5b6159;font-size:12px">هذا البريد يُرسل تلقائيًا عند كل تغيير على حالة طلبك. للاستفسار تواصل مع مكتب القبول.</p>`,
    });

    const sent = await sendEmail(record.email, `تحديث حالة طلبك ${record.application_no} — ${statusLabel}`, html);
    return json({ ok: true, sent, reason: sent ? undefined : "SEND_FAILED" });
  }

  const reference = typeof body.reference === "string" ? body.reference.trim() : "";
  if (reference.length < 6 || reference.length > 80) {
    return json({ ok: false, message: "الرقم المرجعي غير صالح." }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  const { data: enquiry, error: enquiryError } = await admin
    .from("admissions_enquiries")
    .select("application_no,applicant_full_name,guardian_name,phone,email,preferred_program,preferred_level,status,created_at,branch_id,academic_session_id")
    .ilike("application_no", reference)
    .maybeSingle<Enquiry>();
  if (enquiryError) return json({ ok: false, message: enquiryError.message }, 500);
  if (!enquiry) return json({ ok: false, message: "الطلب غير موجود." }, 404);
  if (!enquiry.email) return json({ ok: true, sent: false, reason: "NO_EMAIL" });
  if (!apiKey || !fromDomain) return json({ ok: true, sent: false, reason: "EMAIL_NOT_CONFIGURED" });

  const teamInbox = Deno.env.get("ADMISSIONS_TEAM_EMAIL") ?? "info@saicollege.com";

  const [branchResult, sessionResult] = await Promise.all([
    admin.from("branches").select("name").eq("id", enquiry.branch_id).maybeSingle(),
    admin.from("academic_sessions").select("name").eq("id", enquiry.academic_session_id).maybeSingle(),
  ]);
  const branchName = (branchResult.data as { name?: string } | null)?.name ?? "—";
  const sessionName = (sessionResult.data as { name?: string } | null)?.name ?? "—";

  const statusLabel = STATUS_LABELS[enquiry.status] ?? enquiry.status;
  const program = enquiry.preferred_program ?? "—";
  const level = enquiry.preferred_level ?? "—";
  const submitted = formatDate(enquiry.created_at);
  const ref = escapeHtml(enquiry.application_no);
  const name = escapeHtml(enquiry.applicant_full_name);

  const applicantHtml = layout({
    accent: "#0f5132",
    kicker: "كلية ساي التعليمية اليمنية الصينية",
    title: "تم استلام طلب القبول",
    body: `
      <p style="margin:0">مرحباً ${name}،</p>
      <p style="margin:10px 0 0">شكراً لتقديمك على كلية ساي. تم تسجيل طلبك رسمياً، وهذا رقم الطلب المرجعي الذي ستحتاجه لمتابعة حالتك:</p>
      <p style="margin:14px 0;font-size:22px;font-weight:700;letter-spacing:1px;direction:ltr;text-align:center;background:#eef3ee;border-radius:8px;padding:12px">${ref}</p>
      <table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:8px">
        <tr><td style="padding:8px 0;color:#5b6159">البرنامج</td><td style="padding:8px 0;font-weight:600">${escapeHtml(String(program))}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">المستوى</td><td style="padding:8px 0;font-weight:600">${escapeHtml(String(level))}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">الفرع</td><td style="padding:8px 0;font-weight:600">${escapeHtml(branchName)}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">الجلسة</td><td style="padding:8px 0;font-weight:600">${escapeHtml(sessionName)}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">تاريخ التقديم</td><td style="padding:8px 0;font-weight:600">${escapeHtml(submitted)}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">حالة الطلب</td><td style="padding:8px 0;font-weight:600">${escapeHtml(statusLabel)}</td></tr>
      </table>
      ${trackButton(statusUrl)}
      <p style="margin:20px 0 0;color:#5b6159;font-size:12px">سيتواصل معك فريق القبول خلال أيام العمل القادمة. يرجى الاحتفاظ بهذا الرقم.</p>`,
  });

  const teamHtml = layout({
    accent: "#6b4f1d",
    kicker: "كلية ساي — مكتب القبول",
    title: "طلب قبول جديد",
    body: `
      <p style="margin:0">تم استلام طلب قبول جديد من الموقع الإلكتروني.</p>
      <table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:12px">
        <tr><td style="padding:8px 0;color:#5b6159">رقم الطلب</td><td style="padding:8px 0;font-weight:700;direction:ltr">${ref}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">المتقدم</td><td style="padding:8px 0;font-weight:600">${name}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">البريد</td><td style="padding:8px 0">${escapeHtml(enquiry.email ?? "—")}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">الهاتف</td><td style="padding:8px 0" dir="ltr">${escapeHtml(enquiry.phone ?? "—")}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">البرنامج</td><td style="padding:8px 0">${escapeHtml(String(program))}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">الفرع</td><td style="padding:8px 0">${escapeHtml(branchName)}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">الجلسة</td><td style="padding:8px 0">${escapeHtml(sessionName)}</td></tr>
        <tr><td style="padding:8px 0;color:#5b6159">تاريخ التقديم</td><td style="padding:8px 0">${escapeHtml(submitted)}</td></tr>
      </table>
      <p style="margin:20px 0 0;color:#5b6159;font-size:12px">يرجى تسجيل الدخول إلى بوابة الكلية لتعيين الطلب ومتابعته.</p>`,
  });

  const applicantSent = await sendEmail(
    enquiry.email,
    `تم استلام طلبك - ${enquiry.application_no}`,
    applicantHtml,
  );
  const teamSent = await sendEmail(
    teamInbox,
    `طلب قبول جديد ${enquiry.application_no} - ${enquiry.applicant_full_name}`,
    teamHtml,
  );

  return json({ ok: true, sent: applicantSent || teamSent, applicant: applicantSent, team: teamSent });
});
