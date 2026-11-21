import { supabase } from "./supabase";

/**
 * Learning-lab data layer.
 *
 * The six Chinese-language practice labs used to import static sample content
 * from `src/mocks`. This module reads the real curriculum (courses, lessons,
 * vocabulary) and media catalogue from Supabase and derives each lab's practice
 * set from those records, so a lab always reflects what teachers actually
 * published. When the database has nothing usable for a given lab (for example
 * no authored dialogues yet), a curated fallback keeps the screen rich instead
 * of empty — the fallback is passed in by the provider, never hard-coded here.
 */

export type LabCourse = { id: string; title: string; level: string | null };
export type LabLesson = {
  id: string;
  course_id: string;
  title: string;
  summary: string | null;
  kind: string | null;
  duration_minutes: number | null;
  content_body: string | null;
};
export type LabWord = {
  id: string;
  course_id: string;
  lesson_id: string | null;
  hanzi: string;
  pinyin: string;
  meaning_ar: string;
  meaning_en: string | null;
  example_zh: string | null;
  example_ar: string | null;
  hsk_level: number | null;
};
export type LabAudio = {
  id: string;
  title_ar: string;
  storage_path: string;
  course_id: string | null;
  lesson_id: string | null;
};

export type LabWorkspace = {
  courses: LabCourse[];
  lessons: LabLesson[];
  vocabulary: LabWord[];
  audio: LabAudio[];
  learnerId: string | null;
};

/* ------------------------------------------------------------------ *
 * Dataset shape — mirrors the curated sample so the labs render unchanged
 * ------------------------------------------------------------------ */

export type LabDialogueLine = { speaker: string; hanzi: string; pinyin: string; arabic: string };
export type LabQuestion = { id: string; prompt: string; options: string[]; answer: number; hint: string };
export type LabListeningLesson = {
  id: string;
  title: string;
  subtitle: string;
  level: string;
  minutes: number;
  summary: string;
  transcript: LabDialogueLine[];
  questions: LabQuestion[];
};
export type LabToneReference = {
  id: string;
  tone: number;
  name: string;
  mark: string;
  hanzi: string;
  pinyin: string;
  arabic: string;
  contour: number[];
  hint: string;
};
export type LabTonePractice = { id: string; word: string; meaning: string; pinyin: string; tone: number; options: string[] };
export type LabSpeakingDrill = { id: string; hanzi: string; pinyin: string; arabic: string; focus: string; tips: string[] };
export type LabHandwritingChar = {
  id: string;
  char: string;
  pinyin: string;
  arabic: string;
  strokes: number;
  radical: string;
  hint: string;
};
export type LabReadingParagraph = { hanzi: string; pinyin: string; arabic: string };
export type LabReadingPassage = {
  id: string;
  title: string;
  level: string;
  minutes: number;
  intro: string;
  paragraphs: LabReadingParagraph[];
  vocabulary: { hanzi: string; pinyin: string; arabic: string }[];
  questions: LabQuestion[];
};
export type LabReviewCard = {
  id: string;
  hanzi: string;
  pinyin: string;
  arabic: string;
  example: string;
  exampleAr: string;
  tag: string;
  bucket: string;
  dueIn: string;
};
export type LabSummaryStat = { id: string; label: string; value: string };

export type LabDatasets = {
  listeningLessons: LabListeningLesson[];
  toneReferences: LabToneReference[];
  tonePractice: LabTonePractice[];
  speakingDrills: LabSpeakingDrill[];
  handwritingChars: LabHandwritingChar[];
  readingPassages: LabReadingPassage[];
  reviewCards: LabReviewCard[];
  labSummaryStats: LabSummaryStat[];
};

/* ------------------------------------------------------------------ *
 * Loader
 * ------------------------------------------------------------------ */

/**
 * Loads the published curriculum and the learner record in one round trip.
 *
 * A media or learner lookup failure is non-fatal: the labs still render from the
 * curriculum, they just cannot personalise progress or show audio.
 */
export async function loadLabWorkspace(): Promise<LabWorkspace> {
  const [coursesRes, lessonsRes, wordsRes, audioRes, auth] = await Promise.all([
    supabase
      .from("learning_courses")
      .select("id,title,level,is_active")
      .eq("is_active", true)
      .order("title"),
    supabase
      .from("learning_lessons")
      .select("id,course_id,title,summary,kind,duration_minutes,content_body")
      .eq("is_published", true)
      .order("position"),
    supabase
      .from("learning_vocabulary")
      .select("id,course_id,lesson_id,hanzi,pinyin,meaning_ar,meaning_en,example_zh,example_ar,hsk_level")
      .eq("is_published", true)
      .order("position"),
    supabase
      .from("sai_media_assets")
      .select("id,title_ar,storage_path,course_id,lesson_id")
      .eq("media_type", "audio")
      .limit(100),
    supabase.auth.getUser(),
  ]);

  if (coursesRes.error) throw new Error(`تعذّر تحميل المقررات: ${coursesRes.error.message}`);
  if (lessonsRes.error) throw new Error(`تعذّر تحميل الدروس: ${lessonsRes.error.message}`);
  if (wordsRes.error) throw new Error(`تعذّر تحميل المفردات: ${wordsRes.error.message}`);

  let learnerId: string | null = null;
  const userId = auth.data?.user?.id ?? null;
  if (userId) {
    const student = await supabase.from("students").select("id").eq("user_id", userId).limit(1).maybeSingle();
    if (!student.error && student.data && typeof student.data.id === "string") {
      learnerId = student.data.id;
    }
  }

  return {
    courses: (coursesRes.data ?? []) as LabCourse[],
    lessons: (lessonsRes.data ?? []) as LabLesson[],
    vocabulary: (wordsRes.data ?? []) as LabWord[],
    audio: (audioRes.data ?? []) as LabAudio[],
    learnerId,
  };
}

