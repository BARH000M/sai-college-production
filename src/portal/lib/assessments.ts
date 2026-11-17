import { supabase } from "./supabase";

export const assessmentKinds = [
  "multiple_choice",
  "true_false",
  "matching",
  "fill_blank",
  "written",
] as const;

export type AssessmentQuestionKind = typeof assessmentKinds[number];
export const assessmentKindLabels: Record<AssessmentQuestionKind, string> = {
  multiple_choice: "اختيار من متعدد",
  true_false: "صح أو خطأ",
  matching: "مطابقة",
  fill_blank: "أكمل الفراغ",
  written: "إجابة كتابية",
};

export type LearningAssessment = {
  id: string;
  course_id: string;
  lesson_id: string;
  class_id: string;
  academic_session_id: string;
  title: string;
  instructions: string | null;
  due_at: string | null;
  attempt_limit: number;
  status: "draft" | "published";
  results_released: boolean;
  created_at: string;
};

export type AssessmentQuestion = {
  id: string;
  kind: AssessmentQuestionKind;
  prompt: string;
  choices: string[];
  points: number;
  position: number;
};

export type AssessmentQuestionAdmin = AssessmentQuestion & {
  correct_choice: number | null;
  answer_key: Record<string, string> | string[] | null;
};

export type AssessmentStart = {
  attempt_id: string;
  attempt_number: number;
  due_at: string | null;
  questions: AssessmentQuestion[];
  saved_answers: Record<string, unknown>;
};

export type AssessmentResultRow = {
  attempt_id: string;
  student_id: string;
  attempt_number: number;
  status: "in_progress" | "submitted" | "graded";
  score: number | null;
  max_score: number;
  submitted_at: string | null;
  answer_id: string | null;
  question_id: string | null;
  answer: unknown;
  is_correct: boolean | null;
  points_awarded: number | null;
  feedback: string | null;
  prompt: string | null;
  kind: AssessmentQuestionKind | null;
};

function message(error: { message: string } | null, label: string): never {
  throw new Error(`${label}: ${error?.message ?? "استجابة غير صالحة."}`);
}

function parseQuestion(row: Record<string, unknown>): AssessmentQuestion {
  if (!assessmentKinds.includes(row.kind as AssessmentQuestionKind)
    || !Array.isArray(row.choices)
    || row.choices.some((choice) => typeof choice !== "string")
    || typeof row.id !== "string"
    || typeof row.prompt !== "string"
    || typeof row.points !== "number"
    || typeof row.position !== "number") {
    throw new Error("استجابة أسئلة التقييم غير صالحة.");
  }
  return {
    id: row.id,
    kind: row.kind as AssessmentQuestionKind,
    prompt: row.prompt,
    choices: row.choices,
    points: row.points,
    position: row.position,
  };
}

export async function loadAssessments(lessonId: string): Promise<LearningAssessment[]> {
  if (!lessonId) return [];
  const { data, error } = await supabase
    .from("learning_assessments")
    .select("id,course_id,lesson_id,class_id,academic_session_id,title,instructions,due_at,attempt_limit,status,results_released,created_at")
    .eq("lesson_id", lessonId)
    .order("created_at", { ascending: false });
  if (error) message(error, "تعذر تحميل التقييمات");
  return (data ?? []) as LearningAssessment[];
}

export async function createAssessment(input: {
  courseId: string;
  lessonId: string;
  title: string;
  instructions: string;
  dueAt: string | null;
  attemptLimit: number;
}): Promise<string> {
  const title = input.title.trim();
  if (!input.courseId || !input.lessonId) throw new Error("اختر المقرر والدرس.");
  if (title.length < 2 || title.length > 200) throw new Error("عنوان التقييم يجب أن يكون بين حرفين و٢٠٠ حرف.");
  if (!Number.isInteger(input.attemptLimit) || input.attemptLimit < 1 || input.attemptLimit > 10) {
    throw new Error("عدد المحاولات يجب أن يكون بين ١ و١٠.");
  }
  const { data, error } = await supabase.from("learning_assessments").insert({
    course_id: input.courseId,
    lesson_id: input.lessonId,
    title,
    instructions: input.instructions.trim() || null,
    due_at: input.dueAt,
    attempt_limit: input.attemptLimit,
  }).select("id");
  if (error) message(error, "تعذر إنشاء التقييم");
  const id = data?.[0]?.id;
  if (typeof id !== "string") throw new Error("لم يُحفظ التقييم؛ تحقق من صلاحيات المقرر.");
  return id;
}

export async function setAssessmentStatus(id: string, status: "draft" | "published"): Promise<void> {
  const { data, error } = await supabase.from("learning_assessments")
    .update({ status }).eq("id", id).select("id");
  if (error) message(error, status === "published" ? "تعذر نشر التقييم" : "تعذر إيقاف النشر");
  if (!data?.length) throw new Error("لم يُحفظ تغيير حالة التقييم.");
}

