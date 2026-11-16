import { useEffect, useMemo, useState } from "react";
import {
  canCompleteLesson, lessonExercisePlan, lessonMediaUrl, recordLessonCompletion, recordLessonStart,
  type LearningLesson, type LessonExerciseId, type LessonProgress,
} from "@/portal/lib/learning";
import { loadLessonVocabulary, saveWordProgress, type VocabularyWord } from "@/portal/lib/vocabulary";
import { supabase } from "@/portal/lib/supabase";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

type ExerciseState = {
  reading: boolean;
  listeningPlayed: boolean;
  listening: boolean;
  reviewed: ReadonlySet<string>;
  known: ReadonlySet<string>;
};

const initialState: ExerciseState = {
  reading: false, listeningPlayed: false, listening: false, reviewed: new Set(), known: new Set(),
};

/**
 * The learner's lesson exercises: reading, listening and vocabulary review.
 * Completion is written only when every available exercise is done, and is
 * recorded with completion_basis = 'self_reported': the student's own account
 * writes it, so it documents self-reported practice, not verified mastery.
 */
export function LessonExercises({
  lesson, studentId, progressRow, onChanged,
}: {
  lesson: LearningLesson;
  studentId: string;
  progressRow: LessonProgress | null;
  onChanged: () => void;
}) {
  const [words, setWords] = useState<VocabularyWord[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [state, setState] = useState<ExerciseState>(initialState);
  const [startError, setStartError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [finishError, setFinishError] = useState<string | null>(null);
  const [finished, setFinished] = useState(false);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [audioError, setAudioError] = useState<string | null>(null);
  const completed = progressRow?.status === "completed";

  useEffect(() => {
    let active = true;
    setWords(null);
    setLoadError(null);
    setState(initialState);
    setFinished(false);
    setAudioUrl(null);
    setAudioError(null);

    void loadLessonVocabulary(lesson.id)
      .then(async (rows) => {
        if (!active) return;
        if (!rows.length) { setWords(rows); return; }
        const progress = await supabase
          .from("learning_vocab_progress")
          .select("vocabulary_id,review_count")
          .eq("student_id", studentId)
          .in("vocabulary_id", rows.map((row) => row.id));
        if (progress.error) throw new Error(progress.error.message);
        if (!active) return;
        setState((current) => ({
          ...current,
          known: new Set((progress.data ?? []).filter((row) => Number(row.review_count) > 0).map((row) => row.vocabulary_id as string)),
        }));
        setWords(rows);
      })
      .catch((failure: unknown) => { if (active) setLoadError(message(failure)); });

    if (lesson.content_kind === "audio" && lesson.content_path) {
      void lessonMediaUrl(lesson.content_path)
        .then((url) => { if (active) setAudioUrl(url); })
        .catch((failure: unknown) => { if (active) setAudioError(message(failure)); });
    } else if (lesson.content_kind === "audio" && lesson.content_url) {
      setAudioUrl(lesson.content_url);
    }
    return () => { active = false; };
  }, [lesson, studentId]);

  useEffect(() => {
    if (completed || progressRow?.status === "in_progress") return;
    let active = true;
    void recordLessonStart(lesson.id, studentId)
      .catch((failure: unknown) => { if (active) setStartError(message(failure)); });
    return () => { active = false; };
  }, [lesson.id, studentId, completed, progressRow?.status]);

  const plan = useMemo(
    () => lessonExercisePlan(lesson, words?.length ?? 0),
    [lesson, words],
  );
  const doneCount = useMemo<Record<LessonExerciseId, number>>(() => ({
    reading: state.reading ? 1 : 0,
    listening: state.listening ? 1 : 0,
    vocabulary: words ? words.filter((word) => state.reviewed.has(word.id) || state.known.has(word.id)).length : 0,
  }), [state, words]);
  const completable = canCompleteLesson(plan, doneCount);

  async function reviewWord(word: VocabularyWord) {
    if (saving || state.reviewed.has(word.id)) return;
    setSaving(true);
    setFinishError(null);
    try {
      await saveWordProgress(word.id, studentId, "learning", 1);
      setState((current) => ({ ...current, reviewed: new Set([...current.reviewed, word.id]) }));
    } catch (failure) {
      setFinishError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function finish() {
    if (saving || !completable || completed) return;
    setSaving(true);
    setFinishError(null);
    try {
      await recordLessonCompletion(lesson.id, studentId);
      setFinished(true);
      onChanged();
    } catch (failure) {
      setFinishError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  if (loadError) {
    return <div className="learn-exercises">
      <p className="error-box" role="alert">تعذر تحميل تمارين الدرس: {loadError}</p>
    </div>;
  }
  if (words === null) {
    return <div className="learn-exercises"><p role="status">جارٍ تحميل تمارين الدرس...</p></div>;
  }

  return <div className="learn-exercises">
    <h3>تمارين الدرس</h3>
    {startError && <p className="error-box" role="alert">تعذر تسجيل بدء الدرس: {startError}</p>}
    {!plan.length && <p className="muted">لا توجد تمارين مرتبطة بهذا الدرس بعد؛ أضف مادة قراءة أو تسجيلاً صوتياً أو مفردات ليتمكن الطالب من إتمامه.</p>}

    {plan.map((exercise) => {
      if (exercise.id === "vocabulary") {
        return <section key={exercise.id} className="learn-exercise">
          <h4>{exercise.label} <small className="learn-meta">{doneCount.vocabulary} / {words.length}</small></h4>
          <ul className="learn-exercise-words">
            {words.map((word) => {
              const done = state.reviewed.has(word.id) || state.known.has(word.id);
              return <li key={word.id}>
                <span className="vocab-hanzi" lang="zh">{word.hanzi}</span>
                <span dir="ltr">{word.pinyin}</span>
                <span>{word.meaning_ar}</span>
                {done
                  ? <span className="learn-pill learn-status-completed">تمت مراجعتها</span>
                  : <button type="button" className="button secondary" disabled={saving || completed}
                      onClick={() => void reviewWord(word)}>راجعتها</button>}
              </li>;
            })}
          </ul>
        </section>;
      }
      if (exercise.id === "listening") {
        return <section key={exercise.id} className="learn-exercise">
          <h4>{exercise.label}</h4>
          {audioError && <p className="error-box" role="alert">تعذر تجهيز التسجيل: {audioError}</p>}
          {!audioUrl && !audioError && <p role="status">جارٍ تجهيز التسجيل الصوتي...</p>}
          {audioUrl && <>
            <audio controls preload="none" src={audioUrl}
              onPlay={() => setState((current) => ({ ...current, listeningPlayed: true }))} />
            <div className="actions">
              <button type="button" className="button secondary"
                disabled={saving || completed || !state.listeningPlayed || state.listening}
                onClick={() => setState((current) => ({ ...current, listening: true }))}>
                {state.listening ? "اكتمل الاستماع" : "استمعت للتسجيل كاملاً"}
              </button>
            </div>
            {!state.listening && <p className="data-note">شغّل التسجيل أولاً ثم أكّد إتمام الاستماع.</p>}
          </>}
        </section>;
      }
      return <section key={exercise.id} className="learn-exercise">
        <h4>{exercise.label}</h4>
        <p className="data-note">اقرأ مادة الدرس المعروضة أعلاه كاملة ثم أكّد إتمام القراءة.</p>
        <button type="button" className="button secondary" disabled={saving || completed || state.reading}
          onClick={() => setState((current) => ({ ...current, reading: true }))}>
          {state.reading ? "اكتملت القراءة" : "أنهيت قراءة المادة"}
        </button>
      </section>;
    })}

    {finishError && <p className="error-box" role="alert">{finishError}</p>}
    {(finished || (completed && progressRow?.completion_basis === "self_reported")) &&
      <p className="success-box" role="status">أُتممت تمارين هذا الدرس وسُجّل إكمالك الذاتي؛ هذا إثبات مراجعة ذاتية وليس تقييماً معتمداً.</p>}
    {completed && progressRow?.completion_basis !== "self_reported" &&
      <p className="data-note">توجد حالة إكمال سابقة غير متحققة لهذا الدرس؛ أكمل التمارين لتسجيل مراجعتك الذاتية.</p>}
    {!completed && !!plan.length && <div className="actions">
      <button type="button" className="button primary" disabled={saving || !completable} onClick={() => void finish()}>
        {saving ? "جارٍ الحفظ..." : "إنهاء الدرس"}
      </button>
    </div>}
  </div>;
}
