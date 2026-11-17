import { useCallback, useEffect, useState } from "react";
import {
  assessmentKindLabels,
  assessmentKinds,
  createAssessment,
  createAssessmentQuestion,
  deleteAssessmentQuestion,
  gradeAssessmentAnswer,
  loadAssessmentQuestionsAdmin,
  loadAssessmentResults,
  loadAssessments,
  saveAssessmentAnswer,
  setAssessmentResultsReleased,
  setAssessmentStatus,
  startAssessment,
  submitAssessment,
  updateAssessment,
  updateAssessmentQuestion,
  type AssessmentQuestionAdmin,
  type AssessmentQuestionKind,
  type AssessmentResultRow,
  type LearningAssessment,
} from "@/portal/lib/assessments";

type QuestionForm = {
  kind: AssessmentQuestionKind;
  prompt: string;
  points: number;
  choices: string;
  correct: number;
  fillAnswers: string;
  matchingAnswers: string;
};

const emptyQuestion: QuestionForm = {
  kind: "multiple_choice",
  prompt: "",
  points: 1,
  choices: "",
  correct: 0,
  fillAnswers: "",
  matchingAnswers: "",
};
const message = (error: unknown) => error instanceof Error ? error.message : String(error);

function localDate(value: string | null): string {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const shifted = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return shifted.toISOString().slice(0, 16);
}

function cleanDate(value: string): string | null {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new Error("موعد التسليم غير صالح.");
  if (date.getTime() <= Date.now()) throw new Error("يجب أن يكون موعد التسليم في المستقبل.");
  return date.toISOString();
}

