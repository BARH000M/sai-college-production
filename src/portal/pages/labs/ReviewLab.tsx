import { useState } from "react";
import { reviewCards } from "@/mocks/learningLabs";
import { LabPage } from "@/portal/pages/labs/LabShell";

type Rating = "again" | "hard" | "good" | "easy";

const ratings: { id: Rating; label: string; hint: string; icon: string }[] = [
  { id: "again", label: "مرة أخرى", hint: "دقيقة واحدة", icon: "ri-restart-line" },
  { id: "hard", label: "صعب", hint: "يومان", icon: "ri-emotion-unhappy-line" },
  { id: "good", label: "جيد", hint: "4 أيام", icon: "ri-emotion-normal-line" },
  { id: "easy", label: "سهل", hint: "10 أيام", icon: "ri-emotion-happy-line" },
];

export function ReviewLab() {
  const [order, setOrder] = useState<string[]>(() => reviewCards.map((card) => card.id));
  const [index, setIndex] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [results, setResults] = useState<{ id: string; rating: Rating }[]>([]);

  const card = reviewCards.find((row) => row.id === order[index]) ?? null;
  const total = order.length;
  const progress = total ? Math.round((index / total) * 100) : 0;
  const finished = index >= total;
  const counts = {
    again: results.filter((row) => row.rating === "again").length,
    hard: results.filter((row) => row.rating === "hard").length,
    good: results.filter((row) => row.rating === "good").length,
    easy: results.filter((row) => row.rating === "easy").length,
  };

  function rate(rating: Rating) {
    if (!card) return;
    setResults((current) => [...current, { id: card.id, rating }]);
    setRevealed(false);
    setIndex((value) => value + 1);
    if (rating === "again") {
      // The card returns to the end of the queue, as in a real spaced-repetition session.
      setOrder((current) => [...current, card.id]);
    }
  }

  function restart() {
    setOrder(reviewCards.map((row) => row.id));
    setIndex(0);
    setRevealed(false);
    setResults([]);
  }

  const dueCards = reviewCards.filter((row) => row.bucket !== "جديد").length;

  return <LabPage
    eyebrow="مهارات المراجعة"
    title="المراجعة المتباعدة"
    intro="جلسة مراجعة ذكية تعيد البطاقات الصعبة بسرعة وتؤجل البطاقات السهلة، حتى يثبت المفردات في الذاكرة طويلة المدى."
    badge={`${dueCards} بطاقات مستحقة`}
  >
    <section className="panel">
      <div className="page-heading">
        <div><h2>بطاقات المفردات</h2><p className="data-note">اقلب البطاقة أولاً، ثم قيّم مستوى تذكّرك لجدولة المراجعة القادمة.</p></div>
        <span className="learn-pill">{Math.min(index, total)} / {total}</span>
      </div>
      <div className="lab-progress">
        <span className="learn-bar" aria-hidden="true"><span style={{ width: `${progress}%` }}></span></span>
        <small>{progress}% من الجلسة</small>
      </div>

      {card && <div className="review-stage">
        <div className={`review-card${revealed ? " revealed" : ""}`}>
          <div className="review-card-top">
            <span className="lab-tag">{card.tag}</span>
            <span className={`lab-status ${card.bucket === "متأخر" ? "status-danger" : card.bucket === "جديد" ? "status-neutral" : "status-warn"}`}>
              {card.dueIn}
            </span>
          </div>
          <p className="review-hanzi">{card.hanzi}</p>
          {revealed
            ? <>
                <p className="lab-pinyin lab-pinyin-large" dir="ltr">{card.pinyin}</p>
                <p className="review-answer">{card.arabic}</p>
                <p className="review-example"><span className="lab-hanzi">{card.example}</span><br /><span className="lab-item-text">{card.exampleAr}</span></p>
              </>
            : <p className="review-placeholder">اضغط «قلب البطاقة» لعرض النطق والمعنى والمثال.</p>}
        </div>
      </div>}

      {card && !revealed && <button className="button primary lab-wide-button" type="button" onClick={() => setRevealed(true)}>
        <i className="ri-eye-line" aria-hidden="true"></i> قلب البطاقة
      </button>}

      {card && revealed && <div className="review-rating">
        <p className="data-note">كيف كان تذكّرك للكلمة؟ يُحدَّد موعد المراجعة تلقائياً حسب تقييمك.</p>
        <div className="review-rating-grid">
          {ratings.map((row) => <button
            key={row.id}
            type="button"
            className={`review-rate-button rate-${row.id}`}
            onClick={() => rate(row.id)}
          >
            <i className={row.icon} aria-hidden="true"></i>
            <strong>{row.label}</strong>
            <small>{row.hint}</small>
          </button>)}
        </div>
      </div>}

      {finished && <div className="review-finished">
        <span className="review-finished-icon"><i className="ri-article-line" aria-hidden="true"></i></span>
        <h2>أنهيت جلسة المراجعة</h2>
        <p className="lab-item-text">
          راجعت {counts.again + counts.hard + counts.good + counts.easy} تقييماً على {total} بطاقة.
          البطاقات التي قيّمتها بـ«مرة أخرى» أُعيدت إلى نهاية الطابور وتحتاج مراجعة قريبة.
        </p>
        <div className="review-result-grid">
          <div><span>مرة أخرى</span><strong>{counts.again}</strong></div>
          <div><span>صعب</span><strong>{counts.hard}</strong></div>
          <div><span>جيد</span><strong>{counts.good}</strong></div>
          <div><span>سهل</span><strong>{counts.easy}</strong></div>
        </div>
        <button className="button primary" type="button" onClick={restart}>
          <i className="ri-refresh-line" aria-hidden="true"></i> بدء جلسة جديدة
        </button>
      </div>}
    </section>

    <div className="lab-split">
      <section className="panel">
        <h2>كيف تُجدول المراجعة؟</h2>
        <ul className="lab-compact-list">
          <li><strong>مرة أخرى</strong><span>تعيد البطاقة إلى الطابور مباشرة لأن المفردة لم تُثبت بعد.</span></li>
          <li><strong>صعب</strong><span>تعود بعد يومين مع مثال أوضح.</span></li>
          <li><strong>جيد</strong><span>تعود بعد أربعة أيام، وهو الخيار المعتاد.</span></li>
          <li><strong>سهل</strong><span>تؤجل عشرة أيام لتوفير وقت الجلسة للبطاقات الأصعب.</span></li>
        </ul>
        <p className="data-note">هذه الجلسة تعمل على بطاقات نموذجية داخل المتصفح. عند ربط بوابة التعلّم ستُخزَّن نتائج المراجعة لكل طالب في حسابه.</p>
      </section>

      <section className="panel">
        <h2>ملخص الجلسة الحالية</h2>
        <div className="lab-stats lab-stats-tight">
          <div className="lab-stat lab-stat-0"><span>بطاقات الطابور</span><strong>{Math.max(0, order.length - index)}</strong></div>
          <div className="lab-stat lab-stat-1"><span>تمت مراجعتها</span><strong>{results.length}</strong></div>
          <div className="lab-stat lab-stat-2"><span>أُعيدت للطابور</span><strong>{counts.again}</strong></div>
          <div className="lab-stat lab-stat-3"><span>إجمالي البطاقات</span><strong>{reviewCards.length}</strong></div>
        </div>
        <h3 className="lab-subheading">توزيع البطاقات</h3>
        <ul className="lab-compact-list">
          {reviewCards.slice(0, 5).map((row) => <li key={row.id}>
            <span className="lab-hanzi">{row.hanzi}</span>
            <span className="lab-meta" dir="ltr">{row.pinyin}</span>
            <span className="lab-meta">{row.dueIn}</span>
          </li>)}
        </ul>
      </section>
    </div>
  </LabPage>;
}