/* ------------------------------------------------------------------ *
 * Pure derivation helpers (unit tested)
 * ------------------------------------------------------------------ */

const TONE_MARKS: Record<string, number> = {
  ā: 1, ē: 1, ī: 1, ō: 1, ū: 1, ǖ: 1,
  á: 2, é: 2, í: 2, ó: 2, ú: 2, ǘ: 2,
  ǎ: 3, ě: 3, ǐ: 3, ǒ: 3, ǔ: 3, ǚ: 3,
  à: 4, è: 4, ì: 4, ò: 4, ù: 4, ǜ: 4,
};

/** Tone number (1–4) from a toned pinyin syllable; 5 for neutral. */
export function toneOf(pinyin: string): number {
  for (const char of pinyin) {
    const tone = TONE_MARKS[char];
    if (tone) return tone;
  }
  return 5;
}

const STROKES: Record<string, number> = {
  你: 7, 好: 6, 学: 8, 爱: 10, 书: 4, 国: 8, 妈: 6, 麻: 11, 马: 3,
  一: 1, 二: 2, 三: 3, 老: 6, 师: 6, 教: 11, 室: 9, 哪: 9, 里: 7,
  我: 7, 叫: 5, 人: 2, 大: 3, 中: 4, 文: 4, 电: 5, 话: 8, 茶: 9,
};

function strokeEstimate(hanzi: string): number {
  let total = 0;
  for (const char of hanzi) total += STROKES[char] ?? 3;
  return total;
}

/** Deterministic distractor choices that always contain the correct answer. */
export function optionsFor(correct: string, pool: readonly string[], seed: number): string[] {
  const others = Array.from(new Set(pool.filter((value) => value && value !== correct)));
  const picks: string[] = [];
  for (let index = 0; index < others.length && picks.length < 3; index += 1) {
    const candidate = others[(seed * 3 + index * 5) % others.length];
    if (!picks.includes(candidate)) picks.push(candidate);
  }
  const options = [...picks];
  const answer = ((seed % 4) + 4) % 4;
  options.splice(Math.min(answer, options.length), 0, correct);
  const padding = ["—", "؟", "…"];
  let pad = 0;
  while (options.length < 4) options.push(padding[pad++] ?? "—");
  return options.slice(0, 4);
}

function buildQuestion(
  id: string,
  prompt: string,
  correct: string,
  pool: readonly string[],
  hint: string,
  seed: number,
): LabQuestion {
  const others = Array.from(new Set(pool.filter((value) => value && value !== correct))).slice(0, 3);
  while (others.length < 3) others.push("—");
  const answer = ((seed % 4) + 4) % 4;
  const options = [...others];
  options.splice(answer, 0, correct);
  return { id, prompt, options, answer, hint };
}

function groupByLesson(words: readonly LabWord[]): Map<string, LabWord[]> {
  const map = new Map<string, LabWord[]>();
  for (const word of words) {
    if (!word.lesson_id) continue;
    const list = map.get(word.lesson_id) ?? [];
    list.push(word);
    map.set(word.lesson_id, list);
  }
  return map;
}

function buildReading(
  lessons: readonly LabLesson[],
  words: readonly LabWord[],
  courses: readonly LabCourse[],
): LabReadingPassage[] {
  const byLesson = groupByLesson(words);
  const meanings = words.map((word) => word.meaning_ar);
  const passages: LabReadingPassage[] = [];

  for (const lesson of lessons) {
    const lessonWords = (byLesson.get(lesson.id) ?? []).filter((word) => word.example_zh);
    if (lessonWords.length === 0) continue;
    const course = courses.find((entry) => entry.id === lesson.course_id);
    passages.push({
      id: `rd-${lesson.id}`,
      title: lesson.title,
      level: course?.level || `HSK ${lessonWords[0].hsk_level ?? 1}`,
      minutes: Math.max(3, Math.round((lesson.duration_minutes ?? 20) / 10)),
      intro: lesson.summary || `مفردات وأمثلة من درس «${lesson.title}».`,
      paragraphs: lessonWords.map((word) => ({
        hanzi: word.example_zh as string,
        pinyin: word.pinyin,
        arabic: word.example_ar || word.meaning_ar,
      })),
      vocabulary: lessonWords.map((word) => ({
        hanzi: word.hanzi,
        pinyin: word.pinyin,
        arabic: word.meaning_ar,
      })),
      questions: lessonWords.slice(0, 3).map((word, index) => buildQuestion(
        `rd-${lesson.id}-q${index}`,
        `ما معنى «${word.hanzi}»؟`,
        word.meaning_ar,
        meanings,
        `الكلمة «${word.hanzi}» تعني ${word.meaning_ar}.`,
        index,
      )),
    });
  }
  return passages.slice(0, 8);
}

