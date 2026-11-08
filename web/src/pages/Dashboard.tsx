import { useEffect, useState } from "react";
import { KpiCard } from "../components/KpiCard";
import { loadContext, loadDashboard, type AcademicSession, type AuditEntry, type Branch, type Result } from "../lib/dashboard";

type DashboardData = { students: Result<number>; classes: Result<number>; audit: Result<AuditEntry[]> };
const unavailable: Result<number> = { data: null, error: null };

export function Dashboard() {
  const [branches, setBranches] = useState<Branch[]>([]);
  const [sessions, setSessions] = useState<AcademicSession[]>([]);
  const [branchId, setBranchId] = useState("");
  const [sessionId, setSessionId] = useState("");
  const [contextError, setContextError] = useState<string | null>(null);
  const [contextLoading, setContextLoading] = useState(true);
  const [data, setData] = useState<DashboardData | null>(null);
  const [dataLoading, setDataLoading] = useState(false);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setContextLoading(true);
    void loadContext().then((result) => {
      if (!active) return;
      const newBranches = result.branches.data ?? [];
      const newSessions = result.sessions.data ?? [];
      setBranches(newBranches);
      setSessions(newSessions);
      setBranchId((current) => newBranches.some((b) => b.id === current) ? current : newBranches[0]?.id ?? "");
      setSessionId((current) => newSessions.some((s) => s.id === current) ? current : newSessions.find((s) => s.is_active)?.id ?? newSessions[0]?.id ?? "");
      setContextError([result.branches.error, result.sessions.error].filter(Boolean).join(" — ") || null);
      setContextLoading(false);
    });
    return () => { active = false; };
  }, [retry]);

  useEffect(() => {
    let active = true;
    setData(null);
    if (!branchId || !sessionId) { setDataLoading(false); return; }
    setDataLoading(true);
    void loadDashboard(branchId, sessionId).then((result) => {
      if (active) { setData(result); setDataLoading(false); }
    });
    return () => { active = false; };
  }, [branchId, sessionId, retry]);

  const students = data?.students ?? unavailable;
  const classes = data?.classes ?? unavailable;
  const audit = data?.audit;
  const refresh = () => setRetry((current) => current + 1);
  const activeSession = sessions.find((session) => session.id === sessionId && session.is_active);

  return <main className="workspace">
    <section id="overview">
      <div className="page-heading"><div><p className="eyebrow">الإدارة العامة</p><h1>لوحة التحكم</h1><p className="muted">نظرة على بيانات الأكاديمية في النطاق المحدد.</p></div><button className="button secondary" onClick={refresh} disabled={contextLoading || dataLoading}>تحديث البيانات</button></div>
      <div className="context-card">
        <label>الفرع<select value={branchId} onChange={(e) => setBranchId(e.target.value)} disabled={contextLoading || !branches.length}><option value="">لا توجد فروع متاحة</option>{branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>)}</select></label>
        <label>الجلسة الأكاديمية<select value={sessionId} onChange={(e) => setSessionId(e.target.value)} disabled={contextLoading || !sessions.length}><option value="">لا توجد جلسات متاحة</option>{sessions.map((session) => <option key={session.id} value={session.id}>{session.name}{session.is_active ? " — نشطة" : ""}</option>)}</select></label>
      </div>
      {contextLoading && <p className="muted" role="status">جارٍ تحميل الفروع والجلسات...</p>}
      {contextError && <div className="error-box" role="alert">تعذر تحميل الفروع أو الجلسات: {contextError} <button className="text-button" onClick={refresh}>إعادة المحاولة</button></div>}
      {!contextLoading && !contextError && (!branches.length || !sessions.length) && <div className="notice">لا توجد فروع أو جلسات متاحة لحسابك. قد تمنع سياسات الوصول عرض السجلات؛ تحقق مع مسؤول النظام.</div>}
      <div className="kpi-grid">
        <KpiCard label="الفروع النشطة" value={contextLoading || contextError ? "—" : branches.filter((branch) => branch.is_active).length} detail="الفروع المتاحة لحسابك" error={contextError} />
        <KpiCard label="الطلاب النشطون" value={dataLoading || students.data === null ? "—" : students.data} detail="المسجلون في صفوف الفرع والجلسة" error={students.error} />
        <KpiCard label="الصفوف" value={dataLoading || classes.data === null ? "—" : classes.data} detail="جميع صفوف الفرع والجلسة المحددين" error={classes.error} />
        <KpiCard label="الجلسة النشطة" value={contextLoading ? "—" : activeSession?.name ?? "لا توجد جلسة نشطة محددة"} detail="الجلسة المختارة" error={contextError} />
      </div>
      {dataLoading && <p className="muted" role="status">جارٍ تحميل بيانات اللوحة...</p>}
      {(students.error || classes.error || audit?.error) && <button className="button secondary" onClick={refresh}>إعادة محاولة تحميل اللوحة</button>}
      <p className="data-note">تعرض الأرقام السجلات التي تسمح بها سياسات الوصول فقط. لا تعني النتيجة الفارغة بالضرورة عدم وجود بيانات.</p>
    </section>
    <div className="dashboard-grid">
      <section id="attendance" className="panel"><h2>نظرة على الحضور</h2><p className="muted">بيانات الحضور غير متاحة بعد في قاعدة البيانات الحالية.</p></section>
      <section id="admissions" className="panel"><h2>نظرة على القبول</h2><p className="muted">بيانات استفسارات القبول غير متاحة بعد في قاعدة البيانات الحالية.</p></section>
      <section id="finance" className="panel"><h2>ملخص الرسوم والمالية</h2><p className="muted">الملخص المالي غير متاح بعد.</p></section>
      <section id="upcoming" className="panel"><h2>الحصص القادمة</h2><p className="muted">جدول الحصص غير متاح بعد في قاعدة البيانات الحالية.</p></section>
      <section id="audit" className="panel audit-panel"><h2>آخر أحداث التدقيق</h2><p className="data-note">سجل عام غير مصنف حسب الفرع أو الجلسة.</p>
        {dataLoading ? <p className="muted">جارٍ تحميل سجل التدقيق...</p> : audit?.error ? <p className="error-box" role="alert">تعذر تحميل سجل التدقيق: {audit.error}</p> : !branchId || !sessionId ? <p className="muted">اختر فرعاً وجلسة لعرض اللوحة.</p> : audit?.data?.length ? <ul className="audit-list">{audit.data.map((entry) => <li key={entry.id}><strong>{entry.action}</strong><span>{entry.entity_type} · <time>{new Date(entry.created_at).toLocaleString("ar")}</time></span></li>)}</ul> : <p className="muted">لا توجد أحداث متاحة لهذا الحساب.</p>}
      </section>
    </div>
  </main>;
}
