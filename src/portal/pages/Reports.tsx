import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../lib/supabase";
import {
  loadAdmissionsReport, loadAttendanceReport, loadDistributionReport, loadEnrollmentReport, loadHomeworkReport,
  loadReportBranches, loadReportClasses, loadReportSessions,
  type AdmissionsReport, type AttendanceReport, type DistributionReport, type EnrollmentReport, type HomeworkReport,
} from "../lib/reports";
import { exportAttendanceReport, exportAdmissionsReport, exportDistributionReport, exportEnrollmentReport, exportHomeworkReport } from "../lib/reportExport";
import { ReportSheet, ReportPeriod, type SummaryItem } from "./reports/ReportShell";
import { AdmissionsSheet, AttendanceSheet, DistributionSheet, EnrollmentSheet, HomeworkSheet } from "./reports/ReportSheets";
import { StudentProgressReport } from "./students/StudentProgressReport";

type ReportKind = "students" | "attendance" | "homework" | "admissions" | "distribution";

type ReportOption = { id: string; name: string };
type StudentOption = { id: string; full_name: string; admission_no: string };

type SheetState =
  | { kind: "students"; data: EnrollmentReport }
  | { kind: "attendance"; data: AttendanceReport }
  | { kind: "homework"; data: HomeworkReport }
  | { kind: "admissions"; data: AdmissionsReport }
  | { kind: "distribution"; data: DistributionReport };

const reportCards: { id: ReportKind; title: string; icon: string; description: string }[] = [
  { id: "students", title: "كشف طلاب الصف", icon: "ri-file-list-3-line", description: "قائمة كاملة بطلاب الصف وحالاتهم مع خانة توقيع، للطباعة والتسليم." },
  { id: "attendance", title: "تقرير الحضور والغياب", icon: "ri-calendar-check-line", description: "ملخص حضور كل طالب داخل فترة محددة مع النسب والإجماليات." },
  { id: "homework", title: "تقرير الواجبات والتسليم", icon: "ri-task-line", description: "حالة كل واجب منشور: من سلّم، من صُحّح، ومن لم يسلّم بعد." },
  { id: "admissions", title: "تقرير القبول والتسجيل", icon: "ri-user-add-line", description: "كشف طلبات القبول وتوزيعها حسب الحالة داخل فرع وجلسة." },
  { id: "distribution", title: "توزيع الطلاب حسب البرنامج والفرع", icon: "ri-pie-chart-line", description: "كشف عام لكل الكلية يوضح عدد الطلاب في كل برنامج وفرع مع الإجماليات." },
];

function isoDate(date: Date): string {
  const offset = date.getTimezoneOffset() * 60000;
  return new Date(date.getTime() - offset).toISOString().slice(0, 10);
}

