import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.119.0";

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

type MutationGateClient = {
  rpc(name: "sai_assert_mutations_enabled"): PromiseLike<{
    error: { code?: string } | null;
  }>;
};

async function mutationGateOpen(client: MutationGateClient): Promise<boolean> {
  const { error } = await client.rpc("sai_assert_mutations_enabled");
  if (error) {
    console.error("Mutation gate rejected the operation", error.code ?? "unknown");
    return false;
  }
  return true;
}

// Every role the super administrator may grant from the portal.
const ASSIGNABLE = [
  "super_admin", "admin", "teacher", "receptionist",
  "accountant", "librarian", "content_editor", "parent", "student",
] as const;
type AssignableRole = (typeof ASSIGNABLE)[number];

// Staff roles are placed in the campus team so they become selectable in the
// admissions assignment dropdown. Parents and students never get a campus.
const BRANCH_SCOPED_ROLES = new Set<string>([
  "admin", "teacher", "receptionist", "accountant", "librarian", "content_editor",
]);
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function roleOperationFailure(code: string | undefined) {
  const known = new Set([
    "42501", "P0002", "22023", "23505", "23514",
  ]);
  const safeCode = code && known.has(code) ? code.toLowerCase() : "role_operation_failed";
  const status = code === "42501" ? 403
    : code === "P0002" ? 404
    : code === "23505" || code === "23514" ? 409
    : code === "22023" ? 422
    : 500;
  const message = code === "42501" ? "لا تملك صلاحية تنفيذ هذا الإجراء."
    : code === "P0002" ? "الدور المطلوب غير مسند إلى هذا الحساب."
    : code === "23505" ? "هذا الدور مسند للحساب بالفعل."
    : code === "23514" ? "لا يمكن سحب الدور من آخر مسؤول عام صالح للاستخدام."
    : code === "22023" ? "تعذر اعتماد البيانات؛ تحقق من تأكيد البريد ونطاق الفروع والتأكيد المطلوب."
    : "تعذر حفظ تغيير الصلاحيات؛ لم يتم تأكيد نجاح العملية.";
  return json({ ok: false, code: safeCode, message }, status);
}

type AccountRow = {
  id: string;
  fullName: string;
  email: string;
  roles: string[];
  branchIds: string[];
  createdAt: string;
  emailConfirmed: boolean;
  profileMissing: boolean;
};

type DashboardSummary = {
  totalUsers: number;
  emailConfirmedUsers: number;
  pendingEmailConfirmation: number;
  bannedUsers: number;
  usersWithoutRoles: number;
  totalProfiles: number;
  totalRoleAssignments: number;
  teachers: number;
  students: number;
  activeStudents: number;
  studentsWithoutAccounts: number;
  activeClasses: number;
  activeClassesWithoutTeachers: number;
  branches: number;
  academicSessions: number;
  courses: number;
  activeCourses: number;
  lessons: number;
  publishedLessons: number;
  lessonsWithAssetPaths: number;
  lessonsMissingContent: number;
  activeEnrollments: number;
  lessonProgressInProgress: number;
  legacyCompletedProgress: number;
  homeworkSubmissionsPendingReview: number;
  homeworkSubmissionsGraded: number;
  pendingAdmissions: number;
};