export function AssessmentsPanel({
  lessonId,
  courseId,
  canManage,
  canTake,
}: {
  lessonId: string;
  courseId: string;
  canManage: boolean;
  canTake: boolean;
}) {
  const [assessments, setAssessments] = useState<LearningAssessment[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [openId, setOpenId] = useState("");
  const [questions, setQuestions] = useState<AssessmentQuestionAdmin[]>([]);
  const [results, setResults] = useState<AssessmentResultRow[]>([]);
  const [attempt, setAttempt] = useState<Awaited<ReturnType<typeof startAssessment>> | null>(null);
  const [answers, setAnswers] = useState<Record<string, unknown>>({});
  const [submitted, setSubmitted] = useState(false);
  const [attemptNotice, setAttemptNotice] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [createOpen, setCreateOpen] = useState(false);
  const [title, setTitle] = useState("");
  const [instructions, setInstructions] = useState("");
  const [dueAt, setDueAt] = useState("");
  const [attemptLimit, setAttemptLimit] = useState(1);
  const [editing, setEditing] = useState("");
  const [questionForm, setQuestionForm] = useState<QuestionForm>(emptyQuestion);
  const [editingQuestion, setEditingQuestion] = useState<string | null>(null);

  const reload = useCallback(() => {
    setAssessments(null);
    setLoadError(null);
    void loadAssessments(lessonId)
      .then(setAssessments)
      .catch((failure: unknown) => setLoadError(message(failure)));
  }, [lessonId]);

  useEffect(() => {
    reload();
  }, [reload]);

  async function openAssessment(item: LearningAssessment) {
    setOpenId(openId === item.id ? "" : item.id);
    setAttempt(null);
    setAnswers({});
    setSubmitted(false);
    setError("");
    setNotice("");
    if (openId === item.id) return;
    if (canManage) {
      try {
        const [loadedQuestions, loadedResults] = await Promise.all([
          loadAssessmentQuestionsAdmin(item.id),
          loadAssessmentResults(item.id),
        ]);
        setQuestions(loadedQuestions);
        setResults(loadedResults);
      } catch (failure) {
        setError(message(failure));
      }
    } else {
      setQuestions([]);
      try {
        setResults(await loadAssessmentResults(item.id));
      } catch (failure) {
        setError(message(failure));
      }
    }
  }

  function beginEdit(item: LearningAssessment) {
    setEditing(item.id);
    setTitle(item.title);
    setInstructions(item.instructions ?? "");
    setDueAt(localDate(item.due_at));
    setAttemptLimit(item.attempt_limit);
    setError("");
  }

  async function saveMetadata(item: LearningAssessment) {
    if (saving) return;
    setSaving(true);
    setError("");
    try {
      await updateAssessment({
        id: item.id,
        title,
        instructions,
        dueAt: cleanDate(dueAt),
        attemptLimit,
      });
      setNotice("حُفظت إعدادات التقييم.");
      setEditing("");
      reload();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function saveNewAssessment() {
    if (saving) return;
    setSaving(true);
    setError("");
    try {
      const id = await createAssessment({
        courseId,
        lessonId,
        title,
        instructions,
        dueAt: cleanDate(dueAt),
        attemptLimit,
      });
      setCreateOpen(false);
      setTitle("");
      setInstructions("");
      setDueAt("");
      setAttemptLimit(1);
      setNotice("أُنشئت مسودة التقييم. أضف الأسئلة ثم انشرها للطلاب.");
      reload();
      setOpenId(id);
      setQuestions([]);
      setResults([]);
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  function questionInput(item: LearningAssessment) {
    const choiceLines = questionForm.choices.split(/\r?\n/).map((value) => value.trim()).filter(Boolean);
    let choices = choiceLines;
    let answerKey: Record<string, string> | string[] | null = null;
    if (questionForm.kind === "matching") {
      const split = questionForm.matchingAnswers.split(/\r?\n/).map((value) => value.trim()).filter(Boolean);
      choices = [...choiceLines, ...split];
      answerKey = Object.fromEntries(choiceLines.map((left, index) => [left, split[index] ?? ""]));
    } else if (questionForm.kind === "fill_blank") {
      answerKey = questionForm.fillAnswers.split(/\r?\n/).map((value) => value.trim()).filter(Boolean);
      choices = [];
    } else if (questionForm.kind === "written") {
      choices = [];
    }
    return {
      assessmentId: item.id,
      lessonId,
      kind: questionForm.kind,
      prompt: questionForm.prompt,
      points: Number(questionForm.points),
      choices,
      correctChoice: questionForm.kind === "multiple_choice" || questionForm.kind === "true_false"
        ? questionForm.correct
        : null,
      answerKey,
    };
  }

  function beginQuestionEdit(question: AssessmentQuestionAdmin) {
    const choiceCount = question.kind === "matching" ? question.choices.length / 2 : question.choices.length;
    const fillKey = Array.isArray(question.answer_key) ? question.answer_key.join("\n") : "";
    const key = question.answer_key && !Array.isArray(question.answer_key) ? question.answer_key : {};
    const matchingKey = question.choices.slice(0, choiceCount).map((left) => key[left] ?? "").join("\n");
    setEditingQuestion(question.id);
    setQuestionForm({
      kind: question.kind,
      prompt: question.prompt,
      points: question.points,
      choices: question.kind === "matching" ? question.choices.slice(0, choiceCount).join("\n")
        : question.choices.join("\n"),
      correct: question.correct_choice ?? 0,
      fillAnswers: fillKey,
      matchingAnswers: matchingKey,
    });
  }

  async function saveQuestion(item: LearningAssessment) {
    if (saving) return;
    setSaving(true);
    setError("");
    try {
      const input = questionInput(item);
      if (editingQuestion) await updateAssessmentQuestion(editingQuestion, input);
      else await createAssessmentQuestion(input);
      setQuestions(await loadAssessmentQuestionsAdmin(item.id));
      setQuestionForm(emptyQuestion);
      setEditingQuestion(null);
      setNotice("حُفظ السؤال في قاعدة البيانات المشتركة.");
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function removeQuestion(item: LearningAssessment, questionId: string) {
    if (saving || !window.confirm("حذف السؤال؟")) return;
    setSaving(true);
    setError("");
    try {
      await deleteAssessmentQuestion(questionId, item.id);
      setQuestions(await loadAssessmentQuestionsAdmin(item.id));
      setNotice("حُذف السؤال.");
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function start(item: LearningAssessment) {
    setSaving(true);
    setError("");
    try {
      const started = await startAssessment(item.id);
      setAttempt(started);
      setAnswers(started.saved_answers);
      setSubmitted(false);
      setAttemptNotice(`المحاولة رقم ${started.attempt_number}. يُحفظ التقدم على الخادم.`);
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function saveProgress() {
    if (!attempt || saving) return;
    setSaving(true);
    setError("");
    try {
      for (const question of attempt.questions) {
        const answer = answers[question.id];
        if (answer !== undefined) {
          await saveAssessmentAnswer(attempt.attempt_id, question.id, answer);
        }
      }
      setNotice("حُفظ تقدمك ويمكنك المتابعة لاحقاً من هذا الجهاز أو جهاز آخر.");
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function submit(item: LearningAssessment) {
    if (!attempt || saving) return;
    setSaving(true);
    setError("");
    try {
      for (const question of attempt.questions) {
        const answer = answers[question.id];
        if (answer !== undefined) await saveAssessmentAnswer(attempt.attempt_id, question.id, answer);
      }
      const outcome = await submitAssessment(attempt.attempt_id);
      setSubmitted(true);
      setAttemptNotice(outcome.message);
      setNotice(outcome.needs_manual_grading
        ? "ستظهر النتيجة بعد مراجعة الإجابات الكتابية وإتاحة النتائج."
        : "سُجلت الإجابات. ستظهر النتيجة بعد إتاحتها من المعلم.");
      setResults(await loadAssessmentResults(item.id));
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function grade(answerId: string, maxPoints: number) {
    const scoreInput = document.querySelector<HTMLInputElement>(`[data-grade="${answerId}"]`);
    const feedbackInput = document.querySelector<HTMLTextAreaElement>(`[data-feedback="${answerId}"]`);
    const score = Number(scoreInput?.value);
    if (!Number.isFinite(score) || score < 0 || score > maxPoints) {
      setError(`أدخل درجة بين صفر و${maxPoints}.`);
      return;
    }
    setSaving(true);
    setError("");
    try {
      await gradeAssessmentAnswer(answerId, score, feedbackInput?.value ?? "");
      setNotice("حُفظ تصحيح الإجابة الكتابية.");
      if (openId) setResults(await loadAssessmentResults(openId));
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function toggleStatus(item: LearningAssessment) {
    setSaving(true);
    setError("");
    try {
      await setAssessmentStatus(item.id, item.status === "published" ? "draft" : "published");
      setNotice(item.status === "published" ? "أُوقف نشر التقييم." : "نُشر التقييم للطلاب.");
      reload();
      if (openId === item.id) setQuestions(await loadAssessmentQuestionsAdmin(item.id));
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function toggleResults(item: LearningAssessment) {
    setSaving(true);
    setError("");
    try {
      await setAssessmentResultsReleased(item.id, !item.results_released);
      setNotice(item.results_released ? "أُخفيت النتائج عن الطالب والأسرة." : "أُتيحت النتائج للطالب وولي الأمر المرتبط.");
      reload();
      setResults(await loadAssessmentResults(item.id));
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  return <section className="panel management-detail" aria-label="التقييمات والتمارين">
    <div className="page-heading">
      <div>
        <h3>التقييمات والتمارين</h3>
        <p className="muted">محاولات محفوظة، تصحيح آلي للموضوعي، ومراجعة كتابية من المعلم.</p>
      </div>
      {canManage && <button className="button primary" type="button" disabled={saving || createOpen}
        onClick={() => { setCreateOpen(true); setTitle(""); setInstructions(""); setError(""); }}>
        إنشاء تقييم
      </button>}
    </div>
    {notice && <p className="success-box" role="status">{notice}</p>}
    {(error || loadError) && <p className="error-box" role="alert">
      {error || loadError}
      {loadError && <button type="button" className="text-button" onClick={reload}>إعادة المحاولة</button>}
    </p>}
    {assessments === null && !loadError && <p role="status">جارٍ تحميل التقييمات...</p>}
    {assessments && assessments.length === 0 && <p className="muted">لا توجد تقييمات لهذا الدرس بعد.</p>}

    {createOpen && <form className="management-form" onSubmit={(event) => { event.preventDefault(); void saveNewAssessment(); }}>
      <h4>تقييم جديد — مسودة</h4>
      <label>العنوان<input required minLength={2} maxLength={200} value={title} onChange={(event) => setTitle(event.target.value)} /></label>
      <label>التعليمات<textarea rows={3} maxLength={4000} value={instructions} onChange={(event) => setInstructions(event.target.value)} /></label>
      <label>موعد التسليم<input type="datetime-local" value={dueAt} onChange={(event) => setDueAt(event.target.value)} /></label>
      <label>الحد الأقصى للمحاولات<input type="number" min={1} max={10} value={attemptLimit}
        onChange={(event) => setAttemptLimit(Number(event.target.value))} /></label>
      <div className="actions">
        <button className="button primary" disabled={saving}>{saving ? "جارٍ الإنشاء..." : "إنشاء المسودة"}</button>
        <button type="button" className="button secondary" disabled={saving} onClick={() => setCreateOpen(false)}>إلغاء</button>
      </div>
    </form>}

    {assessments?.map((item) => <article className="learn-exercise" key={item.id}>
      <div className="page-heading">
        <div>
          <h4>{item.title}</h4>
          <small className="learn-meta">
            {item.status === "published" ? "منشور" : "مسودة"}
            {" · "}
            {item.attempt_limit} محاولة كحد أقصى
            {item.due_at ? ` · التسليم ${new Date(item.due_at).toLocaleString("ar-EG")}` : " · بلا موعد نهائي"}
          </small>
        </div>
        <button type="button" className="button secondary" onClick={() => void openAssessment(item)}>
          {openId === item.id ? "إغلاق" : canManage ? "إدارة ونتائج" : "فتح التقييم"}
        </button>
      </div>
      {editing === item.id && canManage && <form className="management-form"
        onSubmit={(event) => { event.preventDefault(); void saveMetadata(item); }}>
        <label>العنوان<input value={title} onChange={(event) => setTitle(event.target.value)} /></label>
        <label>التعليمات<textarea rows={3} value={instructions} onChange={(event) => setInstructions(event.target.value)} /></label>
        <label>موعد التسليم<input type="datetime-local" value={dueAt} onChange={(event) => setDueAt(event.target.value)} /></label>
        <label>الحد الأقصى للمحاولات<input type="number" min={1} max={10} value={attemptLimit}
          onChange={(event) => setAttemptLimit(Number(event.target.value))} /></label>
        <div className="actions">
          <button className="button primary" disabled={saving}>حفظ التعديل</button>
          <button type="button" className="button secondary" onClick={() => setEditing("")}>إلغاء</button>
        </div>
      </form>}
      {openId === item.id && <>
        {item.instructions && <p>{item.instructions}</p>}
        {canManage && <div className="actions">
          <button type="button" className="text-button" onClick={() => beginEdit(item)}>تعديل إعدادات التقييم</button>
          <button type="button" className="text-button" disabled={saving} onClick={() => void toggleStatus(item)}>
            {item.status === "published" ? "إيقاف النشر" : "نشر للطلاب"}
          </button>
          <button type="button" className="text-button" disabled={saving || item.status !== "published"}
            onClick={() => void toggleResults(item)}>
            {item.results_released ? "إخفاء النتائج" : "إتاحة النتائج"}
          </button>
        </div>}

        {canManage && <>
          <h5>بنك أسئلة التقييم</h5>
          {!questions.length && <p className="muted">أضف سؤالاً واحداً على الأقل قبل النشر.</p>}
          {questions.map((question) => <div className="learn-exercise" key={question.id}>
            <strong>{question.prompt}</strong>
            <small className="learn-meta">{assessmentKindLabels[question.kind]} · {question.points} درجة</small>
            {question.kind === "matching" && <p className="data-note">
              {Object.entries(question.answer_key ?? {}).map(([left, right]) => `${left} ← ${right}`).join(" · ")}
            </p>}
            {question.kind === "fill_blank" && <p className="data-note">الإجابات المقبولة: {(question.answer_key as string[] | null)?.join("، ")}</p>}
            {(question.kind === "multiple_choice" || question.kind === "true_false")
              && <p className="data-note">الإجابة: {question.choices[question.correct_choice ?? 0]}</p>}
            <div className="actions">
              <button type="button" className="text-button" onClick={() => beginQuestionEdit(question)}>تعديل</button>
              <button type="button" className="text-button" disabled={saving}
                onClick={() => void removeQuestion(item, question.id)}>حذف</button>
            </div>
          </div>)}

          <form className="management-form" onSubmit={(event) => { event.preventDefault(); void saveQuestion(item); }}>
            <h5>{editingQuestion ? "تعديل السؤال" : "إضافة سؤال"}</h5>
            <label>نوع السؤال<select value={questionForm.kind} onChange={(event) => {
              const next = event.target.value as AssessmentQuestionKind;
              if (assessmentKinds.includes(next)) setQuestionForm({ ...questionForm, kind: next });
            }}>
              {assessmentKinds.map((kind) => <option value={kind} key={kind}>{assessmentKindLabels[kind]}</option>)}
            </select></label>
            <label>نص السؤال<input required maxLength={200} value={questionForm.prompt}
              onChange={(event) => setQuestionForm({ ...questionForm, prompt: event.target.value })} /></label>
            <label>الدرجة<input type="number" min={0.01} max={1000} step={0.01} value={questionForm.points}
              onChange={(event) => setQuestionForm({ ...questionForm, points: Number(event.target.value) })} /></label>
            {(questionForm.kind === "multiple_choice" || questionForm.kind === "true_false") && <>
              <label>الخيارات — كل خيار في سطر<textarea rows={4} value={questionForm.choices}
                onChange={(event) => setQuestionForm({ ...questionForm, choices: event.target.value, correct: 0 })} /></label>
              <label>الإجابة الصحيحة<select value={questionForm.correct}
                onChange={(event) => setQuestionForm({ ...questionForm, correct: Number(event.target.value) })}>
                {questionForm.choices.split(/\r?\n/).map((value, index) => value.trim() && <option value={index} key={index}>{value}</option>)}
              </select></label>
            </>}
            {questionForm.kind === "matching" && <>
              <label>العناصر المطلوب مطابقتها — كل عنصر في سطر<textarea rows={3} value={questionForm.choices}
                onChange={(event) => setQuestionForm({ ...questionForm, choices: event.target.value })} /></label>
              <label>الإجابات المطابقة بالترتيب نفسه<textarea rows={3} value={questionForm.matchingAnswers}
                onChange={(event) => setQuestionForm({ ...questionForm, matchingAnswers: event.target.value })} /></label>
            </>}
            {questionForm.kind === "fill_blank" && <label>الإجابات المقبولة — كل إجابة في سطر<textarea rows={3}
              value={questionForm.fillAnswers} onChange={(event) => setQuestionForm({ ...questionForm, fillAnswers: event.target.value })} /></label>}
            <div className="actions">
              <button className="button primary" disabled={saving}>{saving ? "جارٍ الحفظ..." : editingQuestion ? "حفظ السؤال" : "إضافة السؤال"}</button>
              {editingQuestion && <button type="button" className="button secondary" onClick={() => {
                setEditingQuestion(null); setQuestionForm(emptyQuestion);
              }}>إلغاء التعديل</button>}
            </div>
          </form>

          <h5>المحاولات والنتائج</h5>
          {!results.length && <p className="muted">لا توجد محاولات حتى الآن.</p>}
          {results.map((row) => row.answer_id && <div className="learn-exercise" key={row.answer_id}>
            <strong>{row.prompt}</strong>
            <p>{typeof row.answer === "string" ? row.answer : JSON.stringify(row.answer)}</p>
            {row.kind === "written" && !row.feedback && row.status !== "graded" && <div className="management-form">
              <label>الدرجة من {questions.find((question) => question.id === row.question_id)?.points ?? 0}
                <input type="number" min={0} step={0.01} data-grade={row.answer_id} />
              </label>
              <label>ملاحظات المعلم<textarea rows={2} data-feedback={row.answer_id} /></label>
              <button type="button" className="button secondary" disabled={saving}
                onClick={() => void grade(row.answer_id!, questions.find((question) => question.id === row.question_id)?.points ?? 0)}>
                حفظ التصحيح
              </button>
            </div>}
            {row.feedback && <p className="data-note">ملاحظات المعلم: {row.feedback}</p>}
          </div>)}
        </>}

        {canTake && item.status === "published" && !attempt && <button type="button"
          className="button primary" disabled={saving} onClick={() => void start(item)}>
          بدء التقييم أو استكمال المحاولة المحفوظة
        </button>}
        {canTake && attempt && !submitted && <>
          <p role="status">{attemptNotice}</p>
          {attempt.questions.map((question, index) => {
            const value = answers[question.id];
            return <fieldset className="learn-exercise" key={question.id} disabled={saving}>
              <legend>{index + 1}. {question.prompt} · {question.points} درجة</legend>
              {(question.kind === "multiple_choice" || question.kind === "true_false") && question.choices.map((choice, choiceIndex) =>
                <label className="learn-quiz-choice" key={choiceIndex}>
                  <input type="radio" name={`assessment-${question.id}`} checked={value === choiceIndex}
                    onChange={() => setAnswers({ ...answers, [question.id]: choiceIndex })} />
                  {choice}
                </label>)}
              {question.kind === "matching" && Array.from({ length: question.choices.length / 2 }, (_, pairIndex) => {
                const left = question.choices[pairIndex];
                const rightOptions = question.choices.slice(question.choices.length / 2);
                const match = (value && typeof value === "object" ? value : {}) as Record<string, string>;
                return <label key={left}>{left}<select value={match[left] ?? ""} onChange={(event) =>
                  setAnswers({ ...answers, [question.id]: { ...match, [left]: event.target.value } })}>
                  <option value="">اختر المطابقة</option>
                  {rightOptions.map((option) => <option key={option} value={option}>{option}</option>)}
                </select></label>;
              })}
              {(question.kind === "fill_blank" || question.kind === "written") && <textarea rows={question.kind === "written" ? 5 : 2}
                maxLength={5000} value={typeof value === "string" ? value : ""}
                onChange={(event) => setAnswers({ ...answers, [question.id]: event.target.value })} />}
            </fieldset>;
          })}
          <div className="actions">
            <button type="button" className="button secondary" disabled={saving} onClick={() => void saveProgress()}>حفظ التقدم</button>
            <button type="button" className="button primary" disabled={saving}
              onClick={() => void submit(item)}>{saving ? "جارٍ الحفظ والتسليم..." : "تسليم الإجابات"}</button>
          </div>
        </>}
        {canTake && submitted && <p className="success-box" role="status">{attemptNotice} {notice}</p>}
        {!canTake && !canManage && <>
          {!results.length && <p className="data-note">تظهر نتيجة الطالب هنا بعد إتاحتها من المعلم.</p>}
          {results.map((row) => <p className="data-note" key={row.answer_id ?? row.attempt_id}>
            {row.status === "graded" ? `النتيجة ${row.score ?? 0} من ${row.max_score}` : "ما زالت النتيجة قيد التصحيح."}
            {row.feedback ? ` · ${row.feedback}` : ""}
          </p>)}
        </>}
      </>}
    </article>)}
  </section>;
}
