import { useEffect, useMemo, useState } from "react";
import {
  loadVocabularyWorkspace, saveWordProgress,
  type VocabularyProgress, type VocabularyWorkspace,
} from "@/portal/lib/vocabulary";
import {
  buildReviewQueue, progressFor, reviewRatings, ratingPlan, nextDueAt,
  weeklyReviewSummary, type ReviewQueueItem, type ReviewRating,
} from "@/portal/lib/vocabularyReview";
import { LabPage, LabStats } from "@/portal/pages/labs/LabShell";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

const formatDue = (date: Date | null): string => {
  if (!date) return "لم تُراجع بعد";
  const diff = date.getTime() - Date.now();
  if (diff <= 0) return "مستحقة الآن";
  const days = Math.ceil(diff / 86_400_000);
  if (days <= 1) return "غداً";
  return `بعد ${days} يوماً`;
};

/**
 * The learner's own spaced-repetition queue. Every word comes from the course
 * word bank and every rating is stored in learning_vocab_progress, so the queue
 * follows the account across devices instead of living in the browser.
 */
export function ReviewLab() {
  const [data, setData] = useState<VocabularyWorkspace | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);
  const [session, setSession] = useState<ReviewQueueItem[]>([]);
  const [cursor, setCursor] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [saving, setSaving] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [results, setResults] = useState<ReviewRating[]>([]);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    loadVocabularyWorkspace()
      .then((workspace) => { if (active) setData(workspace); })
      .catch((failure: unknown) => { if (active) { setData(null); setError(message(failure)); } })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [retry]);

  const words = useMemo(() => data?.words ?? [], [data]);
  const progress = useMemo(() => data?.progress ?? [], [data]);
  const learnerId = data?.learnerId ?? null;
  const lessons = useMemo(() => data?.lessons ?? [], [data]);

  const summary = useMemo(
    () => weeklyReviewSummary(words, progress, learnerId),
    [words, progress, learnerId],
  );

  const dueItems = useMemo(
    () => buildReviewQueue(words, progress, learnerId, 200),
    [words, progress, learnerId],
  );

  function startSession(list: ReviewQueueItem[]) {
    setSession(list);
    setCursor(0);
    setRevealed(false);
    setResults([]);
    setNotice(null);
    setActionError(null);
  }

  // The first queue is prepared once the workspace arrives; later sessions are
  // started explicitly so a save never reshuffles the card under the learner.
  useEffect(() => {
    if (loading || error || !data) return;
    startSession(buildReviewQueue(words, progress, learnerId, 15));
    // Only the finished load rebuilds the queue; a rating updates the data but
    // must not reshuffle the card the learner is looking at.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loading, error, retry]);

  const card = session[cursor] ?? null;
  const finished = session.length > 0 && cursor >= session.length;
  const percent = session.length ? Math.round((Math.min(cursor, session.length) / session.length) * 100) : 0;

  function applyProgress(wordId: string, status: "learning" | "known", reviewCount: number) {
    if (!learnerId) return;
    const now = new Date().toISOString();
    setData((current) => {
      if (!current) return current;
      const rest = current.progress.filter((row) => !(row.vocabulary_id === wordId && row.student_id === learnerId));
      const next: VocabularyProgress = {
        vocabulary_id: wordId,
        student_id: learnerId,
        status,
        review_count: reviewCount,
        last_reviewed_at: now,
      };
      return { ...current, progress: [...rest, next] };
    });
  }

  async function rate(rating: ReviewRating) {
    if (!card || saving) return;
    const plan = ratingPlan(rating, progressFor(progress, card.word.id, learnerId));
    setActionError(null);

    if (!learnerId) {
      setNotice("هذا الحساب غير مرتبط بسجل طالب، لذلك تُعرض القائمة دون حفظ التقدم. بعد ربط الحساب يُحفظ كل تقييم تلقائياً.");
    } else {
      setSaving(true);
      try {
        await saveWordProgress(card.word.id, learnerId, plan.status, plan.reviewCount);
        applyProgress(card.word.id, plan.status, plan.reviewCount);
      } catch (failure) {
        setActionError(message(failure));
        setSaving(false);
        return;
      }
      setSaving(false);
    }

    setResults((current) => [...current, rating]);
    setRevealed(false);
    setCursor((value) => value + 1);
    if (rating === "again") {
      // The word returns to the end of this session, exactly like a paper deck.
      setSession((current) => [...current, card]);
    }
  }

  const counts = {
    again: results.filter((row) => row === "again").length,
    hard: results.filter((row) => row === "hard").length,
    good: results.filter((row) => row === "good").length,
    easy: results.filter((row) => row === "easy").length,
  };

  const upcoming = useMemo(
    () => words
      .map((word) => ({ word, row: progressFor(progress, word.id, learnerId) }))
      .filter((item) => item.row && item.row.status !== "known")
      .sort((a, b) => (nextDueAt(a.row)?.getTime() ?? 0) - (nextDueAt(b.row)?.getTime() ?? 0))
      .slice(0, 5),
    [words, progress, learnerId],
  );

  return <LabPage
    eyebrow="مهارات المراجعة"
    title="قائمة المراجعة الشخصية"
    intro="طابور مراجعة مبني على مفردات مقرراتك: تعود الكلمة الصعبة سريعاً، وتُؤجَّل الكلمة التي أتقنتها، ويُحفظ كل تقييم في حسابك."
    badge={learnerId ? `${summary.mastered} من ${summary.total} متقنة` : "الحساب غير مرتبط بطالب"}
  >
    {loading && <p className="muted" role="status">جارٍ تحميل قائمة المراجعة...</p>}
    {error && <p className="error-box" role="alert">
      تعذر تحميل قائمة المراجعة: {error}
      <button className="text-button" type="button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button>
    </p>}

    {!loading && !error && <>
      <LabStats items={[
        { label: "مستحقة الآن", value: String(dueItems.length), detail: "داخل طابورك" },
        { label: "راجعت هذا الأسبوع", value: String(summary.reviewedThisWeek), detail: `${summary.activeDays} من ٧ أيام نشطة` },
        { label: "أيام متتالية", value: String(summary.streak), detail: summary.streak ? "استمر على نفس الوتيرة" : "ابدأ سلسلة اليوم" },
        { label: "نسبة الإتقان", value: `${summary.percent}%`, detail: `${summary.mastered} من ${summary.total} مفردة` },
      ]} />

      {!learnerId && <p className="notice" role="status">
        هذا الحساب ليس مرتبطاً بسجل طالب بعد، لذلك تُعرض المفردات للمراجعة دون حفظ النتائج.
        يُحفظ التقدم تلقائياً بعد ربط الحساب بسجل الطالب من صفحة الأدوار.
      </p>}

      <div className="lab-split">
        <section className="panel">
          <div className="page-heading">
            <div>
              <h2>بطاقة المراجعة</h2>
              <p className="data-note">اقلب البطاقة ثم قيّم تذكّرك؛ يُحدَّد موعد العودة من تقييمك.</p>
            </div>
            <span className="learn-pill">{Math.min(cursor, session.length)} / {session.length}</span>
          </div>

          <div className="lab-progress">
            <span className="learn-bar" aria-hidden="true"><span style={{ width: `${percent}%` }} /></span>
            <small>{percent}% من الجلسة</small>
          </div>

          {notice && <p className="notice" role="status">{notice}</p>}
          {actionError && <p className="error-box" role="alert">تعذر حفظ التقييم: {actionError}</p>}

          {!session.length && <div className="review-finished">
            <span className="review-finished-icon"><i className="ri-checkbox-circle-line" aria-hidden="true"></i></span>
            <h2>لا توجد بطاقات مستحقة</h2>
            <p className="muted">كل مفردات مقرراتك مُجدولة لمواعيد لاحقة. يمكنك بدء جلسة تدريب إضافية طوعاً.</p>
            <button className="button primary" type="button" onClick={() => startSession(buildReviewQueue(words, progress, learnerId, 10).slice(0, 10))}>
              <i className="ri-play-line" aria-hidden="true"></i> جلسة تدريب إضافية
            </button>
          </div>}

          {card && <div className="review-stage">
            <div className={`review-card${revealed ? " revealed" : ""}`}>
              <div className="review-card-top">
                <span className="lab-tag">
                  {card.isNew ? "مفردة جديدة" : card.progress?.status === "learning" ? "قيد التثبيت" : "مراجعة"}
                </span>
                <span className={`lab-status ${card.isDue ? "status-warn" : "status-neutral"}`}>
                  {formatDue(card.dueAt)}
                </span>
              </div>
              <p className="review-hanzi">{card.word.hanzi}</p>
              {revealed
                ? <>
                  <p className="lab-pinyin lab-pinyin-large" dir="ltr">{card.word.pinyin}</p>
                  <p className="review-answer">{card.word.meaning_ar}</p>
                  {card.word.meaning_en && <p className="data-note" dir="ltr">{card.word.meaning_en}</p>}
                  {card.word.example_zh
                    ? <p className="review-example">
                      <span className="lab-hanzi">{card.word.example_zh}</span>
                      <br /><span className="lab-item-text">{card.word.example_ar}</span>
                    </p>
                    : <p className="review-placeholder">لا يوجد مثال مسجل لهذه المفردة.</p>}
                  {card.word.lesson_id && <p className="data-note">
                    الدرس: {lessons.find((lesson) => lesson.id === card.word.lesson_id)?.title ?? "—"}
                    {card.word.hsk_level ? ` · HSK ${card.word.hsk_level}` : ""}
                  </p>}
                </>
                : <p className="review-placeholder">اضغط «قلب البطاقة» لعرض النطق والمعنى.</p>}
            </div>
          </div>}

          {card && !revealed && <button className="button primary lab-wide-button" type="button" onClick={() => setRevealed(true)}>
            <i className="ri-eye-line" aria-hidden="true"></i> قلب البطاقة
          </button>}

          {card && revealed && <div className="review-rating">
            <p className="data-note">كيف كان تذكّرك؟ يُحسب موعد المراجعة القادم من تقييمك ومن عدد مرات مراجعتك السابقة.</p>
            <div className="review-rating-grid">
              {reviewRatings.map((row) => <button
                key={row.id}
                type="button"
                className={`review-rate-button rate-${row.id}`}
                disabled={saving}
                onClick={() => void rate(row.id)}
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
              راجعت {results.length} تقييماً على {session.length} بطاقة.
              البطاقات التي قيّمتها بـ«مرة أخرى» أُعيدت إلى نهاية الطابور.
            </p>
            <div className="review-result-grid">
              <div><span>مرة أخرى</span><strong>{counts.again}</strong></div>
              <div><span>صعب</span><strong>{counts.hard}</strong></div>
              <div><span>جيد</span><strong>{counts.good}</strong></div>
              <div><span>سهل</span><strong>{counts.easy}</strong></div>
            </div>
            <button
              className="button primary"
              type="button"
              onClick={() => startSession(buildReviewQueue(words, progress, learnerId, 15))}
            >
              <i className="ri-refresh-line" aria-hidden="true"></i> جلسة جديدة
            </button>
          </div>}
        </section>

        <div className="learner-side">
          <section className="panel">
            <h2>نشاطك هذا الأسبوع</h2>
            <div className="review-week" role="img" aria-label="عدد المفردات التي راجعتها كل يوم">
              {summary.days.map((day) => {
                const max = Math.max(1, ...summary.days.map((entry) => entry.count));
                const height = Math.round((day.count / max) * 100);
                return <div className="review-week-day" key={day.key}>
                  <span className="review-week-bar" aria-hidden="true">
                    <span style={{ height: `${Math.max(4, height)}%` }} className={day.count ? "filled" : ""} />
                  </span>
                  <strong>{day.count}</strong>
                  <small>{day.label}</small>
                </div>;
              })}
            </div>
            <p className="data-note">
              مجموع هذا الأسبوع {summary.reviewedThisWeek} مراجعة · {summary.learning} مفردة قيد التثبيت · {summary.mastered} متقنة.
            </p>
          </section>

          <section className="panel">
            <h2>أقرب الاستحقاقات</h2>
            {!upcoming.length
              ? <p className="muted">لا توجد مفردات مؤجلة حالياً.</p>
              : <ul className="lab-compact-list">
                {upcoming.map((item) => <li key={item.word.id}>
                  <span className="lab-hanzi">{item.word.hanzi}</span>
                  <span className="lab-meta" dir="ltr">{item.word.pinyin}</span>
                  <span className="lab-meta">{formatDue(nextDueAt(item.row))}</span>
                </li>)}
              </ul>}
          </section>
        </div>
      </div>

      <section className="panel">
        <h2>كيف تُجدول المراجعة؟</h2>
        <ul className="lab-compact-list">
          <li><strong>مرة أخرى</strong><span>تعيد البطاقة إلى نهاية الجلسة وتعطيها موعداً فورياً.</span></li>
          <li><strong>صعب</strong><span>تبقى في حالة تثبيت وتعود بعد يوم.</span></li>
          <li><strong>جيد</strong><span>تُعلَّم كمتقنة وتعود بعد ثلاثة أيام.</span></li>
          <li><strong>سهل</strong><span>تُؤجل أسبوعاً كاملاً لتوفير وقت الجلسة للبطاقات الأصعب.</span></li>
        </ul>
        <p className="data-note">الفاصل الزمني يطول مع كل مراجعة ناجحة، ويُحفظ الطابور في حسابك على الخادم.</p>
      </section>
    </>}
  </LabPage>;
}