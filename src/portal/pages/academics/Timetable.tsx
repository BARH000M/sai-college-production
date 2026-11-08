import { useMemo, useState } from "react";
import {
  academicBranchOptions, academicClassOptions, calendarEvents, periodSlots, weekDays, weeklyLessons,
} from "@/mocks/academics";
import { LabTabs } from "@/portal/pages/labs/LabShell";
import { PrintDoc } from "@/portal/pages/academics/PrintDoc";

type View = "week" | "month";

const calendarWeekdays = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"];
const monthLabel = "نوفمبر 2026";
const monthYear = 2026;
const monthIndex = 10;

const typeLabels: Record<string, string> = {
  exam: "اختبار",
  event: "فعالية",
  holiday: "إجازة",
  meeting: "اجتماع",
  deadline: "موعد تسليم",
};

function isoDay(day: number): string {
  return `${monthYear}-${String(monthIndex + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function formatArabicDate(date: string): string {
  const parsed = new Date(`${date}T00:00:00`);
  if (Number.isNaN(parsed.getTime())) return date;
  return parsed.toLocaleDateString("ar-EG", { weekday: "long", day: "numeric", month: "long", year: "numeric" });
}

function WeekGrid({ classId }: { classId: string }) {
  return <div className="timetable-wrap">
    <table className="timetable">
      <thead>
        <tr>
          <th scope="col">الحصة</th>
          {weekDays.map((day) => <th key={day.id} scope="col">{day.label}</th>)}
        </tr>
      </thead>
      <tbody>
        {periodSlots.map((slot) => <tr key={slot.id}>
          <th scope="row" className="timetable-period">
            <strong>{slot.label}</strong>
            <span dir="ltr">{slot.time}</span>
          </th>
          {weekDays.map((day) => {
            const lesson = weeklyLessons.find((row) => row.classId === classId && row.day === day.id && row.period === slot.id);
            return <td key={`${slot.id}-${day.id}`}>
              {lesson
                ? <div className={`timetable-slot kind-${lesson.kind}`}>
                    <strong>{lesson.subject}</strong>
                    <span>{lesson.teacher}</span>
                    <small><i className="ri-map-pin-line" aria-hidden="true"></i> {lesson.room}</small>
                  </div>
                : <span className="timetable-free">—</span>}
            </td>;
          })}
        </tr>)}
      </tbody>
    </table>
  </div>;
}

export function Timetable() {
  const [branch, setBranch] = useState(academicBranchOptions[0].id);
  const [classId, setClassId] = useState(academicClassOptions[0].id);
  const [view, setView] = useState<View>("week");
  const [selectedDate, setSelectedDate] = useState("2026-11-11");
  const [printOpen, setPrintOpen] = useState(false);

  const activeClass = academicClassOptions.find((row) => row.id === classId) ?? academicClassOptions[0];
  const branchName = academicBranchOptions.find((row) => row.id === branch)?.name ?? academicBranchOptions[0].name;

  const eventsByDay = useMemo(() => {
    const map: Record<string, typeof calendarEvents> = {};
    calendarEvents.forEach((event) => {
      map[event.date] = [...(map[event.date] ?? []), event];
    });
    return map;
  }, []);

  const selectedEvents = eventsByDay[selectedDate] ?? [];

  const firstWeekday = new Date(monthYear, monthIndex, 1).getDay();
  const daysInMonth = new Date(monthYear, monthIndex + 1, 0).getDate();
  const cells: (number | null)[] = [
    ...Array.from({ length: firstWeekday }, () => null),
    ...Array.from({ length: daysInMonth }, (_, index) => index + 1),
  ];
  while (cells.length % 7 !== 0) cells.push(null);

  const weekLessonCount = weeklyLessons.filter((row) => row.classId === classId).length;

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">الشؤون الأكاديمية</p>
        <h1>الجداول والتقويم</h1>
        <p className="muted">جدول الحصص الأسبوعي وتقويم الاختبارات والفعاليات والمواعيد الرسمية للكلية.</p>
      </div>
      <button className="button secondary" type="button" onClick={() => setPrintOpen(true)}>
        <i className="ri-printer-line" aria-hidden="true"></i> طباعة الجدول
      </button>
    </div>

    <fieldset className="context-card">
      <label>الفرع
        <select value={branch} onChange={(event) => setBranch(event.target.value)}>
          {academicBranchOptions.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
        </select>
      </label>
      <label>الصف / الشعبة
        <select value={classId} onChange={(event) => setClassId(event.target.value)}>
          {academicClassOptions.map((row) => <option key={row.id} value={row.id}>{row.name}</option>)}
        </select>
      </label>
      <label>عرض التقويم
        <select value={view} onChange={(event) => setView(event.target.value as View)}>
          <option value="week">الجدول الأسبوعي</option>
          <option value="month">تقويم الشهر</option>
        </select>
      </label>
      <div className="actions" style={{ alignSelf: "end" }}>
        <span className="learn-pill">{weekLessonCount} حصة أسبوعية</span>
      </div>
    </fieldset>

    <LabTabs<View>
      label="طريقة عرض الجدول"
      tabs={[{ id: "week", label: "الجدول الأسبوعي", icon: "ri-calendar-2-line" }, { id: "month", label: "تقويم نوفمبر 2026", icon: "ri-calendar-event-line" }]}
      value={view}
      onChange={setView}
    />

    {view === "week" && <section className="panel">
      <div className="page-heading">
        <div>
          <h2>جدول {activeClass.name} · {branchName}</h2>
          <p className="data-note">المعلم المسؤول: {activeClass.teacher} · {activeClass.students} طالباً · الأسبوع من 8 إلى 14 نوفمبر 2026.</p>
        </div>
        <div className="timetable-legend">
          <span><i className="legend-dot kind-core" aria-hidden="true"></i> مادة أساسية</span>
          <span><i className="legend-dot kind-lab" aria-hidden="true"></i> مختبر لغة</span>
          <span><i className="legend-dot kind-general" aria-hidden="true"></i> مادة عامة</span>
          <span><i className="legend-dot kind-culture" aria-hidden="true"></i> ثقافة</span>
        </div>
      </div>
      <WeekGrid classId={classId} />
    </section>}

    {view === "month" && <div className="lab-split">
      <section className="panel">
        <div className="page-heading">
          <div><h2>تقويم {monthLabel}</h2><p className="data-note">اضغط على أي يوم لعرض تفاصيله.</p></div>
          <span className="learn-pill">{calendarEvents.length} مناسبة هذا الشهر</span>
        </div>
        <div className="calendar-grid calendar-head" aria-hidden="true">
          {calendarWeekdays.map((day) => <span key={day}>{day}</span>)}
        </div>
        <div className="calendar-grid" role="grid" aria-label={`تقويم ${monthLabel}`}>
          {cells.map((day, index) => {
            if (!day) return <span key={`empty-${index}`} className="calendar-day calendar-empty" aria-hidden="true"></span>;
            const date = isoDay(day);
            const dayEvents = eventsByDay[date] ?? [];
            const isToday = date === "2026-11-08";
            return <button
              key={date}
              type="button"
              className={`calendar-day${date === selectedDate ? " selected" : ""}${isToday ? " today" : ""}${dayEvents.length ? " has-event" : ""}`}
              aria-pressed={date === selectedDate}
              onClick={() => setSelectedDate(date)}
            >
              <span className="calendar-number">{day}</span>
              {dayEvents.length > 0 && <span className="calendar-dots">
                {dayEvents.slice(0, 3).map((event) => <i key={event.id} className={`legend-dot type-${event.type}`} aria-hidden="true"></i>)}
              </span>}
            </button>;
          })}
        </div>
      </section>

      <section className="panel">
        <h2>{formatArabicDate(selectedDate)}</h2>
        {selectedEvents.length === 0
          ? <p className="muted">لا توجد مناسبات مسجلة في هذا اليوم. الأيام الملوّنة في التقويم تحتوي على فعاليات أو اختبارات.</p>
          : <ul className="lab-list">
              {selectedEvents.map((event) => <li key={event.id} className="lab-item">
                <div className="lab-item-head">
                  <span className={`event-type type-${event.type}`}>{typeLabels[event.type] ?? event.type}</span>
                  <strong>{event.title}</strong>
                </div>
                <p className="lab-item-text">{event.note}</p>
                <div className="lab-meta-row">
                  <span><i className="ri-time-line" aria-hidden="true"></i> {event.time}</span>
                  <span><i className="ri-map-pin-line" aria-hidden="true"></i> {event.place}</span>
                </div>
              </li>)}
            </ul>}
        <div className="calendar-legend">
          <span><i className="legend-dot type-exam" aria-hidden="true"></i> اختبار</span>
          <span><i className="legend-dot type-event" aria-hidden="true"></i> فعالية</span>
          <span><i className="legend-dot type-holiday" aria-hidden="true"></i> إجازة</span>
          <span><i className="legend-dot type-meeting" aria-hidden="true"></i> اجتماع</span>
          <span><i className="legend-dot type-deadline" aria-hidden="true"></i> موعد تسليم</span>
        </div>
      </section>
    </div>}

    <section className="panel">
      <h2>أقرب المناسبات</h2>
      <ul className="lab-compact-list">
        {calendarEvents.slice(0, 5).map((event) => <li key={event.id}>
          <time dateTime={event.date}>{formatArabicDate(event.date)}</time>
          <span className={`event-type type-${event.type}`}>{typeLabels[event.type] ?? event.type}</span>
          <strong>{event.title}</strong>
          <span className="lab-meta-row"><i className="ri-map-pin-line" aria-hidden="true"></i> {event.place}</span>
        </li>)}
      </ul>
    </section>

    {printOpen && <PrintDoc
      title="الجدول الأسبوعي للحصص"
      subtitle={`${activeClass.name} · ${branchName} · ${activeClass.program}`}
      archive={{ term: "الفصل الأول 2026/2027", preparedBy: activeClass.teacher }}
      onClose={() => setPrintOpen(false)}
    >
      <WeekGrid classId={classId} />
      <p className="sheet-note">هذا الجدول صادر عن الشؤون الأكاديمية ويعتمد التوزيع المعتمد للفصل الأول. أي تعديل يُنشر إشعاره للطلاب وأولياء الأمور.</p>
      <div className="receipt-signatures">
        <div><span>إعداد: {activeClass.teacher}</span></div>
        <div><span>اعتماد الشؤون الأكاديمية</span></div>
      </div>
    </PrintDoc>}
  </main>;
}