import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { LabPage, LabStats, LabTabs } from "@/portal/pages/labs/LabShell";
import { useActiveBranch } from "@/portal/hooks/useActiveBranch";
import {
  loadEnquiries, loadFollowUps, createEnquiry, setEnquiryStatus, addFollowUp,
  findDuplicateEnquiry, loadVisitors, checkInVisitor, checkOutVisitor,
  loadAppointments, createAppointment, setAppointmentStatus,
  loadComplaints, createComplaint, resolveComplaint,
  ENQUIRY_STATUS_LABELS,
  type Enquiry, type EnquiryStatus, type FollowUp, type Visitor, type Appointment, type Complaint,
} from "@/portal/lib/receptionRepository";

const sources = ["هاتف", "زيارة", "موقع إلكتروني", "وسائل التواصل", "توصية"] as const;

function formatDate(value: string | null): string {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

const statusTone: Record<EnquiryStatus, string> = {
  new: "status-warn",
  contacted: "status-info",
  assessment: "status-info",
  accepted: "status-ok",
  enrolled: "status-ok",
  rejected: "status-danger",
  withdrawn: "status-neutral",
};

const emptyEnquiry = { applicant: "", guardian: "", phone: "", source: sources[0] as string, program: "", assignedTo: "", notes: "" };
const emptyVisitor = { name: "", phone: "", purpose: "", host: "" };
const emptyAppointment = { name: "", phone: "", date: "", time: "", purpose: "" };
const emptyComplaint = { name: "", phone: "", subject: "", severity: "medium" as Complaint["severity"] };

export function Reception({ userId }: { userId: string | null }) {
  const { branchId } = useActiveBranch();
  const [tab, setTab] = useState<"enquiries" | "visitors" | "appointments" | "complaints">("enquiries");
  const [enquiries, setEnquiries] = useState<Enquiry[]>([]);
  const [followUps, setFollowUps] = useState<FollowUp[]>([]);
  const [visitors, setVisitors] = useState<Visitor[]>([]);
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<EnquiryStatus | "all">("all");
  const [enquiry, setEnquiry] = useState(emptyEnquiry);
  const [visitor, setVisitor] = useState(emptyVisitor);
  const [appointment, setAppointment] = useState(emptyAppointment);
  const [complaint, setComplaint] = useState(emptyComplaint);
  const [followUpNote, setFollowUpNote] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    if (!branchId) return;
    setLoading(true);
    setError(null);
    try {
      const [enquiryRows, visitorRows, appointmentRows, complaintRows] = await Promise.all([
        loadEnquiries(branchId),
        loadVisitors(branchId),
        loadAppointments(branchId),
        loadComplaints(branchId),
      ]);
      setEnquiries(enquiryRows);
      setVisitors(visitorRows);
      setAppointments(appointmentRows);
      setComplaints(complaintRows);
      setFollowUps(await loadFollowUps(enquiryRows.map((row) => row.id)));
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setLoading(false);
    }
  }, [branchId]);

  useEffect(() => { void load(); }, [load]);

  const stats = useMemo(() => ({
    open: enquiries.filter((row) => !["enrolled", "rejected", "withdrawn"].includes(row.status)).length,
    converted: enquiries.filter((row) => ["assessment", "accepted", "enrolled"].includes(row.status)).length,
    onSite: visitors.filter((row) => row.status === "on_site").length,
    complaints: complaints.filter((row) => row.status !== "resolved" && row.status !== "closed").length,
  }), [enquiries, visitors, complaints]);

  const filteredEnquiries = useMemo(() => {
    const term = search.trim().toLowerCase();
    return enquiries
      .filter((row) => (statusFilter === "all" ? true : row.status === statusFilter))
      .filter((row) => !term || [row.applicant_full_name, row.guardian_name, row.phone, row.preferred_program]
        .filter(Boolean).join(" ").toLowerCase().includes(term));
  }, [enquiries, search, statusFilter]);

  async function run(action: () => Promise<void>, success: string) {
    setError(null);
    setNotice(null);
    setBusy(true);
    try {
      await action();
      setNotice(success);
      await load();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setBusy(false);
    }
  }

  function submitEnquiry() {
    const duplicate = findDuplicateEnquiry(enquiries, enquiry.phone);
    if (duplicate) {
      setError(`تحذير تكرار: يوجد استفسار مسبق بنفس رقم الهاتف للمتقدم «${duplicate.applicant_full_name}». راجع السجل قبل إنشاء سجل جديد.`);
      return;
    }
    void run(
      () => createEnquiry({ ...enquiry, sessionId: null, branchId }),
      `أُضيف استفسار «${enquiry.applicant.trim()}» إلى السجل الدائم.`,
    ).then(() => setEnquiry(emptyEnquiry));
  }

  return <LabPage
    eyebrow="الاستقبال والإدارة الأمامية"
    title="سجل الاستقبال والمكتب الأمامي"
    intro="استفسارات القبول، سجل الزوار، المواعيد والشكاوى — سجلات دائمة مرتبطة بالفرع مع كشف التكرار وسجل متابعة."
    badge={branchId ? `${stats.open} استفسار مفتوح` : "لا يوجد فرع متاح"}
  >
    <LabStats items={[
      { label: "استفسارات مفتوحة", value: String(stats.open), detail: `${stats.converted} في مرحلة القبول` },
      { label: "زوار حالياً", value: String(stats.onSite), detail: "لم يُسجَّل خروجهم" },
      { label: "مواعيد قادمة", value: String(appointments.filter((row) => row.status === "scheduled").length), detail: "مجدولة" },
      { label: "شكاوى مفتوحة", value: String(stats.complaints), detail: "بانتظار المعالجة" },
    ]} />

    <LabTabs
      label="أقسام الاستقبال"
      value={tab}
      onChange={setTab}
      tabs={[
        { id: "enquiries", label: "استفسارات القبول", icon: "ri-user-search-line" },
        { id: "visitors", label: "سجل الزوار", icon: "ri-door-open-line" },
        { id: "appointments", label: "المواعيد", icon: "ri-calendar-event-line" },
        { id: "complaints", label: "الشكاوى", icon: "ri-feedback-line" },
      ]}
    />

    {error && <p className="error-box" role="alert">{error}</p>}
    {notice && <p className="notice" role="status">{notice}</p>}
    {loading && <p className="muted">جارٍ تحميل سجلات الاستقبال من الخادم...</p>}
    {!branchId && !loading && <p className="error-box" role="alert">لا يوجد فرع متاح لحسابك؛ لا يمكن عرض سجلات الاستقبال. <button className="button secondary" type="button" onClick={() => void load()}>إعادة المحاولة</button></p>}

    {tab === "enquiries" && branchId && <>
      <section className="panel">
        <h2>تسجيل استفسار جديد</h2>
        <div className="media-form">
          <label>اسم المتقدم<input value={enquiry.applicant} onChange={(event) => setEnquiry({ ...enquiry, applicant: event.target.value })} /></label>
          <label>ولي الأمر<input value={enquiry.guardian} onChange={(event) => setEnquiry({ ...enquiry, guardian: event.target.value })} /></label>
          <label>الهاتف<input dir="ltr" value={enquiry.phone} onChange={(event) => setEnquiry({ ...enquiry, phone: event.target.value })} placeholder="+967 ..." /></label>
          <label>المصدر<select value={enquiry.source} onChange={(event) => setEnquiry({ ...enquiry, source: event.target.value })}>{sources.map((source) => <option key={source} value={source}>{source}</option>)}</select></label>
          <label>البرنامج المطلوب<input value={enquiry.program} onChange={(event) => setEnquiry({ ...enquiry, program: event.target.value })} /></label>
        </div>
        <label className="approval-comment">ملاحظات<textarea rows={2} maxLength={500} value={enquiry.notes} onChange={(event) => setEnquiry({ ...enquiry, notes: event.target.value })} /></label>
        <div className="actions"><button className="button primary" type="button" onClick={submitEnquiry} disabled={busy}><i className="ri-add-line" aria-hidden="true"></i> تسجيل الاستفسار</button></div>
      </section>

      <section className="panel">
        <div className="media-toolbar">
          <label className="media-search"><i className="ri-search-line" aria-hidden="true"></i><input type="search" placeholder="ابحث بالاسم أو الهاتف" value={search} onChange={(event) => setSearch(event.target.value)} aria-label="بحث في الاستفسارات" /></label>
          <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as EnquiryStatus | "all")} aria-label="حالة الاستفسار">
            <option value="all">كل الحالات</option>
            {Object.entries(ENQUIRY_STATUS_LABELS).map(([id, label]) => <option key={id} value={id}>{label}</option>)}
          </select>
        </div>
        {!filteredEnquiries.length
          ? <p className="muted">لا توجد استفسارات مطابقة.</p>
          : <div className="reception-list">
            {filteredEnquiries.map((row) => <article key={row.id} className="reception-card">
              <div className="page-heading">
                <div><h3>{row.applicant_full_name}</h3><p className="muted">{row.preferred_program ?? "—"} · {row.source ?? "—"} · ولي الأمر {row.guardian_name ?? "—"}</p></div>
                <span className={`lab-status ${statusTone[row.status]}`}>{ENQUIRY_STATUS_LABELS[row.status]}</span>
              </div>
              <p className="lab-item-text" dir="ltr">{row.phone ?? "—"}</p>
              <p className="data-note">{formatDate(row.created_at)}</p>
              {row.notes && <p className="lab-item-text">{row.notes}</p>}
              {followUps.filter((entry) => entry.enquiry_id === row.id).length > 0 && <ul className="reception-followups">
                {followUps.filter((entry) => entry.enquiry_id === row.id).map((entry) => <li key={entry.id}>{formatDate(entry.created_at)}<br />{entry.note}</li>)}
              </ul>}
              <div className="reception-followup">
                <input placeholder="أضف متابعة..." value={followUpNote[row.id] ?? ""} onChange={(event) => setFollowUpNote({ ...followUpNote, [row.id]: event.target.value })} />
                <button className="button secondary" type="button" disabled={busy} onClick={() => void run(() => addFollowUp(row.id, followUpNote[row.id] ?? "", userId), "أُضيفت المتابعة.").then(() => setFollowUpNote({ ...followUpNote, [row.id]: "" }))}><i className="ri-chat-3-line" aria-hidden="true"></i> متابعة</button>
              </div>
              <div className="actions">
                {row.status !== "assessment" && row.status !== "accepted" && row.status !== "enrolled" && <button className="button primary" type="button" disabled={busy} onClick={() => void run(() => setEnquiryStatus(row.id, "assessment"), "نُقل الاستفسار إلى مرحلة التقييم في مسار القبول.")}><i className="ri-user-add-line" aria-hidden="true"></i> ترقية إلى مرحلة القبول</button>}
                {["assessment", "accepted", "enrolled"].includes(row.status) && <Link className="button secondary" to="/portal/modules/admissions">فتح القبول والتسجيل</Link>}
                {row.status !== "withdrawn" && <button className="text-button" type="button" disabled={busy} onClick={() => void run(() => setEnquiryStatus(row.id, "withdrawn"), "أُغلق الاستفسار.")}>سحب/إغلاق</button>}
              </div>
            </article>)}
          </div>}
      </section>
    </>}

    {tab === "visitors" && branchId && <>
      <section className="panel">
        <h2>تسجيل دخول زائر</h2>
        <div className="media-form">
          <label>الاسم<input value={visitor.name} onChange={(event) => setVisitor({ ...visitor, name: event.target.value })} /></label>
          <label>الهاتف<input dir="ltr" value={visitor.phone} onChange={(event) => setVisitor({ ...visitor, phone: event.target.value })} /></label>
          <label>الغرض<input value={visitor.purpose} onChange={(event) => setVisitor({ ...visitor, purpose: event.target.value })} /></label>
          <label>المضيف<input value={visitor.host} onChange={(event) => setVisitor({ ...visitor, host: event.target.value })} /></label>
        </div>
        <div className="actions"><button className="button primary" type="button" disabled={busy} onClick={() => void run(() => checkInVisitor({ ...visitor, branchId, userId }), `سُجّل دخول الزائر «${visitor.name.trim()}».`).then(() => setVisitor(emptyVisitor))}><i className="ri-login-box-line" aria-hidden="true"></i> تسجيل الدخول</button></div>
      </section>
      <section className="panel">
        <h2>سجل الزوار</h2>
        {!visitors.length ? <p className="muted">لا يوجد زوار مسجلون.</p>
          : <div className="table-scroll"><table className="data-table">
            <thead><tr><th>الزائر</th><th>الهاتف</th><th>الغرض</th><th>المضيف</th><th>الدخول</th><th>الخروج</th><th></th></tr></thead>
            <tbody>{visitors.map((row) => <tr key={row.id}>
              <td>{row.full_name}</td><td dir="ltr">{row.phone ?? "—"}</td><td>{row.purpose ?? "—"}</td><td>{row.host_name ?? "—"}</td>
              <td>{formatDate(row.check_in_at)}</td>
              <td>{row.check_out_at ? formatDate(row.check_out_at) : <span className="lab-status status-warn">داخل المبنى</span>}</td>
              <td>{!row.check_out_at && <button className="text-button" type="button" disabled={busy} onClick={() => void run(() => checkOutVisitor(row.id), "سُجّل خروج الزائر.")}>تسجيل خروج</button>}</td>
            </tr>)}</tbody>
          </table></div>}
      </section>
    </>}

    {tab === "appointments" && branchId && <>
      <section className="panel">
        <h2>حجز موعد</h2>
        <div className="media-form">
          <label>الاسم<input value={appointment.name} onChange={(event) => setAppointment({ ...appointment, name: event.target.value })} /></label>
          <label>الهاتف<input dir="ltr" value={appointment.phone} onChange={(event) => setAppointment({ ...appointment, phone: event.target.value })} /></label>
          <label>التاريخ<input type="date" value={appointment.date} onChange={(event) => setAppointment({ ...appointment, date: event.target.value })} /></label>
          <label>الوقت<input type="time" value={appointment.time} onChange={(event) => setAppointment({ ...appointment, time: event.target.value })} /></label>
          <label>الغرض<input value={appointment.purpose} onChange={(event) => setAppointment({ ...appointment, purpose: event.target.value })} /></label>
        </div>
        <div className="actions"><button className="button primary" type="button" disabled={busy} onClick={() => void run(() => createAppointment({ ...appointment, branchId, userId }), "حُدِّد الموعد وسُجّل في السجل الدائم.").then(() => setAppointment(emptyAppointment))}><i className="ri-calendar-check-line" aria-hidden="true"></i> تحديد الموعد</button></div>
      </section>
      <section className="panel">
        <h2>المواعيد</h2>
        {!appointments.length ? <p className="muted">لا توجد مواعيد.</p>
          : <div className="reception-list">{appointments.map((row) => <article key={row.id} className="reception-card">
            <div className="page-heading"><div><h3>{row.full_name}</h3><p className="muted">{formatDate(row.scheduled_at)} · {row.purpose ?? "—"}</p></div>
              <span className={`lab-status ${row.status === "completed" ? "status-ok" : row.status === "cancelled" ? "status-danger" : "status-info"}`}>{row.status === "scheduled" ? "مجدول" : row.status === "completed" ? "مكتمل" : row.status === "no_show" ? "لم يحضر" : "ملغى"}</span></div>
            <p className="lab-item-text" dir="ltr">{row.phone ?? "—"}</p>
            <div className="actions">
              {row.status === "scheduled" && <>
                <button className="button secondary" type="button" disabled={busy} onClick={() => void run(() => setAppointmentStatus(row.id, "completed"), "أُتمّ الموعد.")}>إتمام</button>
                <button className="text-button" type="button" disabled={busy} onClick={() => void run(() => setAppointmentStatus(row.id, "cancelled"), "أُلغي الموعد.")}>إلغاء</button>
              </>}
            </div>
          </article>)}</div>}
      </section>
    </>}

    {tab === "complaints" && branchId && <>
      <section className="panel">
        <h2>تسجيل شكوى</h2>
        <div className="media-form">
          <label>مقدّم الشكوى<input value={complaint.name} onChange={(event) => setComplaint({ ...complaint, name: event.target.value })} /></label>
          <label>الهاتف<input dir="ltr" value={complaint.phone} onChange={(event) => setComplaint({ ...complaint, phone: event.target.value })} /></label>
          <label>الموضوع<input value={complaint.subject} onChange={(event) => setComplaint({ ...complaint, subject: event.target.value })} /></label>
          <label>الأهمية<select value={complaint.severity} onChange={(event) => setComplaint({ ...complaint, severity: event.target.value as Complaint["severity"] })}>
            <option value="low">منخفضة</option><option value="medium">متوسطة</option><option value="high">عالية</option>
          </select></label>
        </div>
        <div className="actions"><button className="button primary" type="button" disabled={busy} onClick={() => void run(() => createComplaint({ ...complaint, branchId, userId }), "سُجّلت الشكوى وأُحيلت للمتابعة.").then(() => setComplaint(emptyComplaint))}><i className="ri-add-line" aria-hidden="true"></i> تسجيل الشكوى</button></div>
      </section>
      <section className="panel">
        <h2>الشكاوى</h2>
        {!complaints.length ? <p className="muted">لا توجد شكاوى مسجلة.</p>
          : <div className="reception-list">{complaints.map((row) => <article key={row.id} className="reception-card">
            <div className="page-heading"><div><h3>{row.subject}</h3><p className="muted">{row.complainant_name} · {formatDate(row.created_at)}</p></div>
              <span className={`lab-status ${row.status === "resolved" || row.status === "closed" ? "status-ok" : row.severity === "high" ? "status-danger" : "status-warn"}`}>{row.status === "resolved" || row.status === "closed" ? "محلولة" : row.severity === "high" ? "عاجلة" : "مفتوحة"}</span></div>
            <p className="lab-item-text" dir="ltr">{row.phone ?? "—"}</p>
            {row.resolution && <p className="lab-item-text">المعالجة: {row.resolution}</p>}
            {row.status === "open" && <div className="actions"><button className="button secondary" type="button" disabled={busy} onClick={() => void run(() => resolveComplaint(row.id, "عولجت في الاستقبال"), "عُلّمت الشكوى كمحلولة.")}>تعليم كمحلولة</button></div>}
          </article>)}</div>}
      </section>
    </>}
  </LabPage>;
}