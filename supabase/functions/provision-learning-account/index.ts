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

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

type EmailResult = { sent: boolean; reason?: string };

async function sendTeacherEmail(to: string, subject: string, html: string): Promise<EmailResult> {
  if (!to) return { sent: false, reason: "NO_EMAIL" };
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const fromDomain = Deno.env.get("RESEND_FROM_DOMAIN");
  if (!apiKey || !fromDomain) return { sent: false, reason: "EMAIL_NOT_CONFIGURED" };
  const from = `SAI College <noreply@${fromDomain}>`;
  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from, to: [to], subject, html }),
    });
    if (!response.ok) {
      const detail = await response.text();
      console.error("Resend error", response.status, detail.slice(0, 300));
      return { sent: false, reason: "SEND_FAILED" };
    }
    return { sent: true };
  } catch (error) {
    console.error("Resend request failed", error);
    return { sent: false, reason: "SEND_FAILED" };
  }
}

function emailShell(options: { title: string; body: string }): string {
  return `
  <div dir="rtl" style="font-family:'Segoe UI',Tahoma,Arial,sans-serif;background:#f6f7f4;padding:24px">
    <div style="max-width:600px;margin:0 auto;background:#ffffff;border:1px solid #e4e6e0;border-radius:12px;overflow:hidden">
      <div style="background:#0f5132;padding:22px 24px;color:#ffffff">
        <p style="margin:0;font-size:13px;opacity:.85">بوابة كلية ساي التعليمية اليمنية الصينية</p>
        <h1 style="margin:6px 0 0;font-size:20px">${options.title}</h1>
      </div>
      <div style="padding:24px;color:#1f241f;font-size:14px;line-height:1.9">${options.body}</div>
    </div>
  </div>`;
}