function buildListening(
  lessons: readonly LabLesson[],
  words: readonly LabWord[],
  courses: readonly LabCourse[],
): LabListeningLesson[] {
  const byLesson = groupByLesson(words);
  const meanings = words.map((word) => word.meaning_ar);
  const result: LabListeningLesson[] = [];

  for (const lesson of lessons) {
    const lessonWords = (byLesson.get(lesson.id) ?? []).filter((word) => word.example_zh);
    if (lessonWords.length < 2) continue;
    const course = courses.find((entry) => entry.id === lesson.course_id);
    result.push({
      id: `ls-${lesson.id}`,
      title: lesson.title,
      subtitle: lesson.summary || "حوار وأمثلة صوتية",
      level: course?.level || "المستوى الأول",
      minutes: Math.max(3, Math.round((lesson.duration_minutes ?? 20) / 10)),
      summary: lesson.summary || `استمع إلى أمثلة درس «${lesson.title}».`,
      transcript: lessonWords.map((word, index) => ({
        speaker: index % 2 === 0 ? "المعلم" : "الطالب",
        hanzi: word.example_zh as string,
        pinyin: word.pinyin,
        arabic: word.example_ar || word.meaning_ar,
      })),
      questions: lessonWords.slice(0, 3).map((word, index) => buildQuestion(
        `ls-${lesson.id}-q${index}`,
        `ما معنى «${word.hanzi}»؟`,
        word.meaning_ar,
        meanings,
        `«${word.hanzi}» = ${word.meaning_ar}.`,
        index,
      )),
    });
  }
  return result.slice(0, 8);
}

/**
 * Builds every lab dataset from the workspace.
 *
 * A dataset is derived from real records whenever there is enough content; when
 * a lab has no suitable published rows yet, the curated fallback is used so the
 * screen is never empty.
 */
export function buildLabDatasets(workspace: LabWorkspace | null, fallback: LabDatasets): LabDatasets {
  if (!workspace) return fallback;

  const words = workspace.vocabulary.filter((word) => word.hanzi && word.pinyin && word.meaning_ar);
  const pinyins = words.map((word) => word.pinyin);
  const meanings = words.map((word) => word.meaning_ar);

  const tonePractice = words.length >= 4
    ? words.slice(0, 12).map((word) => ({
      id: `tp-${word.id}`,
      word: word.hanzi,
      meaning: word.meaning_ar,
      pinyin: word.pinyin,
      tone: toneOf(word.pinyin),
      options: optionsFor(word.pinyin, pinyins, word.hanzi.length),
    }))
    : fallback.tonePractice;

  const exampleWords = words.filter((word) => word.example_zh);
  const speakingDrills = exampleWords.length >= 2
    ? exampleWords.slice(0, 12).map((word) => ({
      id: `sp-${word.id}`,
      hanzi: word.example_zh as string,
      pinyin: word.pinyin,
      arabic: word.example_ar || word.meaning_ar,
      focus: `النغمة في «${word.hanzi}»`,
      tips: [
        `ركّز على نطق «${word.hanzi}» (${word.pinyin}).`,
        `المعنى: ${word.meaning_ar}.`,
      ],
    }))
    : fallback.speakingDrills;

  const handwritingChars = words.length >= 4
    ? words.slice(0, 18).map((word) => ({
      id: `hw-${word.id}`,
      char: word.hanzi,
      pinyin: word.pinyin,
      arabic: word.meaning_ar,
      strokes: strokeEstimate(word.hanzi),
      radical: "",
      hint: `اكتب «${word.hanzi}» بترتيب الضربات من الأعلى إلى الأسفل ومن اليسار إلى اليمين.`,
    }))
    : fallback.handwritingChars;

  const readingPassages = buildReading(workspace.lessons, words, workspace.courses);
  const listeningLessons = buildListening(workspace.lessons, words, workspace.courses);

  const labSummaryStats: LabSummaryStat[] = [
    { id: "ls1", label: "مفردات المقرر", value: String(words.length) },
    { id: "ls2", label: "دروس متاحة", value: String(workspace.lessons.length) },
    { id: "ls3", label: "أمثلة مسموعة", value: String(exampleWords.length) },
    { id: "ls4", label: "مقررات نشطة", value: String(workspace.courses.length) },
  ];

  void meanings;

  return {
    listeningLessons: listeningLessons.length ? listeningLessons : fallback.listeningLessons,
    toneReferences: fallback.toneReferences,
    tonePractice,
    speakingDrills,
    handwritingChars,
    readingPassages: readingPassages.length ? readingPassages : fallback.readingPassages,
    reviewCards: fallback.reviewCards,
    labSummaryStats,
  };
}