import { useEffect, useState } from "react";
import { speakingDrills } from "@/mocks/learningLabs";
import { LabPage } from "@/portal/pages/labs/LabShell";

const RECORD_SECONDS = 3;
const BARS = [22, 46, 68, 38, 74, 52, 88, 44, 62, 30, 78, 56, 36, 84, 48, 66, 26, 70, 42, 58];

type Result = { overall: number; tone: number; clarity: number; rhythm: number; note: string };

export function SpeakingLab() {
  const [drillId, setDrillId] = useState(speakingDrills[0].id);
  const [recording, setRecording] = useState(false);
  const [recordSeconds, setRecordSeconds] = useState(0);
  const [attempts, setAttempts] = useState(0);
  const [result, setResult] = useState<Result | null>(null);
  const [modelPlaying, setModelPlaying] = useState(false);

  const drill = speakingDrills.find((row) => row.id === drillId) ?? speakingDrills[0];
  const drillIndex = speakingDrills.findIndex((row) => row.id === drill.id);

  useEffect(() => {
    setRecording(false);
    setRecordSeconds(0);
    setResult(null);
    setModelPlaying(false);
  }, [drillId]);

  useEffect(() => {
    if (!recording) return;
    const timer = window.setTimeout(() => setRecordSeconds((value) => value + 1), 700);
    return () => window.clearTimeout(timer);
  }, [recording, recordSeconds]);

  useEffect(() => {
    if (!recording || recordSeconds < RECORD_SECONDS) return;
    const base = 82 + ((drillIndex * 7 + attempts * 5) % 13);
    const overall = Math.min(97, base);
    setResult({
      overall,
      tone: Math.min(98, overall + 2),
      clarity: Math.max(62, overall - 4),
      rhythm: Math.min(96, overall + 1),
      note: overall >= 90
        ? "نطق ممتاز! النغمات واضحة والإيقاع قريب من النموذج الأصلي."
        : overall >= 84
          ? "أداء جيد جداً. ركّز على ثبات النغمة الثالثة قبل الانتقال للكلمة التالية."
          : "أداء مقبول. أبطئ قليلاً عند النغمة الرابعة وأعد التسجيل للمقارنة.",
    });
    setRecording(false);
    setRecordSeconds(0);
    setAttempts((value) => value + 1);
  }, [recording, recordSeconds, drillIndex, attempts]);

  useEffect(() => {
    if (!modelPlaying) return;
    const timer = window.setTimeout(() => setModelPlaying(false), 2200);
    return () => window.clearTimeout(timer);
  }, [modelPlaying]);

  const scoreCard = (label: string, value: number) => <div key={label} className="lab-score-row">
    <span>{label}</span>
    <span className="learn-bar" aria-hidden="true"><span style={{ width: `${value}%` }} /></span>
    <strong>{value}</strong>
  </div>;

  return <LabPage
    eyebrow="مهارات اللغة الصينية"
    title="التحدث والنطق"
    intro="تدرّب على جمل يومية، استمع إلى النموذج، سجّل صوتك، ثم راجع تقييم النغمة والوضوح والإيقاع."
    badge={`${speakingDrills.length} تدريبات`}
  >
    <div className="lab-split">
      <section className="panel">
        <h2>تدريبات النطق</h2>
        <p className="data-note">اختر جملة للتدريب. تُحفظ المحاولات داخل هذه الجلسة فقط.</p>
        <ul className="lab-list">
          {speakingDrills.map((row, index) => <li key={row.id}>
            <button
              type="button"
              className={`lab-item lab-item-button${row.id === drill.id ? " active" : ""}`}
              onClick={() => setDrillId(row.id)}
            >
              <div className="lab-item-head">
                <strong>{row.hanzi}</strong>
                <span className="learn-pill">{index + 1}</span>
              </div>
              <p className="lab-pinyin" dir="ltr">{row.pinyin}</p>
              <p className="lab-item-text">{row.arabic}</p>
              <div className="lab-meta-row">
                <span><i className="ri-focus-3-line" aria-hidden="true"></i> {row.focus}</span>
              </div>
            </button>
          </li>)}
        </ul>
        <div className="lab-tip-box">
          <strong><i className="ri-lightbulb-line" aria-hidden="true"></i> قبل التسجيل</strong>
          <ul>
            <li>اجلس في مكان هادئ واحمل الهاتف على مسافة 20 سم من الفم.</li>
            <li>اقرأ الجملة مرتين بصوت منخفض ثم سجّل المحاولة الثالثة.</li>
          </ul>
        </div>
      </section>

      <section className="panel">
        <div className="page-heading">
          <div><h2>{drill.hanzi}</h2><p className="data-note">{drill.arabic}</p></div>
          <span className="learn-pill">{drill.focus}</span>
        </div>
        <p className="lab-pinyin lab-pinyin-large" dir="ltr">{drill.pinyin}</p>

        <div className={`lab-recorder${recording ? " recording" : ""}`}>
          <div className="lab-wave lab-wave-record" aria-hidden="true">
            {BARS.map((height, index) => <i key={index} style={{ height: `${recording ? Math.max(14, (height + recordSeconds * 9) % 96) : height}%` }}></i>)}
          </div>
          <div className="lab-recorder-row">
            <button
              type="button"
              className={`lab-record-button${recording ? " active" : ""}`}
              onClick={() => {
                if (recording) {
                  setRecording(false);
                  setRecordSeconds(0);
                  return;
                }
                setResult(null);
                setRecordSeconds(0);
                setRecording(true);
              }}
            >
              <i className={recording ? "ri-stop-circle-line" : "ri-mic-line"} aria-hidden="true"></i>
              {recording ? `جارٍ التسجيل… ${RECORD_SECONDS - recordSeconds}` : "ابدأ التسجيل"}
            </button>
            <button
              type="button"
              className="button secondary"
              onClick={() => setModelPlaying((value) => !value)}
            >
              <i className={modelPlaying ? "ri-volume-up-line" : "ri-volume-down-line"} aria-hidden="true"></i>
              {modelPlaying ? "يُشغّل النموذج…" : "سماع النموذج"}
            </button>
          </div>
          <p className="data-note">مدة التسجيل {RECORD_SECONDS} ثوانٍ. التقييم هنا تدريبي للعرض، ويُستبدل بمحرّك النطق عند ربطه.</p>
        </div>

        <div className="lab-tips">
          {drill.tips.map((tip) => <p key={tip}><i className="ri-check-double-line" aria-hidden="true"></i> {tip}</p>)}
        </div>

        {result && <div className="lab-result">
          <div className="lab-result-score"
            style={{ background: `conic-gradient(oklch(var(--primary-500)) ${result.overall * 3.6}deg, oklch(var(--background-200)) ${result.overall * 3.6}deg)` }}>
            <span>{result.overall}<small>/100</small></span>
          </div>
          <div className="lab-result-body">
            <strong>تقييم المحاولة {attempts}</strong>
            {scoreCard("النغمات", result.tone)}
            {scoreCard("الوضوح", result.clarity)}
            {scoreCard("الإيقاع", result.rhythm)}
            <p className="lab-hint ok"><i className="ri-feedback-line" aria-hidden="true"></i> {result.note}</p>
          </div>
        </div>}

        {!result && !recording && <p className="notice">لم تُسجّل محاولة بعد في هذه الجملة. اضغط «ابدأ التسجيل» ليقوم النظام بتقييم النطق.</p>}
      </section>
    </div>
  </LabPage>;
}