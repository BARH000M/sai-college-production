import { supabase } from "./supabase";

export const exerciseKinds = ["vocabulary", "listening"] as const;
export type ExerciseKind = typeof exerciseKinds[number];

export const exerciseKindLabels: Record<ExerciseKind, string> = {
  vocabulary: "تعرّف على المفردات",
  listening: "استماع",
};

export type ExerciseQuestion = {
  id: string;
  lesson_id: string;
  vocabulary_id: string | null;
  kind: ExerciseKind;
  prompt: string;
  choices: string[];
  position: number;
  is_published: boolean;
};

export type ExerciseQuestionAdmin = ExerciseQuestion & { correct_choice: number };

export type ExerciseAnswer = { question: string; choice: number };

export type ExerciseResult = {
  total: number;
  correct: number;
  score: number;
  passed: boolean;
  results: { question: string; correct: boolean }[];
};

export type ExerciseAttempt = {
  question_id: string;
  student_id: string;
  selected_choice: number;
  is_correct: boolean;
  answered_at: string;
};

const safeColumns = "id,lesson_id,vocabulary_id,kind,prompt,choices,position,is_published";

function parseChoices(value: unknown): string[] {
  if (!Array.isArray(value) || value.some((choice) => typeof choice !== "string")) {
    throw new Error("استجابة الأسئلة غير صالحة.");
  }
  return value as string[];
}

function asQuestion(row: Record<string, unknown>): ExerciseQuestion {
  if (row.kind !== "vocabulary" && row.kind !== "listening") throw new Error("نوع سؤال غير صالح.");
  return { ...(row as unknown as Omit<ExerciseQuestion, "choices" | "kind">), kind: row.kind, choices: parseChoices(row.choices) };
}

/** Student-safe question list: the answer key column is not granted to clients. */
export async function loadExerciseQuestions(lessonId: string): Promise<ExerciseQuestion[]> {
  if (!lessonId) return [];
  const result = await supabase
    .from("learning_exercise_questions")
    .select(safeColumns)
    .eq("lesson_id", lessonId)
    .eq("is_published", true)
    .in("kind", [...exerciseKinds])
    .order("position")
    .order("id");
  if (result.error) throw new Error(`تعذر تحميل أسئلة التقييم: ${result.error.message}`);
  return (result.data ?? []).map((row) => asQuestion(row));
}

/** Manager view including correct answers; the RPC re-checks course authority. */
export async function loadExerciseQuestionsAdmin(lessonId: string): Promise<ExerciseQuestionAdmin[]> {
  if (!lessonId) return [];
  const result = await supabase.rpc("sai_learning_exercise_questions_admin", { p_lesson: lessonId });
  if (result.error) throw new Error(`تعذر تحميل أسئلة الدرس: ${result.error.message}`);
  if (!Array.isArray(result.data)) throw new Error("استجابة الأسئلة غير صالحة.");
  return result.data.map((row) => {
    const question = asQuestion(row);
    const correct = (row as Record<string, unknown>).correct_choice;
    if (typeof correct !== "number" || correct < 0 || correct >= question.choices.length) {
      throw new Error("استجابة الأسئلة غير صالحة.");
    }
    return { ...question, correct_choice: correct };
  });
}

export type ExerciseQuestionInput = {
  lessonId: string;
  vocabularyId: string | null;
  kind: ExerciseKind;
  prompt: string;
  choices: string[];
  correctChoice: number;
  isPublished: boolean;
};

function cleanQuestionInput(input: ExerciseQuestionInput) {
  if (!input.lessonId) throw new Error("لم يُحدَّد الدرس الذي ينتمي إليه السؤال.");
  if (!exerciseKinds.includes(input.kind)) throw new Error("نوع السؤال غير صالح.");
  const prompt = input.prompt.trim();
  if (prompt.length < 2 || prompt.length > 200) throw new Error("نص السؤال يجب أن يكون بين حرفين و ٢٠٠ حرف.");
  const choices = input.choices.map((choice) => choice.trim());
  if (choices.length < 2 || choices.length > 6) throw new Error("أدخل بين خيارين وستة خيارات.");
  if (choices.some((choice) => !choice || choice.length > 200)) throw new Error("كل خيار يجب أن يكون نصاً غير فارغ (حتى ٢٠٠ حرف).");
  if (new Set(choices).size !== choices.length) throw new Error("الخيارات المكررة غير مسموحة.");
  if (!Number.isInteger(input.correctChoice) || input.correctChoice < 0 || input.correctChoice >= choices.length) {
    throw new Error("حدّد الإجابة الصحيحة من الخيارات.");
  }
  return { prompt, choices };
}

