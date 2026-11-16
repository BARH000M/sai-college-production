import { useEffect, useMemo, useState } from "react";
import {
  exercisePassMark, loadExerciseAttempts, loadExerciseQuestionsAdmin,
  type ExerciseAttempt, type ExerciseQuestionAdmin,
} from "@/portal/lib/exercises";
import type { LearningScope } from "@/portal/lib/learning";
import { formatDate } from "@/portal/lib/learning";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

/**
 * Staff view of scored results for one lesson: per-student correct counts and
 * latest submission time, read under the existing class-scope RLS.
 */
export function LessonResultsPanel({
  scope, lessonId, classId,
}: {
  scope: LearningScope;
  lessonId: string;
  classId: string;
}) {
  const [questions, setQuestions] = useState<ExerciseQuestionAdmin[] | null>(null);
  const [attempts, setAttempts] = useState<ExerciseAttempt[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setQuestions(null);
    setAttempts([]);
    setError(null);
    void loadExerciseQuestionsAdmin(lessonId)
      .then(async (rows) => {
        const entries = await loadExerciseAttempts(rows.map((row) => row.id));
        if (active) { setQuestions(rows); setAttempts(entries); }
      })
      .catch((failure: unknown) => { if (active) setError(message(failure)); });
    return () => { active = false; };
  }, [lessonId, retry]);

  const roster = useMemo(
    () => scope.workspace.students.filter((student) => student.class_id === classId),
    [scope.workspace.students, classId],
  );
  const published = (questions ?? []).filter((question) => question.is_published);

  const rows = useMemo(() => roster.map((student) => {
    const mine = attempts.filter((attempt) => attempt.student_id === student.id);
    const byQuestion = new Map(published.map((question) => [question.id, mine.find((attempt) => attempt.question_id === question.id)]));
    const answered = [...byQuestion.values()].filter(Boolean) as ExerciseAttempt[];
    const correct = answered.filter((attempt) => attempt.is_correct).length;
    const latest = answered.map((attempt) => attempt.answered_at).sort().at(-1) ?? null;
    const score = published.length && answered.length ? Math.round((correct / published.length) * 100) : null;
    return { student, correct, answeredCount: answered.length, latest, score };
  }), [roster, attempts, published]);

  if (error) {
    return <section className="panel management-detail">
      <h2>نتائج التقييم</h2>
      <p className="error-box" role="alert">{error} <button type="button" className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>
    </section>;
  }
  if (questions === null) {
    return <section className="panel management-detail"><p role="status">جارٍ تحميل نتائج التقييم...</p></section>;
  }
  if (!published.length) {
    return <section className="panel management-detail">
      <h2>نتائج التقييم</h2>
      <p className="muted">لا توجد أسئلة منشورة لهذا الدرس، لذا لا توجد نتائج بعد.</p>
    </section>;
  }

  return <section className="panel management-detail">
    <h2>نتائج التقييم <small className="learn-meta">{published.length} أسئلة · النجاح من {exercisePassMark}٪</small></h2>
    {!rows.length ? <p className="muted">لا يوجد طلاب في هذا الصف.</p> : <div className="table-scroll">
      <table className="management-table">
        <thead><tr><th>الطالب</th><th>الصحيح</th><th>النتيجة</th><th>آخر إجابة</th></tr></thead>
        <tbody>{rows.map(({ student, correct, answeredCount, latest, score }) => <tr key={student.id}>
          <td>{student.full_name}<span className="learn-meta">{student.admission_no}</span></td>
          <td>{answeredCount ? `${correct} / ${published.length}` : "لم يُجب"}</td>
          <td>{score === null ? "—" : <span className={`learn-pill ${score >= exercisePassMark ? "learn-status-completed" : "learn-status-not_started"}`}>{score}٪</span>}</td>
          <td>{latest ? formatDate(latest, true) : "—"}</td>
        </tr>)}</tbody>
      </table>
    </div>}
  </section>;
}
