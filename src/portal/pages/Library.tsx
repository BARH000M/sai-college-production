import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";
import {
  createLibraryItem, emptyLibraryDraft, issueLoan, libraryPermissions, loadLibraryItems,
  loadLibraryStudents, loadLoans, loadStudentLoanHistory, returnLoan, validateLibraryDraft,
  type LibraryDraft, type LibraryItem, type LibraryLoan, type LibraryStudent,
} from "../lib/library";
import { loadReportBranches, type ReportOption } from "../lib/reports";
import { formatDate } from "../lib/learning";
import { LoanSlip } from "./library/LoanSlip";
import { OverdueSheet } from "./library/OverdueSheet";
import { StudentHistorySheet } from "./library/StudentHistorySheet";

type Tab = "catalogue" | "loans";
type LoanScope = "open" | "returned" | "all";

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

function defaultDue(): string {
  const due = new Date();
  due.setDate(due.getDate() + 14);
  return due.toISOString().slice(0, 10);
}

export function Library({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const permissions = libraryPermissions(roles);
  const canManage = permissions.canManage;

  const [branches, setBranches] = useState<ReportOption[]>([]);
  const [branch, setBranch] = useState("");
  const [tab, setTab] = useState<Tab>("catalogue");
  const [scope, setScope] = useState<LoanScope>("open");
  const [search, setSearch] = useState("");

  const [items, setItems] = useState<LibraryItem[]>([]);
  const [loans, setLoans] = useState<LibraryLoan[]>([]);
  const [openLoansAll, setOpenLoansAll] = useState<LibraryLoan[]>([]);
  const [students, setStudents] = useState<LibraryStudent[]>([]);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [version, setVersion] = useState(0);

  const [draft, setDraft] = useState<LibraryDraft>(emptyLibraryDraft);
  const [showForm, setShowForm] = useState(false);

  const [issueItem, setIssueItem] = useState<LibraryItem | null>(null);
  const [issueStudent, setIssueStudent] = useState("");
  const [issueDue, setIssueDue] = useState(defaultDue);

  const [slip, setSlip] = useState<LibraryLoan | null>(null);
  const [overdueSheet, setOverdueSheet] = useState(false);
  const [history, setHistory] = useState<{ name: string; admissionNo: string; loans: LibraryLoan[] } | null>(null);
  const [historyBusy, setHistoryBusy] = useState(false);

  useEffect(() => {
    let active = true;
    void loadReportBranches()
      .then((rows) => {
        if (!active) return;
        setBranches(rows);
        setBranch((current) => current || rows[0]?.id || "");
      })
      .catch((failure: unknown) => {
        if (active) setError(`تعذر تحميل الفروع: ${message(failure)}`);
      });
    return () => { active = false; };
  }, []);

  useEffect(() => {
    if (!branch) { setItems([]); return; }
    let active = true;
    setLoading(true);
    setError(null);
    void loadLibraryItems(branch)
      .then((rows) => { if (active) setItems(rows); })
      .catch((failure: unknown) => { if (active) setItems([]); setError(`تعذر تحميل الفهرس: ${message(failure)}`); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [branch, version]);

  useEffect(() => {
    if (!branch) { setLoans([]); setOpenLoansAll([]); return; }
    let active = true;
    void Promise.all([
      loadLoans(branch, scope),
      loadLoans(branch, "open"),
      canManage ? loadLibraryStudents(branch) : Promise.resolve([]),
    ])
      .then(([loanRows, openRows, studentRows]) => {
        if (!active) return;
        setLoans(loanRows);
        setOpenLoansAll(openRows);
        setStudents(studentRows);
      })
      .catch((failure: unknown) => { if (active) setError(`تعذر تحميل الإعارات: ${message(failure)}`); });
    return () => { active = false; };
  }, [branch, scope, canManage, version]);

  const filteredItems = useMemo(() => {
    const term = search.trim();
    if (!term) return items;
    return items.filter((item) =>
      [item.title, item.author, item.category, item.isbn, item.shelf_code]
        .some((value) => (value ?? "").toLowerCase().includes(term.toLowerCase())),
    );
  }, [items, search]);

  const openLoans = openLoansAll;
  const overdue = useMemo(
    () => openLoans.filter((loan) => loan.due_date < today()),
    [openLoans],
  );
  const totalCopies = items.reduce((sum, item) => sum + item.copies_total, 0);
  const availableCopies = items.reduce((sum, item) => sum + item.copies_available, 0);

  const run = useCallback(async (action: () => Promise<void>, done: string) => {
    setBusy(true);
    setError(null);
    setSuccess(null);
    try {
      await action();
      setSuccess(done);
      setVersion((value) => value + 1);
      return true;
    } catch (failure) {
      setError(message(failure));
      return false;
    } finally {
      setBusy(false);
    }
  }, []);

  async function openHistory(loan: LibraryLoan) {
    setHistoryBusy(true);
    setError(null);
    try {
      const rows = await loadStudentLoanHistory(loan.student_id);
      setHistory({ name: loan.studentName, admissionNo: loan.admissionNo, loans: rows });
    } catch (failure) {
      setError(message(failure));
    } finally {
      setHistoryBusy(false);
    }
  }

  function submitItem(event: FormEvent) {
    event.preventDefault();
    const invalid = validateLibraryDraft(draft);
    if (invalid) { setError(invalid); return; }
    void run(async () => {
      await createLibraryItem(branch, draft, userId);
      setDraft(emptyLibraryDraft());
      setShowForm(false);
    }, "أُضيف الكتاب إلى الفهرس.");
  }

  function submitIssue(event: FormEvent) {
    event.preventDefault();
    if (!issueItem) return;
    if (!issueStudent) { setError("اختر الطالب المستعير."); return; }
    const item = issueItem;
    void run(async () => {
      await issueLoan(item.id, issueStudent, issueDue);
      setIssueItem(null);
      setIssueStudent("");
      setIssueDue(defaultDue());
    }, `أُعير الكتاب «${item.title}».`);
  }

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">كلية ساي · المكتبة</p>
        <h1>المكتبة والاستعارة</h1>
        <p className="muted">فهرس الكتب، الإعارة والإرجاع، وإيصالات مطبوعة — كل الأرقام من السجلات الفعلية.</p>
      </div>
      {canManage && <button className="button primary" type="button" onClick={() => { setShowForm((value) => !value); setError(null); }}>
        <i className={showForm ? "ri-close-line" : "ri-add-line"} aria-hidden="true"></i> {showForm ? "إغلاق النموذج" : "كتاب جديد"}
      </button>}
    </div>

    <fieldset className="context-card">
      <legend className="sr-only">نطاق المكتبة</legend>
      <label>الفرع
        <select value={branch} onChange={(event) => { setBranch(event.target.value); setIssueItem(null); }} disabled={branches.length <= 1}>
          <option value="">اختر الفرع</option>
          {branches.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
        </select>
      </label>
      <label>البحث في الفهرس
        <input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="العنوان، المؤلف، التصنيف أو ISBN" />
      </label>
    </fieldset>

    {error && <p className="error-box" role="alert">{error}</p>}
    {success && <p className="success-box" role="status">{success}</p>}
    {loading && <p role="status">جارٍ تحميل فهرس المكتبة...</p>}

    {!loading && !error && <div className="kpi-grid">
      <div className="kpi-card"><span>عناوين في الفهرس</span><strong>{items.length}</strong><small>كتب نشطة في هذا الفرع</small></div>
      <div className="kpi-card"><span>نسخ متاحة الآن</span><strong>{availableCopies}</strong><small>من أصل {totalCopies} نسخة</small></div>
      <div className="kpi-card"><span>إعارات مفتوحة</span><strong>{openLoans.length}</strong><small>لم تُرجع بعد</small></div>
      <div className="kpi-card"><span>إعارات متأخرة</span><strong>{overdue.length}</strong><small>{overdue.length ? "تحتاج متابعة" : "لا تأخير"}</small></div>
    </div>}

    <div className="lab-toolbar">
      <div className="lab-tabs" role="tablist" aria-label="أقسام المكتبة">
        <button className={`lab-tab${tab === "catalogue" ? " active" : ""}`} type="button" role="tab" aria-selected={tab === "catalogue"} onClick={() => setTab("catalogue")}>
          <i className="ri-book-shelf-line" aria-hidden="true"></i> الفهرس ({filteredItems.length})
        </button>
        <button className={`lab-tab${tab === "loans" ? " active" : ""}`} type="button" role="tab" aria-selected={tab === "loans"} onClick={() => setTab("loans")}>
          <i className="ri-exchange-line" aria-hidden="true"></i> الإعارة والإرجاع ({loans.length})
        </button>
      </div>
      {tab === "loans" && <div className="lab-toolbar-end">
        <button className="button secondary quick-action" type="button" disabled={!overdue.length}
          onClick={() => setOverdueSheet(true)}>
          <i className="ri-printer-line" aria-hidden="true"></i> طباعة المتأخرات ({overdue.length})
        </button>
        <select aria-label="تصفية الإعارات" value={scope} onChange={(event) => setScope(event.target.value as LoanScope)}>
          <option value="open">الإعارات المفتوحة</option>
          <option value="returned">الإعارات المُعادة</option>
          <option value="all">الكل</option>
        </select>
      </div>}
    </div>

    {canManage && showForm && <section className="panel">
      <h2>إضافة كتاب إلى الفهرس</h2>
      <p className="data-note">عدد النسخ يُحدد عدد النسخ القابلة للإعارة. لا يمكن إضافة كتاب لفرع آخر.</p>
      <form className="management-form" onSubmit={submitItem}>
        <label>عنوان الكتاب<span className="vocab-required"> *</span>
          <input required value={draft.title} onChange={(event) => setDraft({ ...draft, title: event.target.value })} />
        </label>
        <label>المؤلف
          <input value={draft.author} onChange={(event) => setDraft({ ...draft, author: event.target.value })} />
        </label>
        <label>التصنيف
          <input value={draft.category} onChange={(event) => setDraft({ ...draft, category: event.target.value })} placeholder="لغة، أدب، مرجع..." />
        </label>
        <label>ISBN
          <input value={draft.isbn} onChange={(event) => setDraft({ ...draft, isbn: event.target.value })} dir="ltr" />
        </label>
        <label>رمز الرف
          <input value={draft.shelf_code} onChange={(event) => setDraft({ ...draft, shelf_code: event.target.value })} />
        </label>
        <label>عدد النسخ<span className="vocab-required"> *</span>
          <input required inputMode="numeric" value={draft.copies_total} onChange={(event) => setDraft({ ...draft, copies_total: event.target.value })} />
        </label>
        <div className="actions">
          <button className="button primary" disabled={busy}>{busy ? "جارٍ الحفظ..." : "حفظ الكتاب"}</button>
          <button className="button secondary" type="button" disabled={busy} onClick={() => setDraft(emptyLibraryDraft())}>مسح الحقول</button>
        </div>
      </form>
    </section>}

    {issueItem && canManage && <section className="panel">
      <div className="home-panel-head">
        <div>
          <h2>إعارة «{issueItem.title}»</h2>
          <p className="data-note">المتاح الآن: {issueItem.copies_available} من {issueItem.copies_total} نسخة.</p>
        </div>
        <button className="text-button" type="button" onClick={() => setIssueItem(null)}>إلغاء</button>
      </div>
      <form className="management-form" onSubmit={submitIssue}>
        <label>الطالب المستعير<span className="vocab-required"> *</span>
          <select required value={issueStudent} onChange={(event) => setIssueStudent(event.target.value)}>
            <option value="">{students.length ? "اختر الطالب" : "لا يوجد طلاب نشطون في الفرع"}</option>
            {students.map((student) => <option key={student.id} value={student.id}>{student.full_name} · {student.admission_no}</option>)}
          </select>
        </label>
        <label>تاريخ الإرجاع المستحق<span className="vocab-required"> *</span>
          <input required type="date" min={today()} value={issueDue} onChange={(event) => setIssueDue(event.target.value)} />
        </label>
        <div className="actions">
          <button className="button primary" disabled={busy || !issueItem.copies_available}>
            {busy ? "جارٍ الإعارة..." : "تأكيد الإعارة"}
          </button>
        </div>
        {!issueItem.copies_available && <p className="error-box">لا توجد نسخ متاحة من هذا الكتاب.</p>}
      </form>
    </section>}

    {tab === "catalogue" && <section className="panel">
      <div className="home-panel-head">
        <div>
          <h2>فهرس الكتب</h2>
          <p className="data-note">تظهر الكتب النشطة فقط. الإعارة تحجز نسخة واحدة في كل مرة.</p>
        </div>
        <span className="lab-pill-count">{filteredItems.length} عنوان</span>
      </div>

      {!loading && !filteredItems.length
        ? <div className="notify-empty">
          <span className="notify-empty-icon"><i className="ri-book-open-line" aria-hidden="true"></i></span>
          <strong>{items.length ? "لا نتائج مطابقة للبحث" : "لا توجد كتب في هذا الفرع بعد"}</strong>
          <p className="muted">{items.length ? "جرّب كلمة أخرى أو امسح البحث." : canManage ? "أضف أول كتاب من زر «كتاب جديد»." : "سيظهر الفهرس بعد إضافة الكتب."}</p>
        </div>
        : <div className="table-scroll">
          <table className="management-table">
            <thead>
              <tr><th>الكتاب</th><th>التصنيف</th><th>الرف</th><th>المتاح</th><th>الإعارة</th></tr>
            </thead>
            <tbody>
              {filteredItems.map((item) => <tr key={item.id}>
                <td>
                  <strong>{item.title}</strong>
                  <span className="learn-meta">{item.author ?? "مؤلف غير محدد"}</span>
                </td>
                <td>{item.category ?? "—"}<span className="learn-meta" dir="ltr">{item.isbn ?? ""}</span></td>
                <td>{item.shelf_code ?? "—"}</td>
                <td>
                  <div className="occupancy">
                    <span className="learn-bar">
                      <span
                        className={`occupancy-fill ${item.copies_available === 0 ? "full" : item.copies_available <= Math.max(1, Math.floor(item.copies_total * 0.25)) ? "warn" : "ok"}`}
                        style={{ width: `${Math.round((item.copies_available / item.copies_total) * 100)}%` }}
                      />
                    </span>
                    <small>{item.copies_available} من {item.copies_total}</small>
                  </div>
                </td>
                <td>
                  {canManage
                    ? <button className="button secondary quick-action" type="button" disabled={busy || item.copies_available === 0} onClick={() => { setIssueItem(item); setError(null); setSuccess(null); }}>
                      <i className="ri-bookmark-line" aria-hidden="true"></i> {item.copies_available === 0 ? "غير متاح" : "إعارة"}
                    </button>
                    : <span className="learn-pill">{item.copies_available ? "متاح" : "غير متاح"}</span>}
                </td>
              </tr>)}
            </tbody>
          </table>
        </div>}
    </section>}

    {tab === "loans" && <section className="panel">
      <div className="home-panel-head">
        <div>
          <h2>سجل الإعارة</h2>
          <p className="data-note">الإعارات المفتوحة تظهر أولاً. الإيصال قابل للطباعة من كل سطر.</p>
        </div>
        <span className="lab-pill-count">{loans.length} سجل</span>
      </div>

      {!loans.length
        ? <div className="notify-empty">
          <span className="notify-empty-icon"><i className="ri-exchange-line" aria-hidden="true"></i></span>
          <strong>لا توجد إعارات في هذا النطاق</strong>
          <p className="muted">ابدأ الإعارة من تبويب الفهرس.</p>
        </div>
        : <div className="table-scroll">
          <table className="management-table">
            <thead>
              <tr><th>الطالب</th><th>الكتاب</th><th>الإعارة</th><th>الاستحقاق</th><th>الحالة</th><th>الإجراءات</th></tr>
            </thead>
            <tbody>
              {loans.map((loan) => {
                const late = !loan.returned_at && loan.due_date < today();
                return <tr key={loan.id}>
                  <td>{loan.studentName}<span className="learn-meta">{loan.admissionNo}</span></td>
                  <td>{loan.itemTitle}</td>
                  <td>{formatDate(loan.issued_at)}</td>
                  <td>{formatDate(loan.due_date)}</td>
                  <td>
                    <span className={`lab-status ${loan.returned_at ? "status-ok" : late ? "status-danger" : "status-warn"}`}>
                      {loan.returned_at ? "أُعيد" : late ? "متأخر" : "قيد الإعارة"}
                    </span>
                  </td>
                  <td>
                    <div className="homework-admin">
                      <button className="button secondary quick-action" type="button" onClick={() => setSlip(loan)}>
                        <i className="ri-printer-line" aria-hidden="true"></i> إيصال
                      </button>
                      <button className="button secondary quick-action" type="button" disabled={historyBusy}
                        onClick={() => void openHistory(loan)}>
                        <i className="ri-file-list-3-line" aria-hidden="true"></i> سجل الطالب
                      </button>
                      {canManage && !loan.returned_at && <button className="button primary quick-action" type="button" disabled={busy}
                        onClick={() => void run(() => returnLoan(loan.id), `أُعيد الكتاب «${loan.itemTitle}».`)}>
                        <i className="ri-arrow-go-back-line" aria-hidden="true"></i> إرجاع
                      </button>}
                    </div>
                  </td>
                </tr>
              })}
            </tbody>
          </table>
        </div>}
    </section>}

    {slip && <LoanSlip loan={slip} onClose={() => setSlip(null)} />}
    {overdueSheet && <OverdueSheet
      branchName={branches.find((row) => row.id === branch)?.name ?? ""}
      loans={overdue}
      onClose={() => setOverdueSheet(false)}
    />}
    {history && <StudentHistorySheet
      studentName={history.name}
      admissionNo={history.admissionNo}
      branchName={branches.find((row) => row.id === branch)?.name ?? ""}
      loans={history.loans}
      onClose={() => setHistory(null)}
    />}
  </main>;
}