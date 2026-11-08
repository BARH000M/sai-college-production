import { useState } from "react";
import {
  academicExams, academicKpis, academicPlans, academicRequests, academicSections,
} from "@/mocks/academics";
import { LabPage, LabStats, LabTabs } from "@/portal/pages/labs/LabShell";
import { PrintDoc } from "@/portal/pages/academics/PrintDoc";

type Tab = "plans" | "exams" | "sections" | "requests";

const tabs = [
  { id: "plans" as const, label: "الخطط الدراسية", icon: "ri-draft-line" },
  { id: "exams" as const, label: "الاختبارات", icon: "ri-file-edit-line" },
  { id: "sections" as const, label: "الشعب والتوزيع", icon: "ri-group-line" },
  { id: "requests" as const, label: "الطلبات الأكاديمية", icon: "ri-inbox-line" },
];

const statusTone: Record<string, "ok" | "warn" | "neutral" | "danger"> = {
  معتمدة: "ok",
  مستقرة: "ok",
  مقبول: "ok",
  مجدول: "ok",
  اكتمل: "ok",
  "قيد المراجعة": "warn",
  "بانتظار الاعتماد": "warn",
  "بحاجة لمستند": "danger",
  "تحتاج دعماً": "danger",
  مسودة: "neutral",
  مكتملة: "neutral",
};

function Status({ value }: { value: string }) {
  return <span className={`lab-status status-${statusTone[value] ?? "neutral"}`}>{value}</span>;
}

const tabTitles: Record<Tab, string> = {
  plans: "الخطط الدراسية المعتمدة",
  exams: "الاختبارات المجدولة",
  sections: "الشعب والتوزيع الأكاديمي",
  requests: "الطلبات الأكاديمية",
};

