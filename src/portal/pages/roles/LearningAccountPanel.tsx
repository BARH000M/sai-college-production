import { useEffect, useState } from "react";
import {
  loadProvisionOverview, provisionLearningAccount, suggestAccountEmail,
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
  const [parentName, setParentName] = useState("");
  const [busy, setBusy] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [bulkError, setBulkError] = useState<string | null>(null);
  const [created, setCreated] = useState<CreatedAccount[]>([]);

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
    setParentName(kind === "parent" ? `ولي أمر ${student.studentName}` : "");
    setFormError(null);
    setBulkError(null);
  }

  function closeForm() {
    setTarget(null);
    setFormError(null);
  }

  async function submit() {
    if (!target || busy) return;
    if (!email.trim()) {
      setFormError("أدخل البريد الإلكتروني لإرسال دعوة الحساب.");
      return;
    }
    setBusy(true);
    setFormError(null);
    try {
      const account = await provisionLearningAccount({
        studentId: target.student.studentId,
        kind: target.kind,
        email: email.trim(),
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

  /** Sends invitations without linking either account until its owner confirms it. */
  async function createBoth(row: ProvisionStudent) {
    if (busy) return;
    if (row.studentAccount && row.parentAccount) return;
    setBusy(true);
    setBulkError(null);
    setFormError(null);
    setCreated([]);
    const results: CreatedAccount[] = [];
    try {
      if (!row.studentAccount) {
        results.push(await provisionLearningAccount({
          studentId: row.studentId,
          kind: "student",
          email: suggestAccountEmail(row.admissionNo, "student"),
        }));
      }
      if (!row.parentAccount) {
        results.push(await provisionLearningAccount({
          studentId: row.studentId,
          kind: "parent",
          email: suggestAccountEmail(row.admissionNo, "parent"),
          parentName: `ولي أمر ${row.studentName}`,
        }));
      }
      setCreated(results);
    } catch (failure) {
      setBulkError(`${message(failure)}${results.length ? " — أُرسلت الدعوة الأولى ويمكنك مراجعة حالتها أدناه." : ""}`);
      setCreated(results);
    } finally {
      setBusy(false);
      setRetry((value) => value + 1);
    }
  }

  const withoutStudent = rows.filter((row) => !row.studentAccount).length;
  const withoutParent = rows.filter((row) => !row.parentAccount).length;

  return <section className="panel">
    <div className="page-heading">
      <div>
        <h2>حسابات بوابة التعلّم</h2>
        <p className="data-note">
          أرسل دعوة إلى بريد الطالب أو ولي أمره. لا يرتبط الحساب بأي سجل ولا يستطيع الدخول حتى يؤكد صاحبه بريده؛
          بعد ذلك يربط الموظف الحساب ويتحقق من علاقة ولي الأمر بشكل منفصل.
        </p>
      </div>
      <button className="button secondary" type="button" onClick={() => setRetry((value) => value + 1)} disabled={loading}>
        تحديث القائمة
      </button>
    </div>

    {!!created.length && <div className="credential-box" role="status">
      <strong>{created.length > 1 ? "أُرسلت الدعوتان بنجاح" : "أُرسلت الدعوة بنجاح"}</strong>
      {created.map((account) => <div key={`${account.role}:${account.email}`}>
        <p className="data-note">
          {account.role === "parent" ? "ولي أمر" : "طالب"} — {account.fullName} · سجل {account.studentName}
        </p>
        <p className="data-note">رابط التحقق أُرسل إلى <span dir="ltr">{account.email}</span>.</p>
      </div>)}
      <p className="data-note">لن يُربط الحساب بالسجل حتى يؤكد صاحبه البريد. بعد التأكيد، استخدم صفحة تفاصيل الطالب لربط الحساب والتحقق من علاقة ولي الأمر.</p>
      <div className="actions">
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
        ? "ستُرسل دعوة تحقق إلى البريد. بعد تأكيدها، يجب على موظف مخوّل التحقق من صلة ولي الأمر بالطالب قبل الربط."
        : "ستُرسل دعوة تحقق إلى البريد. بعد تأكيدها، يربط الموظف الحساب الموجود بسجل الطالب."}
      </p>
      <div className="management-form">
        {target.kind === "parent" && <label>اسم ولي الأمر
          <input value={parentName} onChange={(event) => setParentName(event.target.value)} placeholder="الاسم الكامل" />
        </label>}
        <label>البريد الإلكتروني
          <input dir="ltr" type="email" value={email} onChange={(event) => setEmail(event.target.value)} />
        </label>
        <div className="actions">
          <button className="button primary" type="button" disabled={busy} onClick={() => void submit()}>
            {busy ? "جارٍ إرسال الدعوة..." : "إرسال دعوة التحقق"}
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