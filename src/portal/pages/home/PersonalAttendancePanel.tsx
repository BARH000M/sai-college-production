import { useEffect, useState } from "react";
import {
  attendanceStatuses, loadPersonalAttendance, type PersonalAttendance,
} from "../../lib/attendance";
import { formatDate } from "./dateFormat";

type State =
  | { status: "loading"; data: null; error: null }
  | { status: "ready"; data: PersonalAttendance; error: null }
  | { status: "error"; data: null; error: string };

export function PersonalAttendancePanel({ studentId }: { studentId: string }) {
  const [state, setState] = useState<State>({ status: "loading", data: null, error: null });
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setState({ status: "loading", data: null, error: null });
    void loadPersonalAttendance(studentId)
      .then((data) => { if (active) setState({ status: "ready", data, error: null }); })
      .catch((failure: unknown) => {
        if (active) setState({
          status: "error",
          data: null,
          error: failure instanceof Error ? failure.message : String(failure),
        });
      });
    return () => { active = false; };
  }, [studentId, retry]);

  return <section id={`personal-attendance-${studentId}`} className="panel" aria-labelledby={`attendance-${studentId}`}>
    <div className="home-panel-head">
      <div>
        <h2 id={`attendance-${studentId}`}>الحضور الشخصي</h2>
        <p className="data-note">تُحمّل السجلات المرتبطة بهذا الطالب فقط، وتظل سياسات Supabase هي جهة التفويض.</p>
      </div>
      <button className="text-button" type="button" onClick={() => setRetry((value) => value + 1)}
        disabled={state.status === "loading"}>تحديث</button>
    </div>

    {state.status === "loading" && <p role="status">جارٍ تحميل سجل الحضور الشخصي...</p>}
    {state.status === "error" && <div>
      <p className="error-box" role="alert">تعذر تحميل سجل الحضور: {state.error}</p>
      <button className="text-button" type="button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button>
    </div>}
    {state.status === "ready" && <>
      <p className="learn-score">إجمالي السجلات المتاحة: <strong>{state.data.total.toLocaleString("ar")}</strong></p>
      {!state.data.recent.length
        ? <p className="muted">لا توجد سجلات حضور متاحة لهذا الطالب.</p>
        : <div className="table-scroll">
          <table className="management-table">
            <thead><tr><th>التاريخ</th><th>الحالة</th><th>ملاحظة</th></tr></thead>
            <tbody>{state.data.recent.slice(0, 10).map((item) => <tr key={item.id}>
              <td>{formatDate(item.attendanceDate)}</td>
              <td>{attendanceStatuses[item.status]}</td>
              <td>{item.note ?? "—"}</td>
            </tr>)}</tbody>
          </table>
        </div>}
      {!!state.data.recent.length && <p className="data-note">تعرض هذه اللوحة أحدث 10 سجلات شخصية؛ الإجمالي محسوب من قاعدة البيانات.</p>}
    </>}
  </section>;
}
