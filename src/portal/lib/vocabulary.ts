import { supabase } from "./supabase";

export type VocabularyWord = {
  id: string;
  course_id: string;
  lesson_id: string | null;
  hanzi: string;
  pinyin: string;
  meaning_ar: string;
  meaning_en: string | null;
  part_of_speech: string | null;
  example_zh: string | null;
  example_ar: string | null;
  hsk_level: number | null;
  position: number;
  is_published: boolean;
};

export type VocabularyProgressStatus = "learning" | "known";
export type WordStatus = "new" | VocabularyProgressStatus;

export type VocabularyProgress = {
  vocabulary_id: string;
  student_id: string;
  status: VocabularyProgressStatus;
  review_count: number;
  last_reviewed_at: string | null;
};

export type VocabularyCourse = {
  id: string;
  title: string;
  level: string | null;
  class_id: string;
};

export type VocabularyLesson = {
  id: string;
  course_id: string;
  title: string;
  position: number;
};

export type VocabularyWorkspace = {
  words: VocabularyWord[];
  courses: VocabularyCourse[];
  lessons: VocabularyLesson[];
  progress: VocabularyProgress[];
  learnerId: string | null;
};

const wordColumns = "id,course_id,lesson_id,hanzi,pinyin,meaning_ar,meaning_en,part_of_speech,example_zh,example_ar,hsk_level,position,is_published";
const progressColumns = "vocabulary_id,student_id,status,review_count,last_reviewed_at";

function fail(label: string, message: string | undefined): never {
  throw new Error(`${label}: ${message ?? "طلب غير صالح"}`);
}

export async function loadVocabularyWorkspace(): Promise<VocabularyWorkspace> {
  const [{ data: authData }, words, courses, lessons] = await Promise.all([
    supabase.auth.getUser(),
    supabase.from("learning_vocabulary").select(wordColumns).order("position"),
    supabase.from("learning_courses").select("id,title,level,class_id").eq("is_active", true).order("title"),
    supabase.from("learning_lessons").select("id,course_id,title,position").order("position"),
  ]);

  if (words.error) fail("تعذر تحميل المفردات", words.error.message);
  if (courses.error) fail("تعذر تحميل المقررات", courses.error.message);
  if (lessons.error) fail("تعذر تحميل الدروس", lessons.error.message);

  const userId = authData.user?.id ?? null;
  let learnerId: string | null = null;
  let progress: VocabularyProgress[] = [];

  if (userId) {
    const student = await supabase.from("students").select("id").eq("user_id", userId).limit(1).maybeSingle();
    if (!student.error && student.data && typeof student.data.id === "string") {
      learnerId = student.data.id;
      const rows = await supabase
        .from("learning_vocab_progress")
        .select(progressColumns)
        .eq("student_id", learnerId);
      if (!rows.error && Array.isArray(rows.data)) {
        progress = rows.data as VocabularyProgress[];
      }
    }
  }

  return {
    words: (words.data ?? []) as VocabularyWord[],
    courses: (courses.data ?? []) as VocabularyCourse[],
    lessons: (lessons.data ?? []) as VocabularyLesson[],
    progress,
    learnerId,
  };
}

export function wordStatus(
  progress: readonly VocabularyProgress[],
  wordId: string,
  learnerId: string | null,
): WordStatus {
  if (!learnerId) return "new";
  const row = progress.find((item) => item.vocabulary_id === wordId && item.student_id === learnerId);
  return row?.status ?? "new";
}

export function progressCount(
  progress: readonly VocabularyProgress[],
  wordId: string,
  learnerId: string | null,
): number {
  if (!learnerId) return 0;
  const row = progress.find((item) => item.vocabulary_id === wordId && item.student_id === learnerId);
  return row?.review_count ?? 0;
}

export async function saveWordProgress(
  wordId: string,
  studentId: string,
  status: VocabularyProgressStatus,
  reviewCount: number,
): Promise<void> {
  if (!wordId || !studentId) throw new Error("لا يمكن حفظ التقدم دون طالب مرتبط بالحساب.");
  const now = new Date().toISOString();
  const result = await supabase
    .from("learning_vocab_progress")
    .upsert(
      {
        vocabulary_id: wordId,
        student_id: studentId,
        status,
        review_count: Math.max(0, Math.floor(reviewCount)),
        last_reviewed_at: now,
        updated_at: now,
      },
      { onConflict: "vocabulary_id,student_id" },
    )
    .select("vocabulary_id");

  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحفظ التقدم؛ تحقق من صلاحيتك على هذا السجل.");
}

export const wordStatusLabels: Record<WordStatus, string> = {
  new: "جديدة",
  learning: "قيد المراجعة",
  known: "أتقنتها",
};

export function vocabularySummary(
  words: readonly VocabularyWord[],
  progress: readonly VocabularyProgress[],
  learnerId: string | null,
): { total: number; known: number; learning: number; linked: number; percent: number } {
  const total = words.length;
  const known = learnerId
    ? words.filter((word) => wordStatus(progress, word.id, learnerId) === "known").length
    : 0;
  const learning = learnerId
    ? words.filter((word) => wordStatus(progress, word.id, learnerId) === "learning").length
    : 0;
  const linked = words.filter((word) => word.lesson_id).length;
  const percent = total ? Math.round((known / total) * 100) : 0;
  return { total, known, learning, linked, percent };
}