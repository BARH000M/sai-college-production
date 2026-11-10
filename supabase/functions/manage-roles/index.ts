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

// Every role the super administrator may grant from the portal.
const ASSIGNABLE = [
  "super_admin", "admin", "teacher", "receptionist",
  "accountant", "librarian", "content_editor", "parent", "student",
] as const;
type AssignableRole = (typeof ASSIGNABLE)[number];

// Staff roles are placed in the campus team so they become selectable in the
// admissions assignment dropdown. Parents and students never get a campus.
const STAFF_ROLES = new Set<string>([
  "super_admin", "admin", "teacher", "receptionist", "accountant", "librarian", "content_editor",
]);

type AccountRow = {
  id: string;
  fullName: string;
  email: string;
  roles: string[];
  createdAt: string;
  emailConfirmed: boolean;
  profileMissing: boolean;
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
  const { data: superRole, error: superError } = await admin
    .from("user_roles")
    .select("role")
    .eq("user_id", caller.id)
    .eq("role", "super_admin")
    .maybeSingle();
  if (superError) return json({ ok: false, message: superError.message }, 500);
  if (!superRole) return json({ ok: false, message: "هذه الصفحة متاحة للمسؤول العام فقط." }, 403);

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const action = typeof body.action === "string" ? body.action : "list";

  if (action === "list") {
    const accounts: { id: string; email: string; createdAt: string; fullName: string; emailConfirmed: boolean }[] = [];
    for (let page = 1; page <= 10; page += 1) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
      if (error) return json({ ok: false, message: error.message }, 500);
      const batch = data?.users ?? [];
      batch.forEach((user) => {
        const metadata = (user.user_metadata ?? {}) as Record<string, unknown>;
        accounts.push({
          id: user.id,
          email: user.email ?? "",
          createdAt: user.created_at ?? new Date().toISOString(),
          fullName: typeof metadata.full_name === "string" ? metadata.full_name : "",
          emailConfirmed: !!user.email_confirmed_at,
        });
      });
      if (batch.length < 200) break;
    }

    const ids = accounts.map((account) => account.id);
    const rolesByUser = new Map<string, string[]>();
    const namesByUser = new Map<string, string>();
    if (ids.length) {
      const { data: roleRows, error: roleError } = await admin
        .from("user_roles")
        .select("user_id, role")
        .in("user_id", ids);
      if (roleError) return json({ ok: false, message: roleError.message }, 500);
      (roleRows ?? []).forEach((row: { user_id: string; role: string }) => {
        rolesByUser.set(row.user_id, [...(rolesByUser.get(row.user_id) ?? []), row.role]);
      });

      const { data: profileRows, error: profileError } = await admin
        .from("profiles")
        .select("id, full_name")
        .in("id", ids);
      if (profileError) return json({ ok: false, message: profileError.message }, 500);
      (profileRows ?? []).forEach((row: { id: string; full_name: string }) => {
        namesByUser.set(row.id, row.full_name);
      });
    }

    const users: AccountRow[] = accounts.map((account) => ({
      id: account.id,
      fullName: namesByUser.get(account.id) || account.fullName || account.email.split("@")[0] || "بدون اسم",
      email: account.email,
      roles: rolesByUser.get(account.id) ?? [],
      createdAt: account.createdAt,
      emailConfirmed: account.emailConfirmed,
      profileMissing: !namesByUser.has(account.id),
    }));

    return json({ ok: true, users });
  }

  if (action === "grant" || action === "revoke") {
    const userId = typeof body.userId === "string" ? body.userId : "";
    const role = typeof body.role === "string" ? body.role : "";
    if (!userId || !ASSIGNABLE.includes(role as AssignableRole)) {
      return json({ ok: false, message: "بيانات الطلب غير صالحة." }, 400);
    }
    if (userId === caller.id && action === "revoke" && role === "super_admin") {
      return json({ ok: false, message: "لا يمكنك سحب صلاحية المسؤول العام من حسابك." }, 400);
    }

    const { data: target, error: targetError } = await admin.auth.admin.getUserById(userId);
    if (targetError || !target?.user) {
      return json({ ok: false, message: "الحساب المطلوب غير موجود." }, 404);
    }

    if (action === "grant") {
      const { data: existingProfile } = await admin
        .from("profiles")
        .select("id")
        .eq("id", userId)
        .maybeSingle();
      if (!existingProfile) {
        const metadata = (target.user.user_metadata ?? {}) as Record<string, unknown>;
        const fullName = (typeof metadata.full_name === "string" && metadata.full_name.trim())
          || target.user.email?.split("@")[0]
          || "مستخدم جديد";
        const { error: profileInsertError } = await admin.from("profiles").insert({
          id: userId,
          full_name: fullName,
          email: target.user.email ?? null,
        });
        if (profileInsertError) return json({ ok: false, message: profileInsertError.message }, 500);
      }

      const { error: grantError } = await admin.from("user_roles").upsert(
        { user_id: userId, role, assigned_by: caller.id },
        { onConflict: "user_id,role", ignoreDuplicates: true },
      );
      if (grantError) return json({ ok: false, message: grantError.message }, 500);

      // A staff role joins the campus team so the person can be assigned work.
      if (STAFF_ROLES.has(role)) {
        const { data: branches, error: branchError } = await admin
          .from("branches")
          .select("id")
          .eq("is_active", true);
        if (branchError) return json({ ok: false, message: branchError.message }, 500);
        const rows = (branches ?? []).map((branch: { id: string }) => ({
          user_id: userId, branch_id: branch.id, is_active: true,
        }));
        if (rows.length) {
          const { error: membershipError } = await admin
            .from("branch_memberships")
            .upsert(rows, { onConflict: "user_id,branch_id", ignoreDuplicates: true });
          if (membershipError) return json({ ok: false, message: membershipError.message }, 500);
        }
      }
    } else {
      const { error: revokeError } = await admin
        .from("user_roles")
        .delete()
        .eq("user_id", userId)
        .eq("role", role);
      if (revokeError) return json({ ok: false, message: revokeError.message }, 500);

      // If no staff role remains, remove the person from the campus team.
      if (STAFF_ROLES.has(role)) {
        const { data: remaining, error: remainingError } = await admin
          .from("user_roles")
          .select("role")
          .eq("user_id", userId);
        if (remainingError) return json({ ok: false, message: remainingError.message }, 500);
        const stillStaff = (remaining ?? []).some((row: { role: string }) => STAFF_ROLES.has(row.role));
        if (!stillStaff) {
          const { error: membershipError } = await admin
            .from("branch_memberships")
            .delete()
            .eq("user_id", userId);
          if (membershipError) return json({ ok: false, message: membershipError.message }, 500);
        }
      }
    }

    await admin.from("audit_logs").insert({
      actor_user_id: caller.id,
      action: action === "grant" ? "role_grant" : "role_revoke",
      entity_type: "user_roles",
      entity_id: userId,
      metadata: { role, source: "role_management", target_email: target.user.email ?? null },
    });

    return json({ ok: true });
  }

  return json({ ok: false, message: "إجراء غير معروف." }, 400);
});
