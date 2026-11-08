import { useState } from "react";
import { Link } from "react-router-dom";
import { SiteContentPanel } from "./cms/SiteContentPanel";
import { ProgramsPanel } from "./cms/ProgramsPanel";
import { NewsPanel } from "./cms/NewsPanel";

type Tab = "content" | "programs" | "news";

const tabs: { id: Tab; label: string; icon: string }[] = [
  { id: "content", label: "نصوص الموقع", icon: "ri-text" },
  { id: "programs", label: "البرامج", icon: "ri-book-open-line" },
  { id: "news", label: "الأخبار", icon: "ri-newspaper-line" },
];

export function Cms({ roles }: { roles: readonly string[] }) {
  const canEdit = roles.some((role) => ["super_admin", "admin", "content_editor"].includes(role));
  const [tab, setTab] = useState<Tab>("content");

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">كلية ساي · الموقع التعريفي</p>
        <h1>الموقع التعريفي CMS</h1>
        <p className="muted">حرّر نصوص الصفحة العامة وبرامجها وأخبارها، وشاهد النتيجة على الموقع مباشرة بعد الحفظ.</p>
      </div>
      <div className="actions">
        <a className="button secondary" href="/" target="_blank" rel="noreferrer">فتح الموقع</a>
      </div>
    </div>

    <div className="cms-tabs" role="tablist" aria-label="أقسام إدارة الموقع">
      {tabs.map((item) => <button
        key={item.id}
        type="button"
        role="tab"
        aria-selected={tab === item.id}
        className={`cms-tab ${tab === item.id ? "active" : ""}`}
        onClick={() => setTab(item.id)}
      >
        <i className={item.icon} aria-hidden="true"></i>
        <span>{item.label}</span>
      </button>)}
    </div>

    {tab === "content" && <SiteContentPanel canEdit={canEdit} />}
    {tab === "programs" && <ProgramsPanel canEdit={canEdit} />}
    {tab === "news" && <NewsPanel canEdit={canEdit} />}

    <section className="panel cms-help">
      <h2>كيف يعمل النشر؟</h2>
      <ul className="cms-help-list">
        <li><i className="ri-checkbox-circle-line" aria-hidden="true"></i> أي عنصر «منشور» يظهر فوراً للزوّار في الصفحة العامة.</li>
        <li><i className="ri-eye-off-line" aria-hidden="true"></i> العنصر «المخفي» يبقى محفوظاً للإدارة ولا يظهر للزوّار.</li>
        <li><i className="ri-shield-check-line" aria-hidden="true"></i> النشر والتعديل متاحان للإدارة العامة ومدير الأكاديمية ومحرر المحتوى فقط.</li>
      </ul>
      <p className="muted">يبقى المحتوى الاحتياطي ظاهراً في حال تعذّر الوصول إلى قاعدة البيانات، حتى لا تظهر الصفحة فارغة.</p>
      <div className="actions"><Link className="button secondary" to="/portal/dashboard">العودة للرئيسية</Link></div>
    </section>
  </main>;
}