async function loadDashboardSummary(admin: SupabaseClient): Promise<DashboardSummary> {
  const accounts: { id: string; hasEmail: boolean; emailConfirmed: boolean; banned: boolean }[] = [];
  for (let page = 1; ; page += 1) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
    if (error) throw new Error(error.message);
    const batch = data?.users ?? [];
    for (const user of batch) {
      accounts.push({
        id: user.id,
        hasEmail: !!user.email,
        emailConfirmed: !!user.email_confirmed_at,
        banned: !!user.banned_until && Date.parse(user.banned_until) > Date.now(),
      });
    }
    if (batch.length < 200) break;
  }

  const countQueries = {
    profiles: admin.from("profiles").select("id", { count: "exact", head: true }),
    roles: admin.from("user_roles").select("user_id", { count: "exact", head: true }),
    teachers: admin.from("user_roles").select("user_id", { count: "exact", head: true }).eq("role", "teacher"),
    students: admin.from("students").select("id", { count: "exact", head: true }),
    activeStudents: admin.from("students").select("id", { count: "exact", head: true }).eq("status", "active"),
    studentsWithoutAccounts: admin.from("students").select("id", { count: "exact", head: true }).is("user_id", null),
    activeClasses: admin.from("classes").select("id", { count: "exact", head: true }).eq("is_active", true),
    activeClassesWithoutTeachers: admin.from("classes").select("id", { count: "exact", head: true })
      .eq("is_active", true).is("teacher_id", null),
    branches: admin.from("branches").select("id", { count: "exact", head: true }),
    academicSessions: admin.from("academic_sessions").select("id", { count: "exact", head: true }),
    courses: admin.from("learning_courses").select("id", { count: "exact", head: true }),
    activeCourses: admin.from("learning_courses").select("id", { count: "exact", head: true }).eq("is_active", true),
    lessons: admin.from("learning_lessons").select("id", { count: "exact", head: true }),
    publishedLessons: admin.from("learning_lessons").select("id", { count: "exact", head: true }).eq("is_published", true),
    lessonsWithAssetPaths: admin.from("learning_lessons").select("id", { count: "exact", head: true }).not("content_path", "is", null),
    lessonsMissingContent: admin.from("learning_lessons").select("id", { count: "exact", head: true })
      .eq("content_kind", "none").is("content_body", null).is("content_url", null).is("content_path", null),
    activeEnrollments: admin.from("students").select("id", { count: "exact", head: true })
      .eq("status", "active").not("class_id", "is", null),
    lessonProgressInProgress: admin.from("learning_lesson_progress").select("lesson_id", { count: "exact", head: true })
      .eq("status", "in_progress"),
    legacyCompletedProgress: admin.from("learning_lesson_progress").select("lesson_id", { count: "exact", head: true })
      .eq("status", "completed"),
    homeworkSubmissionsPendingReview: admin.from("learning_homework_submissions")
      .select("id", { count: "exact", head: true }).eq("status", "submitted"),
    homeworkSubmissionsGraded: admin.from("learning_homework_submissions")
      .select("id", { count: "exact", head: true }).eq("status", "graded"),
    pendingAdmissions: admin.from("admissions_enquiries").select("id", { count: "exact", head: true })
      .eq("status", "new"),
  };
  const names = Object.keys(countQueries) as (keyof typeof countQueries)[];
  const results = await Promise.all(Object.values(countQueries));
  const counts = new Map<string, number>();
  results.forEach((result, index) => {
    if (result.error) throw new Error(`${names[index]}: ${result.error.message}`);
    if (result.count === null) throw new Error(`${names[index]}: count was not returned`);
    counts.set(names[index], result.count);
  });

  const roleUserIds = new Set<string>();
  for (let from = 0; ; from += 1000) {
    const { data, error } = await admin.from("user_roles").select("user_id").order("user_id").range(from, from + 999);
    if (error) throw new Error(error.message);
    for (const row of data ?? []) roleUserIds.add(row.user_id);
    if (!data || data.length < 1000) break;
  }

  const count = (key: string) => {
    const value = counts.get(key);
    if (value === undefined) throw new Error(`Missing dashboard count: ${key}`);
    return value;
  };
  const confirmed = accounts.filter((account) => account.emailConfirmed).length;
  const pendingEmail = accounts.filter((account) => account.hasEmail && !account.emailConfirmed).length;

  return {
    totalUsers: accounts.length,
    emailConfirmedUsers: confirmed,
    pendingEmailConfirmation: pendingEmail,
    bannedUsers: accounts.filter((account) => account.banned).length,
    usersWithoutRoles: accounts.filter((account) => !roleUserIds.has(account.id)).length,
    totalProfiles: count("profiles"),
    totalRoleAssignments: count("roles"),
    teachers: count("teachers"),
    students: count("students"),
    activeStudents: count("activeStudents"),
    studentsWithoutAccounts: count("studentsWithoutAccounts"),
    activeClasses: count("activeClasses"),
    activeClassesWithoutTeachers: count("activeClassesWithoutTeachers"),
    branches: count("branches"),
    academicSessions: count("academicSessions"),
    courses: count("courses"),
    activeCourses: count("activeCourses"),
    lessons: count("lessons"),
    publishedLessons: count("publishedLessons"),
    lessonsWithAssetPaths: count("lessonsWithAssetPaths"),
    lessonsMissingContent: count("lessonsMissingContent"),
    activeEnrollments: count("activeEnrollments"),
    lessonProgressInProgress: count("lessonProgressInProgress"),
    legacyCompletedProgress: count("legacyCompletedProgress"),
    homeworkSubmissionsPendingReview: count("homeworkSubmissionsPendingReview"),
    homeworkSubmissionsGraded: count("homeworkSubmissionsGraded"),
    pendingAdmissions: count("pendingAdmissions"),
  };
}

