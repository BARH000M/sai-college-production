import { useState } from "react";
import { readingPassages } from "@/mocks/learningLabs";
import { AnswerMark, LabPage } from "@/portal/pages/labs/LabShell";

export function ReadingLab() {
  const [passageId, setPassageId] = useState(readingPassages[0].id);
  const [showPinyin, setShowPinyin] = useState(true);
  const [answers, setAnswers] = useState<Record<string, number>>({});
  const [finished, setFinished] = useState<string[]>([]);

  const passage = readingPassages.find((row) => row.id === passageId) ?? readingPassages[0];
  const answered = passage.questions.filter((question) => answers[question.id] !== undefined);
  const correct = passage.questions.filter((question) => answers[question.id] === question.answer).length;
  const isFinished = finished.includes(passage.id);

  return <LabPage
    eyebrow="مهارات القراءة"
    title="القراءة"
    intro="اقرأ نصوصاً قصيرة بمستويات متدرجة، استعرض المفردات الجديدة، ثم أجب عن أسئلة الفهم."
    badge={`${readingPassages.length} نصوص`}
  >
    <div className="lab-split">
      <section className="panel">
        <h2>نصوص القراءة</h2>
        <p className="data-note">اختر نصاً لبدء القراءة. يمكنك إخفاء البينيين عند الاستعداد للاختبار.</p>
        <ul className="lab-list">
          {readingPassages.map((row) => <li key={row.id}>
            <button
              type="button"
              className={`lab-item lab-item-button${row.id === passage.id ? " active" : ""}`}
              onClick={() => { setPassageId(row.id); setAnswers({}); }}
            >
              <div className="lab-item-head">
                <strong>{row.title}</strong>
                <span className="learn-pill">{row.level}</span>
              </div>
              <p className="lab-item-text">{row.intro}</p>
              <div className="lab-meta-row">
                <span><i className="ri-time-line" aria-hidden="true"></i> {row.minutes} دقائق</span>
                <span><i className="ri-book-open-line" aria-hidden="true"></i> {row.paragraphs.length} فقرات</span>
                {finished.includes(row.id) && <span><i className="ri-checkbox-circle-line" aria-hidden="true"></i> قُرئ</span>}
              </div>
            </button>
          </li>)}
        </ul>
        <div className="lab-tip-box">
          <strong><i className="ri-lightbulb-line" aria-hidden="true"></i> استراتيجية القراءة</strong>
          <ul>
            <li>اقرأ العنوان أولاً وتوقّع الموضوع.</li>
            <li>لا تتوقف عند كل كلمة جديدة؛ أكمل الفقرة ثم عُد إليها.</li>
            <li>اقرأ النص مرة ثانية بدون بينيين قبل حل الأسئلة.</li>
          </ul>
        </div>
      </section>

      <section className="panel">
        <div className="page-heading">
          <div><h2>{passage.title}</h2><p className="data-note">{passage.intro}</p></div>
          <span className="learn-pill">{passage.level}</span>
        </div>

        <div className="actions lab-player-actions">
          <button className="button secondary" type="button" onClick={() => setShowPinyin((value) => !value)}>
            <i className="ri-text" aria-hidden="true"></i> {showPinyin ? "إخفاء البينيين" : "إظهار البينيين"}
          </button>
          <button
            className={`button ${isFinished ? "secondary" : "primary"}`}
            type="button"
            onClick={() => setFinished((current) => (current.includes(passage.id) ? current.filter((id) => id !== passage.id) : [...current, passage.id]))}
          >
            <i className={isFinished ? "ri-checkbox-circle-fill" : "ri-checkbox-circle-line"} aria-hidden="true"></i>
            {isFinished ? "تمت القراءة" : "تسجيل إتمام القراءة"}
          </button>
        </div>

        <div className="lab-reading">
          {passage.paragraphs.map((paragraph, index) => <div className="lab-paragraph" key={`${passage.id}-${index}`}>
            <span className="lab-paragraph-index">{index + 1}</span>
            <div>
              <p className="lab-hanzi lab-reading-text">{paragraph.hanzi}</p>
              {showPinyin && <p className="lab-pinyin" dir="ltr">{paragraph.pinyin}</p>}
              <p className="lab-item-text lab-translation">{paragraph.arabic}</p>
            </div>
          </div>)}
        </div>

        <h3 className="lab-subheading">المفردات الجديدة</h3>
        <ul className="lab-vocab-list">
          {passage.vocabulary.map((word) => <li key={word.hanzi} className="lab-vocab">
            <span className="lab-hanzi">{word.hanzi}</span>
            <span className="lab-pinyin" dir="ltr">{word.pinyin}</span>
            <span>{word.arabic}</span>
          </li>)}
        </ul>
      </section>
    </div>

    <section className="panel">
      <div className="page-heading">
        <div><h2>أسئلة الفهم</h2><p className="data-note">أجب بعد قراءة النص كاملاً. التلميح يوضح الكلمة المفتاحية.</p></div>
        <span className="lab-pill-count">{correct} / {passage.questions.length} صحيحة</span>
      </div>
      <ol className="lab-question-list">
        {passage.questions.map((question) => {
          const chosen = answers[question.id];
          const isAnswered = chosen !== undefined;
          return <li key={question.id} className="lab-question">
            <p className="lab-question-title">{question.prompt}</p>
            <div className="lab-options">
              {question.options.map((option, index) => {
                const state = !isAnswered ? null : index === question.answer ? "correct" : chosen === index ? "wrong" : null;
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
              {chosen === question.answer ? "إجابة صحيحة. " : "راجع النص مرة أخرى. "}
              {question.hint}
            </p>}
          </li>;
        })}
      </ol>
      <div className="actions">
        <button className="button secondary" type="button" onClick={() => setAnswers({})} disabled={!answered.length}>
          <i className="ri-refresh-line" aria-hidden="true"></i> إعادة الأسئلة
        </button>
        <span className="lab-meta">أجبت عن {answered.length} من {passage.questions.length} أسئلة.</span>
      </div>
    </section>
  </LabPage>;
}