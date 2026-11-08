import { supabase } from "./supabase";
import type { HomeworkSubmission, LearningHomework } from "./learning";

export type LearningNotificationKind = "homework" | "grade";

export type LearningNotification = {
  id: string;
  kind: LearningNotificationKind;
  title: string;
  detail: string;
  homeworkId: string;
  at: string;
};

export const learningSeenEvent = "sai:learning-seen";
const inboxTable = "learning_inbox_reads";

/**
 * Reads the last time this account acknowledged its learning updates. The marker
 * lives in the database, so the badge follows the account across browsers and phones.
 */
export async function loadLearningSeen(): Promise<{ userId: string | null; seenAt: string | null }> {
  const { data } = await supabase.auth.getUser();
  const userId = data.user?.id ?? null;
  if (!userId) return { userId: null, seenAt: null };

  const result = await supabase
    .from(inboxTable)
    .select("seen_at")
    .eq("user_id", userId)
    .maybeSingle();
  if (result.error) return { userId, seenAt: null };

  const seenAt = typeof result.data?.seen_at === "string" ? result.data.seen_at : null;
  return { userId, seenAt };
}

/** Stores the current moment as this account's acknowledgement marker. */
export async function markLearningSeen(): Promise<void> {
  const { data } = await supabase.auth.getUser();
  const userId = data.user?.id ?? null;
  if (!userId) return;

  const now = new Date().toISOString();
  const { error } = await supabase
    .from(inboxTable)
    .upsert({ user_id: userId, seen_at: now, updated_at: now }, { onConflict: "user_id" });
  if (error) throw new Error(error.message);
  window.dispatchEvent(new CustomEvent(learningSeenEvent));
}

function afterSeen(at: string | null | undefined, seenAt: string | null): boolean {
  if (!at) return false;
  if (!seenAt) return true;
  return new Date(at).getTime() > new Date(seenAt).getTime();
}

export function isUnreadHomework(item: LearningHomework, seenAt: string | null): boolean {
  if (!item.is_published) return false;
  return afterSeen(item.published_at ?? item.created_at, seenAt);
}

export function isUnreadGrade(submission: HomeworkSubmission, seenAt: string | null): boolean {
  if (submission.status !== "graded") return false;
  return afterSeen(submission.graded_at, seenAt);
}

/**
 * Builds the learner-facing notification list from data already in the workspace.
 * Only published homework and graded submissions are considered, so nothing leaks
 * from drafts the student cannot read.
 */
export function buildLearningNotifications(
  homework: LearningHomework[],
  submissions: HomeworkSubmission[],
  studentIds: readonly string[],
  seenAt: string | null,
): LearningNotification[] {
  const studentSet = new Set(studentIds);
  const homeworkById = new Map(homework.map((item) => [item.id, item]));
  const list: LearningNotification[] = [];

  for (const item of homework) {
    if (!isUnreadHomework(item, seenAt)) continue;
    list.push({
      id: `homework-${item.id}`,
      kind: "homework",
      title: `واجب جديد: ${item.title}`,
      detail: `الدرجة العظمى ${item.max_score} · التسليم قبل ${formatShort(item.due_at)}`,
      homeworkId: item.id,
      at: item.published_at ?? item.created_at,
    });
  }

  for (const submission of submissions) {
    if (!studentSet.has(submission.student_id)) continue;
    if (!isUnreadGrade(submission, seenAt)) continue;
    const item = homeworkById.get(submission.homework_id);
    if (!item) continue;
    list.push({
      id: `grade-${submission.id}`,
      kind: "grade",
      title: `صُحّح واجب: ${item.title}`,
      detail: submission.score === null
        ? "صدرت ملاحظات المعلم على تسليمك."
        : `الدرجة ${submission.score} من ${item.max_score}`,
      homeworkId: item.id,
      at: submission.graded_at ?? submission.submitted_at,
    });
  }

  return list.sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime());
}

function formatShort(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString("ar-EG", {
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}