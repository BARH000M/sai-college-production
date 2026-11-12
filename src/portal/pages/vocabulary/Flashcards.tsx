import { useEffect, useState } from "react";
import {
  progressCount, saveWordProgress,
  type VocabularyProgress, type VocabularyProgressStatus, type VocabularyWord,
} from "@/portal/lib/vocabulary";

export function Flashcards({ words, progress, learnerId, onSaved }: {
  words: readonly VocabularyWord[];
  progress: readonly VocabularyProgress[];
  learnerId: string | null;
  onSaved: (wordId: string, status: VocabularyProgressStatus, reviewCount: number) => void;
}) {
  const [order, setOrder] = useState<number[]>([]);
  const [cursor, setCursor] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [tally, setTally] = useState({ known: 0, learning: 0 });
  const signature = words.map((word) => word.id).join("|");

  useEffect(() => {
    setOrder(words.map((_, index) => index));
    setCursor(0);
    setFlipped(false);
    setTally({ known: 0, learning: 0 });
    setError(null);
    // The id signature is the only thing that should reset the deck.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [signature]);

  if (!words.length) {
    return <section className="panel"><p className="muted">لا توجد بطاقات في هذه التصفية. غيّر المقرر أو الدرس أو أزل البحث.</p></section>;
  }

  const word = words[order[cursor] ?? cursor];
  const finished = cursor >= words.length;
  const percent = words.length ? Math.round((cursor / words.length) * 100) : 0;

  function shuffle() {
    setOrder(() => {
      const next = words.map((_, index) => index);
      for (let i = next.length - 1; i > 0; i -= 1) {
        const j = Math.floor(Math.random() * (i + 1));
        [next[i], next[j]] = [next[j], next[i]];
      }
      return next;
    });
    setCursor(0);
    setFlipped(false);
    setTally({ known: 0, learning: 0 });
    setError(null);
  }

  async function mark(status: VocabularyProgressStatus) {
    if (!word || busy) return;
    const reviewCount = progressCount(progress, word.id, learnerId) + 1;
    setError(null);
    if (learnerId) {
      setBusy(true);
      try {
        await saveWordProgress(word.id, learnerId, status, reviewCount);
        onSaved(word.id, status, reviewCount);
      } catch (failure) {
        setError(failure instanceof Error ? failure.message : String(failure));
        setBusy(false);
        return;
      }
      setBusy(false);
    } else {
      setNotice("التقدم غير محفوظ لأن هذا الحساب غير مرتبط بسجل طالب. يمكنك المراجعة الآن وسيُحفظ عند الربط.");
    }
    setTally((current) => ({
      known: current.known + (status === "known" ? 1 : 0),
      learning: current.learning + (status === "learning" ? 1 : 0),
    }));
    setCursor((current) => current + 1);
    setFlipped(false);
  }

  return <section className="panel">
    <div className="page-heading">
      <div>
        <h2>بطاقات المراجعة</h2>
        <p className="data-note">اقلب البطاقة لكشف المعنى ثم صنّفها ذاتياً. هذا ليس تقييماً للإتقان.</p>
      </div>
      <button className="button secondary" type="button" onClick={shuffle}><i className="ri-shuffle-line" aria-hidden="true"></i> خلط البطاقات</button>
    </div>

    <div className="lab-progress">
      <span className="learn-bar"><span style={{ width: `${percent}%` }} /></span>
      <small>{Math.min(cursor, words.length)} / {words.length} بطاقة</small>
    </div>

    {notice && <p className="notice" role="status">{notice}</p>}
    {error && <p className="error-box" role="alert">{error}</p>}

    {finished ? <div className="review-finished">
      <span className="review-finished-icon"><i className="ri-checkbox-circle-line" aria-hidden="true"></i></span>
      <h2>أكملت المجموعة</h2>
      <p className="muted">راجعت {words.length} بطاقة في هذه الجلسة.</p>
      <div className="review-result-grid">
        <div><span>أتذكرها ذاتياً</span><strong>{tally.known}</strong></div>
        <div><span>تحتاج مراجعة</span><strong>{tally.learning}</strong></div>
        <div><span>إجمالي المجموعة</span><strong>{words.length}</strong></div>
        <div><span>نسبة التذكر الذاتي</span><strong>{Math.round((tally.known / words.length) * 100)}%</strong></div>
      </div>
      <button className="button primary" type="button" onClick={shuffle}><i className="ri-refresh-line" aria-hidden="true"></i> جلسة جديدة</button>
    </div> : <div className="flash-stage">
      <button
        type="button"
        className={`flash-card${flipped ? " revealed" : ""}`}
        onClick={() => setFlipped((value) => !value)}
        aria-label={flipped ? "إخفاء المعنى" : "كشف المعنى"}
      >
        <div className="flash-card-top">
          <span className="lab-tag">{words.length ? `بطاقة ${cursor + 1}` : "بطاقة"}</span>
          {word?.part_of_speech && <span className="lab-meta">{word.part_of_speech}</span>}
        </div>
        <span className="flash-hanzi">{word?.hanzi}</span>
        <span className="flash-pinyin" dir="ltr">{word?.pinyin}</span>
        {flipped ? <>
          <span className="flash-meaning">{word?.meaning_ar}</span>
          {word?.meaning_en && <span className="flash-meaning-en" dir="ltr">{word.meaning_en}</span>}
          {word?.example_zh && <span className="flash-example">
            <strong>{word.example_zh}</strong>
            <small>{word.example_ar}</small>
          </span>}
        </> : <span className="flash-hint">اضغط على البطاقة لكشف المعنى</span>}
      </button>

      <div className="flash-actions">
        <button className="button secondary" type="button" onClick={() => mark("learning")} disabled={busy || !flipped}>
          <i className="ri-refresh-line" aria-hidden="true"></i> تحتاج مراجعة
        </button>
        <button className="button primary" type="button" onClick={() => mark("known")} disabled={busy || !flipped}>
          <i className="ri-check-line" aria-hidden="true"></i> أتذكرها
        </button>
      </div>
      <div className="flash-tally">
        <span><i className="ri-checkbox-circle-line" aria-hidden="true"></i> {tally.known} أتذكرها ذاتياً</span>
        <span><i className="ri-time-line" aria-hidden="true"></i> {tally.learning} للمراجعة</span>
        <button className="text-button" type="button" onClick={() => setFlipped((value) => !value)} disabled={!word}>
          {flipped ? "إخفاء المعنى" : "كشف المعنى"}
        </button>
      </div>
    </div>}
  </section>;
}