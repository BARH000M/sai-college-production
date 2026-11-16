import { Link } from "react-router-dom";
import {
  isModuleAvailable, modulePath, navigation, pendingModules,
} from "../lib/navigation";
import { expectedSystemEntryCount, inventoryRelatedModulePath, systemCategories } from "../lib/systemInventory";
import { inventoryReference, type InventoryEntryStatus } from "../lib/systemInventoryEntries";

const moduleById = new Map(navigation.map((item) => [item.id, item]));
const superAdminModules = navigation.filter((item) =>
  item.id !== "systemCatalog" && isModuleAvailable(item.id) && item.roles.includes("super_admin"),
);
const entryStatusLabels: Record<InventoryEntryStatus, string> = {
  implemented: "منفذ في التطبيق",
  partial: "جزئي",
  pending: "غير مكتمل أو غير متحقق",
};

export function SystemInventory() {
  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">الإدارة العامة · جرد النظام</p>
        <h1>الوحدات والفجوات الوظيفية</h1>
        <p className="muted">روابط مباشرة للشاشات المفعّلة، مع توضيح ما هو جزئي أو ينتظر التحقق والتكامل الخلفي.</p>
      </div>
      <Link className="button secondary" to="/portal/dashboard">لوحة الإدارة العامة</Link>
    </div>

    <div className="kpi-grid">
      <div className="kpi-card"><span>الفئات المرجعية</span><strong>{systemCategories.length}</strong></div>
      <div className="kpi-card"><span>مداخل القائمة الفرعية حسب التقرير</span><strong>{expectedSystemEntryCount}</strong></div>
      <div className="kpi-card"><span>وحدات مفعّلة قابلة للفتح</span><strong>{superAdminModules.length}</strong></div>
      <div className="kpi-card"><span>وحدات غير مفعّلة</span><strong>{pendingModules.length}</strong></div>
    </div>

    <section className="panel" role="note">
      <h2>حدود جرد الوحدات</h2>
      <p className="data-note">
        يعرض الجرد المداخل المرجعية الـ{expectedSystemEntryCount} وتقييمها من مراجعة التطبيق.
        الروابط تشير إلى وحدات ذات صلة ولا تعني اكتمال كل مدخل أو اجتياز اختبارات خلفية بحسابات فعلية.
        لا يثبت غياب ترحيل محلي أن الجدول غير موجود في قاعدة البيانات.
      </p>
    </section>

    <section className="panel">
      <div className="home-panel-head">
        <div><h2>الوحدات المفعّلة</h2><p className="data-note">تظهر هنا الشاشات المسموحة للإدارة العامة؛ قد تكون بعض وظائفها تجريبية أو جزئية.</p></div>
      </div>
      <div className="role-chips">
        {superAdminModules.map((item) => <Link className="role-chip" key={item.id} to={modulePath(item)}>{item.label}</Link>)}
      </div>
    </section>

    <section className="panel">
      <div className="home-panel-head">
        <div><h2>الفئات المرجعية (32 / {expectedSystemEntryCount} مدخل)</h2>
          <p className="data-note">أي ربط أدناه يعني أن شاشة ذات صلة موجودة، وليس أن جميع وظائف الفئة اكتملت.</p>
        </div>
      </div>
      <div className="table-scroll">
        <table className="management-table">
          <thead><tr><th>#</th><th>الفئة</th><th>عدد المداخل المرجعي</th><th>الوحدات المرتبطة المفعّلة</th><th>الحالة</th></tr></thead>
          <tbody>{systemCategories.map((category, index) => {
            const linked = [...new Set(category.moduleIds)]
              .flatMap((id) => {
                const item = moduleById.get(id);
                return item && isModuleAvailable(id) ? [item] : [];
              });
            return <tr key={category.id}>
              <td>{index + 1}</td>
              <td><strong>{category.name}</strong></td>
              <td>{category.expectedEntries}</td>
              <td>{linked.length
                ? <div className="role-chips">{linked.map((item) => <Link key={item.id} className="role-chip" to={modulePath(item)}>{item.label}</Link>)}</div>
                : <span className="muted">لا توجد وحدة مفعّلة مرتبطة</span>}</td>
              <td><span className={`learn-pill ${linked.length ? "learn-status-in_progress" : "learn-status-not_started"}`}>
                {linked.length ? "جزئي — مراجعة المداخل مطلوبة" : "غير مدعوم حالياً"}
              </span></td>
            </tr>;
          })}</tbody>
        </table>
      </div>
    </section>

    <section className="panel" aria-labelledby="reference-entries-heading">
      <h2 id="reference-entries-heading">تفاصيل المداخل المرجعية</h2>
      <p className="data-note">الحالة تصف تنفيذ التطبيق، وليس اعتماد صلاحيات قاعدة البيانات أو التحقق من الإنتاج.</p>
      {inventoryReference.map((category, categoryIndex) => <details key={systemCategories[categoryIndex].id}>
        <summary>{categoryIndex + 1} · {category.ar} ({category.entries.length})</summary>
        <div className="table-scroll">
          <table className="management-table">
            <thead><tr><th>المدخل</th><th>الحالة</th><th>الوحدة ذات الصلة</th><th>ملاحظة التدقيق</th></tr></thead>
            <tbody>{category.entries.map((entry, entryIndex) => {
              const path = inventoryRelatedModulePath(entry);
              return <tr key={`${categoryIndex}-${entryIndex}`}>
                <td>{entry.ar}<br /><small dir="ltr">{entry.en}</small></td>
                <td>{entryStatusLabels[entry.status]}</td>
                <td>{path ? <Link to={path}>فتح الوحدة ذات الصلة</Link> : <span className="muted">—</span>}</td>
                <td><span dir="auto">{entry.note}</span> <small>({entry.profile})</small></td>
              </tr>;
            })}</tbody>
          </table>
        </div>
      </details>)}
    </section>

    <section className="panel">
      <h2>وحدات معلّقة — لا تفتح صفحات وهمية</h2>
      <div className="home-section-grid">
        {pendingModules.map((item) => <article className="panel" key={item.id}>
          <h3>{item.label}</h3>
          <p className="data-note">{item.reason}</p>
        </article>)}
      </div>
    </section>
  </main>;
}
