import { useCallback, useState } from "react";
import { Link } from "react-router-dom";
import { useUnsavedChangesGuard } from "../hooks/useUnsavedChangesGuard";
import { SiteContentPanel } from "./cms/SiteContentPanel";
import { ProgramsPanel } from "./cms/ProgramsPanel";
import { NewsPanel } from "./cms/NewsPanel";
import { CmsPreview } from "./cms/CmsPreview";
import { PreviewDraftContext, type CmsDraftKind, type CmsDirtyCounts, type PreviewDraftState } from "./cms/previewDraft";

type Tab = CmsDraftKind;

const tabs: { id: Tab; label: string; icon: string }[] = [
  { id: "content", label: "نصوص الموقع", icon: "ri-text" },
  { id: "programs", label: "البرامج", icon: "ri-book-open-line" },
  { id: "news", label: "الأخبار", icon: "ri-newspaper-line" },
];

export function Cms({ roles }: { roles: readonly string[] }) {
  const canEdit = roles.some((role) => ["super_admin", "admin", "content_editor"].includes(role));
  const [tab, setTab] = useState<Tab>("content");
  const [previewOpen, setPreviewOpen] = useState(false);
  const [draftState, setDraftState] = useState<PreviewDraftState>({ content: null, programs: null, news: null });
  const [dirty, setDirtyState] = useState<CmsDirtyCounts>({ content: 0, programs: 0, news: 0 });
  const [resetSignal, setResetSignal] = useState(0);

  const publishDraft = useCallback((patch: Partial<PreviewDraftState>) => {
    setDraftState((current) => ({ ...current, ...patch }));
  }, []);

  const setDirty = useCallback((kind: CmsDraftKind, count: number) => {
    setDirtyState((current) => (current[kind] === count ? current : { ...current, [kind]: count }));
  }, []);

  const totalDirty = dirty.content + dirty.programs + dirty.news;
  useUnsavedChangesGuard(totalDirty);

  const requestDiscard = useCallback(() => {
    setResetSignal((value) => value + 1);
  }, []);

  function discardChanges() {
    if (totalDirty <= 0) return;
    if (!window.confirm(`سيتم التراجع عن ${totalDirty} تعديلاً غير محفوظ وإرجاع الحقول إلى آخر نسخة منشورة. هل تريد المتابعة؟`)) return;
    requestDiscard();
  }

  return <PreviewDraftContext.Provider value={{ draft: draftState, publish: publishDraft, dirty, setDirty, resetSignal, requestDiscard }}>
    <main className="workspace">
      <div className="page-heading">
        <div>
          <p className="eyebrow">كلية ساي · الموقع التعريفي</p>
          <h1>الموقع التعريفي CMS</h1>
          <p className="muted">حرّر نصوص الصفحة العامة وبرامجها وأخبارها، وشاهد النتيجة على الموقع مباشرة بعد الحفظ.</p>
        </div>
        <div className="actions">
          {totalDirty > 0 && <span className="cms-tab-count cms-tab-count-standalone">
            <i className="ri-error-warning-line" aria-hidden="true"></i>
            {totalDirty} تعديل غير محفوظ
          </span>}
          {totalDirty > 0 && <button className="button secondary" type="button" onClick={discardChanges}>
            <i className="ri-arrow-go-back-line" aria-hidden="true"></i> تجاهل التعديلات
          </button>}
          <button className="button primary" type="button" onClick={() => setPreviewOpen(true)}>
            <i className="ri-eye-line" aria-hidden="true"></i> معاينة مباشرة
          </button>
          <a className="button secondary" href="/" target="_blank" rel="noreferrer">فتح الموقع</a>
        </div>
      </div>

      {totalDirty > 0 && <p className="cms-leave-warning" role="status">
        <i className="ri-error-warning-line" aria-hidden="true"></i>
        <span>لديك <strong>{totalDirty}</strong> تعديلاً غير محفوظ. سيظهر تنبيه تأكيد قبل مغادرة الصفحة أو إغلاق التبويب حتى لا تفقد تعديلاتك. يمكنك أيضاً الضغط على «تجاهل التعديلات» لإرجاع الحقول إلى آخر نسخة منشورة.</span>
      </p>}

      <div className="cms-tabs" role="tablist" aria-label="أقسام إدارة الموقع">
        {tabs.map((item) => <button
          key={item.id}
          type="button"
          role="tab"
          aria-selected={tab === item.id}
          aria-label={dirty[item.id] > 0 ? `${item.label} — ${dirty[item.id]} تغيير غير محفوظ` : item.label}
          className={`cms-tab ${tab === item.id ? "active" : ""}`}
          onClick={() => setTab(item.id)}
        >
          <i className={item.icon} aria-hidden="true"></i>
          <span>{item.label}</span>
          {dirty[item.id] > 0 && <span className="cms-tab-count" title="تعديلات كتبتها ولم تُحفظ بعد">
            <i className="ri-error-warning-line" aria-hidden="true"></i>{dirty[item.id]}
          </span>}
        </button>)}
      </div>

      <div hidden={tab !== "content"}><SiteContentPanel canEdit={canEdit} /></div>
      <div hidden={tab !== "programs"}><ProgramsPanel canEdit={canEdit} /></div>
      <div hidden={tab !== "news"}><NewsPanel canEdit={canEdit} /></div>

      <section className="panel cms-help">
        <h2>كيف يعمل النشر؟</h2>
        <ul className="cms-help-list">
          <li><i className="ri-eye-line" aria-hidden="true"></i> زر «معاينة مباشرة» يعرض الصفحة كما ستبدو للزائر، بما فيها التعديلات غير المحفوظة بعد.</li>
          <li><i className="ri-checkbox-circle-line" aria-hidden="true"></i> أي عنصر «منشور» يظهر فوراً للزوّار في الصفحة العامة.</li>
          <li><i className="ri-eye-off-line" aria-hidden="true"></i> العنصر «المخفي» يبقى محفوظاً للإدارة ولا يظهر للزوّار.</li>
          <li><i className="ri-error-warning-line" aria-hidden="true"></i> الرقم البنّي على التبويب يعني أن لديك تعديلات لم تُحفظ في ذلك القسم.</li>
          <li><i className="ri-shield-check-line" aria-hidden="true"></i> عند وجود تعديلات غير محفوظة يظهر تأكيد قبل مغادرة الصفحة أو إغلاق التبويب، فلا تُفقد كتابتك بالخطأ.</li>
          <li><i className="ri-arrow-go-back-line" aria-hidden="true"></i> زر «تجاهل التعديلات» يرجع كل الحقول إلى آخر نسخة منشورة دون مغادرة الصفحة (بعد تأكيد).</li>
          <li><i className="ri-lock-line" aria-hidden="true"></i> النشر والتعديل متاحان للإدارة العامة ومدير الأكاديمية ومحرر المحتوى فقط.</li>
        </ul>
        <p className="muted">يبقى المحتوى الاحتياطي ظاهراً في حال تعذّر الوصول إلى قاعدة البيانات، حتى لا تظهر الصفحة فارغة.</p>
        <div className="actions"><Link className="button secondary" to="/portal/dashboard">العودة للرئيسية</Link></div>
      </section>
    </main>

    <CmsPreview open={previewOpen} onClose={() => setPreviewOpen(false)} />
  </PreviewDraftContext.Provider>;
}