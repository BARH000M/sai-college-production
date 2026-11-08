import { supabase } from "./supabase";

export type NotificationCategory = "admissions" | "homework" | "attendance";

export type AppNotification = {
  id: string;
  category: NotificationCategory;
  title: string;
  detail: string;
  at: string;
  href: string;
};

export type NotificationFeed = {
  userId: string | null;
  items: AppNotification[];
};

export const notificationsSeenEvent = "sai:notifications-seen";
const seenKey = (userId: string) => `sai:notifications-seen:${userId}`;

function cachedSeenAt(userId: string): string | null {
  try {
    return window.localStorage.getItem(seenKey(userId));
  } catch {
    return null;
  }
}

function cacheSeenAt(userId: string, value: string): void {
  try {
    window.localStorage.setItem(seenKey(userId), value);
  } catch {
    // Storage can be blocked in private mode; the database copy still holds the marker.
  }
}

/**
 * The read marker lives in notification_reads, so it follows the account across
 * devices. The browser copy is only an offline fallback.
 */
export async function readSeenAt(userId: string): Promise<string | null> {
  try {
    const { data, error } = await supabase
      .from("notification_reads")
      .select("seen_at")
      .eq("user_id", userId)
      .maybeSingle();
    if (!error && data && typeof data.seen_at === "string") {
      cacheSeenAt(userId, data.seen_at);
      return data.seen_at;
    }
  } catch {
    // Fall through to the local copy below.
  }
  return cachedSeenAt(userId);
}

export async function markNotificationsSeen(userId: string): Promise<string> {
  const now = new Date().toISOString();
  cacheSeenAt(userId, now);
  try {
    const { error } = await supabase
      .from("notification_reads")
      .upsert(
        { user_id: userId, seen_at: now, updated_at: now },
        { onConflict: "user_id" },
      );
    if (error) throw new Error(error.message);
  } catch {
    // Keep the local marker; the next refresh retries the database write.
  }
  window.dispatchEvent(new CustomEvent(notificationsSeenEvent));
  return now;
}

export function unreadCount(items: readonly AppNotification[], seenAt: string | null): number {
  if (!seenAt) return items.length;
  const seenTime = new Date(seenAt).getTime();
  return items.filter((item) => new Date(item.at).getTime() > seenTime).length;
}

function time(value: string | null | undefined): number {
  if (!value) return 0;
  const parsed = new Date(value).getTime();
  return Number.isNaN(parsed) ? 0 : parsed;
}

const staffRoles = ["super_admin", "admin", "teacher", "receptionist"];

/**
 * Builds one feed out of admissions enquiries, homework and attendance activity.
 * Every source is read through Row Level Security, so the list only ever shows
 * records the signed-in account is allowed to see. A failing source never blocks
 * the other two; it is simply omitted.
 */