function questionPayload(input: ExerciseQuestionInput) {
  const clean = cleanQuestionInput(input);
  return {
    lesson_id: input.lessonId,
    vocabulary_id: input.kind === "vocabulary" ? input.vocabularyId : null,
    kind: input.kind,
    prompt: clean.prompt,
    choices: clean.choices,
    correct_choice: input.correctChoice,
    is_published: input.isPublished,
  };
}

export async function createExerciseQuestion(input: ExerciseQuestionInput): Promise<string> {
  const last = await supabase
    .from("learning_exercise_questions")
    .select("position")
    .eq("lesson_id", input.lessonId)
    .order("position", { ascending: false })
    .limit(1);
  if (last.error) throw new Error(last.error.message);
  const position = Number(last.data?.[0]?.position ?? 0) + 1;
  const result = await supabase
    .from("learning_exercise_questions")
    .insert({ ...questionPayload(input), position })
    .select("id");
  if (result.error) throw new Error(result.error.message);
  const id = result.data?.[0]?.id;
  if (!id) throw new Error("لم يُحفظ السؤال؛ تحقق من صلاحيتك على هذا المقرر.");
  return id;
}

export async function updateExerciseQuestion(id: string, input: ExerciseQuestionInput): Promise<void> {
  if (!id) throw new Error("لم يُحدَّد السؤال المطلوب تعديله.");
  const payload = questionPayload(input);
  const { lesson_id: _lesson, ...values } = payload;
  const result = await supabase
    .from("learning_exercise_questions")
    .update(values)
    .eq("id", id)
    .eq("lesson_id", input.lessonId)
    .select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحفظ التعديل؛ تحقق من صلاحيتك على هذا المقرر.");
}

export async function deleteExerciseQuestion(id: string, lessonId: string): Promise<void> {
  if (!id || !lessonId) throw new Error("لم يُحدَّد السؤال المطلوب حذفه.");
  const result = await supabase
    .from("learning_exercise_questions")
    .delete()
    .eq("id", id)
    .eq("lesson_id", lessonId)
    .select("id");
  if (result.error) throw new Error(`${result.error.message} — قد توجد إجابات مسجلة على هذا السؤال.`);
  if (!result.data?.length) throw new Error("لم يُحذف السؤال؛ تحقق من صلاحيتك على هذا المقرر.");
}

/**
 * Submits answers for server-side grading. The server owns the answer key,
 * computes the score, queues missed vocabulary for review, and records an
 * assessed completion on pass; the client only receives the outcome.
 */
export async function submitExercise(lessonId: string, answers: readonly ExerciseAnswer[]): Promise<ExerciseResult> {
  if (!lessonId) throw new Error("لم يُحدَّد الدرس.");
  if (!answers.length) throw new Error("أجب عن سؤال واحد على الأقل قبل الإرسال.");
  const { data, error } = await supabase.rpc("sai_learning_submit_exercise", {
    p_lesson: lessonId,
    p_answers: answers,
  });
  if (error) throw new Error(error.message);
  const result = data as Record<string, unknown> | null;
  if (!result || typeof result.total !== "number" || typeof result.correct !== "number"
    || typeof result.score !== "number" || typeof result.passed !== "boolean"
    || !Array.isArray(result.results)) {
    throw new Error("استجابة التصحيح غير صالحة؛ تحقق من النتيجة قبل إعادة المحاولة.");
  }
  return result as unknown as ExerciseResult;
}

/** Attempts for one lesson's questions, read under the caller's RLS scope. */
export async function loadExerciseAttempts(questionIds: readonly string[]): Promise<ExerciseAttempt[]> {
  if (!questionIds.length) return [];
  const result = await supabase
    .from("learning_exercise_attempts")
    .select("question_id,student_id,selected_choice,is_correct,answered_at")
    .in("question_id", [...questionIds])
    .order("answered_at", { ascending: false });
  if (result.error) throw new Error(`تعذر تحميل نتائج التقييم: ${result.error.message}`);
  return (result.data ?? []) as ExerciseAttempt[];
}

export const exercisePassMark = 70;
