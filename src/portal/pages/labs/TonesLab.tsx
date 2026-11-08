import { useEffect, useState } from "react";
import { tonePractice, toneReferences } from "@/mocks/learningLabs";
import { AnswerMark, LabPage } from "@/portal/pages/labs/LabShell";

export function TonesLab() {
  const [playingTone, setPlayingTone] = useState<number | null>(null);
  const [answers, setAnswers] = useState<Record<string, string>>({});

  useEffect(() => {
    if (playingTone === null) return;
    const timer = window.setTimeout(() => setPlayingTone(null), 1300);
    return () => window.clearTimeout(timer);
  }, [playingTone]);

  const answered = tonePractice.filter((row) => answers[row.id] !== undefined);
  const correct = answered.filter((row) => answers[row.id] === row.pinyin).length;

  return <LabPage
    eyebrow="مهارات اللغة الصينية"
    title="النغمات الصينية"
    intro="النغمة تغيّر معنى الكلمة بالكامل. تعلّم الأشكال الأربعة، استمع إلى كل نغمة، ثم اختبر تمييزك."
    badge={`${tonePractice.length} تدريبات`}
  >
    <section className="panel">
      <div className="page-heading">
        <div><h2>النغمات الأربع</h2><p className="data-note">المقطع نفسه «ma» يعطي أربع كلمات مختلفة تماماً حسب النغمة.</p></div>
        <span className="learn-pill">HSK 1</span>
      </div>
      <div className="tone-grid">
        {toneReferences.map((row) => <article key={row.id} className={`tone-card tone-${row.tone}`}>
          <div className="tone-card-head">
            <span className="tone-index">{row.tone}</span>
            <div>
              <strong>{row.name}</strong>
              <small>علامة النغمة: <span dir="ltr">{row.mark}</span></small>
            </div>
          </div>
          <div className="tone-contour" aria-hidden="true">
            {row.contour.map((height, index) => <i key={index} style={{ height: `${height}%` }}></i>)}
          </div>
          <p className="tone-word"><span className="lab-hanzi">{row.hanzi}</span> <span className="lab-pinyin" dir="ltr">{row.pinyin}</span></p>
          <p className="lab-item-text">{row.arabic}</p>
          <p className="lab-hint"><i className="ri-information-line" aria-hidden="true"></i> {row.hint}</p>
          <button
            type="button"
            className={`button ${playingTone === row.tone ? "primary" : "secondary"}`}
            onClick={() => setPlayingTone(row.tone)}
          >
            <i className={playingTone === row.tone ? "ri-volume-up-line" : "ri-play-line"} aria-hidden="true"></i>
            {playingTone === row.tone ? "يُشغّل النموذج…" : "استمع"}
          </button>
        </article>)}
      </div>
    </section>

    <section className="panel">
      <div className="page-heading">
        <div><h2>تدريب تمييز النغمات</h2><p className="data-note">اختر البينيين الصحيح لكل كلمة. سيظهر التصحيح فور الاختيار.</p></div>
        <span className="lab-status status-ok">{correct} / {tonePractice.length} صحيحة</span>
      </div>
      <ol className="lab-question-list">
        {tonePractice.map((row) => {
          const chosen = answers[row.id];
          const isAnswered = chosen !== undefined;
          const isCorrect = chosen === row.pinyin;
          return <li key={row.id} className="lab-question tone-question">
            <div className="tone-question-head">
              <span className="lab-hanzi tone-hanzi">{row.word}</span>
              <div>
                <p className="lab-question-title">{row.meaning}</p>
                <p className="lab-meta">النغمة المطلوبة: {row.tone} · الكلمة تحتوي {row.word.length} مقطعاً</p>
              </div>
            </div>
            <div className="lab-options tone-options">
              {row.options.map((option) => {
                const state = !isAnswered ? null : option === row.pinyin ? "correct" : option === chosen ? "wrong" : null;
                return <button
                  key={option}
                  type="button"
                  className={`lab-option${state ? ` ${state}` : ""}`}
                  dir="ltr"
                  disabled={isAnswered}
                  onClick={() => setAnswers((current) => ({ ...current, [row.id]: option }))}
                >
                  <span>{option}</span>
                  <AnswerMark state={state} />
                </button>;
              })}
            </div>
            {isAnswered && <p className={`lab-hint${isCorrect ? " ok" : ""}`}>
              <i className={isCorrect ? "ri-checkbox-circle-line" : "ri-close-circle-line"} aria-hidden="true"></i>
              {isCorrect ? "إجابة صحيحة." : `الإجابة الصحيحة: ${row.pinyin}.`} النغمة {row.tone} في «{row.word}».
            </p>}
          </li>;
        })}
      </ol>
      <div className="actions">
        <button className="button secondary" type="button" onClick={() => setAnswers({})} disabled={!answered.length}>
          <i className="ri-refresh-line" aria-hidden="true"></i> إعادة التدريب
        </button>
        <span className="lab-meta">أجبت عن {answered.length} من {tonePractice.length} بطاقات.</span>
      </div>
    </section>

    <section className="panel">
      <h2>قاعدة سريعة</h2>
      <ul className="lab-compact-list">
        <li><strong>الثالثة + الثالثة:</strong> <span>تتحول الأولى إلى نغمة ثانية، مثل «你好» تُلفظ <span dir="ltr">ní hǎo</span>.</span></li>
        <li><strong>«不» قبل الرابعة:</strong> <span>تتحول إلى نغمة ثانية، مثل «不是» تُلفظ <span dir="ltr">bú shì</span>.</span></li>
        <li><strong>«一» قبل الرابعة:</strong> <span>تصبح نغمة ثانية، وقبل الأولى والثانية والثالثة تبقى رابعة.</span></li>
      </ul>
    </section>
  </LabPage>;
}