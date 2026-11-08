import { PrintDoc } from "@/portal/pages/academics/PrintDoc";
import { printReference } from "@/portal/lib/letterhead";
import { attendanceStatuses, type AttendanceSession, type AttendanceStatus } from "@/portal/lib/attendance";

export type RegisterEntry = {
  key: string;
  name: string;
  status: AttendanceStatus | null;
  note: string | null;
  saved: boolean;
};

/**
 * Printable class register for one attendance session, printed on the shared
 * centred letterhead so it can be filed with the other official college sheets.
 */
export function AttendanceRegisterSheet({
  session, className, branchName, entries, onClose,
}: {
  session: AttendanceSession;
  className: string;
  branchName: string;
  entries: readonly RegisterEntry[];
  onClose: () => void;
}) {
  const count = (status: AttendanceStatus) => entries.filter((entry) => entry.status === status).length;
  const recorded = entries.filter((entry) => entry.status).length;
  const unrecorded = entries.length - recorded;

  return <PrintDoc
    title="كشف حضور الصف"
    subtitle={`${className} · ${branchName} · ${session.attendance_date}`}
    onClose={onClose}
  >
    <div className="sheet-summary">
      <div><span>الصف</span><strong>{className}</strong></div>
      <div><span>الفرع</span><strong>{branchName}</strong></div>
      <div><span>تاريخ الحضور</span><strong>{session.attendance_date}</strong></div>
      <div><span>حالة الجلسة</span><strong>{session.status === "open" ? "مفتوحة" : session.status === "closed" ? "مغلقة" : "ملغاة"}</strong></div>
    </div>

    <div className="sheet-summary">
      <div><span>حاضر</span><strong>{count("present")}</strong></div>
      <div><span>غائب</span><strong>{count("absent")}</strong></div>
      <div><span>متأخر</span><strong>{count("late")}</strong></div>
      <div><span>بعذر</span><strong>{count("excused")}</strong></div>
    </div>

    <div className="report-section">
      <strong className="report-heading">
        سجل الطلاب ({entries.length} طالباً · {recorded} مسجل · {unrecorded} بلا حالة)
      </strong>
      <div className="table-scroll">
        <table className="sheet-table attendance-sheet-table">
          <thead>
            <tr>
              <th className="sheet-col-index">#</th>
              <th>اسم الطالب</th>
              <th>الحالة</th>
              <th>ملاحظة المعلم</th>
              <th className="sheet-sign-cell">التوقيع</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((entry, index) => <tr key={entry.key}>
              <td className="sheet-col-index">{index + 1}</td>
              <td><strong>{entry.name}</strong></td>
              <td>{entry.status ? attendanceStatuses[entry.status] : "—"}</td>
              <td>{entry.note?.trim() || "—"}</td>
              <td className="sheet-sign-cell" />
            </tr>)}
          </tbody>
        </table>
      </div>
    </div>

    <p className="sheet-note">
      يُعتمد هذا الكشف بعد توقيع معلم الصف. أي تصحيح لاحق يحتاج إلى مسار تصحيح رسمي مع ذكر السبب،
      ويُحفظ سجل التعديل في قاعدة البيانات. مرجع الكشف: {printReference("ATT")}.
    </p>

    <div className="receipt-signatures">
      <div><span>معلم الصف</span></div>
      <div><span>اعتماد الشؤون الأكاديمية</span></div>
    </div>
  </PrintDoc>;
}