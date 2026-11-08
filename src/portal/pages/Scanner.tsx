import { useCallback, useEffect, useRef, useState, type ChangeEvent, type FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import jsQR from "jsqr";
import {
  admissionStatuses, assignAdmission, loadAdmissionByReference, loadAdmissionStaff,
  type StaffOption,
} from "../lib/admissions";
import { clearRecentScans, loadRecentScans, rememberScan, type RecentScan } from "../lib/scannerRecent";

function extractReference(raw: string): string | null {
  const text = raw.trim();
  const param = /[?&]ref=([^&\s#]+)/i.exec(text);
  if (param) {
    try {
      return decodeURIComponent(param[1]).trim();
    } catch {
      return param[1].trim();
    }
  }
  const direct = /SAI-APP-[A-Za-z0-9-]+/i.exec(text);
  if (direct) return direct[0].toUpperCase();
  if (/^[A-Za-z0-9-]{6,40}$/.test(text)) return text;
  return null;
}

function readCanvas(source: HTMLVideoElement | HTMLImageElement, width: number, height: number): ImageData | null {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d", { willReadFrequently: true });
  if (!context) return null;
  context.drawImage(source, 0, 0, width, height);
  return context.getImageData(0, 0, width, height);
}

function statusLabel(value: string): string {
  const labels = admissionStatuses as Record<string, string>;
  return labels[value] ?? value;
}

function errorText(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function formatScannedAt(value: string): string {
  const parsed = new Date(value).getTime();
  if (Number.isNaN(parsed)) return "—";
  const minutes = Math.round((Date.now() - parsed) / 60000);
  if (minutes < 1) return "الآن";
  if (minutes < 60) return `قبل ${minutes} دقيقة`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `قبل ${hours} ساعة`;
  const days = Math.round(hours / 24);
  if (days < 30) return `قبل ${days} يوم`;
  return new Date(value).toLocaleDateString("ar");
}

type RecentItem = RecentScan & {
  enquiryId: string | null;
  name: string | null;
  status: string | null;
  branchId: string | null;
  assignedTo: string | null;
  assignedName: string | null;
  resolved: boolean;
};

const emptyItem = (scan: RecentScan): RecentItem => ({
  ...scan, enquiryId: null, name: null, status: null, branchId: null,
  assignedTo: null, assignedName: null, resolved: false,
});

export function Scanner({ roles }: { roles: readonly string[] }) {
  const navigate = useNavigate();
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const doneRef = useRef(false);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [manual, setManual] = useState("");
  const [recent, setRecent] = useState<RecentItem[]>([]);
  const [staffByBranch, setStaffByBranch] = useState<Record<string, StaffOption[]>>({});
  const [staffError, setStaffError] = useState<string | null>(null);
  const [assigningRef, setAssigningRef] = useState<string | null>(null);
  const [savingRef, setSavingRef] = useState<string | null>(null);
  const [assignNotice, setAssignNotice] = useState<string | null>(null);
  const [assignError, setAssignError] = useState<string | null>(null);
  const canScan = roles.some((role) => ["super_admin", "admin", "receptionist"].includes(role));
  const canAssign = canScan;

  const stopCamera = useCallback(() => {
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
    if (videoRef.current) videoRef.current.srcObject = null;
    setRunning(false);
  }, []);

  const openEnquiry = useCallback((raw: string) => {
    if (doneRef.current) return;
    const reference = extractReference(raw);
    if (!reference) {
      setError("تعذّر قراءة رقم الطلب من هذا الرمز. تأكد أنه رمز إيصال صادر من مكتب القبول.");
      return;
    }
    doneRef.current = true;
    setError(null);
    setNotice(`تمت قراءة الرقم المرجعي ${reference} — جارٍ فتح الطلب في مساحة العمل...`);
    rememberScan(reference);
    stopCamera();
    navigate(`/portal/modules/admissions?ref=${encodeURIComponent(reference)}`);
  }, [navigate, stopCamera]);

  const reopen = useCallback((reference: string) => {
    doneRef.current = true;
    setError(null);
    rememberScan(reference);
    stopCamera();
    navigate(`/portal/modules/admissions?ref=${encodeURIComponent(reference)}`);
  }, [navigate, stopCamera]);

  useEffect(() => () => {
    streamRef.current?.getTracks().forEach((track) => track.stop());
  }, []);

  useEffect(() => {
    setRecent(loadRecentScans().map(emptyItem));
  }, []);

  useEffect(() => {
    if (!canScan) return;
    const pending = recent.filter((item) => !item.resolved);
    if (!pending.length) return;
    let active = true;
    void Promise.all(pending.map(async (item) => {
      try {
        const row = await loadAdmissionByReference(item.reference);
        return {
          reference: item.reference,
          enquiryId: row?.id ?? null,
          name: row?.applicant_full_name ?? null,
          status: row?.status ?? null,
          branchId: row?.branch_id ?? null,
          assignedTo: row?.assigned_to ?? null,
        };
      } catch {
        return { reference: item.reference, enquiryId: null, name: null, status: null, branchId: null, assignedTo: null };
      }
    })).then(async (results) => {
      if (!active) return;
      const branchIds = Array.from(new Set(results
        .map((entry) => entry.branchId)
        .filter((value): value is string => typeof value === "string" && value.length > 0)));
      const lists: Record<string, StaffOption[]> = {};
      await Promise.all(branchIds.map(async (branchId) => {
        try { lists[branchId] = await loadAdmissionStaff(branchId); } catch { /* names stay unknown */ }
      }));
      if (!active) return;
      if (Object.keys(lists).length) setStaffByBranch((current) => ({ ...current, ...lists }));
      setRecent((current) => current.map((item) => {
        const hit = results.find((entry) => entry.reference === item.reference);
        if (!hit) return item;
        const people = hit.branchId ? lists[hit.branchId] ?? [] : [];
        const assignedName = hit.assignedTo
          ? people.find((person) => person.user_id === hit.assignedTo)?.full_name ?? null
          : null;
        return { ...item, ...hit, assignedName, resolved: true };
      }));
    });
    return () => { active = false; };
  }, [recent, canScan]);

  useEffect(() => {
    if (!running) return;
    let frame = 0;
    let cancelled = false;
    const tick = () => {
      if (cancelled) return;
      const video = videoRef.current;
      if (video && video.readyState >= 2 && video.videoWidth > 0) {
        const image = readCanvas(video, video.videoWidth, video.videoHeight);
        if (image) {
          const code = jsQR(image.data, image.width, image.height, { inversionAttempts: "dontInvert" });
          if (code?.data) {
            openEnquiry(code.data);
            return;
          }
        }
      }
      frame = window.requestAnimationFrame(tick);
    };
    frame = window.requestAnimationFrame(tick);
    return () => {
      cancelled = true;
      window.cancelAnimationFrame(frame);
    };
  }, [running, openEnquiry]);

  async function startCamera() {
    setError(null);
    setNotice(null);
    doneRef.current = false;
    if (!navigator.mediaDevices?.getUserMedia) {
      setError("هذا المتصفح لا يدعم تشغيل الكاميرا. استخدم رفع صورة الإيصال أو أدخل الرقم يدويًا.");
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: "environment" } },
        audio: false,
      });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }
      setRunning(true);
    } catch {
      setError("تعذّر تشغيل الكاميرا. امنح المتصفح إذن الكاميرا، أو استخدم رفع صورة الإيصال.");
    }
  }

  async function handleFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    setError(null);
    setNotice(null);
    doneRef.current = false;
    const url = URL.createObjectURL(file);
    try {
      const image = new Image();
      await new Promise<void>((resolve, reject) => {
        image.onload = () => resolve();
        image.onerror = () => reject(new Error("decode failed"));
        image.src = url;
      });
      const data = readCanvas(image, image.naturalWidth, image.naturalHeight);
      if (!data) throw new Error("canvas unavailable");
      const code = jsQR(data.data, data.width, data.height, { inversionAttempts: "attemptBoth" });
      if (!code?.data) {
        setError("لم نعثر على رمز QR واضح في الصورة. جرّب صورة أقرب وأوضح، أو أدخل الرقم يدويًا.");
        return;
      }
      openEnquiry(code.data);
    } catch {
      setError("تعذّرت قراءة هذه الصورة. جرّب صورة أخرى أو أدخل الرقم المرجعي يدويًا.");
    } finally {
      URL.revokeObjectURL(url);
    }
  }

  function submitManual(event: FormEvent) {
    event.preventDefault();
    const value = manual.trim();
    if (value.length < 6) {
      setError("أدخل الرقم المرجعي كاملًا (مثال: SAI-APP-1042).");
      return;
    }
    openEnquiry(value);
  }

  function clearRecent() {
    clearRecentScans();
    setRecent([]);
    setAssigningRef(null);
    setAssignNotice(null);
    setAssignError(null);
  }

  async function openAssign(item: RecentItem) {
    setAssignError(null);
    setAssignNotice(null);
    setStaffError(null);
    if (!item.branchId) {
      setAssignError("تعذّر تحديد فرع هذا الطلب، لذلك لا يمكن عرض قائمة الموظفين.");
      return;
    }
    setAssigningRef(item.reference);
    if (staffByBranch[item.branchId]) return;
    const branchId = item.branchId;
    try {
      const staff = await loadAdmissionStaff(branchId);
      setStaffByBranch((current) => ({ ...current, [branchId]: staff }));
    } catch (failure) {
      setStaffError(`تعذّر تحميل موظفي الفرع: ${errorText(failure)}`);
      setAssignError("تعذّر تحميل قائمة الموظفين لهذا الفرع، لذلك لم يُفتح الإسناد.");
      setAssigningRef(null);
    }
  }

  async function applyAssign(item: RecentItem, userId: string) {
    if (!item.enquiryId || savingRef) return;
    const staff = item.branchId ? staffByBranch[item.branchId] ?? [] : [];
    const chosen = userId ? staff.find((person) => person.user_id === userId) ?? null : null;
    if (userId && !chosen) {
      setAssignError("الموظف المختار لم يعد ضمن قائمة الفرع؛ أعد فتح الإسناد.");
      return;
    }
    setSavingRef(item.reference);
    setAssignError(null);
    setAssignNotice(null);
    try {
      await assignAdmission(item.enquiryId, userId || null);
      setRecent((current) => current.map((row) => row.reference === item.reference
        ? { ...row, assignedTo: userId || null, assignedName: chosen?.full_name ?? null }
        : row));
      setAssigningRef(null);
      setAssignNotice(userId
        ? `تم إسناد الطلب ${item.reference} إلى ${chosen?.full_name ?? "الموظف المحدد"}.`
        : `تم إلغاء إسناد الطلب ${item.reference}.`);
    } catch (failure) {
      setAssignError(`تعذّر تحديث الإسناد: ${errorText(failure)}`);
    } finally {
      setSavingRef(null);
    }
  }

  if (!canScan) {
    return <main className="workspace"><section className="panel" role="alert">
      <h1>الوصول غير متاح</h1>
      <p>ماسح الإيصالات متاح لموظفي الاستقبال ومكتب القبول فقط.</p>
      <Link className="button secondary" to="/portal/dashboard">العودة للرئيسية</Link>
    </section></main>;
  }

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">مكتب القبول</p>
        <h1>ماسح إيصالات القبول</h1>
      </div>
      <Link className="button secondary" to="/portal/modules/admissions">فتح مساحة القبول</Link>
    </div>
    <p className="data-note">
      وجّه كاميرا الجهاز إلى رمز QR المطبوع على إيصال الاستلام، وسيُفتح الطلب مباشرة في مساحة العمل
      مع كل بياناته وسجل حالته. يمكنك أيضًا رفع صورة الإيصال أو إدخال الرقم يدويًا.
    </p>

    <div className="scanner-grid">
      <section className="panel scanner-panel">
        <div className={`scanner-viewport${running ? " live" : ""}`}>
          <video ref={videoRef} playsInline muted aria-label="معاينة كاميرا الماسح" />
          {!running && <div className="scanner-idle">
            <span className="scanner-idle-icon" aria-hidden="true"><i className="ri-qr-scan-2-line"></i></span>
            <p>الكاميرا متوقفة</p>
            <small>ابدأ المسح لتوجيه الكاميرا نحو رمز الإيصال.</small>
          </div>}
          {running && <span className="scanner-frame" aria-hidden="true"></span>}
        </div>
        <div className="actions scanner-actions">
          {running
            ? <button type="button" className="button secondary" onClick={stopCamera}>إيقاف الكاميرا</button>
            : <button type="button" className="button primary" onClick={() => void startCamera()}>بدء المسح بالكاميرا</button>}
          <label className="button secondary scanner-upload">
            رفع صورة الإيصال
            <input type="file" accept="image/*" onChange={(event) => void handleFile(event)} />
          </label>
        </div>
        {notice && <p className="success-box" role="status">{notice}</p>}
        {error && <p className="error-box" role="alert">{error}</p>}
      </section>

      <section className="panel">
        <h2>إدخال يدوي</h2>
        <p className="data-note">إذا كان رمز الإيصال تالفًا أو الكاميرا غير متاحة، أدخل الرقم المرجعي المطبوع على الإيصال.</p>
        <form className="management-form scanner-manual" onSubmit={submitManual}>
          <label>الرقم المرجعي للطلب
            <input value={manual} onChange={(event) => setManual(event.target.value)} placeholder="SAI-APP-1042" dir="ltr" autoComplete="off" />
          </label>
          <div className="actions">
            <button className="button primary" type="submit" disabled={manual.trim().length < 6}>فتح الطلب</button>
          </div>
        </form>
        <ul className="scanner-tips">
          <li><i className="ri-lightbulb-line" aria-hidden="true"></i> ثبّت الإيصال في إضاءة جيدة وبعيدًا عن الانعكاسات.</li>
          <li><i className="ri-focus-3-line" aria-hidden="true"></i> ضع الرمز داخل الإطار المربع حتى يلتقطه الماسح.</li>
          <li><i className="ri-shield-check-line" aria-hidden="true"></i> لن يُفتح إلا طلب يقع ضمن الفروع المسموح بها لحسابك.</li>
        </ul>
      </section>
    </div>

    <section className="panel recent-panel" aria-label="آخر الطلبات الممسوحة">
      <div className="page-heading">
        <div>
          <h2>آخر الطلبات الممسوحة</h2>
        </div>
        {!!recent.length && <button type="button" className="button secondary" onClick={clearRecent}>مسح القائمة</button>}
      </div>
      <p className="data-note">
        تُحفظ آخر ستة طلبات على هذا الجهاز فقط، لتتمكن من إعادة فتحها دون إعادة مسح الإيصال.
        {canAssign ? " ويمكنك إسناد أي طلب منها إلى موظف مباشرة دون فتح ملفه الكامل." : ""}
      </p>
      {assignNotice && <p className="success-box" role="status">{assignNotice}</p>}
      {assignError && <p className="error-box" role="alert">{assignError}</p>}
      {staffError && <p className="error-box" role="alert">{staffError}</p>}
      {!recent.length
        ? <p className="muted">لم يتم مسح أي إيصال على هذا الجهاز بعد.</p>
        : <ul className="recent-list">
          {recent.map((item) => {
            const staff = item.branchId ? staffByBranch[item.branchId] ?? [] : [];
            const busy = savingRef === item.reference;
            return <li key={item.reference} className="recent-item">
              <div className="recent-main">
                <span className="recent-ref" dir="ltr">{item.reference}</span>
                <span className="recent-name">{item.name ?? (item.resolved ? "غير متاح لهذا الحساب" : "جارٍ التحقق من البيانات...")}</span>
                {item.resolved && item.name && <span className="recent-assignee">
                  <i className="ri-user-line" aria-hidden="true"></i>
                  {item.assignedTo ? `مسند إلى: ${item.assignedName ?? "موظف"}` : "غير مسند"}
                </span>}
              </div>
              <div className="recent-side">
                {item.status && <span className="recent-status">{statusLabel(item.status)}</span>}
                <time className="recent-time" dateTime={item.scannedAt}>{formatScannedAt(item.scannedAt)}</time>
                <button type="button" className="button secondary" onClick={() => reopen(item.reference)}>
                  <i className="ri-external-link-line" aria-hidden="true"></i> فتح
                </button>
                {canAssign && item.resolved && item.name && item.branchId && assigningRef !== item.reference && <button
                  type="button"
                  className="button secondary"
                  disabled={busy}
                  onClick={() => void openAssign(item)}
                >
                  <i className="ri-user-add-line" aria-hidden="true"></i> تعيين
                </button>}
              </div>
              {assigningRef === item.reference && <div className="recent-assign">
                <label>إسناد الطلب إلى
                  <select
                    value={item.assignedTo ?? ""}
                    disabled={busy}
                    onChange={(event) => void applyAssign(item, event.target.value)}
                  >
                    <option value="">غير مسند</option>
                    {staff.map((person) => <option key={person.user_id} value={person.user_id}>{person.full_name}</option>)}
                    {item.assignedTo && !staff.some((person) => person.user_id === item.assignedTo) && <option value={item.assignedTo}>{item.assignedName ?? "الموظف الحالي"}</option>}
                  </select>
                </label>
                <button type="button" className="button secondary" disabled={busy} onClick={() => setAssigningRef(null)}>
                  {busy ? "جارٍ الحفظ..." : "إغلاق"}
                </button>
              </div>}
            </li>;
          })}
        </ul>}
    </section>
  </main>;
}