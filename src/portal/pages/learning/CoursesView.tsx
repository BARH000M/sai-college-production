import { useMemo, useState } from "react";
import {
  lessonKindLabels, lessonStatusLabels, saveLessonProgress, statusForLesson,
  type LearningScope, type LearningCourse, type LessonStatus,
} from "@/portal/lib/learning";
import { LessonContent } from "@/portal/pages/learning/LessonContent";
import { CourseVocabularyPanel } from "@/portal/pages/learning/CourseVocabularyPanel";

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

export function CoursesView({ scope }: { scope: LearningScope }) {
  const { workspace, mode, learnerId, canTrack, canManageContent } = scope;
  const learner = workspace.students.find((student) => student.id === learnerId) ?? null;
  const [selectedId, setSelectedId] = useState("");
  const [openLessonId, setOpenLessonId] = useState("");
  const [savingLesson, setSavingLesson] = useState("");
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const courses = useMemo(() => (mode === "staff"
    ? workspace.courses
    : workspace.courses.filter((course) => course.class_id === learner?.class_id)), [mode, workspace.courses, learner?.class_id]);

  const active = courses.find((course) => course.id === selectedId) ?? courses[0] ?? null;
  const lessons = active
    ? workspace.lessons.filter((lesson) => lesson.course_id === active.id).sort((a, b) => a.position - b.position)
    : [];

  const classStudents = active
    ? workspace.students.filter((student) => student.class_id === active.class_id)
    : [];

  const classOf = (course: LearningCourse) => workspace.classes.find((item) => item.id === course.class_id) ?? null;

  function courseStat(course: LearningCourse) {
    const courseLessons = workspace.lessons.filter((lesson) => lesson.course_id === course.id);
    if (mode === "staff") {
      const ids = new Set(courseLessons.map((lesson) => lesson.id));
      const students = workspace.students.filter((student) => student.class_id === course.class_id);
      const slots = courseLessons.length * students.length;
      if (!slots) return { label: "لا يوجد طلبة", percent: 0 };
      const done = workspace.progress.filter((row) => ids.has(row.lesson_id) && row.status === "completed").length;
      return { label: `${done} من ${slots} إنجاز`, percent: Math.round((done / slots) * 100) };
    }
    const ids = new Set(courseLessons.map((lesson) => lesson.id));
    const rows = workspace.progress.filter((row) => ids.has(row.lesson_id) && row.student_id === learnerId);
    const done = rows.filter((row) => row.status === "completed").length;
    return {
      label: `${done} من ${courseLessons.length} دروس`,
      percent: courseLessons.length ? Math.round((done / courseLessons.length) * 100) : 0,
    };
  }

  async function changeStatus(lessonId: string, status: LessonStatus) {
    if (!learner || !canTrack || savingLesson) return;
    setSavingLesson(lessonId); setError(null); setNotice(null);
    try {
      await saveLessonProgress(lessonId, learner.id, status);
      setNotice(status === "completed" ? "سُجّل الدرس كمكتمل." : "حُدّثت حالة الدرس.");
      scope.reload();
    } catch (failure) {
      setError(message(failure));
    } finally {
      setSavingLesson("");
    }
  }

  if (!courses.length) {
    return <section className="panel learn-empty">
      <h2>لا توجد مقررات متاحة</h2>
      <p className="muted">{mode === "staff"
        ? "لم تُسجَّل مقررات في الصفوف المتاحة لدورك بعد."
        : "لم يُسجَّل مقرر لصفك الدراسي بعد. سيظهر هنا فور إضافته من إدارة الأكاديمية."}</p>
    </section>;
  }

  return <>
    <section className="panel">
      <h2>المقررات المتاحة</h2>
      <p className="data-note">اختر مقرراً لعرض دروسه بالترتيب.</p>
      <div className="learn-course-grid">
        {courses.map((course) => {
          const stat = courseStat(course);
          const cls = classOf(course);
          return <button
            type="button"
            key={course.id}
            className={`learn-course ${active?.id === course.id ? "active" : ""}`}
            onClick={() => { setSelectedId(course.id); setNotice(null); setError(null); }}
          >
            <strong>{course.title}</strong>
            <small>{cls ? `${cls.name} · ${cls.program}` : "صف غير معروف"}</small>
            <span className="learn-bar" aria-hidden="true"><span style={{ width: `${stat.percent}%` }} /></span>
            <small className="learn-course-stat">{stat.label} · {stat.percent}%</small>
          </button>;
        })}
      </div>
    </section>

    {notice && <p className="success-box" role="status">{notice}</p>}
    {error && <p className="error-box" role="alert">تعذر حفظ حالة الدرس: {error}</p>}

    {active && <section className="panel">
      <div className="page-heading">
        <div>
          <h2>{active.title}</h2>
          <p className="muted">{active.description ?? "لا يوجد وصف لهذا المقرر."}</p>
        </div>
        <span className="learn-pill">{active.level ?? "مستوى غير محدد"}</span>
      </div>
      {mode === "staff" && <p className="data-note">{classStudents.length} طالباً في الصف · {lessons.length} دروس.</p>}
      <ol className="learn-lessons">
        {lessons.map((lesson) => {
          const status = statusForLesson(workspace.progress, lesson.id, learnerId);
          const doneCount = workspace.progress.filter((row) => row.lesson_id === lesson.id && row.status === "completed").length;
          return <li className="learn-lesson" key={lesson.id}>
            <span className="learn-lesson-index">{lesson.position}</span>
            <div className="learn-lesson-body">
              <div className="learn-lesson-head">
                <strong>{lesson.title}</strong>
                <span className="learn-tag">{lessonKindLabels[lesson.kind] ?? lesson.kind}</span>
              </div>
              {lesson.summary && <p className="learn-lesson-summary">{lesson.summary}</p>}
              <small className="learn-meta">{lesson.duration_minutes} دقيقة</small>
            </div>
            <div className="learn-lesson-side">
              {mode === "staff"
                ? <span className="learn-pill">{doneCount} / {classStudents.length} أكملوا</span>
                : <span className={`learn-pill learn-status-${status}`}>{lessonStatusLabels[status]}</span>}
              <div className="actions">
                <button
                  type="button"
                  className="button secondary"
                  aria-expanded={openLessonId === lesson.id}
                  onClick={() => setOpenLessonId(openLessonId === lesson.id ? "" : lesson.id)}
                >{openLessonId === lesson.id ? "إغلاق الدرس" : "فتح الدرس"}</button>
                {canTrack && learner && <>
                  {status !== "completed" && <button
                    type="button"
                    className="button primary"
                    disabled={!!savingLesson}
                    onClick={() => void changeStatus(lesson.id, "completed")}
                  >{savingLesson === lesson.id ? "جارٍ الحفظ..." : "إكمال الدرس"}</button>}
                  {status === "completed" && <button
                    type="button"
                    className="button secondary"
                    disabled={!!savingLesson}
                    onClick={() => void changeStatus(lesson.id, "not_started")}
                  >إلغاء الإكمال</button>}
                  {status === "not_started" && <button
                    type="button"
                    className="button secondary"
                    disabled={!!savingLesson}
                    onClick={() => void changeStatus(lesson.id, "in_progress")}
                  >بدء الدراسة</button>}
                </>}
              </div>
            </div>
            {openLessonId === lesson.id && <LessonContent
              key={lesson.id}
              lesson={lesson}
              canManage={canManageContent}
              onSaved={scope.reload}
            />}
          </li>;
        })}
      </ol>
      {!lessons.length && <p className="muted">لم تُضف دروس لهذا المقرر بعد.</p>}

      {canManageContent && <CourseVocabularyPanel key={active.id} course={active} lessons={lessons} />}
    </section>}
  </>;
}