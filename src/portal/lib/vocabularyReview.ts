import type {
  VocabularyProgress, VocabularyProgressStatus, VocabularyWord,
} from "@/portal/lib/vocabulary";

export type ReviewRating = "again" | "hard" | "good" | "easy";

export const reviewRatings: readonly {
  id: ReviewRating; label: string; hint: string; icon: string;
}[] = [
  { id: "again", label: "مرة أخرى", hint: "الآن", icon: "ri-restart-line" },
  { id: "hard", label: "صعب", hint: "يوم", icon: "ri-emotion-unhappy-line" },
  { id: "good", label: "جيد", hint: "٣ أيام", icon: "ri-emotion-normal-line" },
  { id: "easy", label: "سهل", hint: "أسبوع", icon: "ri-emotion-happy-line" },
];

/** Days until the next review, based on how often the word was reviewed. */
const steps = [0, 1, 2, 4, 7, 14, 30, 60];

export function reviewIntervalDays(
  status: VocabularyProgressStatus,
  reviewCount: number,
): number {
  const step = steps[Math.min(Math.max(Math.trunc(reviewCount), 0), steps.length - 1)];
  return status === "learning" ? Math.max(0, Math.round(step / 2)) : step;
}

export function progressFor(
  progress: readonly VocabularyProgress[],
  wordId: string,
  learnerId: string | null,
): VocabularyProgress | null {
  if (!learnerId) return null;
  return progress.find((row) => row.vocabulary_id === wordId && row.student_id === learnerId) ?? null;
}

/** When a word comes back into the queue. Words never reviewed count as due. */
export function nextDueAt(row: VocabularyProgress | null): Date | null {
  if (!row) return null;
  if (!row.last_reviewed_at) return new Date(0);
  const reviewed = new Date(row.last_reviewed_at).getTime();
  if (Number.isNaN(reviewed)) return new Date(0);
  return new Date(reviewed + reviewIntervalDays(row.status, row.review_count) * 86_400_000);
}

export type ReviewQueueItem = {
  word: VocabularyWord;
  progress: VocabularyProgress | null;
  dueAt: Date | null;
  isDue: boolean;
  isNew: boolean;
};

/**
 * Builds the learner's own queue: overdue words first (oldest due first), then
 * words never studied, in course order. Words already reviewed and not yet due
 * stay out of the session so the queue stays short and honest.
 */
export function buildReviewQueue(
  words: readonly VocabularyWord[],
  progress: readonly VocabularyProgress[],
  learnerId: string | null,
  limit = 25,
  now = new Date(),
): ReviewQueueItem[] {
  const items: ReviewQueueItem[] = words.map((word) => {
    const row = progressFor(progress, word.id, learnerId);
    const dueAt = nextDueAt(row);
    const isNew = !row;
    return {
      word,
      progress: row,
      dueAt,
      isNew,
      isDue: isNew || (!!dueAt && dueAt.getTime() <= now.getTime()),
    };
  });

  const due = items
    .filter((item) => item.isDue)
    .sort((a, b) => {
      const aTime = a.dueAt?.getTime() ?? 0;
      const bTime = b.dueAt?.getTime() ?? 0;
      if (aTime !== bTime) return aTime - bTime;
      return a.word.position - b.word.position;
    });

  return due.slice(0, Math.max(0, limit));
}

/**
 * Turns a rating into the stored status and review count. "Again" rewinds the
 * counter so the word returns to the front of the queue immediately.
 */
export function ratingPlan(
  rating: ReviewRating,
  current: VocabularyProgress | null,
): { status: VocabularyProgressStatus; reviewCount: number } {
  const base = Math.max(0, current?.review_count ?? 0);
  switch (rating) {
    case "again":
      return { status: "learning", reviewCount: 0 };
    case "hard":
      return { status: "learning", reviewCount: Math.max(1, base) };
    case "easy":
      return { status: "known", reviewCount: base + 2 };
    case "good":
    default:
      return { status: "known", reviewCount: base + 1 };
  }
}

export function dueCount(
  words: readonly VocabularyWord[],
  progress: readonly VocabularyProgress[],
  learnerId: string | null,
  now = new Date(),
): number {
  return words.filter((word) => {
    const row = progressFor(progress, word.id, learnerId);
    if (!row) return true;
    const dueAt = nextDueAt(row);
    return !dueAt || dueAt.getTime() <= now.getTime();
  }).length;
}

const dayKey = (date: Date): string => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
};

export type WeeklyReviewSummary = {
  reviewedThisWeek: number;
  activeDays: number;
  streak: number;
  mastered: number;
  learning: number;
  total: number;
  percent: number;
  days: { key: string; label: string; count: number }[];
};

/**
 * Weekly activity for the learner: how many words were reviewed each day, how
 * many days in a row they studied, and how much of the bank is mastered.
 */
export function weeklyReviewSummary(
  words: readonly VocabularyWord[],
  progress: readonly VocabularyProgress[],
  learnerId: string | null,
  now = new Date(),
): WeeklyReviewSummary {
  const rows = learnerId
    ? progress.filter((row) => row.student_id === learnerId)
    : [];
  const reviewedIds = new Set(words.map((word) => word.id));
  const mine = rows.filter((row) => reviewedIds.has(row.vocabulary_id));

  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(today);
    date.setDate(today.getDate() - (6 - index));
    return {
      key: dayKey(date),
      label: date.toLocaleDateString("ar-EG", { weekday: "short" }),
      count: 0,
    };
  });
  const byKey = new Map(days.map((day) => [day.key, day]));

  for (const row of mine) {
    if (!row.last_reviewed_at) continue;
    const at = new Date(row.last_reviewed_at);
    if (Number.isNaN(at.getTime())) continue;
    const bucket = byKey.get(dayKey(at));
    if (bucket) bucket.count += 1;
  }

  const activeDates = new Set<string>();
  for (const row of mine) {
    if (!row.last_reviewed_at) continue;
    const at = new Date(row.last_reviewed_at);
    if (!Number.isNaN(at.getTime())) activeDates.add(dayKey(at));
  }

  let streak = 0;
  const cursor = new Date(today);
  if (!activeDates.has(dayKey(cursor))) cursor.setDate(cursor.getDate() - 1);
  while (activeDates.has(dayKey(cursor))) {
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }

  const mastered = mine.filter((row) => row.status === "known").length;
  const learning = mine.filter((row) => row.status === "learning").length;
  const total = words.length;

  return {
    reviewedThisWeek: days.reduce((sum, day) => sum + day.count, 0),
    activeDays: days.filter((day) => day.count > 0).length,
    streak,
    mastered,
    learning,
    total,
    percent: total ? Math.round((mastered / total) * 100) : 0,
    days,
  };
}