export async function loadNotifications(roles: readonly string[]): Promise<NotificationFeed> {
  const { data: authData } = await supabase.auth.getUser();
  const userId = authData.user?.id ?? null;
  if (!userId) return { userId: null, items: [] };

  const isStaff = roles.some((role) => staffRoles.includes(role));
  const isLearner = roles.includes("student") || roles.includes("parent");
  const items: AppNotification[] = [];

  if (isStaff) {
    const enquiries = await supabase
      .from("admissions_enquiries")
      .select("id,applicant_full_name,preferred_program,status,created_at")
      .eq("status", "new")
      .order("created_at", { ascending: false })
      .limit(20);
    if (!enquiries.error) {
      for (const row of enquiries.data ?? []) {
        items.push({
          id: `admissions-${row.id}`,
          category: "admissions",
          title: `طلب قبول جديد: ${row.applicant_full_name}`,
          detail: row.preferred_program
            ? `البرنامج المطلوب ${row.preferred_program} · بانتظار أول تواصل`
            : "بانتظار أول تواصل من فريق القبول",
          at: row.created_at ?? new Date().toISOString(),
          href: "/portal/modules/admissions?status=new",
        });
      }
    }
  }

  const [homework, classes, students] = await Promise.all([
    supabase.from("learning_homework").select("id,title,due_at,max_score,is_published"),
    supabase.from("classes").select("id,name"),
    supabase.from("students").select("id,full_name,class_id"),
  ]);
  const homeworkTitle = new Map<string, string>();
  if (!homework.error) {
    for (const row of homework.data ?? []) homeworkTitle.set(row.id, row.title);
  }
  const className = new Map<string, string>();
  if (!classes.error) {
    for (const row of classes.data ?? []) className.set(row.id, row.name);
  }
  const studentName = new Map<string, string>();
  const studentClass = new Map<string, string>();
  if (!students.error) {
    for (const row of students.data ?? []) {
      studentName.set(row.id, row.full_name);
      if (row.class_id) studentClass.set(row.id, row.class_id);
    }
  }

  if (isStaff) {
    const submissions = await supabase
      .from("learning_homework_submissions")
      .select("id,homework_id,student_id,status,submitted_at")
      .eq("status", "submitted")
      .order("submitted_at", { ascending: false })
      .limit(20);
    if (!submissions.error) {
      for (const row of submissions.data ?? []) {
        items.push({
          id: `homework-${row.id}`,
          category: "homework",
          title: `تسليم بانتظار التصحيح: ${homeworkTitle.get(row.homework_id) ?? "واجب"}`,
          detail: `${studentName.get(row.student_id) ?? "طالب"} · بانتظار مراجعة المعلم`,
          at: row.submitted_at ?? new Date().toISOString(),
          href: "/portal/modules/homework",
        });
      }
    }
  }

  if (isLearner) {
    const graded = await supabase
      .from("learning_homework_submissions")
      .select("id,homework_id,status,score,graded_at")
      .eq("status", "graded")
      .order("graded_at", { ascending: false })
      .limit(20);
    if (!graded.error) {
      for (const row of graded.data ?? []) {
        items.push({
          id: `grade-${row.id}`,
          category: "homework",
          title: `صُحّح واجب: ${homeworkTitle.get(row.homework_id) ?? "واجب"}`,
          detail: row.score === null ? "صدرت ملاحظات المعلم على تسليمك." : `الدرجة ${row.score}`,
          at: row.graded_at ?? new Date().toISOString(),
          href: "/portal/modules/homework",
        });
      }
    }
  }

  const sessions = await supabase
    .from("attendance_sessions")
    .select("id,class_id,attendance_date,status")
    .order("attendance_date", { ascending: false })
    .limit(40);
  if (!sessions.error && (sessions.data ?? []).length) {
    const sessionIds = (sessions.data ?? []).map((row) => row.id);
    const sessionClass = new Map<string, string>();
    const sessionDate = new Map<string, string>();
    for (const row of sessions.data ?? []) {
      sessionClass.set(row.id, row.class_id);
      sessionDate.set(row.id, row.attendance_date);
    }

    const records = await supabase
      .from("attendance_records")
      .select("id,student_id,attendance_session_id,status,marked_at")
      .in("attendance_session_id", sessionIds)
      .in("status", ["absent", "late"])
      .order("marked_at", { ascending: false })
      .limit(25);

    if (!records.error) {
      for (const row of records.data ?? []) {
        const classId = sessionClass.get(row.attendance_session_id);
        const label = row.status === "absent" ? "غياب" : "تأخر";
        items.push({
          id: `attendance-${row.id}`,
          category: "attendance",
          title: `${label}: ${studentName.get(row.student_id) ?? "طالب"}`,
          detail: `${className.get(classId ?? "") ?? "شعبة"} · ${sessionDate.get(row.attendance_session_id) ?? ""}`,
          at: row.marked_at ?? new Date().toISOString(),
          href: "/portal/modules/attendance",
        });
      }
    }
  }

  items.sort((a, b) => time(b.at) - time(a.at));
  return { userId, items: items.slice(0, 60) };
}

export const notificationCategoryLabels: Record<NotificationCategory, string> = {
  admissions: "القبول والتسجيل",
  homework: "الواجبات",
  attendance: "الحضور",
};

export const notificationCategoryIcons: Record<NotificationCategory, string> = {
  admissions: "ri-user-add-line",
  homework: "ri-task-line",
  attendance: "ri-calendar-check-line",
};

export function formatNotificationTime(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  const diff = Date.now() - date.getTime();
  const minutes = Math.round(diff / 60000);
  if (minutes < 1) return "الآن";
  if (minutes < 60) return `قبل ${minutes} دقيقة`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `قبل ${hours} ساعة`;
  const days = Math.round(hours / 24);
  if (days < 7) return `قبل ${days} يوم`;
  return date.toLocaleDateString("ar-EG", { year: "numeric", month: "long", day: "numeric" });
}