export async function updateAssessment(input: {
  id: string;
  title: string;
  instructions: string;
  dueAt: string | null;
  attemptLimit: number;
}): Promise<void> {
  const title = input.title.trim();
  if (title.length < 2 || title.length > 200) throw new Error("عنوان التقييم يجب أن يكون بين حرفين و٢٠٠ حرف.");
  if (!Number.isInteger(input.attemptLimit) || input.attemptLimit < 1 || input.attemptLimit > 10) {
    throw new Error("عدد المحاولات يجب أن يكون بين ١ و١٠.");
  }
  const { data, error } = await supabase.from("learning_assessments").update({
    title,
    instructions: input.instructions.trim() || null,
    due_at: input.dueAt,
    attempt_limit: input.attemptLimit,
  }).eq("id", input.id).select("id");
  if (error) message(error, "تعذر تعديل التقييم");
  if (!data?.length) throw new Error("لم يُحفظ تعديل التقييم.");
}

export async function setAssessmentResultsReleased(id: string, resultsReleased: boolean): Promise<void> {
  const { data, error } = await supabase.from("learning_assessments")
    .update({ results_released: resultsReleased }).eq("id", id).select("id");
  if (error) message(error, "تعذر تغيير إتاحة النتائج");
  if (!data?.length) throw new Error("لم يُحفظ تغيير إتاحة النتائج.");
}

export async function loadAssessmentQuestionsAdmin(
  assessmentId: string,
): Promise<AssessmentQuestionAdmin[]> {
  const { data, error } = await supabase.rpc("sai_learning_assessment_questions_admin", {
    p_assessment: assessmentId,
  });
  if (error) message(error, "تعذر تحميل أسئلة التقييم");
  if (!Array.isArray(data)) throw new Error("استجابة أسئلة المعلم غير صالحة.");
  return data.map((item) => {
    const row = item as Record<string, unknown>;
    const question = parseQuestion(row);
    const correctChoice = row.correct_choice;
    if (correctChoice !== null && (typeof correctChoice !== "number"
      || correctChoice < 0 || correctChoice >= question.choices.length)) {
      throw new Error("مفتاح الإجابة غير صالح.");
    }
    return {
      ...question,
      correct_choice: correctChoice as number | null,
      answer_key: row.answer_key as Record<string, string> | string[] | null,
    };
  });
}

export type AssessmentQuestionInput = {
  assessmentId: string;
  lessonId: string;
  kind: AssessmentQuestionKind;
  prompt: string;
  points: number;
  choices: string[];
  correctChoice: number | null;
  answerKey: Record<string, string> | string[] | null;
};

function questionPayload(input: AssessmentQuestionInput) {
  const prompt = input.prompt.trim();
  const choices = input.choices.map((choice) => choice.trim());
  if (prompt.length < 2 || prompt.length > 200) throw new Error("نص السؤال يجب أن يكون بين حرفين و٢٠٠ حرف.");
  if (!Number.isFinite(input.points) || input.points <= 0 || input.points > 1000) throw new Error("درجة السؤال يجب أن تكون أكبر من صفر وحتى ١٠٠٠.");
  if (input.kind === "multiple_choice" || input.kind === "true_false") {
    if (choices.length < 2 || choices.length > 6 || choices.some((item) => !item || item.length > 300)) {
      throw new Error("أدخل بين خيارين وستة خيارات، بحد أقصى ٣٠٠ حرف لكل خيار.");
    }
    if (input.kind === "true_false" && choices.length !== 2) throw new Error("سؤال الصح والخطأ يحتاج خيارين فقط.");
    if (!Number.isInteger(input.correctChoice) || input.correctChoice! < 0 || input.correctChoice! >= choices.length) {
      throw new Error("حدّد الإجابة الصحيحة.");
    }
  } else if (input.kind === "matching") {
    if (choices.length < 4 || choices.length > 12 || choices.length % 2 !== 0
      || choices.some((item) => !item || item.length > 300)
      || !input.answerKey || Array.isArray(input.answerKey)) {
      throw new Error("أدخل العدد نفسه من العناصر والمطابقات (٢–٦ أزواج).");
    }
    const expected = new Set(choices.slice(0, choices.length / 2));
    const targets = new Set(choices.slice(choices.length / 2));
    const entries = Object.entries(input.answerKey);
    if (entries.length !== expected.size || entries.some(([left, right]) => !expected.has(left) || !targets.has(right))) {
      throw new Error("كل عنصر يجب أن يقترن بخيار صحيح واحد.");
    }
  } else if (input.kind === "fill_blank") {
    if (!Array.isArray(input.answerKey) || !input.answerKey.length
      || input.answerKey.some((item) => typeof item !== "string" || !item.trim())) {
      throw new Error("أدخل إجابة صحيحة واحدة على الأقل.");
    }
  } else if (choices.length !== 0 || input.answerKey !== null) {
    throw new Error("الإجابة الكتابية لا تتضمن خيارات أو مفتاح إجابة.");
  }
  return {
    lesson_id: input.lessonId,
    assessment_id: input.assessmentId,
    kind: input.kind,
    prompt,
    choices: input.kind === "written" || input.kind === "fill_blank"
      ? []
      : choices,
    correct_choice: input.kind === "multiple_choice" || input.kind === "true_false"
      ? input.correctChoice
      : null,
    answer_key: input.answerKey,
    points: input.points,
    is_published: false,
  };
}

