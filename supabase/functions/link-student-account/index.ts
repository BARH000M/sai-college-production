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

  const { data: callerRoles, error: rolesError } = await admin
    .from("user_roles")
    .select("role")
    .eq("user_id", caller.id);
  if (rolesError) return json({ ok: false, message: rolesError.message }, 500);
  const roleSet = new Set((callerRoles ?? []).map((row: { role: string }) => row.role));
  const isSuper = roleSet.has("super_admin");
  const isAdmin = roleSet.has("admin");
  if (!isSuper && !isAdmin) {
    return json({ ok: false, message: "هذا الإجراء متاح للإدارة فقط." }, 403);
  }

  async function callerBranches(): Promise<Set<string>> {
    const { data, error } = await admin
      .from("branch_memberships")
      .select("branch_id")
      .eq("user_id", caller.id)
      .eq("is_active", true);
    if (error) throw new Error(error.message);
    return new Set((data ?? []).map((row: { branch_id: string }) => row.branch_id));
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const action = typeof body.action === "string" ? body.action : "list";

  if (action === "list") {
    const accounts: { id: string; email: string; fullName: string }[] = [];
    for (let page = 1; page <= 10; page += 1) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
      if (error) return json({ ok: false, message: error.message }, 500);
      const batch = data?.users ?? [];
      batch.forEach((user) => {
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
      const { data: roleRows } = await admin.from("user_roles").select("user_id, role").in("user_id", ids);
      (roleRows ?? []).forEach((row: { user_id: string; role: string }) => {
        rolesByUser.set(row.user_id, [...(rolesByUser.get(row.user_id) ?? []), row.role]);
      });
      const { data: profileRows } = await admin.from("profiles").select("id, full_name").in("id", ids);
      (profileRows ?? []).forEach((row: { id: string; full_name: string }) => namesByUser.set(row.id, row.full_name));
      const { data: linkRows } = await admin.from("students").select("id, user_id").in("user_id", ids);
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
    if (!studentId) return json({ ok: false, message: "بيانات الطلب غير صالحة." }, 400);

    const { data: student, error: studentError } = await admin
      .from("students")
      .select("id, branch_id, user_id, full_name")
      .eq("id", studentId)
      .maybeSingle();
    if (studentError) return json({ ok: false, message: studentError.message }, 500);
    if (!student) return json({ ok: false, message: "سجل الطالب غير موجود." }, 404);

    if (!isSuper) {
      const branches = await callerBranches();
      if (!branches.has(student.branch_id)) {
        return json({ ok: false, message: "لا تملك صلاحية إدارة هذا الفرع." }, 403);
      }
    }

    if (action === "unlink") {
      const { error: clearError } = await admin
        .from("students").update({ user_id: null }).eq("id", studentId);
      if (clearError) return json({ ok: false, message: clearError.message }, 500);
      await admin.from("audit_logs").insert({
        actor_user_id: caller.id,
        action: "student_account_unlink",
        entity_type: "students",
        entity_id: studentId,
        metadata: { previous_user_id: student.user_id, source: "student_records" },
      });
      return json({ ok: true });
    }

    const userId = typeof body.userId === "string" ? body.userId : "";
    if (!userId) return json({ ok: false, message: "اختر حساب الدخول المراد ربطه." }, 400);

    const { data: target, error: targetError } = await admin.auth.admin.getUserById(userId);
    if (targetError || !target?.user) {
      return json({ ok: false, message: "الحساب المطلوب غير موجود." }, 404);
    }

    const { data: otherLink, error: otherError } = await admin
      .from("students").select("id").eq("user_id", userId).neq("id", studentId).maybeSingle();
    if (otherError) return json({ ok: false, message: otherError.message }, 500);
    if (otherLink) return json({ ok: false, message: "هذا الحساب مرتبط بطالب آخر بالفعل." }, 409);

    const { data: existingProfile } = await admin
      .from("profiles").select("id").eq("id", userId).maybeSingle();
    if (!existingProfile) {
      const metadata = (target.user.user_metadata ?? {}) as Record<string, unknown>;
      const fullName = (typeof metadata.full_name === "string" && metadata.full_name.trim())
        || target.user.email?.split("@")[0] || "مستخدم جديد";
      const { error: profileInsertError } = await admin.from("profiles").insert({
        id: userId, full_name: fullName, email: target.user.email ?? null,
      });
      if (profileInsertError) return json({ ok: false, message: profileInsertError.message }, 500);
    }

    const { data: linked, error: linkError } = await admin
      .from("students").update({ user_id: userId }).eq("id", studentId).select("id");
    if (linkError) return json({ ok: false, message: linkError.message }, 500);
    if (!linked?.length) return json({ ok: false, message: "لم يُحدّث سجل الطالب." }, 500);

    const { error: grantError } = await admin.from("user_roles").upsert(
      { user_id: userId, role: "student", assigned_by: caller.id },
      { onConflict: "user_id,role", ignoreDuplicates: true },
    );
    if (grantError) return json({ ok: false, message: grantError.message }, 500);

    await admin.from("audit_logs").insert({
      actor_user_id: caller.id,
      action: "student_account_link",
      entity_type: "students",
      entity_id: studentId,
      metadata: { user_id: userId, target_email: target.user.email ?? null, source: "student_records" },
    });

    return json({ ok: true, email: target.user.email ?? null });
  }

  return json({ ok: false, message: "إجراء غير معروف." }, 400);
});