async function handleManageRoles(req: Request): Promise<Response> {
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

  const authClient = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const { data: callerData, error: callerError } = await authClient.auth.getUser(token);
  if (callerError || !callerData.user) {
    return json({ ok: false, message: "انتهت الجلسة؛ سجّل الدخول من جديد." }, 401);
  }
  const caller = callerData.user;
  if (!caller.email_confirmed_at || caller.deleted_at
    || (caller.banned_until && Date.parse(caller.banned_until) > Date.now())) {
    return json({ ok: false, code: "caller_unusable", message: "الحساب غير متاح لتنفيذ تغييرات الصلاحيات." }, 403);
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  let body: Record<string, unknown>;
  try {
    const parsed: unknown = await req.json();
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      return json({ ok: false, code: "invalid_request", message: "بيانات الطلب غير صالحة." }, 400);
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json({ ok: false, code: "invalid_request", message: "تعذر قراءة الطلب." }, 400);
  }
  const action = typeof body.action === "string" ? body.action : "";
  if (!action) return json({ ok: false, code: "action_required", message: "الإجراء المطلوب غير محدد." }, 400);
  if ((action === "grant" || action === "revoke") && Deno.env.get("PHASE3B_MUTATIONS_DISABLED") === "true") {
    return json({ ok: false, code: "maintenance", message: "تغييرات الصلاحيات متوقفة مؤقتاً للصيانة." }, 503);
  }

  const { data: superRole, error: superError } = await admin
    .from("user_roles")
    .select("role")
    .eq("user_id", caller.id)
    .eq("role", "super_admin")
    .maybeSingle();
  if (superError) return json({ ok: false, message: superError.message }, 500);
  if (!superRole) return json({ ok: false, message: "هذه الصفحة متاحة للمسؤول العام فقط." }, 403);

  if ((action === "grant" || action === "revoke") && !await mutationGateOpen(admin)) {
    return json({ ok: false, code: "maintenance", message: "تغييرات الصلاحيات متوقفة مؤقتاً للصيانة." }, 503);
  }

  if (action === "summary") {
    try {
      return json({ ok: true, summary: await loadDashboardSummary(admin) });
    } catch (error) {
      return json({ ok: false, message: error instanceof Error ? error.message : String(error) }, 500);
    }
  }

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
    const branchesByUser = new Map<string, string[]>();
    const activeBranches: { id: string; name: string }[] = [];
    const { data: branchRows, error: branchError } = await admin
      .from("branches")
      .select("id,name")
      .eq("is_active", true)
      .order("name");
    if (branchError) return json({ ok: false, message: "تعذر تحميل نطاقات الفروع." }, 500);
    (branchRows ?? []).forEach((row: { id: string; name: string }) => activeBranches.push(row));

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

      const { data: membershipRows, error: membershipError } = await admin
        .from("branch_memberships")
        .select("user_id,branch_id")
        .in("user_id", ids)
        .eq("is_active", true);
      if (membershipError) return json({ ok: false, message: "تعذر تحميل نطاقات الحسابات." }, 500);
      (membershipRows ?? []).forEach((row: { user_id: string; branch_id: string }) => {
        branchesByUser.set(row.user_id, [...(branchesByUser.get(row.user_id) ?? []), row.branch_id]);
      });
    }

    const users: AccountRow[] = accounts.map((account) => ({
      id: account.id,
      fullName: namesByUser.get(account.id) || account.fullName || account.email.split("@")[0] || "بدون اسم",
      email: account.email,
      roles: rolesByUser.get(account.id) ?? [],
      branchIds: branchesByUser.get(account.id) ?? [],
      createdAt: account.createdAt,
      emailConfirmed: account.emailConfirmed,
      profileMissing: !namesByUser.has(account.id),
    }));

    return json({ ok: true, users, branches: activeBranches });
  }

  if (action === "grant" || action === "revoke") {
    const userId = typeof body.userId === "string" ? body.userId : "";
    const role = typeof body.role === "string" ? body.role : "";
    if (!UUID_PATTERN.test(userId) || !ASSIGNABLE.includes(role as AssignableRole)) {
      return json({ ok: false, code: "invalid_request", message: "بيانات الطلب غير صالحة." }, 400);
    }

    const rawBranchIds = body.branchIds ?? [];
    if (!Array.isArray(rawBranchIds) || rawBranchIds.some((id) => typeof id !== "string" || !UUID_PATTERN.test(id))) {
      return json({ ok: false, code: "invalid_branch_scope", message: "نطاق الفروع المحدد غير صالح." }, 400);
    }
    const branchIds = rawBranchIds as string[];
    if (action === "grant" && BRANCH_SCOPED_ROLES.has(role) && !branchIds.length) {
      return json({ ok: false, code: "branch_required", message: "اختر فرعاً نشطاً واحداً على الأقل لهذا الحساب." }, 422);
    }
    if ((!BRANCH_SCOPED_ROLES.has(role) || action === "revoke") && branchIds.length) {
      return json({ ok: false, code: "invalid_branch_scope", message: "لا يُقبل نطاق فروع لهذا الإجراء." }, 400);
    }
    const confirmSuperAdminGrant = body.confirmSuperAdminGrant === true;
    if (action === "grant" && role === "super_admin" && !confirmSuperAdminGrant) {
      return json({ ok: false, code: "super_admin_confirmation_required", message: "يلزم تأكيد إضافي لمنح صلاحية المسؤول العام." }, 422);
    }

    const { data: target, error: targetError } = await admin.auth.admin.getUserById(userId);
    if (targetError || !target?.user) {
      return json({ ok: false, message: "الحساب المطلوب غير موجود." }, 404);
    }

    if (action === "grant" && !target.user.email_confirmed_at) {
      return json({ ok: false, code: "email_verification_required", message: "يجب تأكيد البريد الإلكتروني قبل منح الدور." }, 422);
    }

    const metadata = (target.user.user_metadata ?? {}) as Record<string, unknown>;
    const fullName = (typeof metadata.full_name === "string" && metadata.full_name.trim())
      || target.user.email?.split("@")[0]
      || "مستخدم جديد";
    const { data: assignment, error: assignmentError } = await admin.rpc("sai_manage_role_assignment", {
      p_actor_id: caller.id,
      p_target_id: userId,
      p_action: action,
      p_role: role,
      p_branch_ids: branchIds,
      p_email_confirmed: !!target.user.email_confirmed_at,
      p_confirm_super_admin: confirmSuperAdminGrant,
      p_target_email: target.user.email ?? null,
      p_full_name: fullName,
    });
    if (assignmentError) return roleOperationFailure(assignmentError.code);
    if (!assignment || assignment.ok !== true || assignment.action !== action || assignment.role !== role) {
      return json({ ok: false, code: "role_operation_unconfirmed", message: "تعذر تأكيد نتيجة تغيير الصلاحيات؛ حدّث القائمة للتحقق." }, 500);
    }

    return json({ ok: true, code: action === "grant" ? "role_granted" : "role_revoked" });
  }

  return json({ ok: false, message: "إجراء غير معروف." }, 400);
}

Deno.serve(handleManageRoles);