function defaultRange(): { from: string; to: string } {
  const to = new Date();
  const from = new Date(to.getTime() - 90 * 24 * 60 * 60 * 1000);
  return { from: isoDate(from), to: isoDate(to) };
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function Reports({ roles }: { roles: readonly string[] }) {
  const staffRoles = ["super_admin", "admin", "teacher", "accountant", "receptionist", "librarian", "content_editor"];
  const isStaff = roles.some((role) => staffRoles.includes(role));
  const isSuperAdmin = roles.includes("super_admin");
  const range = useMemo(defaultRange, []);

  const [kind, setKind] = useState<ReportKind>("students");
  const [branches, setBranches] = useState<ReportOption[]>([]);
  const [sessions, setSessions] = useState<ReportOption[]>([]);
  const [classes, setClasses] = useState<ReportOption[]>([]);
  const [students, setStudents] = useState<StudentOption[]>([]);

  const [branch, setBranch] = useState("");
  const [session, setSession] = useState("");
  const [classId, setClassId] = useState("");
  const [from, setFrom] = useState(range.from);
  const [to, setTo] = useState(range.to);
  const [studentId, setStudentId] = useState("");
  const [studentReport, setStudentReport] = useState<string | null>(null);

  const [optionsError, setOptionsError] = useState<string | null>(null);
  const [optionsLoading, setOptionsLoading] = useState(true);
  const [classesLoading, setClassesLoading] = useState(false);
  const [studentsLoading, setStudentsLoading] = useState(false);

  const [sheet, setSheet] = useState<SheetState | null>(null);
  const [sheetLoading, setSheetLoading] = useState(false);
  const [sheetError, setSheetError] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setOptionsLoading(true);
    setOptionsError(null);
    void Promise.all([loadReportBranches(), loadReportSessions()])
      .then(([branchRows, sessionRows]) => {
        if (!active) return;
        setBranches(branchRows);
        setSessions(sessionRows);
        if (branchRows.length === 1) setBranch((current) => current || branchRows[0].id);
        if (sessionRows.length === 1) setSession((current) => current || sessionRows[0].id);
      })
      .catch((failure: unknown) => {
        if (active) setOptionsError(message(failure));
      })
      .finally(() => { if (active) setOptionsLoading(false); });
    return () => { active = false; };
  }, [retry]);

  useEffect(() => {
    if (!branch || !session) { setClasses([]); setClassId(""); return; }
    let active = true;
    setClassesLoading(true);
    void loadReportClasses(branch, session)
      .then((rows) => {
        if (!active) return;
        setClasses(rows);
        setClassId((current) => (current && rows.some((row) => row.id === current) ? current : rows[0]?.id ?? ""));
      })
      .catch((failure: unknown) => { if (active) setOptionsError(message(failure)); })
      .finally(() => { if (active) setClassesLoading(false); });
    return () => { active = false; };
  }, [branch, session, retry]);

  useEffect(() => {
    if (!classId) { setStudents([]); setStudentId(""); return; }
    let active = true;
    setStudentsLoading(true);
    void supabase.from("students").select("id,full_name,admission_no")
      .eq("class_id", classId).eq("status", "active").order("full_name")
      .then((result) => {
        if (!active) return;
        if (result.error) { setOptionsError(result.error.message); setStudents([]); return; }
        const rows = (result.data ?? []) as StudentOption[];
        setStudents(rows);
        setStudentId((current) => (current && rows.some((row) => row.id === current) ? current : rows[0]?.id ?? ""));
      })
      .finally(() => { if (active) setStudentsLoading(false); });
    return () => { active = false; };
  }, [classId]);

  const needsClass = kind !== "admissions" && kind !== "distribution";
  const missingSelection = needsClass && !classId;
  const className = classes.find((row) => row.id === classId)?.name ?? "—";

  async function openSheet() {
    setSheetError(null);
    if (kind === "admissions") {
      if (!from || !to) { setSheetError("حدد بداية ونهاية الفترة."); return; }
    } else if (kind !== "distribution" && !classId) {
      setSheetError("اختر الفرع والجلسة والصف أولاً.");
      return;
    }
    setSheetLoading(true);
    setSheet(null);
    try {
      if (kind === "students") {
        setSheet({ kind, data: await loadEnrollmentReport(classId) });
      } else if (kind === "attendance") {
        setSheet({ kind, data: await loadAttendanceReport(classId, from, to) });
      } else if (kind === "homework") {
        setSheet({ kind, data: await loadHomeworkReport(classId) });
      } else if (kind === "distribution") {
        setSheet({ kind, data: await loadDistributionReport({ branch: branch || null, session: session || null }) });
      } else {
        setSheet({ kind, data: await loadAdmissionsReport({ branch: branch || null, session: session || null, from, to }) });
      }
    } catch (failure) {
      setSheetError(`تعذر تجهيز التقرير: ${message(failure)}`);
    } finally {
      setSheetLoading(false);
    }
  }

  function summaryFor(current: SheetState | null): SummaryItem[] {
    if (!current) return [];
    if (current.kind === "students") {
      return [
        { label: "الصف", value: current.data.className },
        { label: "الفرع", value: current.data.branchName },
        { label: "إجمالي الطلاب", value: String(current.data.counts.total) },
        { label: "الطلاب النشطون", value: String(current.data.counts.active) },
        { label: "السعة", value: current.data.capacity ? String(current.data.capacity) : "—" },
      ];
    }
    if (current.kind === "attendance") {
      const present = current.data.totals.present ?? 0;
      const excused = current.data.totals.excused ?? 0;
      const rate = current.data.totalRecords ? Math.round(((present + excused) / current.data.totalRecords) * 100) : 0;
      return [
        { label: "الصف", value: current.data.className },
        { label: "عدد الجلسات", value: String(current.data.sessionCount) },
        { label: "إجمالي السجلات", value: String(current.data.totalRecords) },
        { label: "حاضر", value: String(present) },
        { label: "نسبة الحضور", value: current.data.totalRecords ? `${rate}%` : "—" },
      ];
    }
    if (current.kind === "homework") {
      return [
        { label: "الصف", value: current.data.className },
        { label: "الطلاب النشطون", value: String(current.data.rosterSize) },
        { label: "الواجبات المنشورة", value: String(current.data.rows.length) },
        { label: "تسليمات مُصحَّحة", value: String(current.data.totalGraded) },
        { label: "تسليمات لم تُنجز", value: String(current.data.totalPending) },
      ];
    }
    if (current.kind === "distribution") {
      return [
        { label: "إجمالي الطلاب", value: String(current.data.totals.total) },
        { label: "الطلاب النشطون", value: String(current.data.totals.active) },
        { label: "الفروع", value: String(current.data.totals.branches) },
        { label: "البرامج", value: String(current.data.totals.programs) },
        { label: "الصفوف", value: String(current.data.totals.classes) },
      ];
    }
    return [
      { label: "الفرع", value: branches.find((row) => row.id === branch)?.name ?? "كل الفروع المتاحة" },
      { label: "الجلسة", value: sessions.find((row) => row.id === session)?.name ?? "كل الجلسات" },
      { label: "إجمالي الطلبات", value: String(current.data.total) },
      { label: "مقبول", value: String(current.data.counts.accepted ?? 0) },
      { label: "مسجل", value: String(current.data.counts.enrolled ?? 0) },
    ];
  }

  const sheetTitles: Record<ReportKind, string> = {
    students: "كشف طلاب الصف",
    attendance: "تقرير الحضور والغياب",
    homework: "تقرير الواجبات والتسليم",
    admissions: "تقرير القبول والتسجيل",
    distribution: "توزيع الطلاب حسب البرنامج والفرع",
  };

  if (!isStaff) {
    return <main className="workspace">
      <div className="page-heading"><div><p className="eyebrow">كلية ساي</p><h1>التقارير والطباعة</h1></div></div>
      <section className="panel">
        <p>تقارير الصفوف والطلاب متاحة لإدارة الكلية والمعلمين. حسابك يرى تقاريره الخاصة من لوحة التعلّم.</p>
        <div className="actions">
          <Link className="button primary" to="/portal/modules/progress">التقدّم والأداء</Link>
          <Link className="button secondary" to="/portal/dashboard">العودة للرئيسية</Link>
        </div>
      </section>
    </main>;
  }

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">كلية ساي · التقارير</p>
        <h1>التقارير والطباعة</h1>
        <p className="muted">أنشئ كشوفاً رسمية جاهزة للطباعة والتوقيع، معتمدة على البيانات المسجلة فعلياً.</p>
      </div>
      <Link className="button secondary" to="/portal/modules/students">سجلات الطلاب</Link>
    </div>

    {optionsLoading && <p role="status">جارٍ تحميل الفروع والجلسات...</p>}
    {optionsError && <p className="error-box" role="alert">تعذر تحميل بيانات التقارير: {optionsError} <button className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}

    <section className="panel export-panel">
      <h2>نوع التقرير</h2>
      <div className="export-blocks">
        {reportCards.map((card) => <div key={card.id} className={`export-block ${kind === card.id ? "active" : ""}`}>
          <h3><i className={`${card.icon} text-primary-600`} aria-hidden="true"></i> {card.title}</h3>
          <p className="muted">{card.description}</p>
          <button className={`button ${kind === card.id ? "primary" : "secondary"}`} type="button" onClick={() => { setKind(card.id); setSheet(null); setSheetError(null); }}>
            {kind === card.id ? "محدد" : "اختيار"}
          </button>
        </div>)}
      </div>
    </section>

    <fieldset className="context-card">
      <legend className="sr-only">نطاق التقرير</legend>
      <label>الفرع
        <select value={branch} onChange={(event) => { setBranch(event.target.value); setSheet(null); }}>
          <option value="">{isSuperAdmin ? "كل الفروع المتاحة" : "اختر فرعاً"}</option>
          {branches.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
        </select>
      </label>
      <label>الجلسة
        <select value={session} onChange={(event) => { setSession(event.target.value); setSheet(null); }}>
          <option value="">{(kind === "admissions" || kind === "distribution") ? "كل الجلسات" : "اختر جلسة"}</option>
          {sessions.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
        </select>
      </label>
      {needsClass && <label>الصف
        <select value={classId} onChange={(event) => { setClassId(event.target.value); setSheet(null); }} disabled={classesLoading || !branch || !session}>
          <option value="">{classesLoading ? "جارٍ التحميل..." : "اختر صفاً"}</option>
          {classes.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
        </select>
      </label>}
      <label>من تاريخ<input type="date" value={from} onChange={(event) => { setFrom(event.target.value); setSheet(null); }} /></label>
      <label>إلى تاريخ<input type="date" value={to} onChange={(event) => { setTo(event.target.value); setSheet(null); }} /></label>
      <div className="actions" style={{ alignSelf: "end" }}>
        <button className="button primary" type="button" disabled={sheetLoading || missingSelection} onClick={() => void openSheet()}>
          {sheetLoading ? "جارٍ التجهيز..." : "معاينة وطباعة"}
        </button>
      </div>
    </fieldset>

    {!classesLoading && needsClass && branch && session && classes.length === 0 && <p className="notice">لا توجد صفوف نشطة في هذا الفرع والجلسة. أنشئ صفاً من «الصفوف» أولاً.</p>}
    {sheetError && <p className="error-box" role="alert">{sheetError} <button className="text-button" type="button" onClick={() => void openSheet()}>إعادة المحاولة</button></p>}

    <section className="panel report-student-panel">
      <h2>تقرير فصل لطالب مفرد</h2>
      <p className="muted">نفس التقرير الذي يُسلَّم لولي الأمر: المقررات، الواجبات، الدرجات، وملخص الحضور.</p>
      <div className="management-form">
        <label>الطالب
          <select value={studentId} onChange={(event) => setStudentId(event.target.value)} disabled={!classId || studentsLoading}>
            <option value="">{studentsLoading ? "جارٍ التحميل..." : students.length ? "اختر طالباً" : "لا يوجد طلاب في الصف"}</option>
            {students.map((row) => <option key={row.id} value={row.id}>{row.full_name} · {row.admission_no}</option>)}
          </select>
        </label>
        <div className="actions" style={{ alignSelf: "end" }}>
          <button className="button secondary" type="button" disabled={!studentId} onClick={() => setStudentReport(studentId)}>فتح التقرير</button>
        </div>
      </div>
    </section>

    {(sheet || sheetLoading) && <ReportSheet
      title={sheetTitles[sheet?.kind ?? kind]}
      subtitle={`${className !== "—" ? `${className} · ` : ""}تقرير رسمي معتمد للطباعة`}
      summary={summaryFor(sheet)}
      loading={sheetLoading}
      error={sheetError}
      onRetry={() => void openSheet()}
      onClose={() => setSheet(null)}
      canPrint
      onExportCsv={sheet?.kind === "attendance"
        ? () => exportAttendanceReport(sheet.data)
        : sheet?.kind === "homework"
          ? () => exportHomeworkReport(sheet.data)
          : sheet?.kind === "students"
            ? () => exportEnrollmentReport(sheet.data)
            : sheet?.kind === "distribution"
              ? () => exportDistributionReport(sheet.data)
              : sheet?.kind === "admissions"
                ? () => exportAdmissionsReport(sheet.data)
                : undefined}
    >
      {sheet?.kind === "admissions" && <ReportPeriod from={sheet.data.from} to={sheet.data.to} />}
      {sheet?.kind === "attendance" && <ReportPeriod from={sheet.data.from} to={sheet.data.to} />}
      {sheet?.kind === "students" && <EnrollmentSheet report={sheet.data} />}
      {sheet?.kind === "attendance" && <AttendanceSheet report={sheet.data} />}
      {sheet?.kind === "homework" && <HomeworkSheet report={sheet.data} />}
      {sheet?.kind === "admissions" && <AdmissionsSheet report={sheet.data} />}
      {sheet?.kind === "distribution" && <DistributionSheet report={sheet.data} />}
    </ReportSheet>}

    {studentReport && <StudentProgressReport studentId={studentReport} onClose={() => setStudentReport(null)} />}
  </main>;
}