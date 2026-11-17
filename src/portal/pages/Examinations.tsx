import { useEffect, useState } from "react";
import { loadManagementBranches, loadManagementOptions, type Option } from "../lib/management";
import {
  canManageExams, canReviewExams, canTransition, examPageSize, examStatuses, gradeForScore, gradeLabels,
  loadExamClasses, loadExamCourses, loadExamRoster, loadExamSessionWindows, loadExams, loadFamilyResults,
  createExam, saveMark, saveMarksBatch, transitionExam, validateExamDraft, validateMark, loadStudentNames,
  rosterToReportRows,
  type Exam, type ExamClass, type ExamDraft, type ExamFilters, type ExamRosterEntry, type ExamSessionWindow,
  type ExamStatus, type FamilyResult,
} from "../lib/examinations";
import { ExamReportSheet } from "./examinations/ExamReportSheet";
import { FamilyResultSheet } from "./examinations/FamilyResultSheet";

const initialFilters: ExamFilters = { branch: "", session: "", classId: "", status: "", page: 0 };
const initialDraft: ExamDraft = {
  classId: "", courseId: "", subject: "", title: "", date: "",
  startTime: "", endTime: "", room: "", maxScore: "100",
};
const errorText = (error: unknown) => error instanceof Error ? error.message : String(error);

const transitionActions: Partial<Record<ExamStatus, { next: ExamStatus; label: string; reviewer: boolean }[]>> = {
  draft: [
    { next: "marks_entry", label: "فتح رصد الدرجات", reviewer: false },
    { next: "cancelled", label: "إلغاء الاختبار", reviewer: false },
  ],
  marks_entry: [
    { next: "review", label: "إرسال للمراجعة", reviewer: true },
    { next: "cancelled", label: "إلغاء الاختبار", reviewer: false },
  ],
  review: [
    { next: "marks_entry", label: "إعادة لرصد الدرجات", reviewer: true },
    { next: "published", label: "نشر النتائج", reviewer: true },
  ],
  published: [
    { next: "review", label: "إلغاء النشر", reviewer: true },
  ],
};

