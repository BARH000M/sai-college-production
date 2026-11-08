import { useEffect, useMemo, useState } from "react";
import { QRCodeCanvas } from "qrcode.react";
import { academicClassOptions, qrRoster } from "@/mocks/academics";
import { LabPage } from "@/portal/pages/labs/LabShell";
import { PrintDoc } from "@/portal/pages/academics/PrintDoc";

const SESSION_SECONDS = 45;

function makeCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from({ length: 6 }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join("");
}

type Row = { id: string; name: string; admissionNo: string; level: string; present: boolean; at: string };

function nowLabel(): string {
  return new Date().toLocaleTimeString("ar-EG", { hour: "2-digit", minute: "2-digit", hour12: false });
}

export function QrAttendance() {
  const [classId, setClassId] = useState(academicClassOptions[0].id);
  const [code, setCode] = useState(makeCode);
  const [secondsLeft, setSecondsLeft] = useState(SESSION_SECONDS);
  const [running, setRunning] = useState(true);
  const [roster, setRoster] = useState<Row[]>(() => qrRoster.map((row) => ({ ...row })));
  const [manual, setManual] = useState("");
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [printOpen, setPrintOpen] = useState(false);

  const activeClass = academicClassOptions.find((row) => row.id === classId) ?? academicClassOptions[0];
  const today = "2026-11-08";

  useEffect(() => {
    if (!running) return;
    const timer = window.setTimeout(() => setSecondsLeft((value) => value - 1), 1000);
    return () => window.clearTimeout(timer);
  }, [running, secondsLeft]);

  useEffect(() => {
    if (secondsLeft > 0) return;
    setCode(makeCode());
    setSecondsLeft(SESSION_SECONDS);
  }, [secondsLeft]);

  const present = roster.filter((row) => row.present).length;
  const rate = roster.length ? Math.round((present / roster.length) * 100) : 0;
  const visible = roster.filter((row) => !search.trim()
    || row.name.includes(search.trim())
    || row.admissionNo.toLowerCase().includes(search.trim().toLowerCase()));

  const qrValue = useMemo(
    () => `SAI-ATT|${activeClass.id}|${today}|${code}`,
    [activeClass.id, code],
  );

  function toggle(id: string) {
    setNotice(null);
    setRoster((current) => current.map((row) => {
      if (row.id !== id) return row;
      return row.present
        ? { ...row, present: false, at: "" }
        : { ...row, present: true, at: nowLabel() };
    }));
  }

  function refreshCode() {
    setCode(makeCode());
    setSecondsLeft(SESSION_SECONDS);
    setRunning(true);
    setNotice("تم إصدار رمز حضور جديد وإبطال الرمز السابق.");
  }

  function markManual() {
    const value = manual.trim().toUpperCase();
    if (!value) {
      setError("أدخل الرقم الأكاديمي للطالب أولاً.");
      return;
    }
    const hit = roster.find((row) => row.admissionNo.toUpperCase() === value);
    if (!hit) {
      setError(`لا يوجد طالب بالرقم ${value} في هذه الشعبة.`);
      setNotice(null);
      return;
    }
    setError(null);
    if (hit.present) {
      setNotice(`${hit.name} مسجل حاضر مسبقاً.`);
      setManual("");
      return;
    }
    setRoster((current) => current.map((row) => row.id === hit.id ? { ...row, present: true, at: nowLabel() } : row));
    setNotice(`تم تسجيل حضور ${hit.name} يدوياً.`);
    setManual("");
  }

  const timerDegrees = Math.round((secondsLeft / SESSION_SECONDS) * 360);

  return <LabPage
    eyebrow="الحضور والغياب"
    title="الحضور بالرمز QR"
    intro="اعرض رمز الحضور على شاشة القاعة، ويسجّل الطلاب حضورهم بمسحه من هواتفهم. يتجدد الرمز تلقائياً لمنع مشاركته خارج القاعة."
    badge={running ? "الجلسة مفتوحة" : "الجلسة موقوفة"}
  >
    <fieldset className="context-card">
      <label>الشعبة
        <select value={classId} onChange={(event) => { setClassId(event.target.value); setNotice(null); setError(null); }}>
          {academicClassOptions.map((row) => <option key={row.id} value={row.id}>{row.name} — {row.program}</option>)}
        </select>
      </label>
      <label>التاريخ
        <input type="date" value={today} readOnly />
      </label>
      <label>المعلم المسؤول
        <input type="text" value={activeClass.teacher} readOnly />
      </label>
      <div className="actions" style={{ alignSelf: "end" }}>
        <button className="button secondary" type="button" onClick={() => setRunning((value) => !value)}>
          <i className={running ? "ri-pause-line" : "ri-play-line"} aria-hidden="true"></i> {running ? "إيقاف مؤقت" : "استئناف الجلسة"}
        </button>
        <button className="button secondary" type="button" onClick={() => setPrintOpen(true)}>
          <i className="ri-printer-line" aria-hidden="true"></i> طباعة كشف الحضور
        </button>
      </div>
    </fieldset>

    {notice && <p className="success-box" role="status">{notice}</p>}
    {error && <p className="error-box" role="alert">{error}</p>}

    <div className="qr-layout">
      <section className="panel qr-panel">
        <div className="page-heading">
          <div><h2>رمز الحضور المباشر</h2><p className="data-note">امسح الرمز من هاتفك لتسجيل الحضور.</p></div>
          <span className={`lab-status ${running ? "status-ok" : "status-neutral"}`}>{running ? "يعمل" : "متوقف"}</span>
        </div>

        <div className="qr-frame">
          <QRCodeCanvas
            value={qrValue}
            size={210}
            level="M"
            marginSize={2}
            bgColor="#ffffff"
            fgColor="#1b1b1b"
            aria-label={`رمز حضور ${activeClass.name}`}
          />
          {!running && <span className="qr-paused">الرمز معطّل مؤقتاً</span>}
        </div>

        <div className="qr-code-row">
          <div>
            <span>الرمز الاحتياطي</span>
            <strong dir="ltr">{code}</strong>
          </div>
          <div
            className="qr-timer"
            style={{ background: `conic-gradient(oklch(var(--primary-500)) ${timerDegrees}deg, oklch(var(--background-200)) ${timerDegrees}deg)` }}
            aria-label={`يتجدد الرمز بعد ${secondsLeft} ثانية`}
          >
            <span>{secondsLeft}</span>
          </div>
        </div>
        <p className="data-note">يتجدد الرمز تلقائياً كل {SESSION_SECONDS} ثانية. إذا لم يعمل المسح، أدخل الرمز الاحتياطي في صفحة الحضور.</p>
        <button className="button primary" type="button" onClick={refreshCode} style={{ width: "100%" }}>
          <i className="ri-refresh-line" aria-hidden="true"></i> إصدار رمز جديد الآن
        </button>
      </section>

      <section className="panel">
        <h2>ملخص الحضور</h2>
        <div className="qr-summary">
          <div className="qr-summary-ring" style={{ background: `conic-gradient(oklch(var(--secondary-500)) ${rate * 3.6}deg, oklch(var(--background-200)) ${rate * 3.6}deg)` }}>
            <span>{rate}%</span>
          </div>
          <div className="qr-summary-stats">
            <div><span>إجمالي الطلاب</span><strong>{roster.length}</strong></div>
            <div><span>حاضر</span><strong>{present}</strong></div>
            <div><span>غائب</span><strong>{roster.length - present}</strong></div>
            <div><span>وقت الجلسة</span><strong dir="ltr">08:00</strong></div>
          </div>
        </div>
        <div className="qr-manual">
          <h3>تسجيل حضور يدوي</h3>
          <p className="data-note">استخدمه عند تعذر المسح، أو لتسجيل طالب متأخر.</p>
          <div className="qr-manual-row">
            <input
              value={manual}
              onChange={(event) => setManual(event.target.value)}
              placeholder="SAI-2026-118"
              dir="ltr"
              aria-label="الرقم الأكاديمي للطالب"
            />
            <button className="button primary" type="button" onClick={markManual}>تسجيل</button>
          </div>
        </div>
        <ul className="lab-compact-list qr-tips">
          <li><i className="ri-smartphone-line" aria-hidden="true"></i> <span>يجب أن يكون هاتف الطالب متصلاً بالإنترنت أثناء المسح.</span></li>
          <li><i className="ri-shield-check-line" aria-hidden="true"></i> <span>كل رمز مرتبط بالشعبة والتاريخ، ولا يعمل في جلسة أخرى.</span></li>
          <li><i className="ri-user-location-line" aria-hidden="true"></i> <span>يمكن للمعلم تصحيح أي سجل يدوياً قبل إغلاق الجلسة.</span></li>
        </ul>
      </section>
    </div>

    <section className="panel">
      <div className="page-heading">
        <div><h2>قائمة الطلاب</h2><p className="data-note">تُحدَّث القائمة لحظياً عند تسجيل الحضور.</p></div>
        <label className="lab-search">
          <span className="sr-only">بحث عن طالب</span>
          <i className="ri-search-line" aria-hidden="true"></i>
          <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="بحث بالاسم أو الرقم" />
        </label>
      </div>
      <div className="table-scroll"><table className="management-table">
        <thead><tr><th>الطالب</th><th>الرقم الأكاديمي</th><th>المستوى</th><th>وقت الحضور</th><th>الحالة</th><th>إجراء</th></tr></thead>
        <tbody>
          {visible.map((row) => <tr key={row.id}>
            <td><strong>{row.name}</strong></td>
            <td dir="ltr">{row.admissionNo}</td>
            <td>{row.level}</td>
            <td dir="ltr">{row.at || "—"}</td>
            <td><span className={`lab-status ${row.present ? "status-ok" : "status-warn"}`}>{row.present ? "حاضر" : "لم يسجل"}</span></td>
            <td><button className={`button ${row.present ? "secondary" : "primary"}`} type="button" onClick={() => toggle(row.id)}>
              {row.present ? "إلغاء الحضور" : "تسجيل حضور"}
            </button></td>
          </tr>)}
        </tbody>
      </table></div>
      {!visible.length && <p className="muted">لا يوجد طالب يطابق البحث.</p>}
    </section>

    {printOpen && <PrintDoc
      title="كشف حضور الجلسة"
      subtitle={`${activeClass.name} · ${activeClass.program} · ${today}`}
      archive={{ term: "الفصل الأول 2026/2027", preparedBy: activeClass.teacher }}
      onClose={() => setPrintOpen(false)}
    >
      <div className="print-qr-row">
        <QRCodeCanvas value={qrValue} size={120} level="M" marginSize={1} bgColor="#ffffff" fgColor="#111111" aria-label="رمز الحضور" />
        <div>
          <strong>رمز الجلسة: <span dir="ltr">{code}</span></strong>
          <p className="data-note">التاريخ: {today} · الشعبة: {activeClass.name} · المعلم: {activeClass.teacher}</p>
          <p className="data-note">نسبة الحضور المسجلة: {rate}% ({present} من {roster.length})</p>
        </div>
      </div>
      <div className="table-scroll"><table className="sheet-table">
        <thead><tr><th>#</th><th>الطالب</th><th>الرقم الأكاديمي</th><th>المستوى</th><th>وقت الحضور</th><th>الحالة</th><th>توقيع</th></tr></thead>
        <tbody>{roster.map((row, index) => <tr key={row.id}>
          <td>{index + 1}</td><td><strong>{row.name}</strong></td><td dir="ltr">{row.admissionNo}</td>
          <td>{row.level}</td><td dir="ltr">{row.at || "—"}</td><td>{row.present ? "حاضر" : "غائب"}</td>
          <td className="sheet-sign-cell"></td>
        </tr>)}</tbody>
      </table></div>
      <div className="receipt-signatures">
        <div><span>إعداد: {activeClass.teacher}</span></div>
        <div><span>اعتماد الشؤون الأكاديمية</span></div>
      </div>
    </PrintDoc>}
  </LabPage>;
}