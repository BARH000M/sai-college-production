import { useEffect, useMemo, useState } from "react";
import {
  loadTeacherOverview, provisionTeacherAccount, suggestPassword, suggestTeacherEmail,
  type CreatedTeacher, type TeacherOverview,
} from "@/portal/lib/learningAccounts";
import { TeacherAccountRow } from "@/portal/pages/roles/TeacherAccountRow";
import { TeacherAssignmentSheet } from "@/portal/pages/roles/TeacherAssignmentSheet";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

type TeacherSort = "name" | "backlog" | "class";

export function TeacherAccountPanel() {
  const [overview, setOverview] = useState<TeacherOverview>({ classes: [], teachers: [] });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  const [classId, setClassId] = useState("");
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [created, setCreated] = useState<CreatedTeacher | null>(null);
  const [copied, setCopied] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [sortBy, setSortBy] = useState<TeacherSort>("name");

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    void loadTeacherOverview()
      .then((data) => {
        if (!active) return;
        setOverview(data);
        const free = data.classes.find((row) => !row.teacherId);
        setClassId((current) => (current && !data.classes.some((row) => row.id === current) ? "" : current || free?.id || ""));
      })
      .catch((failure: unknown) => { if (active) setError(message(failure)); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [retry]);

  function resetForm() {
    setFullName("");
    setEmail("");
    setPassword("");
    setFormError(null);
  }

  function openForm(targetClassId: string) {
    resetForm();
    setClassId(targetClassId);
    setPassword(suggestPassword());
    setCopied(false);
  }

  async function submit() {
    if (busy) return;
    if (fullName.trim().length < 3) {
      setFormError("اكتب الاسم الكامل للمعلم (٣ أحرف على الأقل).");
      return;
    }
    if (!classId) {
      setFormError("اختر الصف الذي سيدرّسه المعلم.");
      return;
    }
    if (password.trim().length < 8) {
      setFormError("كلمة المرور يجب ألا تقل عن ٨ أحرف.");
      return;
    }
    setBusy(true);
    setFormError(null);
    try {
      const account = await provisionTeacherAccount({
        fullName: fullName.trim(),
        email: email.trim(),
        password: password.trim(),
        classId,
      });
      setCreated(account);
      resetForm();
      setRetry((value) => value + 1);
    } catch (failure) {
      setFormError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  async function copyCredentials() {
    if (!created) return;
    const payload = [
      "بوابة كلية ساي — حساب معلم",
      `الاسم: ${created.fullName}`,
      `الصف: ${created.className}`,
      `البريد: ${created.email}`,
      `كلمة المرور: ${created.password}`,
    ].join("\n");
    try {
      await navigator.clipboard.writeText(payload);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2500);
    } catch {
      setCopied(false);
    }
  }

  const freeClasses = overview.classes.filter((row) => !row.teacherId);
  const selectedClass = overview.classes.find((row) => row.id === classId) ?? null;

  const totalUngraded = overview.teachers.reduce((sum, row) => sum + row.workload.ungraded, 0);

  const visibleTeachers = useMemo(() => {
    const term = query.trim().toLowerCase();
    const matched = overview.teachers.filter((teacher) => {
      if (!term) return true;
      const haystack = [
        teacher.fullName,
        teacher.email,
        ...teacher.classNames,
        ...teacher.branchNames,
        ...teacher.courseTitles,
      ].join(" ").toLowerCase();
      return haystack.includes(term);
    });
    const sorted = matched.slice();
    if (sortBy === "backlog") {
      sorted.sort((a, b) => b.workload.ungraded - a.workload.ungraded
        || a.fullName.localeCompare(b.fullName, "ar"));
      return sorted;
    }
    if (sortBy === "class") {
      sorted.sort((a, b) => {
        const aKey = a.classNames.join(" · ");
        const bKey = b.classNames.join(" · ");
        if (!aKey !== !bKey) return aKey ? -1 : 1;
        return aKey.localeCompare(bKey, "ar") || a.fullName.localeCompare(b.fullName, "ar");
      });
      return sorted;
    }
    // Default order keeps assigned teachers first, then alphabetical.
    sorted.sort((a, b) => {
      if (!a.classNames.length !== !b.classNames.length) return a.classNames.length ? -1 : 1;
      return a.fullName.localeCompare(b.fullName, "ar");
    });
    return sorted;
  }, [overview.teachers, query, sortBy]);

  return <section className="panel">
    <div className="page-heading">
      <div>
        <h2>حسابات المعلمين</h2>
        <p className="data-note">
          أنشئ حساب دخول حقيقي لمعلم وأسنده إلى صف. يحصل الحساب على دور المعلم وعضوية الفرع تلقائياً،
          فيرى طلاب صفه وواجبات مقرراته ويصحح تسليماتهم من داخل البوابة.
        </p>
      </div>
      <div className="actions">
        <button className="button secondary" type="button" onClick={() => setSheetOpen(true)} disabled={loading || !overview.teachers.length}>
          كشف الإسناد للطباعة
        </button>
        <button className="button secondary" type="button" onClick={() => setRetry((value) => value + 1)} disabled={loading}>
          تحديث القائمة
        </button>
      </div>
    </div>

    {sheetOpen && <TeacherAssignmentSheet
      teachers={overview.teachers}
      classes={overview.classes}
      onClose={() => setSheetOpen(false)}
    />}

    {created && <div className="credential-box" role="status">
      <strong>أُنشئ حساب المعلم بنجاح</strong>
      <p className="data-note">{created.fullName} · الصف {created.className}</p>
      <dl>
        <div><dt>البريد الإلكتروني</dt><dd dir="ltr">{created.email}</dd></div>
        <div><dt>كلمة المرور</dt><dd dir="ltr">{created.password}</dd></div>
      </dl>
      <p className="data-note">انسخ البيانات الآن وسلّمها للمعلم؛ لن تُعرض كلمة المرور مرة أخرى.</p>
      <div className="actions">
        <button className="button primary" type="button" onClick={() => void copyCredentials()}>
          {copied ? "نُسخت البيانات" : "نسخ بيانات الدخول"}
        </button>
        <button className="button secondary" type="button" onClick={() => setCreated(null)}>إخفاء</button>
      </div>
    </div>}

    {loading && <p role="status">جارٍ تحميل الصفوف وحسابات المعلمين...</p>}
    {error && <p className="error-box" role="alert">
      {error}
      <button type="button" className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button>
    </p>}

    {!loading && !error && <p className="data-note">
      {overview.classes.length} صفاً · {freeClasses.length} بلا معلم مسند · {overview.teachers.length} حساب معلم
      {totalUngraded > 0 ? ` · ${totalUngraded} تسليماً بانتظار التصحيح` : ""}
    </p>}

    {!loading && !error && <div className="learn-account-form">
      <h3>إنشاء حساب معلم</h3>
      <p className="data-note">
        {selectedClass
          ? `سيُسند الحساب إلى ${selectedClass.name} (${selectedClass.branchName ?? "فرع غير محدد"}).`
          : "اختر صفاً ليُسند إليه المعلم الجديد."}
      </p>
      <div className="management-form">
        <label>الصف
          <select value={classId} onChange={(event) => setClassId(event.target.value)} disabled={busy}>
            <option value="">— اختر صفاً —</option>
            {overview.classes.map((row) => <option key={row.id} value={row.id} disabled={!!row.teacherId}>
              {row.name}{row.branchName ? ` — ${row.branchName}` : ""}{row.teacherId ? " (له معلم)" : ""}
            </option>)}
          </select>
        </label>
        <label>الاسم الكامل للمعلم
          <input
            value={fullName}
            disabled={busy}
            placeholder="مثال: أ. سامي الحداد"
            onChange={(event) => {
              const value = event.target.value;
              setFullName(value);
              if (!email.trim() && value.trim().length > 2) setEmail(suggestTeacherEmail(value));
            }}
          />
        </label>
        <label>البريد الإلكتروني
          <input dir="ltr" type="email" value={email} disabled={busy} onChange={(event) => setEmail(event.target.value)} />
        </label>
        <label>كلمة المرور المؤقتة
          <input dir="ltr" value={password} disabled={busy} onChange={(event) => setPassword(event.target.value)} />
        </label>
        <div className="actions">
          <button className="button primary" type="button" disabled={busy || !freeClasses.length} onClick={() => void submit()}>
            {busy ? "جارٍ إنشاء الحساب..." : "إنشاء الحساب وإسناد الصف"}
          </button>
          <button className="button secondary" type="button" disabled={busy} onClick={() => { resetForm(); setClassId(freeClasses[0]?.id ?? ""); }}>
            تفريغ النموذج
          </button>
        </div>
        {!freeClasses.length && overview.classes.length > 0 && <p className="notice">
          كل الصفوف لها معلم مسند. أزل إسناد أحد المعلمين من قائمة «حسابات المعلمين الحالية» أدناه
          ثم أعد المحاولة، أو انقل معلماً إلى صف آخر من نفس القائمة.
        </p>}
        {formError && <p className="error-box" role="alert">{formError}</p>}
      </div>
    </div>}

    {!loading && !error && !!overview.classes.length && <div className="table-scroll">
      <table className="management-table">
        <thead><tr>
          <th>الصف</th>
          <th>الفرع</th>
          <th>المعلم المسند</th>
          <th>الإجراء</th>
        </tr></thead>
        <tbody>
          {overview.classes.map((row) => <tr key={row.id}>
            <td>{row.name}</td>
            <td>{row.branchName ?? "—"}</td>
            <td>{row.teacherEmail
              ? <><span className="role-chip" dir="ltr">{row.teacherEmail}</span><small className="learn-meta">{row.teacherName}</small></>
              : <span className="muted">غير مسند</span>}</td>
            <td>
              {row.teacherId
                ? <span className="muted">مكتمل</span>
                : <button className="button primary" type="button" disabled={busy} onClick={() => openForm(row.id)}>حساب معلم</button>}
            </td>
          </tr>)}
        </tbody>
      </table>
    </div>}

    {!loading && !error && !overview.classes.length && <p className="muted">لا توجد صفوف مسجَّلة بعد.</p>}

    {!loading && !error && !!overview.teachers.length && <div className="teacher-account-list">
      <h3>حسابات المعلمين الحالية</h3>
      <p className="data-note">
        من هنا يمكنك إعادة تعيين كلمة مرور معلم بلا إنشاء حساب جديد، أو نقله إلى صف آخر، أو إزالة إسناده نهائياً.
        اضغط على عدّاد «بانتظار التصحيح» لفتح تصحيح تسليمات ذلك المعلم مباشرة.
      </p>

      <fieldset className="context-card teacher-list-controls">
        <label>البحث بالاسم أو الصف أو المقرر
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="مثال: سامي أو Grade 10"
          />
        </label>
        <label>الترتيب
          <select value={sortBy} onChange={(event) => setSortBy(event.target.value as TeacherSort)}>
            <option value="name">الاسم (أ–ي)</option>
            <option value="backlog">أكبر تراكم بانتظار التصحيح</option>
            <option value="class">الصف</option>
          </select>
        </label>
      </fieldset>

      <p className="data-note">
        {visibleTeachers.length} من {overview.teachers.length} معلماً
        {query.trim() ? ` مطابق لـ «${query.trim()}»` : ""}
      </p>

      {!visibleTeachers.length && <p className="muted">لا يوجد معلم مطابق للبحث. جرّب اسماً أو صفاً آخر.</p>}

      <ul>
        {visibleTeachers.map((teacher) => <TeacherAccountRow
          key={teacher.userId}
          teacher={teacher}
          classes={overview.classes}
          onChanged={() => setRetry((value) => value + 1)}
        />)}
      </ul>
    </div>}
  </section>;
}