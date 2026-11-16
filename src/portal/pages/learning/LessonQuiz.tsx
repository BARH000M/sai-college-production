import { useEffect, useState } from "react";
import {
  exerciseKindLabels, exercisePassMark, loadExerciseQuestions, submitExercise,
  type ExerciseQuestion, type ExerciseResult,
} from "@/portal/lib/exercises";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

/**
 * The learner's scored assessment for one lesson. Questions arrive without
 * answer keys; grading happens entirely on the server, which also queues
 * missed vocabulary for spaced review and records assessed completion.
 */
export function LessonQuiz({ lessonId, onPassed }: { lessonId: string; onPassed: () => void }) {
  const [questions, setQuestions] = useState<ExerciseQuestion[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [answers, setAnswers] = useState<Record<string, number>>({});
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [result, setResult] = useState<ExerciseResult | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setQuestions(null);
    setLoadError(null);
    setAnswers({});
    setResult(null);
    void loadExerciseQuestions(lessonId)
      .then((rows) => { if (active) setQuestions(rows); })
      .catch((failure: unknown) => { if (active) setLoadError(message(failure)); });
    return () => { active = false; };
  }, [lessonId, retry]);

  const answered = questions?.filter((question) => answers[question.id] !== undefined).length ?? 0;
  const correctness = new Map(result?.results.map((row) => [row.question, row.correct]) ?? []);

  async function submit() {
    if (submitting || !questions?.length) return;
    setSubmitting(true);
    setSubmitError(null);
    try {
      const payload = questions
        .filter((question) => answers[question.id] !== undefined)
        .map((question) => ({ question: question.id, choice: answers[question.id] }));
      const outcome = await submitExercise(lessonId, payload);
      setResult(outcome);
      if (outcome.passed) onPassed();
    } catch (failure) {
      setSubmitError(message(failure));
    } finally {
      setSubmitting(false);
    }
  }

  if (loadError) {
    return <div className="learn-exercises">
      <p className="error-box" role="alert">تعذر تحميل تقييم الدرس: {loadError} <button type="button" className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>
    </div>;
  }
  if (questions === null) {
    return <div className="learn-exercises"><p role="status">جارٍ تحميل تقييم الدرس...</p></div>;
  }
  if (!questions.length) {
    return <div className="learn-exercises">
      <h3>التقييم المُصحَّح</h3>
      <p className="muted">لا توجد أسئلة تقييم لهذا الدرس بعد.</p>
    </div>;
  }

  return <div className="learn-exercises">
    <h3>التقييم المُصحَّح <small className="learn-meta">يُصحَّح على الخادم · النجاح من {exercisePassMark}٪</small></h3>
    {questions.map((question, index) => {
      const chosen = answers[question.id];
      const answeredCorrectly = correctness.get(question.id);
      return <fieldset key={question.id} className="learn-exercise" disabled={submitting || !!result}>
        <h4>{index + 1}. {question.prompt} <small className="learn-meta">{exerciseKindLabels[question.kind]}</small></h4>
        <div className="learn-quiz-choices">
          {question.choices.map((choice, choiceIndex) => {
            const selected = chosen === choiceIndex;
            const stateClass = result
              ? selected ? (answeredCorrectly ? "learn-quiz-right" : "learn-quiz-wrong") : ""
              : selected ? "learn-quiz-picked" : "";
            return <label key={`${question.id}-${choiceIndex}`} className={`learn-quiz-choice ${stateClass}`}>
              <input
                type="radio"
                name={`quiz-${question.id}`}
                checked={selected}
                disabled={submitting || !!result}
                onChange={() => setAnswers((current) => ({ ...current, [question.id]: choiceIndex }))}
              />
              <span>{choice}</span>
            </label>;
          })}
        </div>
        {result && answeredCorrectly === false && <p className="learn-meta">إجابة غير صحيحة{question.kind === "vocabulary" && question.vocabulary_id ? " — أُعيدت المفردة إلى قائمة المراجعة" : ""}</p>}
        {result && answeredCorrectly === true && <p className="learn-meta">إجابة صحيحة</p>}
      </fieldset>;
    })}

    {submitError && <p className="error-box" role="alert">{submitError}</p>}
    {result && <p className={result.passed ? "success-box" : "notice"} role="status">
      النتيجة: {result.correct} من {result.total} ({result.score}٪).
      {result.passed
        ? " اجتزت التقييم وسُجّل إكمال الدرس كتقييم مُصحَّح من الخادم."
        : " لم تبلغ درجة النجاح؛ راجع المفردات ثم أعد المحاولة."}
    </p>}
    {!result && <div className="actions">
      <button type="button" className="button primary" disabled={submitting || answered === 0} onClick={() => void submit()}>
        {submitting ? "جارٍ التصحيح..." : `إرسال الإجابات (${answered} / ${questions.length})`}
      </button>
    </div>}
    {result && !result.passed && <div className="actions">
      <button type="button" className="button secondary" onClick={() => { setResult(null); setAnswers({}); }}>
        إعادة المحاولة
      </button>
    </div>}
  </div>;
}