type ProfileRow = { id: string; full_name: string | null; email: string | null };
type ClassRow = { id: string; name: string; program: string | null };
type StudentRow = {
  id: string;
  full_name: string;
  admission_no: string;
  class_id: string | null;
  user_id: string | null;
};
type LinkRow = { parent_user_id: string; student_id: string; verified_at: string | null };

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
  if (!superRole) return json({ ok: false, message: "هذه العملية متاحة للمسؤول العام فقط." }, 403);

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const action = text(body.action) || "overview";

  if (action === "overview") {
    const students = await admin
      .from("students")
      .select("id,full_name,admission_no,class_id,user_id")
      .order("full_name");
    if (students.error) return json({ ok: false, message: students.error.message }, 500);

    const classes = await admin.from("classes").select("id,name,program");
    if (classes.error) return json({ ok: false, message: classes.error.message }, 500);

    const links = await admin
      .from("parent_student_links")
      .select("parent_user_id,student_id,verified_at");
    if (links.error) return json({ ok: false, message: links.error.message }, 500);

    const studentRows = (students.data ?? []) as StudentRow[];
    const linkRows = (links.data ?? []) as LinkRow[];

    const ids = new Set<string>();
    studentRows.forEach((row) => { if (row.user_id) ids.add(row.user_id); });
    linkRows.forEach((row) => { if (row.parent_user_id) ids.add(row.parent_user_id); });

    let profiles: ProfileRow[] = [];
    if (ids.size) {
      const profileResult = await admin
        .from("profiles")
        .select("id,full_name,email")
        .in("id", [...ids]);
      if (profileResult.error) return json({ ok: false, message: profileResult.error.message }, 500);
      profiles = (profileResult.data ?? []) as ProfileRow[];
    }

    const profileById = new Map(profiles.map((row) => [row.id, row]));
    const classById = new Map(((classes.data ?? []) as ClassRow[]).map((row) => [row.id, row]));
    const parentByStudent = new Map<string, string>();
    linkRows.forEach((row) => {
      if (row.verified_at) parentByStudent.set(row.student_id, row.parent_user_id);
    });

    const rows = studentRows.map((student) => {
      const cls = student.class_id ? classById.get(student.class_id) ?? null : null;
      const studentProfile = student.user_id ? profileById.get(student.user_id) ?? null : null;
      const parentId = parentByStudent.get(student.id);
      const parentProfile = parentId ? profileById.get(parentId) ?? null : null;
      return {
        studentId: student.id,
        studentName: student.full_name,
        admissionNo: student.admission_no,
        className: cls?.name ?? null,
        program: cls?.program ?? null,
        studentAccount: student.user_id
          ? { userId: student.user_id, email: studentProfile?.email ?? "", fullName: studentProfile?.full_name ?? student.full_name }
          : null,
        parentAccount: parentId
          ? { userId: parentId, email: parentProfile?.email ?? "", fullName: parentProfile?.full_name ?? "" }
          : null,
      };
    });

    return json({ ok: true, students: rows });
  }

  if (action === "create") {
    const studentId = text(body.studentId);
    const kind = text(body.kind) === "parent" ? "parent" : "student";
    const email = text(body.email).toLowerCase();
    const password = text(body.password);
    const parentName = text(body.parentName);

    if (!studentId) return json({ ok: false, message: "اختر الطالب أولاً." }, 400);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ ok: false, message: "صيغة البريد الإلكتروني غير صحيحة." }, 400);
    }
    if (password.length < 8) {
      return json({ ok: false, message: "كلمة المرور يجب ألا تقل عن ٨ أحرف." }, 400);
    }

    const { data: student, error: studentError } = await admin
      .from("students")
      .select("id,full_name,user_id")
      .eq("id", studentId)
      .maybeSingle();
    if (studentError) return json({ ok: false, message: studentError.message }, 500);
    if (!student) return json({ ok: false, message: "سجل الطالب غير موجود." }, 404);

    if (kind === "student" && student.user_id) {
      return json({ ok: false, message: "هذا الطالب مرتبط بحساب مستخدم بالفعل." }, 409);
    }
    if (kind === "parent") {
      const { data: existingLink, error: linkError } = await admin
        .from("parent_student_links")
        .select("student_id")
        .eq("student_id", studentId)
        .maybeSingle();
      if (linkError) return json({ ok: false, message: linkError.message }, 500);
      if (existingLink) {
        return json({ ok: false, message: "هذا الطالب مرتبط بحساب ولي أمر بالفعل." }, 409);
      }
    }

    const fullName = kind === "parent"
      ? (parentName || `ولي أمر ${student.full_name}`)
      : student.full_name;

    const created = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    });
    if (created.error || !created.data.user) {
      const reason = created.error?.message ?? "تعذر إنشاء الحساب.";
      const friendly = /already|registered|exists/i.test(reason)
        ? "هذا البريد مستخدم في حساب آخر؛ اختر بريداً مختلفاً."
        : reason;
      return json({ ok: false, message: friendly }, 400);
    }

    const userId = created.data.user.id;
    const rollback = async (reason: string) => {
      await admin.auth.admin.deleteUser(userId);
      return json({ ok: false, message: reason }, 500);
    };

    const profileResult = await admin
      .from("profiles")
      .upsert({ id: userId, full_name: fullName, email }, { onConflict: "id" });
    if (profileResult.error) return rollback(profileResult.error.message);

    const roleResult = await admin
      .from("user_roles")
      .upsert({ user_id: userId, role: kind, assigned_by: caller.id }, { onConflict: "user_id,role", ignoreDuplicates: true });
    if (roleResult.error) return rollback(roleResult.error.message);

    if (kind === "student") {
      const updateResult = await admin
        .from("students")
        .update({ user_id: userId })
        .eq("id", studentId);
      if (updateResult.error) return rollback(updateResult.error.message);
    } else {
      const linkResult = await admin.from("parent_student_links").insert({
        parent_user_id: userId,
        student_id: studentId,
        verified_at: new Date().toISOString(),
        verified_by: caller.id,
      });
      if (linkResult.error) return rollback(linkResult.error.message);
    }

    await admin.from("audit_logs").insert({
      actor_user_id: caller.id,
      action: kind === "student" ? "student_account_provision" : "parent_account_provision",
      entity_type: kind === "student" ? "students" : "parent_student_links",
      entity_id: studentId,
      metadata: { account_user_id: userId, email, source: "learning_accounts" },
    });

    return json({
      ok: true,
      account: { userId, email, password, role: kind, fullName, studentName: student.full_name },
    });
  }

  if (action === "teacher-overview") {
    const classes = await admin
      .from("classes")
      .select("id,name,branch_id,teacher_id")
      .order("name");
    if (classes.error) return json({ ok: false, message: classes.error.message }, 500);

    const branches = await admin.from("branches").select("id,name");
    if (branches.error) return json({ ok: false, message: branches.error.message }, 500);

    const courses = await admin
      .from("learning_courses")
      .select("id,class_id,teacher_id,title")
      .eq("is_active", true);
    if (courses.error) return json({ ok: false, message: courses.error.message }, 500);

    const homework = await admin.from("learning_homework").select("id,course_id");
    if (homework.error) return json({ ok: false, message: homework.error.message }, 500);

    const pending = await admin
      .from("learning_homework_submissions")
      .select("homework_id")
      .eq("status", "submitted");
    if (pending.error) return json({ ok: false, message: pending.error.message }, 500);

    const studentRows = await admin.from("students").select("id,class_id");
    if (studentRows.error) return json({ ok: false, message: studentRows.error.message }, 500);

    const classRows = (classes.data ?? []) as { id: string; name: string; branch_id: string; teacher_id: string | null }[];
    const courseRows = (courses.data ?? []) as { id: string; class_id: string | null; teacher_id: string | null; title: string }[];
    const homeworkRows = (homework.data ?? []) as { id: string; course_id: string }[];
    const pendingRows = (pending.data ?? []) as { homework_id: string }[];
    const allStudents = (studentRows.data ?? []) as { id: string; class_id: string | null }[];

    // Read the teacher role itself, so an unassigned teacher stays listed and can be reset or re-assigned.
    const roleRows = await admin.from("user_roles").select("user_id,role").eq("role", "teacher");
    if (roleRows.error) return json({ ok: false, message: roleRows.error.message }, 500);

    const teacherIds = new Set<string>();
    classRows.forEach((row) => { if (row.teacher_id) teacherIds.add(row.teacher_id); });
    courseRows.forEach((row) => { if (row.teacher_id) teacherIds.add(row.teacher_id); });
    ((roleRows.data ?? []) as { user_id: string }[]).forEach((row) => teacherIds.add(row.user_id));

    let profiles: ProfileRow[] = [];
    if (teacherIds.size) {
      const profileResult = await admin
        .from("profiles")
        .select("id,full_name,email")
        .in("id", [...teacherIds]);
      if (profileResult.error) return json({ ok: false, message: profileResult.error.message }, 500);
      profiles = (profileResult.data ?? []) as ProfileRow[];
    }
    const profileById = new Map(profiles.map((row) => [row.id, row]));
    const branchById = new Map(
      ((branches.data ?? []) as { id: string; name: string }[]).map((row) => [row.id, row.name]),
    );

    const classById = new Map(classRows.map((row) => [row.id, row]));

    // A teacher owns a course directly or through the class assigned to them.
    const coursesForTeacher = (teacherId: string) => courseRows.filter((row) => {
      if (row.teacher_id === teacherId) return true;
      const cls = row.class_id ? classById.get(row.class_id) : null;
      return !!cls && cls.teacher_id === teacherId;
    });

    const homeworkByCourse = new Map<string, string[]>();
    homeworkRows.forEach((row) => {
      const list = homeworkByCourse.get(row.course_id) ?? [];
      list.push(row.id);
      homeworkByCourse.set(row.course_id, list);
    });

    const pendingByHomework = new Map<string, number>();
    pendingRows.forEach((row) => {
      pendingByHomework.set(row.homework_id, (pendingByHomework.get(row.homework_id) ?? 0) + 1);
    });

    const studentsByClass = new Map<string, number>();
    allStudents.forEach((row) => {
      if (!row.class_id) return;
      studentsByClass.set(row.class_id, (studentsByClass.get(row.class_id) ?? 0) + 1);
    });

    return json({
      ok: true,
      classes: classRows.map((row) => {
        const teacher = row.teacher_id ? profileById.get(row.teacher_id) ?? null : null;
        return {
          id: row.id,
          name: row.name,
          branchName: branchById.get(row.branch_id) ?? null,
          teacherId: row.teacher_id,
          teacherName: teacher?.full_name ?? null,
          teacherEmail: teacher?.email ?? null,
        };
      }),
      teachers: [...teacherIds]
        .map((teacherId) => {
          const profile = profileById.get(teacherId) ?? null;
          const ownedCourses = coursesForTeacher(teacherId);

          const classIds = new Set<string>();
          classRows.forEach((row) => { if (row.teacher_id === teacherId) classIds.add(row.id); });
          ownedCourses.forEach((row) => { if (row.class_id) classIds.add(row.class_id); });

          const classNames = [...new Set(
            [...classIds].map((classId) => classById.get(classId)?.name ?? "").filter(Boolean),
          )].sort();

          const branchNames = [...new Set(
            [...classIds].map((classId) => {
              const cls = classById.get(classId);
              return cls ? branchById.get(cls.branch_id) ?? "" : "";
            }).filter(Boolean),
          )].sort();

          const homeworkIds = new Set<string>();
          ownedCourses.forEach((row) => {
            (homeworkByCourse.get(row.id) ?? []).forEach((id) => homeworkIds.add(id));
          });

          let ungraded = 0;
          homeworkIds.forEach((id) => { ungraded += pendingByHomework.get(id) ?? 0; });

          let students = 0;
          classIds.forEach((classId) => { students += studentsByClass.get(classId) ?? 0; });

          return {
            userId: teacherId,
            fullName: profile?.full_name ?? "معلم",
            email: profile?.email ?? "",
            classNames,
            branchNames,
            courseTitles: ownedCourses.map((row) => row.title).filter(Boolean).sort(),
            workload: {
              classes: classNames.length,
              courses: ownedCourses.length,
              assignments: homeworkIds.size,
              ungraded,
              students,
            },
          };
        })
        .sort((a, b) => {
          if (!a.classNames.length !== !b.classNames.length) return a.classNames.length ? -1 : 1;
          return a.fullName.localeCompare(b.fullName, "ar");
        }),
    });
  }

  if (action === "create-teacher") {
    const fullName = text(body.fullName);
    const classId = text(body.classId);
    const email = text(body.email).toLowerCase();
    const password = text(body.password);

    if (fullName.length < 3) return json({ ok: false, message: "اكتب الاسم الكامل للمعلم (٣ أحرف على الأقل)." }, 400);
    if (!classId) return json({ ok: false, message: "اختر الصف الذي سيدرّسه المعلم." }, 400);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ ok: false, message: "صيغة البريد الإلكتروني غير صحيحة." }, 400);
    }
    if (password.length < 8) return json({ ok: false, message: "كلمة المرور يجب ألا تقل عن ٨ أحرف." }, 400);

    const { data: cls, error: classError } = await admin
      .from("classes")
      .select("id,name,branch_id,teacher_id")
      .eq("id", classId)
      .maybeSingle();
    if (classError) return json({ ok: false, message: classError.message }, 500);
    if (!cls) return json({ ok: false, message: "الصف غير موجود." }, 404);
    if (cls.teacher_id) {
      return json({
        ok: false,
        message: "هذا الصف له معلم مسند بالفعل؛ اختر صفاً آخر لتفادي سحب وصول المعلم الحالي.",
      }, 409);
    }

    const created = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    });
    if (created.error || !created.data.user) {
      const reason = created.error?.message ?? "تعذر إنشاء الحساب.";
      const friendly = /already|registered|exists/i.test(reason)
        ? "هذا البريد مستخدم في حساب آخر؛ اختر بريداً مختلفاً."
        : reason;
      return json({ ok: false, message: friendly }, 400);
    }

    const userId = created.data.user.id;
    const rollback = async (reason: string) => {
      await admin.auth.admin.deleteUser(userId);
      return json({ ok: false, message: reason }, 500);
    };

    const profileResult = await admin
      .from("profiles")
      .upsert({ id: userId, full_name: fullName, email }, { onConflict: "id" });
    if (profileResult.error) return rollback(profileResult.error.message);

    const roleResult = await admin
      .from("user_roles")
      .upsert({ user_id: userId, role: "teacher", assigned_by: caller.id }, { onConflict: "user_id,role", ignoreDuplicates: true });
    if (roleResult.error) return rollback(roleResult.error.message);

    const membershipResult = await admin
      .from("branch_memberships")
      .upsert({ user_id: userId, branch_id: cls.branch_id, is_active: true }, { onConflict: "user_id,branch_id" });
    if (membershipResult.error) return rollback(membershipResult.error.message);

    const classUpdate = await admin
      .from("classes")
      .update({ teacher_id: userId })
      .eq("id", classId);
    if (classUpdate.error) return rollback(classUpdate.error.message);

    // Give the teacher direct ownership of the class courses when no owner is set yet.
    await admin
      .from("learning_courses")
      .update({ teacher_id: userId })
      .eq("class_id", classId)
      .is("teacher_id", null);

    await admin.from("audit_logs").insert({
      actor_user_id: caller.id,
      action: "teacher_account_provision",
      entity_type: "classes",
      entity_id: classId,
      metadata: { account_user_id: userId, email, source: "learning_accounts" },
    });

    return json({
      ok: true,
      account: {
        userId,
        email,
        password,
        fullName,
        className: cls.name,
        role: "teacher",
      },
    });
  }

  if (action === "reset-teacher-password") {
    const userId = text(body.userId);
    const password = text(body.password);
    if (!userId) return json({ ok: false, message: "اختر حساب المعلم أولاً." }, 400);
    if (password.length < 8) return json({ ok: false, message: "كلمة المرور يجب ألا تقل عن ٨ أحرف." }, 400);

    const roleCheck = await admin
      .from("user_roles")
      .select("role")
      .eq("user_id", userId)
      .eq("role", "teacher")
      .maybeSingle();
    if (roleCheck.error) return json({ ok: false, message: roleCheck.error.message }, 500);
    if (!roleCheck.data) return json({ ok: false, message: "هذا الحساب ليس حساب معلم." }, 404);

    const target = await admin.auth.admin.getUserById(userId);
    if (target.error || !target.data.user) {
      return json({ ok: false, message: "حساب الدخول غير موجود؛ قد يكون محذوفاً." }, 404);
    }

    const updated = await admin.auth.admin.updateUserById(userId, { password });
    if (updated.error) return json({ ok: false, message: updated.error.message }, 400);

    const profile = await admin.from("profiles").select("full_name,email").eq("id", userId).maybeSingle();
    const classes = await admin.from("classes").select("name").eq("teacher_id", userId);
    const classNames = ((classes.data ?? []) as { name: string }[]).map((row) => row.name);
    const email = target.data.user.email ?? (profile.data?.email ?? "");

    await admin.from("audit_logs").insert({
      actor_user_id: caller.id,
      action: "teacher_password_reset",
      entity_type: "profiles",
      entity_id: userId,
      metadata: { email, source: "learning_accounts" },
    });

    const fullName = profile.data?.full_name ?? "معلم";
    const notice = await sendTeacherEmail(
      email,
      "تم إعادة تعيين كلمة مرور حساب المعلم — بوابة كلية ساي",
      emailShell({
        title: "تم إعادة تعيين كلمة مرورك",
        body: `
          <p style="margin:0">مرحباً ${escapeHtml(fullName)}،</p>
          <p style="margin:10px 0 0">أعادت إدارة الكلية تعيين كلمة المرور الخاصة بحساب المعلم في بوابة كلية ساي.</p>
          <table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:14px">
            <tr><td style="padding:8px 0;color:#5b6159">البريد الإلكتروني</td><td style="padding:8px 0;font-weight:600" dir="ltr">${escapeHtml(email)}</td></tr>
            <tr><td style="padding:8px 0;color:#5b6159">الصفوف المسندة</td><td style="padding:8px 0;font-weight:600">${escapeHtml(classNames.join(" · ") || "لا صف مسند حالياً")}</td></tr>
          </table>
          <p style="margin:16px 0 0">تجد كلمة المرور المؤقتة لدى إدارة الكلية. سجّل الدخول بها ثم غيّرها من صفحة الحساب.</p>
          <p style="margin:14px 0 0;color:#5b6159;font-size:12px">إن لم تكن تتوقع هذا التغيير، تواصل مع الإدارة فوراً.</p>`,
      }),
    );

    return json({
      ok: true,
      account: {
        userId,
        email,
        password,
        fullName,
        className: classNames.join(" · "),
        emailSent: notice.sent,
        emailReason: notice.reason,
      },
    });
  }

  if (action === "reassign-teacher") {
    const userId = text(body.userId);
    const classId = text(body.classId);
    if (!userId) return json({ ok: false, message: "اختر حساب المعلم أولاً." }, 400);
    if (!classId) return json({ ok: false, message: "اختر الصف الجديد." }, 400);

    const roleCheck = await admin
      .from("user_roles")
      .select("role")
      .eq("user_id", userId)
      .eq("role", "teacher")
      .maybeSingle();
    if (roleCheck.error) return json({ ok: false, message: roleCheck.error.message }, 500);
    if (!roleCheck.data) return json({ ok: false, message: "هذا الحساب ليس حساب معلم." }, 404);

    const target = await admin
      .from("classes")
      .select("id,name,branch_id,teacher_id")
      .eq("id", classId)
      .maybeSingle();
    if (target.error) return json({ ok: false, message: target.error.message }, 500);
    if (!target.data) return json({ ok: false, message: "الصف الجديد غير موجود." }, 404);
    if (target.data.teacher_id && target.data.teacher_id !== userId) {
      return json({
        ok: false,
        message: "هذا الصف له معلم مسند بالفعل؛ أزل إسناده أولاً لتجنب سحب وصول معلم آخر.",
      }, 409);
    }

    const previous = await admin
      .from("classes")
      .select("name")
      .eq("teacher_id", userId)
      .neq("id", classId);
    if (previous.error) return json({ ok: false, message: previous.error.message }, 500);
    const previousClassNames = ((previous.data ?? []) as { name: string }[]).map((row) => row.name);

    const release = await admin
      .from("classes")
      .update({ teacher_id: null })
      .eq("teacher_id", userId)
      .neq("id", classId);
    if (release.error) return json({ ok: false, message: release.error.message }, 500);

    const assign = await admin.from("classes").update({ teacher_id: userId }).eq("id", classId);
    if (assign.error) return json({ ok: false, message: assign.error.message }, 500);

    // Course ownership follows the class, otherwise the teacher would keep seeing the old class.
    const releaseCourses = await admin
      .from("learning_courses")
      .update({ teacher_id: null })
      .eq("teacher_id", userId)
      .neq("class_id", classId);
    if (releaseCourses.error) return json({ ok: false, message: releaseCourses.error.message }, 500);

    await admin
      .from("learning_courses")
      .update({ teacher_id: userId })
      .eq("class_id", classId)
      .is("teacher_id", null);

    const membership = await admin
      .from("branch_memberships")
      .upsert(
        { user_id: userId, branch_id: target.data.branch_id, is_active: true },
        { onConflict: "user_id,branch_id" },
      );
    if (membership.error) return json({ ok: false, message: membership.error.message }, 500);

    const remainingClasses = await admin.from("classes").select("branch_id").eq("teacher_id", userId);
    if (remainingClasses.error) return json({ ok: false, message: remainingClasses.error.message }, 500);
    const remainingCourses = await admin.from("learning_courses").select("branch_id").eq("teacher_id", userId);
    if (remainingCourses.error) return json({ ok: false, message: remainingCourses.error.message }, 500);

    const activeBranches = new Set<string>();
    ((remainingClasses.data ?? []) as { branch_id: string }[]).forEach((row) => activeBranches.add(row.branch_id));
    ((remainingCourses.data ?? []) as { branch_id: string }[]).forEach((row) => activeBranches.add(row.branch_id));
    activeBranches.add(target.data.branch_id);

    const memberships = await admin
      .from("branch_memberships")
      .select("branch_id,is_active")
      .eq("user_id", userId);
    if (memberships.error) return json({ ok: false, message: memberships.error.message }, 500);

    const staleBranches = ((memberships.data ?? []) as { branch_id: string; is_active: boolean }[])
      .filter((row) => row.is_active && !activeBranches.has(row.branch_id))
      .map((row) => row.branch_id);
    if (staleBranches.length) {
      const deactivate = await admin
        .from("branch_memberships")
        .update({ is_active: false })
        .eq("user_id", userId)
        .in("branch_id", staleBranches);
      if (deactivate.error) return json({ ok: false, message: deactivate.error.message }, 500);
    }

    const profile = await admin.from("profiles").select("full_name,email").eq("id", userId).maybeSingle();

    await admin.from("audit_logs").insert({
      actor_user_id: caller.id,
      action: "teacher_class_reassignment",
      entity_type: "classes",
      entity_id: classId,
      metadata: {
        account_user_id: userId,
        previous_classes: previousClassNames,
        new_class: target.data.name,
        source: "learning_accounts",
      },
    });

    const teacherEmail = profile.data?.email ?? "";
    const teacherName = profile.data?.full_name ?? "معلم";
    const branchResult = await admin
      .from("branches")
      .select("name")
      .eq("id", target.data.branch_id)
      .maybeSingle();
    const branchName = (branchResult.data as { name?: string } | null)?.name ?? "الفرع";
    const notice = await sendTeacherEmail(
      teacherEmail,
      `تم نقلك إلى ${target.data.name} — بوابة كلية ساي`,
      emailShell({
        title: "تم تحديث إسناد صفك",
        body: `
          <p style="margin:0">مرحباً ${escapeHtml(teacherName)}،</p>
          <p style="margin:10px 0 0">حدّثت إدارة الكلية إسنادك في بوابة كلية ساي. أصبح صفك الجديد:</p>
          <p style="margin:14px 0;font-size:18px;font-weight:700;text-align:center;background:#eef3ee;border-radius:8px;padding:14px;color:#0f5132">${escapeHtml(target.data.name)} — ${escapeHtml(branchName)}</p>
          <table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:8px">
            <tr><td style="padding:8px 0;color:#5b6159">الصفوف السابقة</td><td style="padding:8px 0;font-weight:600">${escapeHtml(previousClassNames.join(" · ") || "لا شيء")}</td></tr>
            <tr><td style="padding:8px 0;color:#5b6159">البريد الإلكتروني</td><td style="padding:8px 0;font-weight:600" dir="ltr">${escapeHtml(teacherEmail)}</td></tr>
          </table>
          <p style="margin:16px 0 0">أصبح وصولك إلى طلاب الصف الجديد ومقرراته وتصحيح واجباته متاحاً فوراً، وانتهى وصولك إلى الصف السابق.</p>
          <p style="margin:14px 0 0;color:#5b6159;font-size:12px">إن كان في ذلك خطأ، تواصل مع إدارة الكلية.</p>`,
      }),
    );

    return json({
      ok: true,
      account: {
        userId,
        email: teacherEmail,
        fullName: teacherName,
        className: target.data.name,
        previousClassNames,
        emailSent: notice.sent,
        emailReason: notice.reason,
      },
    });
  }

  if (action === "remove-teacher") {
    const userId = text(body.userId);
    if (!userId) return json({ ok: false, message: "اختر حساب المعلم أولاً." }, 400);

    const roleCheck = await admin
      .from("user_roles")
      .select("role")
      .eq("user_id", userId)
      .eq("role", "teacher")
      .maybeSingle();
    if (roleCheck.error) return json({ ok: false, message: roleCheck.error.message }, 500);
    if (!roleCheck.data) return json({ ok: false, message: "هذا الحساب ليس حساب معلم." }, 404);

    const assigned = await admin
      .from("classes")
      .select("id,name,branch_id")
      .eq("teacher_id", userId);
    if (assigned.error) return json({ ok: false, message: assigned.error.message }, 500);
    const assignedClasses = (assigned.data ?? []) as { id: string; name: string; branch_id: string }[];
    const removedClassNames = assignedClasses.map((row) => row.name);

    const branchIds = [...new Set(assignedClasses.map((row) => row.branch_id).filter(Boolean))];
    let branchNames: string[] = [];
    if (branchIds.length) {
      const branchResult = await admin.from("branches").select("id,name").in("id", branchIds);
      if (branchResult.error) return json({ ok: false, message: branchResult.error.message }, 500);
      branchNames = ((branchResult.data ?? []) as { name: string }[]).map((row) => row.name);
    }

    const clearClasses = await admin.from("classes").update({ teacher_id: null }).eq("teacher_id", userId);
    if (clearClasses.error) return json({ ok: false, message: clearClasses.error.message }, 500);

    const clearCourses = await admin
      .from("learning_courses")
      .update({ teacher_id: null })
      .eq("teacher_id", userId);
    if (clearCourses.error) return json({ ok: false, message: clearCourses.error.message }, 500);

    const closeAccess = await admin
      .from("branch_memberships")
      .update({ is_active: false })
      .eq("user_id", userId);
    if (closeAccess.error) return json({ ok: false, message: closeAccess.error.message }, 500);

    await admin.from("audit_logs").insert({
      actor_user_id: caller.id,
      action: "teacher_class_unassignment",
      entity_type: "profiles",
      entity_id: userId,
      metadata: { removed_classes: removedClassNames, source: "learning_accounts" },
    });

    // Tell the teacher their access ended, so losing the class is never a surprise.
    let emailStatus: EmailResult = { sent: false, reason: "NO_REMOVED_CLASS" };
    if (removedClassNames.length) {
      const profile = await admin
        .from("profiles")
        .select("full_name,email")
        .eq("id", userId)
        .maybeSingle();
      const teacherEmail = profile.data?.email ?? "";
      const teacherName = profile.data?.full_name ?? "معلم";
      const branchLine = branchNames.length ? branchNames.join(" · ") : "الفرع";
      emailStatus = await sendTeacherEmail(
        teacherEmail,
        `تم إلغاء إسنادك من ${removedClassNames.join(" و ")} — بوابة كلية ساي`,
        emailShell({
          title: "تم إلغاء إسناد صفك",
          body: `
            <p style="margin:0">مرحباً ${escapeHtml(teacherName)}،</p>
            <p style="margin:10px 0 0">أبلغتك إدارة الكلية بأنه تم إلغاء إسنادك من الصف التالي في بوابة كلية ساي:</p>
            <p style="margin:14px 0;font-size:18px;font-weight:700;text-align:center;background:#f6f1e9;border-radius:8px;padding:14px;color:#7a4a12">${escapeHtml(removedClassNames.join(" · "))}</p>
            <table style="width:100%;border-collapse:collapse;font-size:13px;margin-top:8px">
              <tr><td style="padding:8px 0;color:#5b6159">الفرع</td><td style="padding:8px 0;font-weight:600">${escapeHtml(branchLine)}</td></tr>
              <tr><td style="padding:8px 0;color:#5b6159">البريد الإلكتروني</td><td style="padding:8px 0;font-weight:600" dir="ltr">${escapeHtml(teacherEmail)}</td></tr>
            </table>
            <p style="margin:16px 0 0">انتهى وصولك إلى طلاب هذا الصف ومقرراته، ولم يعد يظهر لك سجله في البوابة. حساب الدخول الخاص بك ما زال محفوظاً، ويمكن للإدارة إعادة إسنادك إلى صف آخر في أي وقت.</p>
            <p style="margin:14px 0 0;color:#5b6159;font-size:12px">إن كان في ذلك خطأ، تواصل مع إدارة الكلية.</p>`,
        }),
      );
    }

    return json({
      ok: true,
      account: {
        userId,
        removedClassNames,
        emailSent: emailStatus.sent,
        emailReason: emailStatus.reason,
      },
    });
  }

  return json({ ok: false, message: "إجراء غير معروف." }, 400);
});
