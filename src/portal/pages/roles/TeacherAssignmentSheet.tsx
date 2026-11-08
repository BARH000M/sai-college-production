import logo from "@/portal/assets/saiLogo";
import type { TeacherAccount, TeacherClass } from "@/portal/lib/learningAccounts";

function today(): string {
  return new Date().toLocaleDateString("ar-EG", {
    year: "numeric", month: "long", day: "numeric",
  });
}

export function TeacherAssignmentSheet({
  teachers, classes, onClose,
}: {
  teachers: TeacherAccount[];
  classes: TeacherClass[];
  onClose: () => void;
}) {
  const unassigned = classes.filter((row) => !row.teacherId);
  const assignedCount = classes.filter((row) => row.teacherId).length;
  const totalStudents = teachers.reduce((sum, row) => sum + row.workload.students, 0);

  return <div className="print-overlay" role="dialog" aria-modal="true" aria-label="كشف إسناد المعلمين والصفوف">
    <div className="assignment-sheet">
      <div className="receipt-head">
        <img src={logo} alt="شعار كلية ساي" className="receipt-logo" />
        <div>
          <p className="receipt-college">كلية ساي التعليمية اليمنية الصينية</p>
          <p className="receipt-college-en" dir="ltr">SAI Yemeni–Chinese College</p>
          <h2 className="receipt-title">كشف إسناد المعلمين والصفوف</h2>
          <p className="receipt-subtitle">بداية الفصل الدراسي — يُسلَّم لكل معلم نسخة</p>
        </div>
      </div>

      <div className="sheet-summary">
        <div><span>تاريخ الكشف</span><strong>{today()}</strong></div>
        <div><span>عدد المعلمين</span><strong>{teachers.length}</strong></div>
        <div><span>صفوف مسندة</span><strong>{assignedCount} من {classes.length}</strong></div>
        <div><span>طلاب مشمولون</span><strong>{totalStudents}</strong></div>
      </div>

      {teachers.length === 0 && <p className="sheet-empty">لا توجد حسابات معلمين مسندة بعد؛ أنشئ حساب معلم أولاً ثم أعد الطباعة.</p>}

      {teachers.length > 0 && <table className="sheet-table">
        <thead>
          <tr>
            <th>المعلم</th>
            <th>البريد الإلكتروني</th>
            <th>الصف / الفرع</th>
            <th>المقررات</th>
            <th>الطلاب</th>
            <th>الواجبات</th>
            <th>توقيع المعلم</th>
          </tr>
        </thead>
        <tbody>
          {teachers.map((teacher) => <tr key={teacher.userId}>
            <td><strong>{teacher.fullName}</strong></td>
            <td dir="ltr">{teacher.email || "—"}</td>
            <td>
              {teacher.classNames.length ? teacher.classNames.join(" · ") : "بلا صف"}
              <small className="sheet-sub">{teacher.branchNames.join(" · ") || "—"}</small>
            </td>
            <td>{teacher.courseTitles.length ? teacher.courseTitles.join(" · ") : "—"}</td>
            <td>{teacher.workload.students}</td>
            <td>{teacher.workload.assignments}</td>
            <td className="sheet-sign-cell" />
          </tr>)}
        </tbody>
      </table>}

      {unassigned.length > 0 && <div className="sheet-unassigned">
        <strong>صفوف بلا معلم مسند</strong>
        <p>{unassigned.map((row) => `${row.name}${row.branchName ? ` (${row.branchName})` : ""}`).join(" · ")}</p>
      </div>}

      <p className="sheet-note">
        يُعتمد هذا الكشف مرجعاً لإسناد الصفوف والمقررات في بداية الفصل. أي تعديل لاحق على الإسناد
        يُنفَّذ من شاشة «حسابات المعلمين» ويُبلَّغ به المعلم بالبريد الإلكتروني.
      </p>

      <div className="receipt-signatures">
        <div><span>توقيع إدارة الكلية</span></div>
        <div><span>توقيع المعلم بالاستلام</span></div>
      </div>

      <p className="receipt-footer" dir="ltr">info@saicollege.com · Sana'a, Republic of Yemen · SAI College</p>
    </div>

    <div className="print-actions">
      <button className="button primary" type="button" onClick={() => window.print()} disabled={!teachers.length}>
        طباعة الكشف
      </button>
      <button className="button secondary" type="button" onClick={onClose}>إغلاق</button>
    </div>
  </div>;
}