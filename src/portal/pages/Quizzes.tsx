import { useCallback, useEffect, useMemo, useState } from "react";
import { LabPage, LabStats, LabTabs } from "@/portal/pages/labs/LabShell";
import {
  loadQuizzes, loadQuizQuestions, loadAttempts, submitQuizAttempt, setQuizStatus,
  normalizeChoices, attemptPercent, QUESTION_TYPE_LABELS,
  type QuizSummary, type QuizQuestion, type QuizAttempt, type QuizStatus,
} from "@/portal/lib/quizRepository";

function formatDate(value: string | null): string {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

export function Quizzes() {
  const [quizzes, setQuizzes] = useState<QuizSummary[]>([]);
  const [questions, setQuestions] = useState<QuizQuestion[]>([]);
  const [attempts, setAttempts] = useState<QuizAttempt[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tab, setTab] = useState<"manage" | "take" | "results">("manage");
  const [selectedQuizId, setSelectedQuizId] = useState<string | null>(null);
  const [activeQuizId, setActiveQuizId] = useState<string | null>(null);
  const [answers, setAnswers] = useState<Record<string, number>>({});
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [quizRows, attemptRows] = await Promise.all([loadQuizzes(), loadAttempts()]);
      setQuizzes(quizRows);
      setAttempts(attemptRows);
      setSelectedQuizId((current) => current ?? quizRows[0]?.id ?? null);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  useEffect(() => {
    if (!selectedQuizId) { setQuestions([]); return; }
    let cancelled = false;
    loadQuizQuestions(selectedQuizId)
      .then((rows) => { if (!cancelled) setQuestions(rows); })
      .catch((caught) => { if (!cancelled) setError(caught instanceof Error ? caught.message : String(caught)); });
    return () => { cancelled = true; };
  }, [selectedQuizId]);

  const selected = quizzes.find((quiz) => quiz.id === selectedQuizId) ?? null;
  const active = quizzes.find((quiz) => quiz.id === activeQuizId) ?? null;

  const stats = useMemo(() => {
    const published = quizzes.filter((quiz) => quiz.status === "published").length;
    const avg = attempts.length
      ? Math.round(attempts.reduce((sum, attempt) => sum + attemptPercent(attempt.score, attempt.max_score), 0) / attempts.length)
      : 0;
    return { published, drafts: quizzes.length - published, attempts: attempts.length, avg };
  }, [quizzes, attempts]);

  async function togglePublish(quiz: QuizSummary) {
    setError(null);
    setNotice(null);
    try {
      const next: QuizStatus = quiz.status === "published" ? "draft" : "published";
      await setQuizStatus(quiz.id, next);
      setQuizzes((current) => current.map((row) => (row.id === quiz.id ? { ...row, status: next } : row)));
      setNotice(next === "published" ? "نُشر الاختبار وأصبح متاحاً للطلاب المؤهلين." : "أُلغي نشر الاختبار.");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    }
  }

  async function startQuiz(quiz: QuizSummary) {
    setError(null);
    setNotice(null);
    if (quiz.status !== "published") { setError("لا يمكن بدء اختبار غير منشور."); return; }
    try {
      const rows = await loadQuizQuestions(quiz.id);
      if (!rows.length) { setError("لا توجد أسئلة متاحة لهذا الاختبار أو أنك غير مؤهل."); return; }
      setActiveQuizId(quiz.id);
      setAnswers({});
      setTab("take");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    }
  }

  async function submit() {
    if (!active) return;
    setError(null);
    setNotice(null);
    const payload = Object.entries(answers).map(([questionId, choiceIndex]) => ({
      question_id: questionId,
      choice_index: choiceIndex,
    }));
    if (!payload.length) { setError("أجب عن سؤال واحد على الأقل قبل التسليم."); return; }
    setBusy(true);
    try {
      const result = await submitQuizAttempt(active.id, payload);
      setNotice(`تم التسليم والتصحيح على الخادم: ${result.score}/${result.max_score} — ${result.passed ? "ناجح" : "لم يجتز"}.`);
      setActiveQuizId(null);
      setAnswers({});
      setAttempts(await loadAttempts());
      setTab("results");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setBusy(false);
    }
  }

  return <LabPage
    eyebrow="الواجبات والتقييم"
    title="الاختبارات القصيرة والتقييمات"
    intro="بنك أسئلة متعدد الأنواع، تسليم محمي للطلاب، وتصحيح نهائي على الخادم — لا يصل مفتاح الإجابة إلى المتصفح."
    badge={`${stats.published} اختبار منشور`}
  >
    <LabStats items={[
      { label: "اختبارات منشورة", value: String(stats.published), detail: "متاحة للطلاب" },
      { label: "مسودات", value: String(stats.drafts), detail: "قيد الإعداد" },
      { label: "محاولات مسجلة", value: String(stats.attempts), detail: "سجل الخادم" },
      { label: "المتوسط العام", value: `${stats.avg}%`, detail: "لكل المحاولات" },
    ]} />

    <LabTabs
      label="أقسام الاختبارات"
      value={tab}
      onChange={setTab}
      tabs={[
        { id: "manage", label: "إدارة الاختبارات", icon: "ri-file-list-3-line" },
        { id: "take", label: "تسليم الطالب", icon: "ri-play-circle-line" },
        { id: "results", label: "النتائج والمحاولات", icon: "ri-bar-chart-box-line" },
      ]}
    />

    {error && <p className="error-box" role="alert">{error}</p>}
    {notice && <p className="notice" role="status">{notice}</p>}
    {loading && <p className="muted">جارٍ تحميل الاختبارات من الخادم...</p>}

    {tab === "manage" && !loading && <div className="approval-layout">
      <section className="panel approval-list-panel">
        {!quizzes.length
          ? <p className="muted">لا توجد اختبارات بعد. تُنشأ من شاشة الدروس والتقييمات.</p>
          : <ul className="approval-list">
            {quizzes.map((quiz) => <li key={quiz.id}>
              <button type="button" className={`approval-item${selectedQuizId === quiz.id ? " active" : ""}`} onClick={() => setSelectedQuizId(quiz.id)}>
                <span className="approval-item-top">
                  <span className="lab-tag">{quiz.attempt_limit} محاولة</span>
                  <span className={`lab-status ${quiz.status === "published" ? "status-ok" : "status-neutral"}`}>{quiz.status === "published" ? "منشور" : "مسودة"}</span>
                </span>
                <strong>{quiz.title}</strong>
                <small>{quiz.time_limit_minutes ?? "—"} دقيقة · الحد الأدنى {quiz.passing_score}%</small>
              </button>
            </li>)}
          </ul>}
        <div className="actions">
          <button className="button secondary" type="button" onClick={() => void load()}><i className="ri-refresh-line" aria-hidden="true"></i> تحديث</button>
        </div>
      </section>

      <section className="panel approval-detail-panel">
        {!selected
          ? <p className="muted">اختر اختباراً لعرض أسئلته.</p>
          : <>
            <div className="page-heading">
              <div><h2>{selected.title}</h2><p className="muted">حد المحاولات {selected.attempt_limit} · الحد الأدنى {selected.passing_score}%</p></div>
              <button className="button secondary" type="button" onClick={() => void togglePublish(selected)}>
                <i className={selected.status === "published" ? "ri-eye-off-line" : "ri-global-line"} aria-hidden="true"></i>
                {selected.status === "published" ? "إلغاء النشر" : "نشر الاختبار"}
              </button>
            </div>
            {!questions.length
              ? <p className="muted">لا توجد أسئلة منشورة متاحة لهذا الاختبار.</p>
              : <ol className="quiz-question-list">
                {questions.map((question, index) => <li key={question.id}>
                  <div className="quiz-question-head">
                    <span className="quiz-index">{index + 1}</span>
                    <div>
                      <span className="lab-tag">{QUESTION_TYPE_LABELS[question.kind] ?? question.kind}</span>
                      <p className="quiz-prompt" dir="auto">{question.prompt}</p>
                    </div>
                    <span className="lab-tag">{question.points} نقطة</span>
                  </div>
                  <ul className="quiz-options">
                    {normalizeChoices(question.choices).map((option, optionIndex) => <li key={optionIndex}>{option}</li>)}
                  </ul>
                </li>)}
              </ol>}
            <p className="data-note">لا يُعاد مفتاح الإجابة من الخادم؛ التصحيح يتم عبر الدالة المحمية.</p>
          </>}
      </section>
    </div>}

    {tab === "take" && (!active
      ? <section className="panel">
        <h2>بدء محاولة اختبار</h2>
        <p className="data-note">تُتحقّق الأهلية وحدّ المحاولات على الخادم عند التسليم.</p>
        <div className="quiz-start-grid">
          {quizzes.filter((quiz) => quiz.status === "published").map((quiz) => <div key={quiz.id} className="quiz-start-card">
            <strong>{quiz.title}</strong>
            <small>{quiz.time_limit_minutes ?? "—"} دقيقة · الحد الأدنى {quiz.passing_score}%</small>
            <button className="button primary" type="button" onClick={() => void startQuiz(quiz)}><i className="ri-play-line" aria-hidden="true"></i> بدء</button>
          </div>)}
        </div>
        {!quizzes.some((quiz) => quiz.status === "published") && <p className="muted">لا توجد اختبارات منشورة متاحة لك.</p>}
      </section>
      : <section className="panel">
        <div className="page-heading">
          <div><h2>{active.title}</h2><p className="muted">{Object.keys(answers).length} من {questions.length} سؤال</p></div>
          <button className="text-button" type="button" onClick={() => { setActiveQuizId(null); setAnswers({}); }}>إلغاء المحاولة</button>
        </div>
        <ol className="quiz-delivery-list">
          {questions.map((question, index) => <li key={question.id}>
            <p className="quiz-prompt" dir="auto"><span className="quiz-index">{index + 1}</span> {question.prompt}</p>
            <div className="quiz-choice-grid">
              {normalizeChoices(question.choices).map((option, optionIndex) => <button
                key={optionIndex}
                type="button"
                className={`quiz-choice${answers[question.id] === optionIndex ? " selected" : ""}`}
                onClick={() => setAnswers((current) => ({ ...current, [question.id]: optionIndex }))}
              >{option}</button>)}
            </div>
          </li>)}
        </ol>
        <div className="actions">
          <button className="button primary" type="button" onClick={() => void submit()} disabled={busy}>
            <i className="ri-send-plane-line" aria-hidden="true"></i> {busy ? "جارٍ التصحيح على الخادم..." : "تسليم الاختبار"}
          </button>
        </div>
      </section>)}

    {tab === "results" && <section className="panel">
      <h2>سجل المحاولات</h2>
      {!attempts.length
        ? <p className="muted">لا توجد محاولات مسجلة بعد.</p>
        : <div className="table-scroll">
          <table className="data-table">
            <thead><tr><th>الطالب</th><th>المحاولة</th><th>الدرجة</th><th>النسبة</th><th>الحالة</th><th>التاريخ</th></tr></thead>
            <tbody>
              {attempts.map((attempt) => <tr key={attempt.id}>
                <td>{attempt.student_name ?? "—"}</td>
                <td>{attempt.attempt_number}</td>
                <td>{attempt.score ?? "—"}/{attempt.max_score}</td>
                <td>{attemptPercent(attempt.score, attempt.max_score)}%</td>
                <td><span className={`lab-status ${attempt.status === "graded" ? "status-ok" : "status-warn"}`}>{attempt.status === "graded" ? "مُصحّح" : attempt.status}</span></td>
                <td>{formatDate(attempt.submitted_at)}</td>
              </tr>)}
            </tbody>
          </table>
        </div>}
      <div className="actions">
        <button className="button secondary" type="button" onClick={() => void load()}><i className="ri-refresh-line" aria-hidden="true"></i> تحديث من الخادم</button>
      </div>
    </section>}
  </LabPage>;
}