export function Examinations({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const staff = roles.some((role) => ["super_admin", "admin", "teacher"].includes(role));
  const family = roles.some((role) => ["student", "parent"].includes(role));
  const allowed = staff || family;
  const reviewer = canReviewExams(roles);
  const teacherOnly = roles.includes("teacher") && !reviewer;

  const [classes, setClasses] = useState<ExamClass[]>([]);
  const [branches, setBranches] = useState<Option[]>([]);
  const [sessions, setSessions] = useState<Option[]>([]);
  const [windows, setWindows] = useState<ExamSessionWindow[]>([]);
  const [scope, setScope] = useState<string[]>([]);
  const [filters, setFilters] = useState<ExamFilters>(initialFilters);
  const [rows, setRows] = useState<Exam[]>([]);
  const [count, setCount] = useState(0);
  const [selected, setSelected] = useState<Exam | null>(null);
  const [roster, setRoster] = useState<ExamRosterEntry[]>([]);
  const [drafts, setDrafts] = useState<Record<string, { score: string; note: string }>>({});
  const [draft, setDraft] = useState<ExamDraft>(initialDraft);
  const [courses, setCourses] = useState<{ id: string; title: string }[]>([]);
  const [familyResults, setFamilyResults] = useState<FamilyResult[]>([]);
  const [studentNames, setStudentNames] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [printing, setPrinting] = useState(false);
  const [printingResult, setPrintingResult] = useState<FamilyResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [detailError, setDetailError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  const selectedClass = classes.find((item) => item.id === selected?.class_id);
  const chosenClass = classes.find((item) => item.id === draft.classId);
  const manager = !!selectedClass && canManageExams(roles, userId, scope, selectedClass);
  const canCreate = !!chosenClass && canManageExams(roles, userId, scope, chosenClass);
  const chosenWindow = windows.find((item) => item.id === chosenClass?.academic_session_id);

  useEffect(() => {
    if (!allowed) { setLoading(false); return; }
    let active = true;
    setLoading(true); setError(null);
    if (!staff) {
      loadFamilyResults().then(async (results) => {
        if (!active) return;
        setFamilyResults(results);
        const ids = Array.from(new Set(results.map((row) => row.student_id)));
        if (ids.length) setStudentNames(await loadStudentNames(ids));
      }).catch((failure: unknown) => { if (active) { setFamilyResults([]); setError(errorText(failure)); } })
        .finally(() => { if (active) setLoading(false); });
      return () => { active = false; };
    }
    const assigned = loadExamClasses().then((rows) =>
      teacherOnly ? rows.filter((row) => row.teacher_id === userId) : rows);
    Promise.all([
      assigned,
      loadManagementOptions("", ""),
      !roles.includes("super_admin") && userId ? loadManagementBranches(userId) : Promise.resolve([]),
      loadExamSessionWindows(),
      assigned.then((rows) => loadExams(filters, teacherOnly ? rows.map((row) => row.id) : undefined)),
    ]).then(([classRows, options, memberships, sessionWindows, result]) => {
      if (!active) return;
      setClasses(classRows); setBranches(options.branches); setSessions(options.sessions);
      setScope(memberships); setWindows(sessionWindows);
      setRows(result.rows); setCount(result.count);
    }).catch((failure: unknown) => { if (active) { setRows([]); setError(errorText(failure)); } })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [allowed, staff, userId, roles, filters, retry, teacherOnly]);

  useEffect(() => {
    if (!selected || !manager) { setRoster([]); return; }
    let active = true;
    setDetailLoading(true); setDetailError(null);
    loadExamRoster(selected.id).then((value) => {
      if (!active) return;
      setRoster(value);
      setDrafts((current) => Object.fromEntries(value.map((row) => [row.student_id,
        current[row.student_id] ?? { score: row.score === null ? "" : String(row.score), note: row.note ?? "" }])));
    }).catch((failure: unknown) => { if (active) { setRoster([]); setDetailError(errorText(failure)); } })
      .finally(() => { if (active) setDetailLoading(false); });
    return () => { active = false; };
  }, [selected, manager, retry]);

  useEffect(() => {
    if (!draft.classId) { setCourses([]); return; }
    let active = true;
    loadExamCourses(draft.classId)
      .then((value) => { if (active) setCourses(value); })
      .catch(() => { if (active) setCourses([]); });
    return () => { active = false; };
  }, [draft.classId]);

  function filter(key: keyof ExamFilters, value: string) {
    setSelected(null); setDrafts({}); setMessage(null);
    setFilters((current) => ({ ...current, [key]: value, page: 0,
      ...(key === "branch" ? { session: "", classId: "" } : key === "session" ? { classId: "" } : {}) }));
  }
  async function mutate(action: () => Promise<void>, success: string, keepSelected = false) {
    if (saving) return;
    setSaving(true); setDetailError(null); setError(null); setMessage(null);
    try { await action(); setMessage(success); if (!keepSelected) { setSelected(null); setDrafts({}); } setRetry((value) => value + 1); }
    catch (failure) { setDetailError(errorText(failure)); }
    finally { setSaving(false); }
  }

  const branchName = (id: string) => branches.find((item) => item.id === id)?.name ?? id;
  const sessionName = (id: string) => windows.find((item) => item.id === id)?.name
    ?? sessions.find((item) => item.id === id)?.name ?? id;
  const className = (id: string) => classes.find((item) => item.id === id)?.name ?? id;
  const courseTitle = (id: string | null) => courses.find((item) => item.id === id)?.title ?? null;
  const availableClasses = classes.filter((item) => (!filters.branch || item.branch_id === filters.branch)
    && (!filters.session || item.academic_session_id === filters.session));
  const branchIds = [...new Set(classes.map((item) => item.branch_id))];
  const sessionIds = [...new Set(classes.filter((item) => !filters.branch || item.branch_id === filters.branch)
    .map((item) => item.academic_session_id))];

  const editable = !!selected && selected.status === "marks_entry" && manager;
  const pendingDrafts = editable
    ? roster.filter((row) => {
        const entry = drafts[row.student_id];
        if (!entry) return false;
        const savedScore = row.score === null ? "" : String(row.score);
        return (entry.score.trim() !== savedScore || entry.note !== (row.note ?? ""))
          && !validateMark(entry.score, selected.max_score);
      })
    : [];

  function saveAllDrafts() {
    if (!selected || !pendingDrafts.length) return;
    void mutate(async () => {
      await saveMarksBatch(selected.id, pendingDrafts.map((row) => ({
        row, score: drafts[row.student_id].score, note: drafts[row.student_id].note,
      })), selected.max_score);
    }, `حُفظت درجات ${pendingDrafts.length} طالباً.`, true);
  }

  if (!allowed) return <main className="workspace"><section className="panel" role="alert">
    <h1>الوصول غير متاح</h1><p>لا يتيح دورك الوصول إلى الاختبارات والنتائج.</p>
  </section></main>;

  if (!staff) {
    return <main className="workspace">
      <div className="page-heading"><div><p className="eyebrow">كلية ساي</p><h1>نتائج الاختبارات</h1></div></div>
      <p className="data-note">تظهر هنا النتائج المنشورة فقط بعد اعتمادها من الشؤون الأكاديمية.</p>
      {loading && <p role="status">جارٍ تحميل النتائج...</p>}
      {error && <p className="error-box" role="alert">تعذر تحميل النتائج: {error} <button className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}
      {!loading && !error && <section className="panel management-detail"><h2>النتائج المنشورة</h2>
        {!familyResults.length ? <p className="muted">لا توجد نتائج منشورة حتى الآن.</p>
          : <div className="table-scroll"><table className="management-table"><thead><tr><th>الطالب</th><th>الاختبار</th><th>المادة</th><th>التاريخ</th><th>الدرجة</th><th>التقدير</th><th>طباعة</th></tr></thead><tbody>
            {familyResults.map((row) => <tr key={row.id}>
              <td>{studentNames[row.student_id] ?? "—"}</td>
              <td><strong>{row.exam?.title ?? "—"}</strong></td>
              <td>{row.exam?.subject ?? "—"}</td>
              <td>{row.exam?.exam_date ?? "—"}</td>
              <td>{row.score === null ? "—" : `${row.score} / ${row.exam?.max_score ?? "—"}`}</td>
              <td>{row.grade ? gradeLabels[row.grade] : "—"}</td>
              <td><button className="button secondary" onClick={() => setPrintingResult(row)}>
                <i className="ri-printer-line" aria-hidden="true"></i> طباعة
              </button></td>
            </tr>)}
          </tbody></table></div>}
      </section>}
      {printingResult && <FamilyResultSheet
        result={printingResult}
        studentName={studentNames[printingResult.student_id] ?? "الطالب"}
        onClose={() => setPrintingResult(null)}
      />}
    </main>;
  }

  return <main className="workspace">
    <div className="page-heading"><div><p className="eyebrow">إدارة الأكاديمية</p><h1>الاختبارات والنتائج</h1></div></div>
    <p className="data-note">تُنشأ الاختبارات كمسودة، ثم تُفتح لرصد الدرجات، وتُراجع وتُنشر من الشؤون الأكاديمية. لا يرى الطلاب وأولياء الأمور إلا النتائج المنشورة.</p>
    <fieldset className="context-card" disabled={saving}>
      <label>الفرع<select value={filters.branch} onChange={(e) => filter("branch", e.target.value)}><option value="">كل الفروع المتاحة</option>{branchIds.map((id) => <option key={id} value={id}>{branchName(id)}</option>)}</select></label>
      <label>الجلسة الأكاديمية<select value={filters.session} onChange={(e) => filter("session", e.target.value)}><option value="">كل الجلسات المتاحة</option>{sessionIds.map((id) => <option key={id} value={id}>{sessionName(id)}</option>)}</select></label>
      <label>الصف<select value={filters.classId} onChange={(e) => filter("classId", e.target.value)}><option value="">كل الصفوف المتاحة</option>{availableClasses.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
      <label>الحالة<select value={filters.status} onChange={(e) => filter("status", e.target.value)}><option value="">كل الحالات</option>{Object.entries(examStatuses).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
    </fieldset>

    <section className="panel"><h2>إنشاء اختبار وجدولته</h2>
      <form className="management-form" onSubmit={(event) => {
        event.preventDefault();
        if (!chosenClass) { setDetailError("اختر الصف أولاً."); return; }
        const problem = validateExamDraft(draft, chosenWindow);
        if (problem) { setDetailError(problem); return; }
        void mutate(() => createExam(chosenClass, draft, chosenWindow), "تم إنشاء الاختبار كمسودة.");
      }}>
        <fieldset disabled={saving} className="profile-contact-fields">
          <label>الصف<select required value={draft.classId} onChange={(e) => setDraft((value) => ({ ...value, classId: e.target.value, courseId: "" }))}>
            <option value="" disabled>اختر الصف</option>
            {availableClasses.map((item) => <option key={item.id} value={item.id}>{item.name} · {branchName(item.branch_id)}</option>)}
          </select></label>
          <label>المقرر (اختياري)<select value={draft.courseId} onChange={(e) => setDraft((value) => ({ ...value, courseId: e.target.value }))}>
            <option value="">بدون مقرر</option>
            {courses.map((item) => <option key={item.id} value={item.id}>{item.title}</option>)}
          </select></label>
          <label>المادة<input required maxLength={120} value={draft.subject} onChange={(e) => setDraft((value) => ({ ...value, subject: e.target.value }))} placeholder="اللغة الصينية" /></label>
          <label>عنوان الاختبار<input required maxLength={160} value={draft.title} onChange={(e) => setDraft((value) => ({ ...value, title: e.target.value }))} placeholder="اختبار منتصف الفصل" /></label>
          <label>التاريخ<input required type="date" value={draft.date} min={chosenWindow?.starts_on} max={chosenWindow?.ends_on} onChange={(e) => setDraft((value) => ({ ...value, date: e.target.value }))} /></label>
          <label>وقت البداية<input type="time" value={draft.startTime} onChange={(e) => setDraft((value) => ({ ...value, startTime: e.target.value }))} /></label>
          <label>وقت النهاية<input type="time" value={draft.endTime} onChange={(e) => setDraft((value) => ({ ...value, endTime: e.target.value }))} /></label>
          <label>القاعة<input maxLength={60} value={draft.room} onChange={(e) => setDraft((value) => ({ ...value, room: e.target.value }))} placeholder="قاعة 1" /></label>
          <label>الدرجة العظمى<input required type="number" min="1" max="1000" step="0.5" value={draft.maxScore} onChange={(e) => setDraft((value) => ({ ...value, maxScore: e.target.value }))} /></label>
        </fieldset>
        <div className="actions"><button className="button primary" type="submit" disabled={saving || !canCreate}>إنشاء المسودة</button></div>
      </form>
    </section>

    {loading && <p role="status">جارٍ تحميل الاختبارات...</p>}
    {error && <p className="error-box" role="alert">تعذر تحميل الاختبارات: {error} <button className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}
    {message && <p className="success-box" role="status">{message}</p>}
    {detailError && <p className="error-box" role="alert">تعذر تنفيذ الطلب: {detailError} <button className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}

    {!loading && !error && <section className="panel management-detail"><h2>الاختبارات</h2>
      {!rows.length ? <p className="muted">لا توجد اختبارات متاحة تطابق التصفية.</p> : <div className="table-scroll"><table className="management-table"><thead><tr><th>الاختبار</th><th>المادة</th><th>الصف</th><th>التاريخ</th><th>القاعة</th><th>الحالة</th><th>التفاصيل</th></tr></thead><tbody>
        {rows.map((row) => <tr key={row.id}><td><strong>{row.title}</strong></td><td>{row.subject}</td><td>{className(row.class_id)}</td><td>{row.exam_date}{row.start_time ? ` · ${row.start_time.slice(0, 5)}` : ""}</td><td>{row.room ?? "—"}</td><td>{examStatuses[row.status]}</td><td><button className="button secondary" disabled={saving} onClick={() => { setSelected(row); setDrafts({}); setPrinting(false); setMessage(null); }}>عرض</button></td></tr>)}
      </tbody></table></div>}
      <div className="pagination"><button className="button secondary" disabled={filters.page === 0 || saving} onClick={() => setFilters((value) => ({ ...value, page: value.page - 1 }))}>السابق</button><span>صفحة {filters.page + 1} · {count} اختبار</span><button className="button secondary" disabled={(filters.page + 1) * examPageSize >= count || saving} onClick={() => setFilters((value) => ({ ...value, page: value.page + 1 }))}>التالي</button></div>
    </section>}

    {selected && <section className="panel management-detail"><div className="page-heading"><h2>{selected.title} · {examStatuses[selected.status]}</h2><div className="actions">
      {manager && <button className="button secondary" disabled={saving || detailLoading || !!detailError || !roster.length} onClick={() => setPrinting(true)}><i className="ri-printer-line" aria-hidden="true"></i> طباعة كشف النتائج</button>}
      <button className="button secondary" disabled={saving} onClick={() => setSelected(null)}>إغلاق التفاصيل</button>
    </div></div>
      <p className="data-note">{selected.subject} · {className(selected.class_id)} · {selected.exam_date}{selected.room ? ` · ${selected.room}` : ""} · الدرجة العظمى {selected.max_score}</p>
      {manager && !!(transitionActions[selected.status]?.length) && <div className="actions">
        {transitionActions[selected.status]!.map((action) => (
          (!action.reviewer || reviewer) && canTransition(selected.status, action.next)
          && <button key={action.next} className={action.next === "published" ? "button primary" : "button secondary"} disabled={saving}
            onClick={() => void mutate(() => transitionExam(selected, action.next), `انتقل الاختبار إلى «${examStatuses[action.next]}».`)}>{action.label}</button>
        ))}
      </div>}
      {detailLoading ? <p role="status">جارٍ تحميل كشف الدرجات...</p> : !detailError && <>
        {editable && !!pendingDrafts.length && <div className="actions">
          <button className="button primary" type="button" disabled={saving} onClick={saveAllDrafts}>
            <i className="ri-save-3-line" aria-hidden="true"></i> {saving ? "جارٍ الحفظ..." : `حفظ الكل (${pendingDrafts.length})`}
          </button>
        </div>}
        {manager ? (!roster.length ? <p className="muted">لا يوجد طلاب نشطون في هذا الصف.</p>
          : <div className="table-scroll"><table className="management-table"><thead><tr><th>الطالب</th><th>الرقم الأكاديمي</th><th>الدرجة</th><th>التقدير</th><th>ملاحظة</th><th>الحفظ</th></tr></thead><tbody>
            {roster.map((row) => {
              const entry = drafts[row.student_id] ?? { score: "", note: "" };
              const markError = validateMark(entry.score, selected.max_score);
              const grade = entry.score.trim() === "" ? null : gradeForScore(Number(entry.score), selected.max_score);
              const changed = entry.score.trim() !== (row.score === null ? "" : String(row.score)) || entry.note !== (row.note ?? "");
              return <tr key={row.student_id}>
                <td>{row.full_name}</td>
                <td>{row.admission_no}</td>
                <td><input aria-label={`درجة ${row.full_name}`} type="number" min="0" max={selected.max_score} step="0.5" dir="ltr" disabled={!editable || saving} value={entry.score}
                  onChange={(e) => setDrafts((value) => ({ ...value, [row.student_id]: { ...entry, score: e.target.value } }))} />
                  {markError && entry.score.trim() !== "" && <small className="error-box" role="alert">{markError}</small>}</td>
                <td>{grade ? gradeLabels[grade] : "—"}</td>
                <td><input aria-label={`ملاحظة ${row.full_name}`} maxLength={240} disabled={!editable || saving} value={entry.note}
                  onChange={(e) => setDrafts((value) => ({ ...value, [row.student_id]: { ...entry, note: e.target.value } }))} /></td>
                <td>{editable && <button className="button primary" disabled={saving || !changed || !!markError}
                  onClick={() => void mutate(() => saveMark(selected.id, row, entry.score, entry.note, selected.max_score), "تم حفظ الدرجة.", true)}>حفظ</button>}</td>
              </tr>;
            })}
          </tbody></table></div>)
          : <p className="muted">تفاصيل الدرجات متاحة لمعلم الصف وإدارة الأكاديمية.</p>}
      </>}
    </section>}

    {printing && selected && <ExamReportSheet
      exam={selected}
      className={className(selected.class_id)}
      branchName={branchName(selected.branch_id)}
      sessionName={sessionName(selected.academic_session_id)}
      courseTitle={courseTitle(selected.course_id)}
      rows={rosterToReportRows(roster)}
      onClose={() => setPrinting(false)}
    />}
  </main>;
}