export function AcademicAffairs() {
  const [tab, setTab] = useState<Tab>("plans");
  const [search, setSearch] = useState("");
  const [examOverrides, setExamOverrides] = useState<Record<string, string>>({});
  const [requestOverrides, setRequestOverrides] = useState<Record<string, string>>({});
  const [notice, setNotice] = useState<string | null>(null);
  const [printOpen, setPrintOpen] = useState(false);

  const term = "الفصل الأول 2026/2027";

  function examStatus(id: string, current: string): string {
    return examOverrides[id] ?? current;
  }
  function requestStatus(id: string, current: string): string {
    return requestOverrides[id] ?? current;
  }

  function approveExam(id: string, title: string) {
    setExamOverrides((current) => ({ ...current, [id]: "مجدول" }));
    setNotice(`تم اعتماد موعد «${title}» وأصبح مجدولاً.`);
  }
  function approveRequest(id: string, student: string) {
    setRequestOverrides((current) => ({ ...current, [id]: "مقبول" }));
    setNotice(`تم قبول الطلب الأكاديمي للطالب ${student}.`);
  }

  const query = search.trim();
  const plans = academicPlans.filter((row) => !query || row.title.includes(query) || row.owner.includes(query));
  const exams = academicExams.filter((row) => !query || row.title.includes(query) || row.className.includes(query));
  const sections = academicSections.filter((row) => !query || row.name.includes(query) || row.teacher.includes(query));
  const requests = academicRequests.filter((row) => !query || row.student.includes(query) || row.type.includes(query));

  const pendingExams = academicExams.filter((row) => examStatus(row.id, row.status) === "بانتظار الاعتماد").length;
  const pendingRequests = academicRequests.filter((row) => requestStatus(row.id, row.status) === "قيد المراجعة").length;

  return <LabPage
    eyebrow="إدارة الأكاديمية"
    title="الشؤون الأكاديمية"
    intro="الخطط الدراسية، جدول الاختبارات، توزيع الشعب، والطلبات الأكاديمية في شاشة واحدة قابلة للطباعة."
    badge={term}
  >
    <LabStats items={academicKpis.map((row) => ({ label: row.label, value: row.value, detail: row.detail }))} />

    <div className="lab-toolbar">
      <LabTabs<Tab> label="أقسام الشؤون الأكاديمية" tabs={tabs} value={tab} onChange={(next) => { setTab(next); setNotice(null); }} />
      <div className="lab-toolbar-end">
        <label className="lab-search">
          <span className="sr-only">بحث في الشؤون الأكاديمية</span>
          <i className="ri-search-line" aria-hidden="true"></i>
          <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="بحث بالاسم أو الخطة" />
        </label>
        <button className="button secondary" type="button" onClick={() => setPrintOpen(true)}>
          <i className="ri-printer-line" aria-hidden="true"></i> طباعة
        </button>
      </div>
    </div>

    {notice && <p className="success-box" role="status">{notice}</p>}

    {tab === "plans" && <section className="panel">
      <div className="page-heading">
        <div><h2>الخطط الدراسية</h2><p className="data-note">الخطط المعتمدة والمقترحة لكل برنامج ومستوى، مع عدد الساعات والأسابيع.</p></div>
        <span className="learn-pill">{plans.length} خطة</span>
      </div>
      <div className="table-scroll"><table className="management-table">
        <thead><tr><th>الخطة</th><th>البرنامج</th><th>المستوى</th><th>الساعات</th><th>الأسابيع</th><th>المسؤول</th><th>الحالة</th><th>آخر تحديث</th></tr></thead>
        <tbody>
          {plans.map((row) => <tr key={row.id}>
            <td><strong>{row.title}</strong></td>
            <td>{row.program}</td>
            <td>{row.level}</td>
            <td>{row.hours}</td>
            <td>{row.weeks}</td>
            <td>{row.owner}</td>
            <td><Status value={row.status} /></td>
            <td>{row.updated}</td>
          </tr>)}
        </tbody>
      </table></div>
      {!plans.length && <p className="muted">لا توجد خطط تطابق البحث.</p>}
    </section>}

    {tab === "exams" && <section className="panel">
      <div className="page-heading">
        <div><h2>جدول الاختبارات</h2><p className="data-note">يحتاج الاختبار إلى اعتماد الشؤون الأكاديمية قبل نشره للطلاب.</p></div>
        <span className="lab-status status-warn">{pendingExams} بانتظار الاعتماد</span>
      </div>
      <div className="table-scroll"><table className="management-table">
        <thead><tr><th>الاختبار</th><th>الشعبة</th><th>التاريخ</th><th>الوقت</th><th>القاعة</th><th>المراقب</th><th>الحالة</th><th>إجراء</th></tr></thead>
        <tbody>
          {exams.map((row) => {
            const status = examStatus(row.id, row.status);
            return <tr key={row.id}>
              <td><strong>{row.title}</strong></td>
              <td>{row.className}</td>
              <td>{row.date}</td>
              <td dir="ltr">{row.time}</td>
              <td>{row.room}</td>
              <td>{row.invigilator}</td>
              <td><Status value={status} /></td>
              <td>{status === "بانتظار الاعتماد"
                ? <button className="button primary" type="button" onClick={() => approveExam(row.id, row.title)}>اعتماد</button>
                : <span className="muted">—</span>}</td>
            </tr>;
          })}
        </tbody>
      </table></div>
      {!exams.length && <p className="muted">لا توجد اختبارات تطابق البحث.</p>}
    </section>}

    {tab === "sections" && <section className="panel">
      <div className="page-heading">
        <div><h2>الشعب والتوزيع</h2><p className="data-note">نسبة الإشغال تعتمد على العدد المسجل مقابل سعة القاعة.</p></div>
        <span className="learn-pill">{sections.reduce((total, row) => total + row.students, 0)} طالباً</span>
      </div>
      <ul className="section-list">
        {sections.map((row) => {
          const percent = Math.min(100, Math.round((row.students / row.capacity) * 100));
          return <li key={row.id} className="section-row">
            <div className="section-row-main">
              <strong>{row.name}</strong>
              <span className="lab-meta">{row.program} · {row.teacher} · {row.room}</span>
            </div>
            <div className="section-row-bar">
              <span className="learn-bar" aria-hidden="true"><span style={{ width: `${percent}%` }} /></span>
              <small>{row.students} / {row.capacity} · {percent}%</small>
            </div>
            <Status value={row.status} />
          </li>;
        })}
      </ul>
      {!sections.length && <p className="muted">لا توجد شعب تطابق البحث.</p>}
    </section>}

    {tab === "requests" && <section className="panel">
      <div className="page-heading">
        <div><h2>الطلبات الأكاديمية</h2><p className="data-note">تحويل الشعبة، التأجيل، إعادة التصحيح، وتجاوز المتطلبات.</p></div>
        <span className="lab-status status-warn">{pendingRequests} قيد المراجعة</span>
      </div>
      <ul className="lab-list">
        {requests.map((row) => {
          const status = requestStatus(row.id, row.status);
          return <li key={row.id} className="lab-item">
            <div className="lab-item-head">
              <strong>{row.type}</strong>
              <Status value={status} />
            </div>
            <p className="lab-item-text">{row.detail}</p>
            <div className="lab-meta-row">
              <span><i className="ri-user-line" aria-hidden="true"></i> {row.student}</span>
              <span dir="ltr">{row.admissionNo}</span>
              <span><i className="ri-calendar-line" aria-hidden="true"></i> {row.submitted}</span>
            </div>
            {(status === "قيد المراجعة" || status === "بحاجة لمستند") && <div className="actions">
              <button className="button primary" type="button" onClick={() => approveRequest(row.id, row.student)}>قبول الطلب</button>
              <button className="button secondary" type="button" onClick={() => setNotice(`تم إرسال تنبيه إلى ${row.student} لاستكمال المستندات المطلوبة.`)}>طلب مستند</button>
            </div>}
          </li>;
        })}
      </ul>
      {!requests.length && <p className="muted">لا توجد طلبات تطابق البحث.</p>}
    </section>}

    <section className="panel">
      <h2>ملاحظات الأسبوع</h2>
      <ul className="lab-compact-list">
        <li><time dateTime="2026-11-08">الأحد 8 نوفمبر</time><strong>انطلاق الأسبوع الثقافي الصيني في الساحة الرئيسية.</strong></li>
        <li><time dateTime="2026-11-11">الأربعاء 11 نوفمبر</time><strong>اختبار منتصف الفصل HSK 3 في القاعة الذكية.</strong></li>
        <li><time dateTime="2026-11-14">السبت 14 نوفمبر</time><strong>اجتماع مجلس الأكاديمية لمراجعة نتائج منتصف الفصل.</strong></li>
        <li><time dateTime="2026-11-18">الأربعاء 18 نوفمبر</time><strong>إجازة وطنية — تعطّل الدراسة في جميع الفروع.</strong></li>
      </ul>
    </section>

    {printOpen && <PrintDoc
      title={tabTitles[tab]}
      subtitle={`ملخص أكاديمي رسمي · ${term}`}
      archive={{ term, preparedBy: "أ. سارة الحداد — منسقة الشؤون الأكاديمية" }}
      onClose={() => setPrintOpen(false)}
    >
      <div className="sheet-summary">
        {academicKpis.map((row) => <div key={row.id}><span>{row.label}</span><strong>{row.value}</strong></div>)}
      </div>
      {tab === "plans" && <div className="table-scroll"><table className="sheet-table">
        <thead><tr><th>#</th><th>الخطة</th><th>البرنامج</th><th>المستوى</th><th>الساعات</th><th>المسؤول</th><th>الحالة</th></tr></thead>
        <tbody>{plans.map((row, index) => <tr key={row.id}>
          <td>{index + 1}</td><td><strong>{row.title}</strong></td><td>{row.program}</td><td>{row.level}</td>
          <td>{row.hours}</td><td>{row.owner}</td><td>{row.status}</td>
        </tr>)}</tbody>
      </table></div>}
      {tab === "exams" && <div className="table-scroll"><table className="sheet-table">
        <thead><tr><th>#</th><th>الاختبار</th><th>الشعبة</th><th>التاريخ</th><th>الوقت</th><th>القاعة</th><th>المراقب</th><th>الحالة</th></tr></thead>
        <tbody>{exams.map((row, index) => <tr key={row.id}>
          <td>{index + 1}</td><td><strong>{row.title}</strong></td><td>{row.className}</td><td>{row.date}</td>
          <td dir="ltr">{row.time}</td><td>{row.room}</td><td>{row.invigilator}</td><td>{examStatus(row.id, row.status)}</td>
        </tr>)}</tbody>
      </table></div>}
      {tab === "sections" && <div className="table-scroll"><table className="sheet-table">
        <thead><tr><th>#</th><th>الشعبة</th><th>البرنامج</th><th>المعلم</th><th>القاعة</th><th>الطلاب</th><th>السعة</th></tr></thead>
        <tbody>{sections.map((row, index) => <tr key={row.id}>
          <td>{index + 1}</td><td><strong>{row.name}</strong></td><td>{row.program}</td><td>{row.teacher}</td>
          <td>{row.room}</td><td>{row.students}</td><td>{row.capacity}</td>
        </tr>)}</tbody>
      </table></div>}
      {tab === "requests" && <div className="table-scroll"><table className="sheet-table">
        <thead><tr><th>#</th><th>الطالب</th><th>الرقم</th><th>النوع</th><th>التفاصيل</th><th>التاريخ</th><th>الحالة</th></tr></thead>
        <tbody>{requests.map((row, index) => <tr key={row.id}>
          <td>{index + 1}</td><td><strong>{row.student}</strong></td><td dir="ltr">{row.admissionNo}</td>
          <td>{row.type}</td><td>{row.detail}</td><td>{row.submitted}</td><td>{requestStatus(row.id, row.status)}</td>
        </tr>)}</tbody>
      </table></div>}
      <p className="sheet-note">هذا الملخص مخصص للمراجعة الداخلية والأرشفة. تعتمد القرارات الأكاديمية النهائية على محضر مجلس الأكاديمية.</p>
      <div className="receipt-signatures">
        <div><span>إعداد: أ. سارة الحداد</span></div>
        <div><span>اعتماد عميد الشؤون الأكاديمية</span></div>
      </div>
    </PrintDoc>}
  </LabPage>;
}