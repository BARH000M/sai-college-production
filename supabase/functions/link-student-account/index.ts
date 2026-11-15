import { createClient } from "https://esm.sh/@supabase/supabase-js@2.119.0";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Cache-Control": "no-store", "Content-Type": "application/json" },
  });
}

type AccountRow = {
  id: string;
  fullName: string;
  email: string;
  roles: string[];
  linkedStudentId: string | null;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, message: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    return json({ ok: false, message: "إعداد الخادم غير مكتمل." }, 500);
  }

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ ok: false, message: "يلزم تسجيل الدخول." }, 401);

  const authClient = createClient(url, anonKey, { auth: { persistSession: false } });
  const { data: callerData, error: callerError } = await authClient.auth.getUser(token);
  if (callerError || !callerData.user) {
    return json({ ok: false, message: "انتهت الجلسة؛ سجّل الدخول من جديد." }, 401);
  }
  const caller = callerData.user;

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const callerClient = createClient(url, anonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: callerRoles, error: rolesError } = await admin
    .from("user_roles")
    .select("role")
    .eq("user_id", caller.id);
  if (rolesError) return json({ ok: false, message: "Account operation failed" }, 500);
  const roleSet = new Set((callerRoles ?? []).map((row: { role: string }) => row.role));
  const isSuper = roleSet.has("super_admin");
  const isAdmin = roleSet.has("admin");
  if (!isSuper && !isAdmin) {
    return json({ ok: false, message: "هذا الإجراء متاح للإدارة فقط." }, 403);
  }

  async function callerBranches(): Promise<Set<string> | null> {
    const { data, error } = await admin
      .from("branch_memberships")
      .select("branch_id")
      .eq("user_id", caller.id)
      .eq("is_active", true);
    if (error) return null;
    return new Set((data ?? []).map((row: { branch_id: string }) => row.branch_id));
  }

  let body: Record<string, unknown> = {};
  try {
    const parsed: unknown = await req.json();
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      return json({ ok: false, message: "Invalid request body" }, 400);
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json({ ok: false, message: "Invalid JSON request body" }, 400);
  }
  const action = typeof body.action === "string" ? body.action : "list";

  if (action === "list") {
    const accounts: { id: string; email: string; fullName: string }[] = [];
    for (let page = 1; page <= 10; page += 1) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
      if (error) return json({ ok: false, message: "Account operation failed" }, 500);
      const batch = data?.users ?? [];
      batch.forEach((user) => {
        if (!user.email_confirmed_at && !user.phone_confirmed_at) return;
        const metadata = (user.user_metadata ?? {}) as Record<string, unknown>;
        accounts.push({
          id: user.id,
          email: user.email ?? "",
          fullName: typeof metadata.full_name === "string" ? metadata.full_name : "",
        });
      });
      if (batch.length < 200) break;
    }

    const ids = accounts.map((a) => a.id);
    const rolesByUser = new Map<string, string[]>();
    const namesByUser = new Map<string, string>();
    const linkedByUser = new Map<string, string>();
    if (ids.length) {
      const { data: roleRows, error: roleRowsError } = await admin
        .from("user_roles").select("user_id, role").in("user_id", ids);
      if (roleRowsError) return json({ ok: false, message: "Account operation failed" }, 500);
      (roleRows ?? []).forEach((row: { user_id: string; role: string }) => {
        rolesByUser.set(row.user_id, [...(rolesByUser.get(row.user_id) ?? []), row.role]);
      });
      const { data: profileRows, error: profileRowsError } = await admin
        .from("profiles").select("id, full_name").in("id", ids);
      if (profileRowsError) return json({ ok: false, message: "Account operation failed" }, 500);
      (profileRows ?? []).forEach((row: { id: string; full_name: string }) => namesByUser.set(row.id, row.full_name));
      const { data: linkRows, error: linkRowsError } = await admin
        .from("students").select("id, user_id").in("user_id", ids);
      if (linkRowsError) return json({ ok: false, message: "Account operation failed" }, 500);
      (linkRows ?? []).forEach((row: { id: string; user_id: string | null }) => {
        if (row.user_id) linkedByUser.set(row.user_id, row.id);
      });
    }

    const users: AccountRow[] = accounts.map((account) => ({
      id: account.id,
      fullName: namesByUser.get(account.id) || account.fullName || account.email.split("@")[0] || "بدون اسم",
      email: account.email,
      roles: rolesByUser.get(account.id) ?? [],
      linkedStudentId: linkedByUser.get(account.id) ?? null,
    }));

    return json({ ok: true, users });
  }

  if (action === "link" || action === "unlink") {
    const studentId = typeof body.studentId === "string" ? body.studentId : "";
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(studentId)) return json({ ok: false, message: "بيانات الطلب غير صالحة." }, 400);

    const { data: student, error: studentError } = await admin
      .from("students")
      .select("id, branch_id, user_id, full_name")
      .eq("id", studentId)
      .maybeSingle();
    if (studentError) return json({ ok: false, message: "Account operation failed" }, 500);
    if (!student) return json({ ok: false, message: "سجل الطالب غير موجود." }, 404);

    if (!isSuper) {
      const branches = await callerBranches();
      if (!branches) return json({ ok: false, message: "Account operation failed" }, 500);
      if (!branches.has(student.branch_id)) {
        return json({ ok: false, message: "لا تملك صلاحية إدارة هذا الفرع." }, 403);
      }
    }

    if (action === "unlink") {
      const { error: unlinkError } = await callerClient.rpc("admissions_unlink_student_account", {
        p_student_id: studentId,
      });
      if (unlinkError) return json({ ok: false, message: "Account operation failed" }, 500);
      return json({ ok: true });
    }

    const userId = typeof body.userId === "string" ? body.userId : "";
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(userId)) return json({ ok: false, message: "اختر حساب الدخول المراد ربطه." }, 400);

    const { data: target, error: targetError } = await admin.auth.admin.getUserById(userId);
    if (targetError || !target?.user) {
      return json({ ok: false, message: "الحساب المطلوب غير موجود." }, 404);
    }
    if (!target.user.email_confirmed_at && !target.user.phone_confirmed_at) {
      return json({ ok: false, message: "لا يمكن ربط حساب لم يتم التحقق من بريده أو هاتفه." }, 422);
    }

    const { error: linkError } = await callerClient.rpc("admissions_link_student_account", {
      p_student_id: studentId,
      p_user_id: userId,
    });
    if (linkError) {
      const status = linkError.code === "23505" ? 409 : 400;
      return json({ ok: false, message: "Account operation failed" }, status);
    }

    return json({ ok: true, email: target.user.email ?? null });
  }

  return json({ ok: false, message: "إجراء غير معروف." }, 400);
});
