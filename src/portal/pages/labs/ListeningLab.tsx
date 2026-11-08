import { useEffect, useState } from "react";
import { labSummaryStats, listeningLessons } from "@/mocks/learningLabs";
import { AnswerMark, LabPage, LabStats } from "@/portal/pages/labs/LabShell";

const WAVE = Array.from({ length: 56 }, (_, index) => 18 + Math.round(Math.abs(Math.sin(index * 1.7)) * 58));

function clock(value: number): string {
  const minutes = Math.floor(value / 60);
  const seconds = value % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}

export function ListeningLab() {
  const [lessonId, setLessonId] = useState(listeningLessons[0].id);
  const [playing, setPlaying] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [showPinyin, setShowPinyin] = useState(true);
  const [answers, setAnswers] = useState<Record<string, number>>({});
  const [showTranscript, setShowTranscript] = useState(false);

  const lesson = listeningLessons.find((row) => row.id === lessonId) ?? listeningLessons[0];
  const duration = lesson.minutes * 60;
  const progress = Math.min(100, Math.round((elapsed / duration) * 100));
  const activeBars = Math.round((progress / 100) * WAVE.length);
  const answered = lesson.questions.filter((question) => answers[question.id] !== undefined).length;
  const correct = lesson.questions.filter((question) => answers[question.id] === question.answer).length;

  useEffect(() => {
    setElapsed(0);
    setPlaying(false);
  }, [lessonId]);

  useEffect(() => {
    if (!playing) return;
    const timer = window.setTimeout(() => setElapsed((value) => Math.min(value + 1, duration)), 1000);
    return () => window.clearTimeout(timer);
  }, [playing, elapsed, duration]);

  useEffect(() => {
    if (playing && elapsed >= duration) setPlaying(false);
  }, [playing, elapsed, duration]);

  return <LabPage
    eyebrow="مهارات اللغة الصينية"
    title="الاستماع"
    intro="استمع إلى حوارات قصيرة بمستويات متدرجة، تابع النص المشفّر بالنغمات، ثم اختبر فهمك."
    badge="HSK 1 – HSK 3"
  >
    <LabStats items={labSummaryStats.map((row) => ({ label: row.label, value: row.value }))} />

    <div className="lab-split">
      <section className="panel">
        <h2>دروس الاستماع</h2>
        <p className="data-note">اختر درساً لبدء الاستماع. يُحفظ تقدم الاستماع داخل هذه الجلسة فقط.</p>
        <ul className="lab-list">
          {listeningLessons.map((row) => <li key={row.id}>
            <button
              type="button"
              className={`lab-item lab-item-button${row.id === lesson.id ? " active" : ""}`}
              onClick={() => { setLessonId(row.id); setAnswers({}); setShowTranscript(false); }}
            >
              <div className="lab-item-head">
                <strong>{row.title}</strong>
                <span className="learn-pill">{row.level}</span>
              </div>
              <p className="lab-item-text">{row.summary}</p>
              <div className="lab-meta-row">
                <span><i className="ri-time-line" aria-hidden="true"></i> {row.minutes} دقائق</span>
                <span><i className="ri-volume-up-line" aria-hidden="true"></i> {row.transcript.length} أسطر حوار</span>
              </div>
            </button>
          </li>)}
        </ul>
      </section>

      <section className="panel">
        <div className="page-heading">
          <div>
            <h2>{lesson.title}</h2>
            <p className="data-note">{lesson.subtitle} · {lesson.level}</p>
          </div>
          <span className={`lab-status ${playing ? "status-ok" : "status-neutral"}`}>{playing ? "قيد التشغيل" : "متوقف"}</span>
        </div>

        <div className="lab-player">
          <button
            type="button"
            className="lab-play-button"
            aria-label={playing ? "إيقاف الاستماع" : "تشغيل الحوار"}
            onClick={() => {
              if (elapsed >= duration) setElapsed(0);
              setPlaying((value) => !value);
            }}
          >
            <i className={playing ? "ri-pause-line" : "ri-play-line"} aria-hidden="true"></i>
          </button>
          <div className="lab-player-body">
            <div className="lab-wave" aria-hidden="true">
              {WAVE.map((height, index) => <i
                key={index}
                className={index < activeBars ? "played" : ""}
                style={{ height: `${height}%` }}
              ></i>)}
            </div>
            <div className="lab-player-row">
              <span dir="ltr">{clock(elapsed)} / {clock(duration)}</span>
              <span className="lab-meta">{progress}% مكتمل</span>
            </div>
          </div>
        </div>
        <p className="data-note">مشغّل تجريبي لدرس نموذجي. يمكن ربط الملف الصوتي الأصلي من مكتبة الوسائط ليعمل بنفس الواجهة.</p>

        <div className="actions lab-player-actions">
          <button className="button secondary" type="button" onClick={() => { setElapsed(0); setPlaying(false); }}>
            <i className="ri-restart-line" aria-hidden="true"></i> إعادة من البداية
          </button>
          <button className="button secondary" type="button" onClick={() => setShowPinyin((value) => !value)}>
            <i className="ri-text" aria-hidden="true"></i> {showPinyin ? "إخفاء البينيين" : "إظهار البينيين"}
          </button>
          <button className="button secondary" type="button" aria-expanded={showTranscript} onClick={() => setShowTranscript((value) => !value)}>
            <i className="ri-file-text-line" aria-hidden="true"></i> {showTranscript ? "إخفاء النص" : "عرض النص الكامل"}
          </button>
        </div>

        {showTranscript && <ol className="lab-transcript">
          {lesson.transcript.map((line, index) => <li key={`${line.hanzi}-${index}`}>
            <span className="lab-speaker">{line.speaker}</span>
            <div>
              <p className="lab-hanzi">{line.hanzi}</p>
              {showPinyin && <p className="lab-pinyin" dir="ltr">{line.pinyin}</p>}
              <p className="lab-item-text">{line.arabic}</p>
            </div>
          </li>)}
        </ol>}
      </section>
    </div>

    <section className="panel">
      <div className="page-heading">
        <div><h2>أسئلة الفهم</h2><p className="data-note">اختر الإجابة الصحيحة، ثم اقرأ التلميح لمعرفة موضع الإجابة في الحوار.</p></div>
        <span className="learn-pill">{correct} / {lesson.questions.length} صحيحة</span>
      </div>
      <ol className="lab-question-list">
        {lesson.questions.map((question) => {
          const chosen = answers[question.id];
          const isAnswered = chosen !== undefined;
          return <li key={question.id} className="lab-question">
            <p className="lab-question-title">{question.prompt}</p>
            <div className="lab-options">
              {question.options.map((option, index) => {
                const isCorrect = index === question.answer;
                const state = !isAnswered ? null : isCorrect ? "correct" : chosen === index ? "wrong" : null;
                return <button
                  key={option}
                  type="button"
                  className={`lab-option${state ? ` ${state}` : ""}`}
                  disabled={isAnswered}
                  onClick={() => setAnswers((current) => ({ ...current, [question.id]: index }))}
                >
                  <span>{option}</span>
                  <AnswerMark state={state} />
                </button>;
              })}
            </div>
            {isAnswered && <p className={`lab-hint${chosen === question.answer ? " ok" : ""}`}>
              <i className={chosen === question.answer ? "ri-checkbox-circle-line" : "ri-lightbulb-line"} aria-hidden="true"></i>
              {chosen === question.answer ? "إجابة صحيحة. " : "ليست الإجابة الصحيحة. "}
              {question.hint}
            </p>}
          </li>;
        })}
      </ol>
      <div className="actions">
        <button className="button secondary" type="button" onClick={() => setAnswers({})} disabled={answered === 0}>
          <i className="ri-refresh-line" aria-hidden="true"></i> إعادة الأسئلة
        </button>
        <span className="lab-meta">أجبت عن {answered} من {lesson.questions.length} أسئلة.</span>
      </div>
    </section>
  </LabPage>;
}