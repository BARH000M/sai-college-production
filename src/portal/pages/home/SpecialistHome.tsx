import { Link } from "react-router-dom";
import { modulePath, roleLabels, visibleNavigation, type AppRole } from "../../lib/navigation";

const specialized = {
  accountant: {
    title: "لوحة المحاسب",
    description: "الرسوم والمدفوعات والتقارير المالية المصرح بها لحسابك.",
    shortcuts: ["finance", "reports", "notifications", "communications"],
    note: "تعرض مساحة المالية المبالغ المسجلة بالفعل. لا تُعرض إيرادات أو مصروفات تقديرية.",
  },
  receptionist: {
    title: "لوحة الاستقبال",
    description: "طلبات القبول وسجلات الطلاب ومتابعة الحضور والإعلانات.",
    shortcuts: ["admissions", "scanner", "students", "attendance", "communications"],
    note: "تعرض سجلات القبول والطلاب التي تسمح صلاحيات حسابك بالوصول إليها فقط.",
  },
  librarian: {
    title: "لوحة أمين المكتبة",
    description: "مقتنيات المكتبة والإعارة والتواصل مع الطلاب.",
    shortcuts: ["library", "notifications", "communications", "reports"],
    note: "عندما لا تتوفر سجلات للإعارة، تعرض المكتبة حالة فارغة بدلاً من أرقام افتراضية.",
  },
  content_editor: {
    title: "لوحة محرر المحتوى",
    description: "إدارة المقررات والموقع التعريفي وتحديثات المحتوى.",
    shortcuts: ["cms", "courses", "vocabulary", "communications", "notifications"],
    note: "لا يمكن اعتبار المحتوى منشوراً أو معتمداً إلا وفق سير العمل والبيانات المتاحة فعلياً.",
  },
} as const;

type SpecialistRole = keyof typeof specialized;
const order: readonly SpecialistRole[] = ["accountant", "receptionist", "librarian", "content_editor"];

export function SpecialistHome({ roles }: { roles: readonly string[] }) {
  const role: SpecialistRole = order.find((candidate) => roles.includes(candidate)) ?? "receptionist";
  const config = specialized[role];
  const visible = new Map(visibleNavigation(roles).map((item) => [item.id, item]));
  const shortcuts = config.shortcuts.flatMap((id) => {
    const item = visible.get(id);
    return item ? [item] : [];
  });

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">{roleLabels[role as AppRole]}</p>
        <h1>{config.title}</h1>
        <p className="muted">{config.description}</p>
      </div>
      <Link to="/portal/profile" className="button secondary">الملف الشخصي</Link>
    </div>
    <section className="panel">
      <h2>روابط عملك</h2>
      <p className="data-note">تعتمد هذه الروابط على أدوار حسابك المسندة من الإدارة، وليست صلاحيات يتم إنشاؤها داخل المتصفح.</p>
      <div className="module-grid">
        {shortcuts.map((item) => <Link key={item.id} to={modulePath(item)} className="module-card">
          <i className={item.icon} aria-hidden="true" />
          <strong>{item.label}</strong>
          <small>فتح القسم</small>
        </Link>)}
      </div>
      {!shortcuts.length && <p className="muted">لا توجد أقسام متاحة لدورك حالياً. تواصل مع مسؤول النظام.</p>}
    </section>
    <section className="panel">
      <h2>معلومات اللوحة</h2>
      <p className="muted">{config.note}</p>
      <p className="data-note">تُحمّل البيانات الفعلية من صفحات الأقسام مع فرض سياسات الوصول في Supabase. هذه اللوحة لا تختلق مؤشرات أداء.</p>
    </section>
  </main>;
}
