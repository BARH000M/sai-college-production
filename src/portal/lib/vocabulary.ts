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

export const partOfSpeechOptions: readonly string[] = [
  "اسم",
  "فعل",
  "صفة",
  "ظرف",
  "حرف",
  "عبارة",
];

export type VocabularyWordInput = {
  courseId: string;
  lessonId: string | null;
  hanzi: string;
  pinyin: string;
  meaningAr: string;
  meaningEn: string;
  partOfSpeech: string;
  exampleZh: string;
  exampleAr: string;
  hskLevel: number | null;
  isPublished: boolean;
};

type CleanWord = {
  hanzi: string;
  pinyin: string;
  meaningAr: string;
  meaningEn: string | null;
  partOfSpeech: string | null;
  exampleZh: string | null;
  exampleAr: string | null;
  hskLevel: number | null;
  isPublished: boolean;
};

/** Validates and trims a word exactly the way the table expects it. */
function cleanWord(input: VocabularyWordInput): CleanWord {
  const hanzi = input.hanzi.trim();
  const pinyin = input.pinyin.trim();
  const meaningAr = input.meaningAr.trim();
  const meaningEn = input.meaningEn.trim();
  const partOfSpeech = input.partOfSpeech.trim();
  const exampleZh = input.exampleZh.trim();
  const exampleAr = input.exampleAr.trim();

  if (!input.courseId) throw new Error("اختر المقرر الذي تنتمي إليه المفردة.");
  if (!hanzi) throw new Error("اكتب المفردة بالحروف الصينية.");
  if (hanzi.length > 30) throw new Error("المفردة أطول من الحد المسموح (٣٠ حرفاً).");
  if (!pinyin) throw new Error("اكتب النطق بالبينيين.");
  if (pinyin.length > 60) throw new Error("البينيين أطول من الحد المسموح (٦٠ حرفاً).");
  if (!meaningAr) throw new Error("اكتب معنى المفردة بالعربية.");
  if (meaningAr.length > 120) throw new Error("المعنى العربي أطول من الحد المسموح (١٢٠ حرفاً).");
  if (meaningEn.length > 120) throw new Error("المعنى الإنجليزي أطول من الحد المسموح (١٢٠ حرفاً).");
  if (partOfSpeech.length > 30) throw new Error("نوع الكلمة أطول من الحد المسموح (٣٠ حرفاً).");
  if (exampleZh.length > 200) throw new Error("الجملة التوضيحية أطول من الحد المسموح (٢٠٠ حرف).");
  if (exampleAr.length > 200) throw new Error("ترجمة الجملة أطول من الحد المسموح (٢٠٠ حرف).");
  if (input.hskLevel !== null && (!Number.isInteger(input.hskLevel) || input.hskLevel < 1 || input.hskLevel > 9)) {
    throw new Error("مستوى HSK يجب أن يكون رقماً صحيحاً بين ١ و ٩.");
  }

  return {
    hanzi,
    pinyin,
    meaningAr,
    meaningEn: meaningEn || null,
    partOfSpeech: partOfSpeech || null,
    exampleZh: exampleZh || null,
    exampleAr: exampleAr || null,
    hskLevel: input.hskLevel,
    isPublished: input.isPublished,
  };
}

function wordPayload(input: VocabularyWordInput): Record<string, unknown> {
  const clean = cleanWord(input);
  return {
    course_id: input.courseId,
    lesson_id: input.lessonId || null,
    hanzi: clean.hanzi,
    pinyin: clean.pinyin,
    meaning_ar: clean.meaningAr,
    meaning_en: clean.meaningEn,
    part_of_speech: clean.partOfSpeech,
    example_zh: clean.exampleZh,
    example_ar: clean.exampleAr,
    hsk_level: clean.hskLevel,
    is_published: clean.isPublished,
  };
}

/** Loads the full word bank of one course, including unpublished drafts. */
export async function loadCourseVocabulary(courseId: string): Promise<VocabularyWord[]> {
  if (!courseId) return [];
  const result = await supabase
    .from("learning_vocabulary")
    .select(wordColumns)
    .eq("course_id", courseId)
    .order("position");
  if (result.error) throw new Error(`تعذر تحميل مفردات المقرر: ${result.error.message}`);
  return (result.data ?? []) as VocabularyWord[];
}

export async function createVocabularyWord(input: VocabularyWordInput): Promise<VocabularyWord> {
  const last = await supabase
    .from("learning_vocabulary")
    .select("position")
    .eq("course_id", input.courseId)
    .order("position", { ascending: false })
    .limit(1);
  if (last.error) throw new Error(last.error.message);
  const position = Number(last.data?.[0]?.position ?? 0) + 1;

  const result = await supabase
    .from("learning_vocabulary")
    .insert({ ...wordPayload(input), position })
    .select(wordColumns);

  if (result.error) throw new Error(result.error.message);
  const row = result.data?.[0];
  if (!row) throw new Error("لم تُحفظ المفردة؛ تحقق من صلاحيتك على هذا المقرر.");
  return row as VocabularyWord;
}

export async function updateVocabularyWord(
  id: string,
  input: VocabularyWordInput,
): Promise<VocabularyWord> {
  if (!id) throw new Error("لم يُحدَّد السجل المطلوب تعديله.");
  const result = await supabase
    .from("learning_vocabulary")
    .update(wordPayload(input))
    .eq("id", id)
    .select(wordColumns);

  if (result.error) throw new Error(result.error.message);
  const row = result.data?.[0];
  if (!row) throw new Error("لم يُحفظ التعديل؛ تحقق من صلاحيتك على هذا المقرر.");
  return row as VocabularyWord;
}

export async function deleteVocabularyWord(id: string): Promise<void> {
  if (!id) throw new Error("لم يُحدَّد السجل المطلوب حذفه.");
  const result = await supabase
    .from("learning_vocabulary")
    .delete()
    .eq("id", id)
    .select("id");

  if (result.error) {
    throw new Error(`${result.error.message} — قد تكون المفردة مرتبطة بسجل مراجعة لطالب.`);
  }
  if (!result.data?.length) throw new Error("لم تُحذف المفردة؛ تحقق من صلاحيتك على هذا المقرر.");
}

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