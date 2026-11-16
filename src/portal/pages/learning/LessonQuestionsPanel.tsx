import { useCallback, useEffect, useState } from "react";
import {
  createExerciseQuestion, deleteExerciseQuestion, exerciseKindLabels, exerciseKinds,
  loadExerciseQuestionsAdmin, updateExerciseQuestion,
  type ExerciseKind, type ExerciseQuestionAdmin,
} from "@/portal/lib/exercises";
import { loadCourseVocabulary, type VocabularyWord } from "@/portal/lib/vocabulary";
import type { LearningCourse } from "@/portal/lib/learning";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

type Form = {
  kind: ExerciseKind;
  prompt: string;
  choices: string;
  correct: number;
  vocabularyId: string;
  published: boolean;
};

const emptyForm: Form = { kind: "vocabulary", prompt: "", choices: "", correct: 0, vocabularyId: "", published: true };

/**
 * Teacher authoring of scored questions for one lesson. The correct answer is
 * written to the server-held key column and read back through the manager-only
 * RPC; students never receive it.
 */
export function LessonQuestionsPanel({
  lessonId, course, onChanged,
}: {
  lessonId: string;
  course: LearningCourse;
  onChanged: () => void;
}) {
  const [questions, setQuestions] = useState<ExerciseQuestionAdmin[] | null>(null);
  const [words, setWords] = useState<VocabularyWord[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<ExerciseQuestionAdmin | null>(null);
  const [form, setForm] = useState<Form>(emptyForm);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const load = useCallback(() => {
    setQuestions(null);
    setLoadError(null);
    void loadExerciseQuestionsAdmin(lessonId)
      .then((rows) => setQuestions(rows))
      .catch((failure: unknown) => setLoadError(message(failure)));
  }, [lessonId]);

  useEffect(() => {
    load();
    void loadCourseVocabulary(course.id)
      .then((rows) => setWords(rows.filter((row) => row.lesson_id === lessonId)))
      .catch(() => setWords([]));
  }, [load, course.id, lessonId]);

  function startCreate() {
    setEditing(null);
    setForm(emptyForm);
    setError(null);
    setOpen(true);
  }

  function startEdit(question: ExerciseQuestionAdmin) {
    setEditing(question);
    setForm({
      kind: question.kind,
      prompt: question.prompt,
      choices: question.choices.join("\n"),
      correct: question.correct_choice,
      vocabularyId: question.vocabulary_id ?? "",
      published: question.is_published,
    });
    setError(null);
    setOpen(true);
  }

  async function submit() {
    if (busy) return;
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      const input = {
        lessonId,
        vocabularyId: form.vocabularyId || null,
        kind: form.kind,
        prompt: form.prompt,
        choices: form.choices.split(/\r?\n/).map((choice) => choice.trim()).filter(Boolean),
        correctChoice: form.correct,
        isPublished: form.published,
      };
      if (editing) {
        await updateExerciseQuestion(editing.id, input);
        setNotice("حُفظ تعديل السؤال.");
      } else {
        await createExerciseQuestion(input);
        setNotice("أُضيف السؤال إلى تقييم الدرس.");
      }
      setOpen(false);
      setEditing(null);
      load();
      onChanged();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  async function remove(question: ExerciseQuestionAdmin) {
    if (busy || !window.confirm("حذف هذا السؤال؟ تبقى إجابات الطلاب السابقة محفوظة في سجلهم.")) return;
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await deleteExerciseQuestion(question.id, lessonId);
      setNotice("حُذف السؤال.");
      load();
      onChanged();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  const choiceList = form.choices.split(/\r?\n/).map((choice) => choice.trim()).filter(Boolean);

  return <section className="panel management-detail" aria-label="أسئلة التقييم">
    <div className="page-heading">
      <div>
        <h2>أسئلة التقييم المُصحَّحة</h2>
        <p className="muted">تُصحَّح الإجابات على الخادم؛ لا تصل الإجابة الصحيحة إلى جهاز الطالب.</p>
      </div>
      <div className="actions">
        <button type="button" className="button primary" disabled={busy || open} onClick={startCreate}>
          <i className="ri-add-line" aria-hidden="true"></i> إضافة سؤال
        </button>
      </div>
    </div>

    {notice && <p className="success-box" role="status">{notice}</p>}
    {loadError && <p className="error-box" role="alert">{loadError} <button type="button" className="text-button" onClick={load}>إعادة المحاولة</button></p>}
    {questions === null && !loadError && <p role="status">جارٍ تحميل الأسئلة...</p>}

    {questions && !questions.length && <p className="muted">لا توجد أسئلة تقييم لهذا الدرس بعد؛ أضف سؤالاً ليتمكن الطلاب من التقييم المُصحَّح.</p>}
    {questions && !!questions.length && <ul className="learn-lesson-manage">
      {questions.map((question) => <li key={question.id}>
        <span>
          {question.position}. {question.prompt}{" "}
          <small className="learn-meta">
            {exerciseKindLabels[question.kind]} · {question.choices.length} خيارات · الإجابة: {question.choices[question.correct_choice]} · {question.is_published ? "منشور" : "مسودة"}
          </small>
        </span>
        <span className="actions">
          <button type="button" className="text-button" disabled={busy} onClick={() => startEdit(question)}>تعديل</button>
          <button type="button" className="text-button" disabled={busy} onClick={() => void remove(question)}>حذف</button>
        </span>
      </li>)}
    </ul>}

    {open && <form className="management-form" onSubmit={(event) => { event.preventDefault(); void submit(); }}>
      <label>نوع السؤال
        <select value={form.kind} onChange={(event) => {
          if ((exerciseKinds as readonly string[]).includes(event.target.value)) {
            setForm({ ...form, kind: event.target.value as ExerciseKind });
          }
        }}>
          {exerciseKinds.map((kind) => <option key={kind} value={kind}>{exerciseKindLabels[kind]}</option>)}
        </select>
      </label>
      <label>نص السؤال<span className="vocab-required"> *</span>
        <input required value={form.prompt} onChange={(event) => setForm({ ...form, prompt: event.target.value })} />
      </label>
      {form.kind === "vocabulary" && <label>ربط بمفردة الدرس (اختياري — تُعاد المفردة الخاطئة إلى المراجعة)
        <select value={form.vocabularyId} onChange={(event) => setForm({ ...form, vocabularyId: event.target.value })}>
          <option value="">بدون ربط</option>
          {words.map((word) => <option key={word.id} value={word.id}>{word.hanzi} — {word.meaning_ar}</option>)}
        </select>
      </label>}
      <label>الخيارات (خيار واحد في كل سطر، ٢–٦ خيارات)<span className="vocab-required"> *</span>
        <textarea required rows={4} value={form.choices}
          onChange={(event) => setForm({ ...form, choices: event.target.value, correct: 0 })} />
      </label>
      <label>الإجابة الصحيحة
        <select value={form.correct} onChange={(event) => setForm({ ...form, correct: Number(event.target.value) })}>
          {choiceList.map((choice, index) => <option key={`${index}-${choice}`} value={index}>{index + 1}. {choice}</option>)}
        </select>
      </label>
      <label>النشر
        <select value={form.published ? "yes" : "no"} onChange={(event) => setForm({ ...form, published: event.target.value === "yes" })}>
          <option value="yes">منشور للطلاب</option>
          <option value="no">مسودة مخفية</option>
        </select>
      </label>
      {error && <p className="error-box" role="alert">{error}</p>}
      <div className="actions">
        <button className="button primary" disabled={busy}>{busy ? "جارٍ الحفظ..." : editing ? "حفظ التعديل" : "إضافة السؤال"}</button>
        <button type="button" className="button secondary" disabled={busy} onClick={() => { setOpen(false); setEditing(null); }}>إلغاء</button>
      </div>
    </form>}
  </section>;
}
