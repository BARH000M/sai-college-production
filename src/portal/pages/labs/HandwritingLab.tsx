import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from "react";
import { handwritingChars } from "@/mocks/learningLabs";
import { LabPage } from "@/portal/pages/labs/LabShell";

type Point = { x: number; y: number };

export function HandwritingLab() {
  const [charId, setCharId] = useState(handwritingChars[0].id);
  const [showGuide, setShowGuide] = useState(true);
  const [hasInk, setHasInk] = useState(false);
  const [done, setDone] = useState<string[]>([]);
  const [notice, setNotice] = useState<string | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const drawing = useRef(false);
  const lastPoint = useRef<Point | null>(null);

  const character = handwritingChars.find((row) => row.id === charId) ?? handwritingChars[0];
  const isDone = done.includes(character.id);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;
    context.clearRect(0, 0, canvas.width, canvas.height);
    context.lineCap = "round";
    context.lineJoin = "round";
    context.lineWidth = 9;
    context.strokeStyle = "#1f2937";
    setHasInk(false);
    setNotice(null);
  }, [charId]);

  function position(event: ReactPointerEvent<HTMLCanvasElement>): Point {
    const canvas = event.currentTarget;
    const rect = canvas.getBoundingClientRect();
    return {
      x: ((event.clientX - rect.left) / rect.width) * canvas.width,
      y: ((event.clientY - rect.top) / rect.height) * canvas.height,
    };
  }

  function start(event: ReactPointerEvent<HTMLCanvasElement>) {
    const canvas = event.currentTarget;
    const context = canvas.getContext("2d");
    if (!context) return;
    canvas.setPointerCapture(event.pointerId);
    const point = position(event);
    drawing.current = true;
    lastPoint.current = point;
    context.beginPath();
    context.moveTo(point.x, point.y);
    context.lineTo(point.x + 0.1, point.y + 0.1);
    context.stroke();
    setHasInk(true);
  }

  function move(event: ReactPointerEvent<HTMLCanvasElement>) {
    if (!drawing.current) return;
    const context = event.currentTarget.getContext("2d");
    const previous = lastPoint.current;
    if (!context || !previous) return;
    const point = position(event);
    context.beginPath();
    context.moveTo(previous.x, previous.y);
    context.lineTo(point.x, point.y);
    context.stroke();
    lastPoint.current = point;
  }

  function stop() {
    drawing.current = false;
    lastPoint.current = null;
  }

  function clearPad() {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) return;
    context.clearRect(0, 0, canvas.width, canvas.height);
    setHasInk(false);
    setNotice(null);
  }

  function finish() {
    if (!hasInk) {
      setNotice("ارسم الحرف أولاً داخل الشبكة، ثم اضغط «أتممت الكتابة».");
      return;
    }
    setDone((current) => (current.includes(character.id) ? current : [...current, character.id]));
    setNotice(`أُضيف الحرف «${character.char}» إلى سجل التدريب.`);
  }

  const index = handwritingChars.findIndex((row) => row.id === character.id);
  const next = handwritingChars[(index + 1) % handwritingChars.length];

  return <LabPage
    eyebrow="مهارات الكتابة الصينية"
    title="الكتابة اليدوية"
    intro="تدرّب على كتابة الحروف داخل شبكة تشبه دفتر الخط الصيني، مع إمكانية إظهار الحرف كدليل شفاف."
    badge={`${done.length} / ${handwritingChars.length} مكتملة`}
  >
    <div className="lab-split lab-split-wide">
      <section className="panel">
        <div className="page-heading">
          <div><h2>لوح التدريب</h2><p className="data-note">استخدم إصبعك أو الفأرة للرسم داخل المربع.</p></div>
          <label className="lab-toggle">
            <input type="checkbox" checked={showGuide} onChange={(event) => setShowGuide(event.target.checked)} />
            <span>إظهار الدليل</span>
          </label>
        </div>

        <div className="lab-write-frame">
          <div className="lab-write-guide" aria-hidden="true">
            <span className="guide-lines"></span>
            {showGuide && <span className="guide-char">{character.char}</span>}
          </div>
          <canvas
            ref={canvasRef}
            width={600}
            height={600}
            className="lab-write-canvas"
            aria-label={`لوح كتابة الحرف ${character.char}`}
            onPointerDown={start}
            onPointerMove={move}
            onPointerUp={stop}
            onPointerLeave={stop}
            onPointerCancel={stop}
          ></canvas>
        </div>

        <div className="actions lab-write-actions">
          <button className="button primary" type="button" onClick={finish}>
            <i className="ri-check-line" aria-hidden="true"></i> أتممت الكتابة
          </button>
          <button className="button secondary" type="button" onClick={clearPad}>
            <i className="ri-eraser-line" aria-hidden="true"></i> مسح اللوح
          </button>
          <button className="button secondary" type="button" onClick={() => setCharId(next.id)}>
            الحرف التالي: {next.char}
          </button>
        </div>
        {notice && <p className={notice.startsWith("ارسم") ? "notice" : "success-box"} role="status">{notice}</p>}
        <p className="data-note">لا يُقيَّم شكل الخط آلياً في هذه النسخة. الهدف هو تكرار الرسم الصحيح بالترتيب.</p>
      </section>

      <section className="panel">
        <div className="page-heading">
          <div><h2>الحرف الحالي</h2><p className="data-note">الحرف {index + 1} من {handwritingChars.length}</p></div>
          {isDone && <span className="lab-status status-ok">مكتمل</span>}
        </div>

        <div className="lab-char-card">
          <span className="lab-char">{character.char}</span>
          <div>
            <p className="lab-pinyin lab-pinyin-large" dir="ltr">{character.pinyin}</p>
            <p className="lab-item-text">{character.arabic}</p>
            <div className="lab-meta-row">
              <span><i className="ri-edit-2-line" aria-hidden="true"></i> {character.strokes} ضربات</span>
              <span><i className="ri-layout-left-2-line" aria-hidden="true"></i> الجذر: {character.radical}</span>
            </div>
          </div>
        </div>

        <div className="lab-tip-box">
          <strong><i className="ri-lightbulb-line" aria-hidden="true"></i> ترتيب الضربات</strong>
          <p className="lab-item-text">{character.hint}</p>
          <ul>
            <li>اكتب من الأعلى إلى الأسفل، ومن اليسار إلى اليمين.</li>
            <li>الخطوط الأفقية قبل الخطوط الرأسية التي تقطعها.</li>
            <li>أغلق الإطارات في النهاية.</li>
          </ul>
        </div>

        <h3 className="lab-subheading">قائمة الحروف</h3>
        <ul className="lab-char-list">
          {handwritingChars.map((row) => <li key={row.id}>
            <button
              type="button"
              className={`lab-char-chip${row.id === character.id ? " active" : ""}`}
              onClick={() => setCharId(row.id)}
            >
              <span className="lab-char-chip-char">{row.char}</span>
              <span className="lab-char-chip-body">
                <strong dir="ltr">{row.pinyin}</strong>
                <small>{row.arabic}</small>
              </span>
              {done.includes(row.id) && <i className="ri-checkbox-circle-fill" aria-label="مكتمل"></i>}
            </button>
          </li>)}
        </ul>
      </section>
    </div>
  </LabPage>;
}