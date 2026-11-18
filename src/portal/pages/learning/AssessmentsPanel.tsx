import { useCallback, useEffect, useState } from "react";
import {
  assessmentKindLabels,
  assessmentKinds,
  addAssessmentQuestionFromBank,
  assignAssessmentStudents,
  createAssessment,
  createAssessmentQuestion,
  duplicateAssessment,
  deleteAssessmentQuestion,
  gradeAssessmentAnswer,
  loadAssessmentRoster,
  loadAssessmentQuestionBank,
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
  type AssessmentStudent,
  type LearningAssessment,
} from "@/portal/lib/assessments";

type QuestionForm = {
  kind: AssessmentQuestionKind;
  prompt: string;
  points: number;
  choices: string;
  correct: number;
  correctIndexes: string;
  orderingAnswers: string;
  fillAnswers: string;
  matchingAnswers: string;
};

const emptyQuestion: QuestionForm = {
  kind: "multiple_choice",
  prompt: "",
  points: 1,
  choices: "",
  correct: 0,
  correctIndexes: "",
  orderingAnswers: "",
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

function cleanStartDate(value: string): string | null {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new Error("موعد البدء غير صالح.");
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
  const [bankQuestions, setBankQuestions] = useState<AssessmentQuestionAdmin[]>([]);
  const [previewMode, setPreviewMode] = useState(false);
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
  const [startsAt, setStartsAt] = useState("");
  const [dueAt, setDueAt] = useState("");
  const [timeLimitMinutes, setTimeLimitMinutes] = useState<number | null>(null);
  const [attemptLimit, setAttemptLimit] = useState(1);
  const [passingScore, setPassingScore] = useState(70);
  const [randomizeQuestions, setRandomizeQuestions] = useState(false);
  const [editing, setEditing] = useState("");
  const [questionForm, setQuestionForm] = useState<QuestionForm>(emptyQuestion);
  const [questionCategory, setQuestionCategory] = useState("");
  const [editingQuestion, setEditingQuestion] = useState<string | null>(null);
  const [assignmentFor, setAssignmentFor] = useState("");
  const [roster, setRoster] = useState<AssessmentStudent[] | null>(null);
  const [selectedStudents, setSelectedStudents] = useState<Set<string>>(new Set());
  const [assignmentBusy, setAssignmentBusy] = useState(false);

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
    setPreviewMode(false);
    setError("");
    setNotice("");
    if (openId === item.id) return;
    if (canManage) {
      try {
        const [loadedQuestions, loadedResults, loadedBank] = await Promise.all([
          loadAssessmentQuestionsAdmin(item.id),
          loadAssessmentResults(item.id),
          loadAssessmentQuestionBank(item.course_id),
        ]);
        setQuestions(loadedQuestions);
        setResults(loadedResults);
        setBankQuestions(loadedBank);
      } catch (failure) {
        setError(message(failure));
      }
    } else {
      setQuestions([]);
      setBankQuestions([]);
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
    setStartsAt(localDate(item.starts_at));
    setDueAt(localDate(item.due_at));
    setTimeLimitMinutes(item.time_limit_minutes);
    setAttemptLimit(item.attempt_limit);
    setPassingScore(item.passing_score);
    setRandomizeQuestions(item.randomize_questions);
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
        startsAt: cleanStartDate(startsAt),
        dueAt: cleanDate(dueAt),
        timeLimitMinutes,
        attemptLimit,
        passingScore,
        randomizeQuestions,
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
        startsAt: cleanStartDate(startsAt),
        dueAt: cleanDate(dueAt),
        timeLimitMinutes,
        attemptLimit,
        passingScore,
        randomizeQuestions,
      });
      setCreateOpen(false);
      setTitle("");
      setInstructions("");
      setStartsAt("");
      setDueAt("");
      setTimeLimitMinutes(null);
      setAttemptLimit(1);
      setPassingScore(70);
      setRandomizeQuestions(false);
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
    let answerKey: Record<string, string> | string[] | number[] | null = null;
    if (questionForm.kind === "multiple_select") {
      answerKey = questionForm.correctIndexes.split(/[,\s]+/).filter(Boolean).map(Number);
      choices = choiceLines;
    } else if (questionForm.kind === "ordering") {
      answerKey = questionForm.orderingAnswers.split(/\r?\n/).map((value) => value.trim()).filter(Boolean);
    } else if (questionForm.kind === "matching") {
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
      bankCategory: questionCategory,
      choices,
      correctChoice: questionForm.kind === "multiple_choice" || questionForm.kind === "true_false"
        ? questionForm.correct
        : null,
      answerKey,
    };
  }

  function beginQuestionEdit(question: AssessmentQuestionAdmin) {
    const choiceCount = question.kind === "matching" ? question.choices.length / 2 : question.choices.length;
    const fillKey = question.kind === "fill_blank" && Array.isArray(question.answer_key)
      ? question.answer_key.join("\n") : "";
    const correctIndexes = question.kind === "multiple_select" && Array.isArray(question.answer_key)
      ? question.answer_key.join(",") : "";
    const orderingAnswers = question.kind === "ordering" && Array.isArray(question.answer_key)
      ? question.answer_key.join("\n") : "";
    const key = question.answer_key && !Array.isArray(question.answer_key) ? question.answer_key : {};
    const matchingKey = question.choices.slice(0, choiceCount).map((left) => key[left] ?? "").join("\n");
    setEditingQuestion(question.id);
    setQuestionCategory(question.bank_category ?? "");
    setQuestionForm({
      kind: question.kind,
      prompt: question.prompt,
      points: question.points,
      choices: question.kind === "matching" ? question.choices.slice(0, choiceCount).join("\n")
        : question.choices.join("\n"),
      correct: question.correct_choice ?? 0,
      correctIndexes,
      orderingAnswers,
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
      const [updatedQuestions, updatedBank] = await Promise.all([
        loadAssessmentQuestionsAdmin(item.id),
        loadAssessmentQuestionBank(item.course_id),
      ]);
      setQuestions(updatedQuestions);
      setBankQuestions(updatedBank);
      setQuestionForm(emptyQuestion);
      setQuestionCategory("");
      setEditingQuestion(null);
      setNotice("حُفظ السؤال في قاعدة البيانات المشتركة.");
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function addBankQuestion(item: LearningAssessment, questionId: string) {
    if (saving) return;
    setSaving(true);
    setError("");
    try {
      await addAssessmentQuestionFromBank(item.id, questionId);
      setQuestions(await loadAssessmentQuestionsAdmin(item.id));
      setNotice("أُضيف السؤال المصنف إلى مسودة التقييم.");
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
      setSubmitted(started.status !== "in_progress");
      setAttemptNotice(started.timed_out
        ? "انتهى الوقت وأُرسلت الإجابات المحفوظة تلقائياً."
        : `المحاولة رقم ${started.attempt_number}. يُحفظ التقدم على الخادم.`);
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

  async function changeStatus(item: LearningAssessment, status: LearningAssessment["status"]) {
    setSaving(true);
    setError("");
    try {
      await setAssessmentStatus(item.id, status);
      setNotice(status === "published" ? "نُشر التقييم للطلاب."
        : status === "closed" ? "أُغلق التقييم ومنع بدء محاولات جديدة."
          : status === "archived" ? "أُرشف التقييم." : "أُعيد التقييم إلى المسودات.");
      reload();
      if (openId === item.id) setQuestions(await loadAssessmentQuestionsAdmin(item.id));
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSaving(false);
    }
  }

  async function openAssignments(item: LearningAssessment) {
    setAssignmentFor(item.id);
    setRoster(null);
    setError("");
    try {
      const students = await loadAssessmentRoster(item.id);
      setRoster(students);
      setSelectedStudents(new Set(students.filter((student) => student.assigned)
        .map((student) => student.student_id)));
    } catch (failure) {
      setError(message(failure));
    }
  }

  async function saveAssignments(item: LearningAssessment, allStudents = false) {
    if (assignmentBusy) return;
    setAssignmentBusy(true);
    setError("");
    try {
      await assignAssessmentStudents(item.id, allStudents ? [] : [...selectedStudents]);
      setNotice(allStudents ? "أُسند التقييم إلى الصف بالكامل." : "حُفظ تعيين الطلاب.");
      setAssignmentFor("");
      setRoster(null);
    } catch (failure) {
      setError(message(failure));
    } finally {
      setAssignmentBusy(false);
    }
  }

  async function duplicate(item: LearningAssessment) {
    setSaving(true);
    setError("");
    try {
      const id = await duplicateAssessment(item.id);
      setNotice("أُنشئت نسخة مسودة بأسئلة التقييم، دون نسخ المحاولات أو الطلاب المعيّنين.");
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
        onClick={() => {
          setCreateOpen(true);
          setTitle("");
          setInstructions("");
          setStartsAt("");
          setDueAt("");
          setTimeLimitMinutes(null);
          setAttemptLimit(1);
          setPassingScore(70);
          setRandomizeQuestions(false);
          setError("");
        }}>
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
      <label>موعد البدء<input type="datetime-local" value={startsAt} onChange={(event) => setStartsAt(event.target.value)} /></label>
      <label>موعد الإغلاق<input type="datetime-local" value={dueAt} onChange={(event) => setDueAt(event.target.value)} /></label>
      <label>مدة المحاولة بالدقائق (اختياري)<input type="number" min={1} max={300} value={timeLimitMinutes ?? ""}
        onChange={(event) => setTimeLimitMinutes(event.target.value ? Number(event.target.value) : null)} /></label>
      <label>الحد الأقصى للمحاولات<input type="number" min={1} max={10} value={attemptLimit}
        onChange={(event) => setAttemptLimit(Number(event.target.value))} /></label>
      <label>درجة الاجتياز (%)<input type="number" min={0} max={100} step={0.01} value={passingScore}
        onChange={(event) => setPassingScore(Number(event.target.value))} /></label>
      <label className="inline-control"><input type="checkbox" checked={randomizeQuestions}
        onChange={(event) => setRandomizeQuestions(event.target.checked)} /> ترتيب عشوائي ثابت لكل محاولة</label>
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
            {({ draft: "مسودة", published: "منشور", closed: "مغلق", archived: "مؤرشف" } as const)[item.status]}
            {item.starts_at ? ` · يبدأ ${new Date(item.starts_at).toLocaleString("ar-EG")}` : ""}
            {item.due_at ? ` · الإغلاق ${new Date(item.due_at).toLocaleString("ar-EG")}` : " · بلا موعد إغلاق"}
            {" · "}
            {item.attempt_limit} محاولة كحد أقصى
            {item.time_limit_minutes ? ` · ${item.time_limit_minutes} دقيقة للمحاولة` : ""}
            {` · الاجتياز ${item.passing_score}%`}
            {item.randomize_questions ? " · ترتيب عشوائي" : ""}
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
        <label>موعد البدء<input type="datetime-local" value={startsAt} onChange={(event) => setStartsAt(event.target.value)} /></label>
        <label>موعد الإغلاق<input type="datetime-local" value={dueAt} onChange={(event) => setDueAt(event.target.value)} /></label>
        <label>مدة المحاولة بالدقائق (اختياري)<input type="number" min={1} max={300} value={timeLimitMinutes ?? ""}
          onChange={(event) => setTimeLimitMinutes(event.target.value ? Number(event.target.value) : null)} /></label>
        <label>الحد الأقصى للمحاولات<input type="number" min={1} max={10} value={attemptLimit}
          onChange={(event) => setAttemptLimit(Number(event.target.value))} /></label>
        <label>درجة الاجتياز (%)<input type="number" min={0} max={100} step={0.01} value={passingScore}
          onChange={(event) => setPassingScore(Number(event.target.value))} /></label>
        <label className="inline-control"><input type="checkbox" checked={randomizeQuestions}
          onChange={(event) => setRandomizeQuestions(event.target.checked)} /> ترتيب عشوائي ثابت لكل محاولة</label>
        <div className="actions">
          <button className="button primary" disabled={saving}>حفظ التعديل</button>
          <button type="button" className="button secondary" onClick={() => setEditing("")}>إلغاء</button>
        </div>
      </form>}
      {openId === item.id && <>
        {item.instructions && <p>{item.instructions}</p>}
        {canManage && <div className="actions">
          {item.status !== "archived" && <button type="button" className="text-button" onClick={() => beginEdit(item)}>تعديل إعدادات التقييم</button>}
          {item.status === "draft" && <button type="button" className="text-button" disabled={saving}
            onClick={() => void changeStatus(item, "published")}>نشر للطلاب</button>}
          {item.status === "published" && <button type="button" className="text-button" disabled={saving}
            onClick={() => void changeStatus(item, "closed")}>إغلاق التقييم</button>}
          {item.status === "closed" && <button type="button" className="text-button" disabled={saving}
            onClick={() => void changeStatus(item, "archived")}>أرشفة التقييم</button>}
          {item.status !== "archived" && <button type="button" className="text-button" disabled={saving}
            onClick={() => void duplicate(item)}>نسخ التقييم</button>}
          {item.status !== "closed" && item.status !== "archived" && <button type="button" className="text-button"
            disabled={saving || assignmentBusy} onClick={() => void openAssignments(item)}>تعيين الطلاب</button>}
          <button type="button" className="text-button" disabled={saving || item.status === "draft" || item.status === "archived"}
            onClick={() => void toggleResults(item)}>
            {item.results_released ? "إخفاء النتائج" : "إتاحة النتائج"}
          </button>
        </div>}

        {canManage && assignmentFor === item.id && <section className="management-form" aria-label="تعيين طلاب التقييم">
          <h5>تعيين الطلاب</h5>
          {!roster && <p role="status">جارٍ تحميل طلاب الصف...</p>}
          {roster?.length === 0 && <p className="muted">لا يوجد طلاب نشطون في الصف.</p>}
          {roster?.map((student) => <label className="inline-control" key={student.student_id}>
            <input type="checkbox" checked={selectedStudents.has(student.student_id)}
              onChange={(event) => setSelectedStudents((current) => {
                const next = new Set(current);
                if (event.target.checked) next.add(student.student_id);
                else next.delete(student.student_id);
                return next;
              })} />
            {student.full_name} · {student.admission_no}
          </label>)}
          <div className="actions">
            <button type="button" className="button primary" disabled={assignmentBusy || !roster?.length || !selectedStudents.size}
              onClick={() => void saveAssignments(item)}>
              {assignmentBusy ? "جارٍ الحفظ..." : "حفظ التعيين الفردي"}
            </button>
            <button type="button" className="button secondary" disabled={assignmentBusy}
              onClick={() => void saveAssignments(item, true)}>إسناد إلى الصف بالكامل</button>
            <button type="button" className="button secondary" disabled={assignmentBusy}
              onClick={() => { setAssignmentFor(""); setRoster(null); }}>إلغاء</button>
          </div>
        </section>}

        {canManage && <>
          <h5>بنك أسئلة التقييم</h5>
          <button type="button" className="text-button"
            onClick={() => setPreviewMode((current) => !current)}>
            {previewMode ? "إغلاق معاينة الطالب" : "معاينة عرض الطالب"}
          </button>
          {previewMode && <section className="management-form" aria-label="معاينة الطالب">
            <h6>معاينة الطالب — دون مفاتيح الإجابة</h6>
            {questions.map((question, index) => <fieldset className="learn-exercise" key={question.id} disabled>
              <legend>{index + 1}. {question.prompt} · {question.points} درجة</legend>
              {(question.kind === "multiple_choice" || question.kind === "true_false") && question.choices.map((choice, choiceIndex) =>
                <label className="learn-quiz-choice" key={choiceIndex}>
                  <input type="radio" name={`preview-${question.id}`} />
                  {choice}
                </label>)}
              {question.kind === "multiple_select" && question.choices.map((choice) =>
                <label className="learn-quiz-choice" key={choice}>
                  <input type="checkbox" />
                  {choice}
                </label>)}
              {question.kind === "ordering" && question.choices.map((choice, orderIndex) =>
                <p key={choice}>{orderIndex + 1}. {choice}</p>)}
              {question.kind === "matching" && question.choices.slice(0, question.choices.length / 2).map((choice) =>
                <label key={choice}>{choice}<select><option>اختر المطابقة</option>
                  {question.choices.slice(question.choices.length / 2).map((option) => <option key={option}>{option}</option>)}
                </select></label>)}
              {question.kind === "fill_blank" && <input aria-label="إجابة الطالب" />}
              {question.kind === "written" && <textarea rows={4} aria-label="إجابة الطالب" />}
            </fieldset>)}
            {!questions.length && <p className="muted">أضف أسئلة لعرض المعاينة.</p>}
          </section>}
          {item.status === "draft" && bankQuestions.length > 0 && <section className="management-form" aria-label="الأسئلة المصنفة القابلة لإعادة الاستخدام">
            <h6>أسئلة مصنفة قابلة لإعادة الاستخدام</h6>
            {bankQuestions.map((question) => <div className="actions" key={question.id}>
              <span>{question.bank_category} · {question.prompt}</span>
              <button type="button" className="text-button" disabled={saving}
                onClick={() => void addBankQuestion(item, question.id)}>إضافة للمسودة</button>
            </div>)}
          </section>}
          {!questions.length && <p className="muted">أضف سؤالاً واحداً على الأقل قبل النشر.</p>}
          {questions.map((question) => <div className="learn-exercise" key={question.id}>
            <strong>{question.prompt}</strong>
            <small className="learn-meta">{assessmentKindLabels[question.kind]} · {question.points} درجة</small>
            {question.bank_category && <small className="learn-meta">تصنيف البنك: {question.bank_category}</small>}
            {question.kind === "matching" && <p className="data-note">
              {Object.entries(question.answer_key ?? {}).map(([left, right]) => `${left} ← ${right}`).join(" · ")}
            </p>}
            {question.kind === "fill_blank" && <p className="data-note">الإجابات المقبولة: {(question.answer_key as string[] | null)?.join("، ")}</p>}
            {(question.kind === "multiple_choice" || question.kind === "true_false")
              && <p className="data-note">الإجابة: {question.choices[question.correct_choice ?? 0]}</p>}
            {question.kind === "multiple_select" && <p className="data-note">
              الإجابات: {(question.answer_key as number[] | null)?.map((index) => question.choices[index]).join("، ")}
            </p>}
            {question.kind === "ordering" && <p className="data-note">
              الترتيب الصحيح: {(question.answer_key as string[] | null)?.join(" ← ")}
            </p>}
            {item.status !== "closed" && item.status !== "archived" && <div className="actions">
              <button type="button" className="text-button" onClick={() => beginQuestionEdit(question)}>تعديل</button>
              <button type="button" className="text-button" disabled={saving}
                onClick={() => void removeQuestion(item, question.id)}>حذف</button>
            </div>}
          </div>)}

          {item.status !== "closed" && item.status !== "archived" && <form className="management-form" onSubmit={(event) => { event.preventDefault(); void saveQuestion(item); }}>
            <h5>{editingQuestion ? "تعديل السؤال" : "إضافة سؤال"}</h5>
            <label>نوع السؤال<select value={questionForm.kind} onChange={(event) => {
              const next = event.target.value as AssessmentQuestionKind;
              if (assessmentKinds.includes(next)) setQuestionForm({ ...questionForm, kind: next });
            }}>
              {assessmentKinds.map((kind) => <option value={kind} key={kind}>{assessmentKindLabels[kind]}</option>)}
            </select></label>
            <label>نص السؤال<input required maxLength={200} value={questionForm.prompt}
              onChange={(event) => setQuestionForm({ ...questionForm, prompt: event.target.value })} /></label>
            <label>تصنيف بنك الأسئلة (اختياري)<input maxLength={80} value={questionCategory}
              onChange={(event) => setQuestionCategory(event.target.value)} /></label>
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
            {questionForm.kind === "multiple_select" && <>
              <label>الخيارات — كل خيار في سطر<textarea rows={4} value={questionForm.choices}
                onChange={(event) => setQuestionForm({ ...questionForm, choices: event.target.value })} /></label>
              <label>أرقام الإجابات الصحيحة، بدءاً من صفر<input value={questionForm.correctIndexes}
                onChange={(event) => setQuestionForm({ ...questionForm, correctIndexes: event.target.value })} /></label>
            </>}
            {questionForm.kind === "ordering" && <>
              <label>العناصر المطلوب ترتيبها — كل عنصر في سطر<textarea rows={4} value={questionForm.choices}
                onChange={(event) => setQuestionForm({ ...questionForm, choices: event.target.value })} /></label>
              <label>الترتيب الصحيح — أعد كتابة العناصر بالترتيب<textarea rows={4} value={questionForm.orderingAnswers}
                onChange={(event) => setQuestionForm({ ...questionForm, orderingAnswers: event.target.value })} /></label>
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
          </form>}

          <h5>المحاولات والنتائج</h5>
          {!results.length && <p className="muted">لا توجد محاولات حتى الآن.</p>}
          {results.map((row) => row.answer_id && <div className="learn-exercise" key={row.answer_id}>
            <strong>{row.prompt}</strong>
            {typeof row.passed === "boolean" && <small className="learn-meta">{row.passed ? "مجتاز" : "لم يجتز"}</small>}
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
          className="button primary"
          disabled={saving
            || Boolean(item.starts_at && Date.now() < new Date(item.starts_at).getTime())
            || Boolean(item.due_at && Date.now() > new Date(item.due_at).getTime())}
          onClick={() => void start(item)}>
          {item.starts_at && Date.now() < new Date(item.starts_at).getTime()
            ? `يفتح في ${new Date(item.starts_at).toLocaleString("ar-EG")}`
            : "بدء التقييم أو استكمال المحاولة المحفوظة"}
        </button>}
        {canTake && attempt && !submitted && <>
          <p role="status">{attemptNotice}</p>
          {attempt.expires_at && <p className="data-note">
            يجب التسليم قبل {new Date(attempt.expires_at).toLocaleString("ar-EG")}.
          </p>}
          {attempt.questions.map((question, index) => {
            const value = answers[question.id];
            const orderedChoices = question.kind === "ordering" && Array.isArray(value)
              ? value as string[] : question.choices;
            return <fieldset className="learn-exercise" key={question.id} disabled={saving}>
              <legend>{index + 1}. {question.prompt} · {question.points} درجة</legend>
              {(question.kind === "multiple_choice" || question.kind === "true_false") && question.choices.map((choice, choiceIndex) =>
                <label className="learn-quiz-choice" key={choiceIndex}>
                  <input type="radio" name={`assessment-${question.id}`} checked={value === choiceIndex}
                    onChange={() => setAnswers({ ...answers, [question.id]: choiceIndex })} />
                  {choice}
                </label>)}
              {question.kind === "multiple_select" && question.choices.map((choice, choiceIndex) => {
                const selected = Array.isArray(value) ? value as number[] : [];
                return <label className="learn-quiz-choice" key={choiceIndex}>
                  <input type="checkbox" checked={selected.includes(choiceIndex)}
                    onChange={(event) => {
                      const next = new Set(selected);
                      if (event.target.checked) next.add(choiceIndex);
                      else next.delete(choiceIndex);
                      setAnswers({ ...answers, [question.id]: [...next].sort((a, b) => a - b) });
                    }} />
                  {choice}
                </label>;
              })}
              {question.kind === "ordering" && orderedChoices.map((choice, choiceIndex) =>
                <div className="actions" key={choice}>
                  <span>{choiceIndex + 1}. {choice}</span>
                  <button type="button" className="text-button" disabled={saving || submitted || choiceIndex === 0}
                    onClick={() => {
                      const next = [...orderedChoices];
                      [next[choiceIndex - 1], next[choiceIndex]] = [next[choiceIndex], next[choiceIndex - 1]];
                      setAnswers({ ...answers, [question.id]: next });
                    }}>↑</button>
                  <button type="button" className="text-button" disabled={saving || submitted || choiceIndex === orderedChoices.length - 1}
                    onClick={() => {
                      const next = [...orderedChoices];
                      [next[choiceIndex], next[choiceIndex + 1]] = [next[choiceIndex + 1], next[choiceIndex]];
                      setAnswers({ ...answers, [question.id]: next });
                    }}>↓</button>
                </div>)}
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
            {typeof row.passed === "boolean" ? ` · ${row.passed ? "مجتاز" : "لم يجتز"}` : ""}
            {row.feedback ? ` · ${row.feedback}` : ""}
          </p>)}
        </>}
      </>}
    </article>)}
  </section>;
}
