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

export async function loadVocabularyWorkspace(studentOnly = false): Promise<VocabularyWorkspace> {
  const [auth, courses] = await Promise.all([
    supabase.auth.getUser(),
    supabase.from("learning_courses").select("id,title,level,class_id").eq("is_active", true).order("title"),
  ]);

  if (auth.error) fail("تعذر التحقق من الحساب", auth.error.message);
  if (courses.error) fail("تعذر تحميل المقررات", courses.error.message);

  const userId = auth.data.user?.id ?? null;
  let learnerId: string | null = null;
  let classId: string | null = null;
  let progress: VocabularyProgress[] = [];

  if (userId) {
    const student = await supabase.from("students").select("id,class_id").eq("user_id", userId).limit(1).maybeSingle();
    if (student.error) fail("تعذر تحميل سجل الطالب", student.error.message);
    if (student.data && typeof student.data.id === "string") {
      learnerId = student.data.id;
      classId = student.data.class_id;
      const rows = await supabase
        .from("learning_vocab_progress")
        .select(progressColumns)
        .eq("student_id", learnerId);
      if (rows.error) fail("تعذر تحميل مراجعة المفردات", rows.error.message);
      if (Array.isArray(rows.data)) {
        progress = rows.data as VocabularyProgress[];
      }
    }
  }

  const visibleCourses = (courses.data ?? []).filter((course) => !studentOnly || (learnerId && course.class_id === classId));
  const courseIds = visibleCourses.map((course) => course.id);
  const empty = { data: [], error: null };
  const [words, lessons] = await Promise.all([
    courseIds.length
      ? supabase.from("learning_vocabulary").select(wordColumns).eq("is_published", true).in("course_id", courseIds).order("position")
      : empty,
    courseIds.length
      ? supabase.from("learning_lessons").select("id,course_id,title,position").eq("is_published", true).in("course_id", courseIds).order("position")
      : empty,
  ]);
  if (words.error) fail("تعذر تحميل المفردات", words.error.message);
  if (lessons.error) fail("تعذر تحميل الدروس", lessons.error.message);
  return {
    words: (words.data ?? []) as VocabularyWord[],
    courses: visibleCourses as VocabularyCourse[],
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
  known: "أتذكرها (تقييم ذاتي)",
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

/* ------------------------------------------------------------------ *
 * Bulk paste import
 * ------------------------------------------------------------------ */

export type VocabularyImportRow = {
  line: number;
  raw: string;
  error: string | null;
  word: VocabularyWordInput | null;
};

export const vocabularyImportColumns = [
  "المفردة (汉字)",
  "البينيين",
  "المعنى بالعربية",
  "المعنى بالإنجليزية",
  "نوع الكلمة",
  "مستوى HSK",
  "الجملة التوضيحية",
  "ترجمة الجملة",
] as const;

const importLimit = 200;

function splitImportLine(line: string): string[] {
  if (line.includes("\t")) return line.split("\t");
  if (line.includes("|")) return line.split("|");
  if (line.includes(";")) return line.split(";");
  if (line.includes(",")) return line.split(",");
  return [line];
}

function cleanHsk(value: string): number | null {
  const digits = value.replace(/[^\d]/g, "");
  if (!digits) return null;
  const level = Number(digits);
  return Number.isInteger(level) ? level : null;
}

/**
 * Reads a pasted word list (one word per line) and validates every line the
 * same way the single-word form does, so a teacher can paste from Excel or a
 * book and see exactly which lines need fixing before anything is written.
 */
export function parseVocabularyText(
  text: string,
  base: { courseId: string; lessonId: string | null; isPublished: boolean },
): VocabularyImportRow[] {
  const lines = text.split(/\r?\n/);
  const rows: VocabularyImportRow[] = [];

  lines.forEach((line, index) => {
    const raw = line.trim();
    if (!raw || raw.startsWith("#")) return;
    const cells = splitImportLine(raw).map((cell) => cell.trim());
    if (cells.length < 3) {
      rows.push({
        line: index + 1,
        raw,
        error: "أدخل ثلاثة أعمدة على الأقل: المفردة | البينيين | المعنى، وافصل بينها بـ Tab أو |",
        word: null,
      });
      return;
    }

    const input: VocabularyWordInput = {
      courseId: base.courseId,
      lessonId: base.lessonId,
      hanzi: cells[0] ?? "",
      pinyin: cells[1] ?? "",
      meaningAr: cells[2] ?? "",
      meaningEn: cells[3] ?? "",
      partOfSpeech: cells[4] ?? "",
      hskLevel: cleanHsk(cells[5] ?? ""),
      exampleZh: cells[6] ?? "",
      exampleAr: cells[7] ?? "",
      isPublished: base.isPublished,
    };

    try {
      cleanWord(input);
      rows.push({ line: index + 1, raw, error: null, word: input });
    } catch (failure) {
      rows.push({
        line: index + 1,
        raw,
        error: failure instanceof Error ? failure.message : String(failure),
        word: null,
      });
    }
  });

  return rows;
}

/**
 * Inserts a whole pasted batch in one request and continues the course
 * position sequence, so the bank keeps a single stable order afterwards.
 */
export async function bulkCreateVocabularyWords(
  inputs: readonly VocabularyWordInput[],
): Promise<VocabularyWord[]> {
  if (!inputs.length) return [];
  if (inputs.length > importLimit) {
    throw new Error(`الحد الأقصى للاستيراد الواحد ${importLimit} مفردة. قسّم القائمة على دفعتين.`);
  }

  const courseId = inputs[0].courseId;
  if (!courseId) throw new Error("اختر المقرر الذي ستُضاف إليه المفردات.");
  if (inputs.some((input) => input.courseId !== courseId)) {
    throw new Error("يجب أن تنتمي كل مفردات الدفعة إلى المقرر نفسه.");
  }

  const payloads = inputs.map(wordPayload);
  const last = await supabase
    .from("learning_vocabulary")
    .select("position")
    .eq("course_id", courseId)
    .order("position", { ascending: false })
    .limit(1);
  if (last.error) throw new Error(last.error.message);

  const start = Number(last.data?.[0]?.position ?? 0);
  const rows = payloads.map((payload, index) => ({ ...payload, position: start + index + 1 }));

  const result = await supabase
    .from("learning_vocabulary")
    .insert(rows)
    .select(wordColumns);

  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم تُحفظ المفردات؛ تحقق من صلاحيتك على هذا المقرر.");
  return [...(result.data as VocabularyWord[])].sort((a, b) => a.position - b.position);
}

export const vocabularyImportLimit = importLimit;