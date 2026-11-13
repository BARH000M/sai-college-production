import { Link } from "react-router-dom";
import {
  isModuleAvailable, modulePath, navigation, pendingModules,
} from "../lib/navigation";
import { expectedSystemEntryCount, systemCategories } from "../lib/systemInventory";

const moduleById = new Map(navigation.map((item) => [item.id, item]));
const superAdminModules = navigation.filter((item) =>
  item.id !== "systemCatalog" && isModuleAvailable(item.id) && item.roles.includes("super_admin"),
);

export function SystemInventory() {
  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">الإدارة العامة · جرد النظام</p>
        <h1>الوحدات والفجوات الوظيفية</h1>
        <p className="muted">روابط مباشرة لكل وحدة عاملة، مع فصل واضح بين الوظائف المتاحة وما ينتظر اعتماداً أو تكاملاً خلفياً.</p>
      </div>
      <Link className="button secondary" to="/portal/dashboard">لوحة الإدارة العامة</Link>
    </div>

    <div className="kpi-grid">
      <div className="kpi-card"><span>الفئات المرجعية</span><strong>{systemCategories.length}</strong></div>
      <div className="kpi-card"><span>مداخل القائمة الفرعية حسب التقرير</span><strong>{expectedSystemEntryCount}</strong></div>
      <div className="kpi-card"><span>وحدات عاملة قابلة للفتح</span><strong>{superAdminModules.length}</strong></div>
      <div className="kpi-card"><span>وحدات غير مفعّلة</span><strong>{pendingModules.length}</strong></div>
    </div>

    <section className="panel" role="note">
      <h2>حدود مراجعة القائمة المرجعية</h2>
      <p className="data-note">
        الملف المحلي المتاح يحفظ أسماء الفئات وأعدادها فقط، ولا يحتوي أسماء المداخل الفرعية الـ{expectedSystemEntryCount}.
        لذلك يقدّم هذا الجدول ربطاً على مستوى الفئة، ولا يدّعي مراجعة كل مدخل فرعي أو مطابقته باسم أصلي.
        يلزم إرفاق القائمة التفصيلية لإكمال التدقيق سطراً بسطر.
      </p>
    </section>

    <section className="panel">
      <div className="home-panel-head">
        <div><h2>الوحدات العاملة</h2><p className="data-note">تظهر هنا الشاشات المفعّلة والمسموحة للإدارة العامة.</p></div>
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
          <thead><tr><th>#</th><th>الفئة</th><th>عدد المداخل المرجعي</th><th>الوحدات المرتبطة العاملة</th><th>الحالة</th></tr></thead>
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
                : <span className="muted">لا توجد وحدة عاملة مرتبطة</span>}</td>
              <td><span className={`learn-pill ${linked.length ? "learn-status-in_progress" : "learn-status-not_started"}`}>
                {linked.length ? "جزئي — مراجعة المداخل مطلوبة" : "غير مدعوم حالياً"}
              </span></td>
            </tr>;
          })}</tbody>
        </table>
      </div>
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
