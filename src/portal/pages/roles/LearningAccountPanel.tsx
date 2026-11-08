import { useEffect, useState } from "react";
import {
  loadProvisionOverview, provisionLearningAccount, suggestAccountEmail, suggestPassword,
  type CreatedAccount, type ProvisionKind, type ProvisionStudent,
} from "@/portal/lib/learningAccounts";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

type Target = { student: ProvisionStudent; kind: ProvisionKind };

export function LearningAccountPanel() {
  const [rows, setRows] = useState<ProvisionStudent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  const [target, setTarget] = useState<Target | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [parentName, setParentName] = useState("");
  const [busy, setBusy] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [bulkError, setBulkError] = useState<string | null>(null);
  const [created, setCreated] = useState<CreatedAccount[]>([]);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    void loadProvisionOverview()
      .then((data) => { if (active) setRows(data); })
      .catch((failure: unknown) => { if (active) setError(message(failure)); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [retry]);

  function openForm(student: ProvisionStudent, kind: ProvisionKind) {
    setTarget({ student, kind });
    setEmail(suggestAccountEmail(student.admissionNo, kind));
    setPassword(suggestPassword());
    setParentName(kind === "parent" ? `ولي أمر ${student.studentName}` : "");
    setFormError(null);
    setBulkError(null);
    setCopied(false);
  }

  function closeForm() {
    setTarget(null);
    setFormError(null);
  }

  async function submit() {
    if (!target || busy) return;
    if (!email.trim() || password.trim().length < 8) {
      setFormError("أدخل بريداً صحيحاً وكلمة مرور لا تقل عن ٨ أحرف.");
      return;
    }
    setBusy(true);
    setFormError(null);
    try {
      const account = await provisionLearningAccount({
        studentId: target.student.studentId,
        kind: target.kind,
        email: email.trim(),
        password: password.trim(),
        parentName: target.kind === "parent" ? parentName.trim() : undefined,
      });
      setCreated([account]);
      setTarget(null);
      setRetry((value) => value + 1);
    } catch (failure) {
      setFormError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  /**
   * Provisions the student account and then the parent account with generated
   * credentials. If the second call fails the first account still exists and its
   * credentials stay visible in the result panel.
   */
  async function createBoth(row: ProvisionStudent) {
    if (busy) return;
    if (row.studentAccount && row.parentAccount) return;
    setBusy(true);
    setBulkError(null);
    setFormError(null);
    setCopied(false);
    setCreated([]);
    const results: CreatedAccount[] = [];
    try {
      if (!row.studentAccount) {
        results.push(await provisionLearningAccount({
          studentId: row.studentId,
          kind: "student",
          email: suggestAccountEmail(row.admissionNo, "student"),
          password: suggestPassword(),
        }));
      }
      if (!row.parentAccount) {
        results.push(await provisionLearningAccount({
          studentId: row.studentId,
          kind: "parent",
          email: suggestAccountEmail(row.admissionNo, "parent"),
          password: suggestPassword(),
          parentName: `ولي أمر ${row.studentName}`,
        }));
      }
      setCreated(results);
    } catch (failure) {
      setBulkError(`${message(failure)}${results.length ? " — الحساب الأول أُنشئ بالفعل وتجد بياناته أدناه." : ""}`);
      setCreated(results);
    } finally {
      setBusy(false);
      setRetry((value) => value + 1);
    }
  }

  async function copyCredentials() {
    if (!created.length) return;
    const payload = [
      "بوابة كلية ساي — بيانات الدخول",
      ...created.map((account) => [
        "",
        `${account.role === "parent" ? "ولي أمر" : "طالب"}: ${account.fullName} (${account.studentName})`,
        `البريد: ${account.email}`,
        `كلمة المرور: ${account.password}`,
      ].join("\n")),
    ].join("\n");
    try {
      await navigator.clipboard.writeText(payload);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2500);
    } catch {
      setCopied(false);
    }
  }

  const withoutStudent = rows.filter((row) => !row.studentAccount).length;
  const withoutParent = rows.filter((row) => !row.parentAccount).length;

  return <section className="panel">
    <div className="page-heading">
      <div>
        <h2>حسابات بوابة التعلّم</h2>
        <p className="data-note">
          أنشئ حساب دخول حقيقي لطالب مسجَّل أو لولي أمره. يُربط الحساب بالسجل مباشرة وتُمنحه الدور المناسب،
          فيرى صاحبه المقررات والواجبات والتقدم فور تسجيل الدخول.
        </p>
      </div>
      <button className="button secondary" type="button" onClick={() => setRetry((value) => value + 1)} disabled={loading}>
        تحديث القائمة
      </button>
    </div>

    {!!created.length && <div className="credential-box" role="status">
      <strong>{created.length > 1 ? "أُنشئ الحسابان بنجاح" : "أُنشئ الحساب بنجاح"}</strong>
      {created.map((account) => <div key={account.userId}>
        <p className="data-note">
          {account.role === "parent" ? "ولي أمر" : "طالب"} — {account.fullName} · سجل {account.studentName}
        </p>
        <dl>
          <div><dt>البريد الإلكتروني</dt><dd dir="ltr">{account.email}</dd></div>
          <div><dt>كلمة المرور</dt><dd dir="ltr">{account.password}</dd></div>
        </dl>
      </div>)}
      <p className="data-note">انسخ البيانات الآن وسلّمها لصاحب الحساب؛ لن تُعرض كلمة المرور مرة أخرى.</p>
      <div className="actions">
        <button className="button primary" type="button" onClick={() => void copyCredentials()}>
          {copied ? "نُسخت البيانات" : "نسخ بيانات الدخول"}
        </button>
        <button className="button secondary" type="button" onClick={() => setCreated([])}>إخفاء</button>
      </div>
    </div>}

    {bulkError && <p className="error-box" role="alert">تعذر إنشاء أحد الحسابين: {bulkError}</p>}

    {loading && <p role="status">جارٍ تحميل سجلات الطلاب...</p>}
    {error && <p className="error-box" role="alert">
      {error}
      <button type="button" className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button>
    </p>}

    {!loading && !error && <p className="data-note">
      {rows.length} طالباً · {withoutStudent} بلا حساب طالب · {withoutParent} بلا حساب ولي أمر
    </p>}

    {target && <div className="learn-account-form">
      <h3>
        {target.kind === "parent" ? "حساب ولي أمر" : "حساب طالب"} — {target.student.studentName}
      </h3>
      <p className="data-note">
        {target.kind === "parent"
          ? "سيُربط الحساب بهذا الطالب بعد اعتماد الصلة، ويستطيع ولي الأمر مشاهدة المقررات والواجبات والتقدم للقراءة فقط."
          : "سيُربط حساب الدخول بسجل الطالب، فيرى مقرراته وواجباته وتقدمه."}
      </p>
      <div className="management-form">
        {target.kind === "parent" && <label>اسم ولي الأمر
          <input value={parentName} onChange={(event) => setParentName(event.target.value)} placeholder="الاسم الكامل" />
        </label>}
        <label>البريد الإلكتروني
          <input dir="ltr" type="email" value={email} onChange={(event) => setEmail(event.target.value)} />
        </label>
        <label>كلمة المرور المؤقتة
          <input dir="ltr" value={password} onChange={(event) => setPassword(event.target.value)} />
        </label>
        <div className="actions">
          <button className="button primary" type="button" disabled={busy} onClick={() => void submit()}>
            {busy ? "جارٍ إنشاء الحساب..." : "إنشاء الحساب وربطه"}
          </button>
          <button className="button secondary" type="button" disabled={busy} onClick={closeForm}>إلغاء</button>
        </div>
        {formError && <p className="error-box" role="alert">{formError}</p>}
      </div>
    </div>}

    {!loading && !error && !!rows.length && <div className="table-scroll">
      <table className="management-table">
        <thead><tr>
          <th>الطالب</th>
          <th>الصف</th>
          <th>حساب الطالب</th>
          <th>حساب ولي الأمر</th>
          <th>الإجراء</th>
        </tr></thead>
        <tbody>
          {rows.map((row) => <tr key={row.studentId}>
            <td>{row.studentName}<small className="learn-meta">{row.admissionNo}</small></td>
            <td>{row.className ?? "—"}</td>
            <td>{row.studentAccount
              ? <span className="role-chip" dir="ltr">{row.studentAccount.email || "مرتبط"}</span>
              : <span className="muted">غير مرتبط</span>}</td>
            <td>{row.parentAccount
              ? <span className="role-chip" dir="ltr">{row.parentAccount.email || "مرتبط"}</span>
              : <span className="muted">غير مرتبط</span>}</td>
            <td><div className="role-actions">
              {!row.studentAccount && <button className="button primary" type="button" disabled={busy} onClick={() => openForm(row, "student")}>حساب طالب</button>}
              {!row.parentAccount && <button className="button secondary" type="button" disabled={busy} onClick={() => openForm(row, "parent")}>حساب ولي أمر</button>}
              {!row.studentAccount && !row.parentAccount && <button className="button secondary" type="button" disabled={busy} onClick={() => void createBoth(row)}>
                {busy ? "جارٍ الإنشاء..." : "إنشاء الحسابين معاً"}
              </button>}
              {row.studentAccount && row.parentAccount && <span className="muted">مكتمل</span>}
            </div></td>
          </tr>)}
        </tbody>
      </table>
    </div>}

    {!loading && !error && !rows.length && <p className="muted">لا توجد سجلات طلاب بعد.</p>}
  </section>;
}