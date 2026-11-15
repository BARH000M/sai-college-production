import { useState } from "react";
import {
  academicExams, academicKpis, academicPlans, academicRequests, academicSections,
} from "@/mocks/academics";
import { LabPage, LabStats, LabTabs } from "@/portal/pages/labs/LabShell";

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


export function AcademicAffairs() {
  const [tab, setTab] = useState<Tab>("plans");
  const [search, setSearch] = useState("");
  const term = "الفصل الأول 2026/2027";

  const query = search.trim();
  const plans = academicPlans.filter((row) => !query || row.title.includes(query) || row.owner.includes(query));
  const exams = academicExams.filter((row) => !query || row.title.includes(query) || row.className.includes(query));
  const sections = academicSections.filter((row) => !query || row.name.includes(query) || row.teacher.includes(query));
  const requests = academicRequests.filter((row) => !query || row.student.includes(query) || row.type.includes(query));

  const pendingExams = academicExams.filter((row) => row.status === "بانتظار الاعتماد").length;
  const pendingRequests = academicRequests.filter((row) => row.status === "قيد المراجعة").length;

  return <LabPage
    eyebrow="إدارة الأكاديمية"
    title="الشؤون الأكاديمية"
    intro="الخطط الدراسية، جدول الاختبارات، توزيع الشعب، والطلبات الأكاديمية في شاشة واحدة قابلة للطباعة."
    badge={term}
  >
    <p className="data-note" role="note" data-academic-demo>عرض توضيحي غير مكتمل — جميع السجلات والأسماء والأرقام والمواعيد أمثلة وليست بيانات طلاب أو معلمين حقيقية. الاعتماد والإشعارات والطباعة الرسمية غير متاحة. Demonstration only — sample data; no backend operations.</p>
    <LabStats items={academicKpis.map((row) => ({ label: row.label, value: row.value, detail: row.detail }))} />

    <div className="lab-toolbar">
      <LabTabs<Tab> label="أقسام الشؤون الأكاديمية" tabs={tabs} value={tab} onChange={(next) => { setTab(next); }} />
      <div className="lab-toolbar-end">
        <label className="lab-search">
          <span className="sr-only">بحث في الشؤون الأكاديمية</span>
          <i className="ri-search-line" aria-hidden="true"></i>
          <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="بحث بالاسم أو الخطة" />
        </label>
        <button className="button secondary" type="button" disabled title="الطباعة الرسمية غير متاحة للبيانات التوضيحية">
          <i className="ri-printer-line" aria-hidden="true"></i> طباعة
        </button>
      </div>
    </div>


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
            const status = row.status;
            return <tr key={row.id}>
              <td><strong>{row.title}</strong></td>
              <td>{row.className}</td>
              <td>{row.date}</td>
              <td dir="ltr">{row.time}</td>
              <td>{row.room}</td>
              <td>{row.invigilator}</td>
              <td><Status value={status} /></td>
              <td>{status === "بانتظار الاعتماد"
                ? <button className="button primary" type="button" disabled>اعتماد</button>
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
          const status = row.status;
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
              <button className="button primary" type="button" disabled>قبول الطلب</button>
              <button className="button secondary" type="button" disabled>طلب مستند</button>
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


  </LabPage>;
}