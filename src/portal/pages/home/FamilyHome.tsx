import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { loadParentChildren, loadStudentRecord, type ChildRecord } from "../../lib/home";
import { formatDate } from "./SectionBits";

type State =
  | { status: "loading"; data: null; error: null }
  | { status: "ready"; data: ChildRecord[]; error: null }
  | { status: "error"; data: null; error: string };

function RecordCard({ record, action }: { record: ChildRecord; action?: boolean }) {
  return <article className="panel home-child-card">
    <div className="home-panel-head">
      <div>
        <h2>{record.fullName}</h2>
        <p className="muted home-section-meta">الرقم الأكاديمي <span dir="ltr">{record.admissionNo}</span></p>
      </div>
      {action && <Link className="text-button" to="/portal/modules/progress">التقدم الدراسي</Link>}
    </div>
    <dl className="home-record-grid">
      <div><dt>الصف</dt><dd>{record.className ?? "غير مسند"}</dd></div>
      <div><dt>البرنامج</dt><dd>{record.program ?? "—"}</dd></div>
      <div><dt>الجلسة الأكاديمية</dt><dd>{record.sessionName ?? "—"}</dd></div>
      <div><dt>الفرع</dt><dd>{record.branchName ?? "—"}</dd></div>
      <div><dt>تاريخ الميلاد</dt><dd>{formatDate(record.dateOfBirth)}</dd></div>
    </dl>
  </article>;
}

export function ParentHome({ userId }: { userId: string }) {
  const [state, setState] = useState<State>({ status: "loading", data: null, error: null });
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setState({ status: "loading", data: null, error: null });
    loadParentChildren(userId)
      .then((data) => { if (active) setState({ status: "ready", data, error: null }); })
      .catch((error: unknown) => {
        if (active) setState({ status: "error", data: null, error: error instanceof Error ? error.message : String(error) });
      });
    return () => { active = false; };
  }, [userId, retry]);

  const children = state.status === "ready" ? state.data : null;

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">بوابة ولي الأمر</p>
        <h1>أبنائي</h1>
        <p className="muted">تظهر فقط الروابط التي اعتمدتها إدارة الكلية، مع الصف والبرنامج والفرع.</p>
      </div>
      <div className="actions">
        <Link className="button secondary" to="/portal/modules/progress">متابعة التقدم</Link>
        <button className="button secondary" onClick={() => setRetry((value) => value + 1)} disabled={state.status === "loading"}>تحديث</button>
      </div>
    </div>

    {state.status === "loading" && <p role="status">جارٍ تحميل سجلات أبنائك...</p>}
    {state.status === "error" && <section className="panel">
      <p className="error-box" role="alert">تعذر تحميل سجلات الأبناء: {state.error}</p>
      <div className="actions" style={{ marginTop: 12 }}>
        <button className="button secondary" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button>
      </div>
    </section>}

    {children && !children.length && <section className="panel">
      <h2>لا يوجد أبناء موثقون بعد</h2>
      <p className="muted">
        نعرض فقط الروابط التي تحمل تاريخ توثيق من الإدارة. لم نجد رابطاً موثقاً لحسابك، لذلك لا تظهر أي سجلات.
      </p>
      <p className="data-note">تواصل مع شؤون الطلاب لتوثيق صلة ولي الأمر بالطالب.</p>
    </section>}

    {children && !!children.length && <div className="home-section-grid">
      {children.map((child) => <RecordCard key={child.id} record={child} action />)}
    </div>}
  </main>;
}

export function StudentHome({ userId }: { userId: string }) {
  const [state, setState] = useState<State>({ status: "loading", data: null, error: null });
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setState({ status: "loading", data: null, error: null });
    loadStudentRecord(userId)
      .then((record) => { if (active) setState({ status: "ready", data: record ? [record] : [], error: null }); })
      .catch((error: unknown) => {
        if (active) setState({ status: "error", data: null, error: error instanceof Error ? error.message : String(error) });
      });
    return () => { active = false; };
  }, [userId, retry]);

  const record = state.status === "ready" ? state.data[0] ?? null : null;

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">بوابة الطالب</p>
        <h1>سجلي الأكاديمي</h1>
        <p className="muted">بياناتك الأساسية وصفك وبرنامجك وجلستك الأكاديمية.</p>
      </div>
      <div className="actions">
        <Link className="button secondary" to="/portal/modules/courses">المقررات</Link>
        <button className="button secondary" onClick={() => setRetry((value) => value + 1)} disabled={state.status === "loading"}>تحديث</button>
      </div>
    </div>

    {state.status === "loading" && <p role="status">جارٍ تحميل سجلك...</p>}
    {state.status === "error" && <section className="panel">
      <p className="error-box" role="alert">تعذر تحميل سجلك الأكاديمي: {state.error}</p>
      <div className="actions" style={{ marginTop: 12 }}>
        <button className="button secondary" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button>
      </div>
    </section>}

    {state.status === "ready" && !record && <section className="panel">
      <h2>لا يوجد سجل طالب مرتبط بحسابك</h2>
      <p className="muted">لم نجد سجلاً مربوطاً بحسابك، أو أن الربط لم يُعتمد بعد.</p>
      <p className="data-note">تواصل مع شؤون الطلاب لربط حساب الدخول بسجل الطالب.</p>
    </section>}

    {record && <RecordCard record={record} action />}

    {record && <div className="learner-links">
      <Link className="button primary" to="/portal/modules/courses">فتح المقررات</Link>
      <Link className="button secondary" to="/portal/modules/homework">الواجبات</Link>
      <Link className="button secondary" to="/portal/modules/attendance">الحضور</Link>
      <Link className="button secondary" to="/portal/modules/progress">التقدم والأداء</Link>
    </div>}
  </main>;
}