export async function createAssessmentQuestion(input: AssessmentQuestionInput): Promise<void> {
  const last = await supabase.from("learning_exercise_questions")
    .select("position").eq("assessment_id", input.assessmentId)
    .order("position", { ascending: false }).limit(1);
  if (last.error) message(last.error, "تعذر ترتيب أسئلة التقييم");
  const position = Number(last.data?.[0]?.position ?? 0) + 1;
  const { error } = await supabase.from("learning_exercise_questions")
    .insert({ ...questionPayload(input), position });
  if (error) message(error, "تعذر حفظ السؤال");
}

export async function updateAssessmentQuestion(
  id: string,
  input: AssessmentQuestionInput,
): Promise<void> {
  const { lesson_id: _lessonId, assessment_id: _assessmentId, ...payload } = questionPayload(input);
  const { data, error } = await supabase.from("learning_exercise_questions")
    .update(payload).eq("id", id).eq("assessment_id", input.assessmentId).select("id");
  if (error) message(error, "تعذر تعديل السؤال");
  if (!data?.length) throw new Error("لم يُحفظ تعديل السؤال.");
}

export async function deleteAssessmentQuestion(id: string, assessmentId: string): Promise<void> {
  const { data, error } = await supabase.from("learning_exercise_questions")
    .delete().eq("id", id).eq("assessment_id", assessmentId).select("id");
  if (error) message(error, "تعذر حذف السؤال");
  if (!data?.length) throw new Error("لم يُحذف السؤال.");
}

export async function startAssessment(id: string): Promise<AssessmentStart> {
  const { data, error } = await supabase.rpc("sai_learning_assessment_start", { p_assessment: id });
  if (error) message(error, "تعذر بدء التقييم");
  if (!data || typeof data !== "object") throw new Error("استجابة بدء التقييم غير صالحة.");
  const row = data as Record<string, unknown>;
  if (typeof row.attempt_id !== "string" || typeof row.attempt_number !== "number"
    || !Array.isArray(row.questions)) throw new Error("استجابة بدء التقييم غير صالحة.");
  return {
    attempt_id: row.attempt_id,
    attempt_number: row.attempt_number,
    due_at: typeof row.due_at === "string" ? row.due_at : null,
    questions: row.questions.map((question) => parseQuestion(question as Record<string, unknown>)),
    saved_answers: (row.saved_answers && typeof row.saved_answers === "object"
      ? row.saved_answers
      : {}) as Record<string, unknown>,
  };
}

export async function saveAssessmentAnswer(
  attemptId: string,
  questionId: string,
  answer: unknown,
): Promise<void> {
  const { error } = await supabase.rpc("sai_learning_assessment_save", {
    p_attempt: attemptId,
    p_question: questionId,
    p_answer: answer,
  });
  if (error) message(error, "تعذر حفظ الإجابة");
}

export async function submitAssessment(attemptId: string): Promise<{ status: string; needs_manual_grading: number; message: string }> {
  const { data, error } = await supabase.rpc("sai_learning_assessment_submit", { p_attempt: attemptId });
  if (error) message(error, "تعذر تسليم التقييم");
  if (!data || typeof data !== "object") throw new Error("استجابة تسليم التقييم غير صالحة.");
  const result = data as Record<string, unknown>;
  if (typeof result.status !== "string" || typeof result.needs_manual_grading !== "number"
    || typeof result.message !== "string") throw new Error("استجابة تسليم التقييم غير صالحة.");
  return {
    status: result.status,
    needs_manual_grading: result.needs_manual_grading,
    message: result.message,
  };
}

export async function loadAssessmentResults(assessmentId: string): Promise<AssessmentResultRow[]> {
  const { data, error } = await supabase.rpc("sai_learning_assessment_results", {
    p_assessment: assessmentId,
  });
  if (error) message(error, "تعذر تحميل نتائج التقييم");
  return (data ?? []) as AssessmentResultRow[];
}

export async function gradeAssessmentAnswer(
  answerId: string,
  points: number,
  feedback: string,
): Promise<void> {
  const { error } = await supabase.rpc("sai_learning_assessment_grade", {
    p_answer: answerId,
    p_points: points,
    p_feedback: feedback.trim() || null,
  });
  if (error) message(error, "تعذر تصحيح الإجابة الكتابية");
}
