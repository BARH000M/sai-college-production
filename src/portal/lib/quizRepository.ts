import { supabase } from "./supabase";

export type QuizStatus = "draft" | "published" | "closed" | "archived";

export type QuizSummary = {
  id: string;
  title: string;
  course_id: string;
  lesson_id: string;
  status: QuizStatus;
  attempt_limit: number;
  time_limit_minutes: number | null;
  passing_score: number;
  results_released: boolean;
};

/** Question shape returned by the student-safe projection. Never holds the key. */
export type QuizQuestion = {
  id: string;
  assessment_id: string;
  kind: string;
  prompt: string;
  choices: unknown;
  position: number;
  points: number;
  bank_category: string | null;
};

export type QuizAttempt = {
  id: string;
  assessment_id: string;
  student_id: string;
  attempt_number: number;
  status: string;
  score: number | null;
  max_score: number;
  submitted_at: string | null;
  student_name?: string;
};

export type GradeResult = {
  attempt_id: string;
  attempt_number: number;
  score: number;
  max_score: number;
  passed: boolean;
};

export type AnswerSubmission = { question_id: string; choice_index: number };

export const QUESTION_TYPE_LABELS: Record<string, string> = {
  multiple_choice: "اختيار من متعدد",
  true_false: "صح / خطأ",
  matching: "مطابقة",
  fill_blank: "إكمال فراغ",
  pinyin: "بينيين",
  character: "تمييز الحروف",
  listening: "فهم المسموع",
  reading: "فهم المقروء",
};

export async function loadQuizzes(): Promise<QuizSummary[]> {
  const result = await supabase
    .from("learning_assessments")
    .select("id,title,course_id,lesson_id,status,attempt_limit,time_limit_minutes,passing_score,results_released")
    .order("created_at", { ascending: false })
    .limit(200);
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as QuizSummary[];
}

/**
 * Loads questions through the safe projection.
 *
 * The projection omits `correct_choice` and `answer_key` entirely, so this
 * function structurally cannot leak the grading key to the browser.
 */
export async function loadQuizQuestions(assessmentId: string): Promise<QuizQuestion[]> {
  const result = await supabase
    .from("sai_quiz_public_questions")
    .select("id,assessment_id,kind,prompt,choices,position,points,bank_category")
    .eq("assessment_id", assessmentId)
    .order("position");
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as QuizQuestion[];
}

export async function loadAttempts(assessmentId?: string): Promise<QuizAttempt[]> {
  let query = supabase
    .from("learning_assessment_attempts")
    .select("id,assessment_id,student_id,attempt_number,status,score,max_score,submitted_at")
    .order("submitted_at", { ascending: false })
    .limit(300);
  if (assessmentId) query = query.eq("assessment_id", assessmentId);
  const result = await query;
  if (result.error) throw new Error(result.error.message);
  const rows = (result.data ?? []) as QuizAttempt[];
  if (!rows.length) return [];

  const studentIds = Array.from(new Set(rows.map((row) => row.student_id)));
  const students = await supabase.from("students").select("id,full_name").in("id", studentIds);
  const names = new Map(
    ((students.data ?? []) as { id: string; full_name: string }[]).map((row) => [row.id, row.full_name]),
  );
  return rows.map((row) => ({ ...row, student_name: names.get(row.student_id) ?? "—" }));
}

/**
 * Submits answers only. The backend calculates and stores the final score.
 */
export async function submitQuizAttempt(
  assessmentId: string,
  answers: AnswerSubmission[],
): Promise<GradeResult> {
  const result = await supabase.rpc("sai_quiz_grade_attempt", {
    p_assessment_id: assessmentId,
    p_answers: answers,
  });
  if (result.error) throw new Error(result.error.message);
  return result.data as GradeResult;
}

export async function setQuizStatus(id: string, status: QuizStatus): Promise<void> {
  const patch: Record<string, unknown> = { status, updated_at: new Date().toISOString() };
  if (status === "published") patch.published_at = new Date().toISOString();
  const result = await supabase.from("learning_assessments").update(patch).eq("id", id);
  if (result.error) throw new Error(result.error.message);
}

/** Choices arrive as JSON; normalise to a displayable string list. */
export function normalizeChoices(choices: unknown): string[] {
  if (Array.isArray(choices)) {
    return choices.map((choice) => (typeof choice === "string" ? choice : JSON.stringify(choice)));
  }
  return [];
}

export function attemptPercent(score: number | null, maxScore: number): number {
  if (!score || !maxScore) return 0;
  return Math.round((score / maxScore) * 100);
}