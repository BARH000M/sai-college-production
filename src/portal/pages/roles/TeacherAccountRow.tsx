import { useState } from "react";
import { Link } from "react-router-dom";
import {
  reassignTeacherClass, removeTeacherFromClasses, resetTeacherPassword, suggestPassword,
  teacherEmailNote, type CreatedTeacher, type TeacherAccount, type TeacherClass,
} from "@/portal/lib/learningAccounts";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

type Panel = "" | "reset" | "move" | "remove";

export function TeacherAccountRow({
  teacher, classes, onChanged,
}: {
  teacher: TeacherAccount;
  classes: TeacherClass[];
  onChanged: () => void;
}) {
  const [panel, setPanel] = useState<Panel>("");
  const [targetClassId, setTargetClassId] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [emailNote, setEmailNote] = useState<string | null>(null);
  const [credentials, setCredentials] = useState<CreatedTeacher | null>(null);
  const [copied, setCopied] = useState(false);

  const candidates = classes.filter((row) => !row.teacherId || row.teacherId === teacher.userId);
  const hasClass = teacher.classNames.length > 0;

  function open(next: Panel) {
    setPanel((current) => (current === next ? "" : next));
    setError(null);
    setNotice(null);
    setEmailNote(null);
    setTargetClassId("");
    if (next === "reset") {
      setPassword(suggestPassword());
      setCredentials(null);
      setCopied(false);
    }
  }

  async function copyCredentials() {
    if (!credentials) return;
    const payload = [
      "بوابة كلية ساي — بيان دخول معلم",
      `الاسم: ${credentials.fullName}`,
      `الصف: ${credentials.className || "بلا صف"}`,
      `البريد: ${credentials.email}`,
      `كلمة المرور: ${credentials.password}`,
    ].join("\n");
    try {
      await navigator.clipboard.writeText(payload);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2500);
    } catch {
      setCopied(false);
    }
  }

  async function submitReset() {
    if (busy) return;
    if (password.trim().length < 8) {
      setError("كلمة المرور يجب ألا تقل عن ٨ أحرف.");
      return;
    }
    setBusy(true);
    setError(null);
    setNotice(null);
    setEmailNote(null);
    try {
      const result = await resetTeacherPassword(teacher.userId, password.trim());
      setCredentials(result);
      setPassword("");
      setNotice("تم تحديث كلمة مرور المعلم؛ الحساب والبيانات لم تتغير.");
      setEmailNote(teacherEmailNote(result));
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  async function submitMove() {
    if (busy) return;
    if (!targetClassId) {
      setError("اختر الصف الجديد أولاً.");
      return;
    }
    setBusy(true);
    setError(null);
    setNotice(null);
    setEmailNote(null);
    try {
      const result = await reassignTeacherClass(teacher.userId, targetClassId);
      const movedFrom = result.previousClassNames.length
        ? `أُزيل إسناد ${result.previousClassNames.join(" و ")} عنه. `
        : "";
      setNotice(`${movedFrom}أُسند ${result.fullName} إلى ${result.className} مع وصوله إلى مقرراته.`);
      setEmailNote(teacherEmailNote(result));
      setPanel("");
      setTargetClassId("");
      onChanged();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  async function submitRemove() {
    if (busy) return;
    setBusy(true);
    setError(null);
    setNotice(null);
    setEmailNote(null);
    try {
      const removal = await removeTeacherFromClasses(teacher.userId);
      const removed = removal.removedClassNames;
      setNotice(removed.length
        ? `أُزيل إسناد ${removed.join(" و ")} عن ${teacher.fullName} وأُغلق وصوله إلى الفرع. الحساب محفوظ ويمكن إعادة إسناده.`
        : `لا صفوف مسندة إلى ${teacher.fullName} حالياً؛ أُغلق وصوله إلى الفرع فقط.`);
      setEmailNote(removed.length
        ? teacherEmailNote({ sent: !!removal.emailSent, reason: removal.emailReason })
        : null);
      setPanel("");
      onChanged();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  return <li className="teacher-account-item">
    <div className="teacher-account-head">
      <div>
        <strong>{teacher.fullName}</strong>
        <small className="learn-meta" dir="ltr">{teacher.email || "بدون بريد"}</small>
      </div>
      <span className={`learn-tag ${hasClass ? "" : "learn-tag-muted"}`}>
        {hasClass ? teacher.classNames.join(" · ") : "بلا صف"}
      </span>
    </div>

    <div className="teacher-workload" aria-label="ملخص عبء عمل المعلم">
      <span>
        <i className="ri-team-line" aria-hidden="true" />
        <strong>{teacher.workload.classes}</strong> صف
      </span>
      <span>
        <i className="ri-file-list-3-line" aria-hidden="true" />
        <strong>{teacher.workload.assignments}</strong> واجب
      </span>
      {teacher.workload.ungraded > 0 ? <Link
        className="teacher-workload-alert teacher-workload-link"
        to={`/portal/modules/homework?teacher=${teacher.userId}&pending=1&name=${encodeURIComponent(teacher.fullName)}`}
        title={`فتح التسليمات بانتظار التصحيح لدى ${teacher.fullName}`}
        aria-label={`فتح ${teacher.workload.ungraded} تسليماً بانتظار التصحيح لدى ${teacher.fullName}`}
      >
        <i className="ri-error-warning-line" aria-hidden="true" />
        <strong>{teacher.workload.ungraded}</strong> بانتظار التصحيح
        <i className="ri-arrow-left-up-line teacher-workload-cue" aria-hidden="true" />
      </Link> : <span>
        <i className="ri-error-warning-line" aria-hidden="true" />
        <strong>0</strong> بانتظار التصحيح
      </span>}
      <span>
        <i className="ri-book-open-line" aria-hidden="true" />
        <strong>{teacher.workload.courses}</strong> مقرر
      </span>
    </div>

    <div className="homework-admin">
      <button className="button secondary" type="button" disabled={busy} onClick={() => open("reset")}>
        إعادة تعيين كلمة المرور
      </button>
      <button className="button secondary" type="button" disabled={busy} onClick={() => open("move")}>
        نقل إلى صف
      </button>
      <button className="button secondary" type="button" disabled={busy} onClick={() => open("remove")}>
        إزالة من الصف
      </button>
    </div>

    {notice && <p className="success-box" role="status">{notice}</p>}
    {emailNote && <p className={emailNote.startsWith("أُرسل") ? "success-box" : "notice"} role="status">{emailNote}</p>}
    {error && <p className="error-box" role="alert">{error}</p>}

    {panel === "reset" && <div className="teacher-account-form">
      <strong>كلمة مرور جديدة</strong>
      <p className="data-note">يُحدَّث دخول الحساب نفسه؛ يحتفظ المعلم بصفه ومقرراته وسجلّه.</p>
      <div className="management-form">
        <label>كلمة المرور المؤقتة
          <input dir="ltr" value={password} disabled={busy} onChange={(event) => setPassword(event.target.value)} />
        </label>
        <div className="actions">
          <button className="button primary" type="button" disabled={busy} onClick={() => void submitReset()}>
            {busy ? "جارٍ التحديث..." : "حفظ كلمة المرور"}
          </button>
          <button className="button secondary" type="button" disabled={busy} onClick={() => setPassword(suggestPassword())}>
            توليد كلمة أخرى
          </button>
        </div>
      </div>
    </div>}

    {credentials && <div className="credential-box" role="status">
      <strong>بيانات الدخول الجديدة</strong>
      <p className="data-note">{credentials.fullName} · {credentials.className || "بلا صف مسند"}</p>
      <dl>
        <div><dt>البريد الإلكتروني</dt><dd dir="ltr">{credentials.email}</dd></div>
        <div><dt>كلمة المرور</dt><dd dir="ltr">{credentials.password}</dd></div>
      </dl>
      <p className="data-note">تظهر كلمة المرور مرة واحدة فقط؛ انسخها وسلّمها للمعلم.</p>
      <div className="actions">
        <button className="button primary" type="button" onClick={() => void copyCredentials()}>
          {copied ? "نُسخت البيانات" : "نسخ بيانات الدخول"}
        </button>
        <button className="button secondary" type="button" onClick={() => setCredentials(null)}>إخفاء</button>
      </div>
    </div>}

    {panel === "move" && <div className="teacher-account-form">
      <strong>نقل المعلم إلى صف آخر</strong>
      <p className="data-note">
        يُنقل إسناد الصف وملكية مقرراته إلى الصف الجديد، ويُلغى إسناد الصف السابق تلقائياً.
      </p>
      <div className="management-form">
        <label>الصف الجديد
          <select value={targetClassId} disabled={busy} onChange={(event) => setTargetClassId(event.target.value)}>
            <option value="">— اختر صفاً —</option>
            {candidates.map((row) => <option key={row.id} value={row.id}>
              {row.name}{row.branchName ? ` — ${row.branchName}` : ""}{row.teacherId === teacher.userId ? " (الصف الحالي)" : ""}
            </option>)}
          </select>
        </label>
        {!candidates.length && <p className="notice">لا يوجد صف متاح للنقل؛ كل الصفوف لها معلمون مسندون.</p>}
        <div className="actions">
          <button className="button primary" type="button" disabled={busy || !candidates.length} onClick={() => void submitMove()}>
            {busy ? "جارٍ النقل..." : "نقل المعلم"}
          </button>
          <button className="button secondary" type="button" disabled={busy} onClick={() => setPanel("")}>إلغاء</button>
        </div>
      </div>
    </div>}

    {panel === "remove" && <div className="teacher-account-form teacher-account-danger">
      <strong>إزالة إسناد الصف</strong>
      <p className="data-note">
        {hasClass
          ? `سيُلغى إسناد ${teacher.classNames.join(" و ")} ويُغلق وصول المعلم إلى الفرع. `
          : "لا صفوف مسندة حالياً؛ ستُغلق صلاحية الوصول إلى الفرع. "}
        حساب الدخول يبقى محفوظاً ويمكن إعادة إسناده أو إعادة تعيين كلمة مروره في أي وقت.
      </p>
      <div className="actions">
        <button className="button primary" type="button" disabled={busy} onClick={() => void submitRemove()}>
          {busy ? "جارٍ الإزالة..." : "تأكيد إزالة الإسناد"}
        </button>
        <button className="button secondary" type="button" disabled={busy} onClick={() => setPanel("")}>إلغاء</button>
      </div>
    </div>}
  </li>;
}