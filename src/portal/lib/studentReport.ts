import { supabase } from "./supabase";
import { attendanceStatuses, type AttendanceStatus } from "./attendance";

export type ReportCourse = {
  id: string;
  title: string;
  level: string | null;
  totalLessons: number;
  completed: number;
  percent: number;
};

export type ReportHomework = {
  title: string;
  courseTitle: string;
  dueAt: string;
  done: boolean;
  overdue: boolean;
  statusLabel: string;
};

export type ReportGrade = {
  homeworkTitle: string;
  courseTitle: string;
  score: number;
  maxScore: number;
  percent: number;
  feedback: string | null;
};

export type ReportAttendance = { label: string; count: number };

export type StudentReport = {
  student: { full_name: string; admission_no: string; status: string };
  className: string | null;
  branchName: string | null;
  courses: ReportCourse[];
  overallPercent: number;
  homework: ReportHomework[];
  homeworkDone: number;
  homeworkPending: number;
  grades: ReportGrade[];
  averageGrade: number | null;
  attendance: ReportAttendance[];
  attendanceTotal: number;
};

function num(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

export async function loadStudentReport(studentId: string): Promise<StudentReport> {
  const studentRes = await supabase
    .from("students")
    .select("id,full_name,admission_no,status,class_id,branch_id")
    .eq("id", studentId)
    .maybeSingle();
  if (studentRes.error) throw new Error(studentRes.error.message);
  if (!studentRes.data) throw new Error("سجل الطالب غير موجود.");
  const student = studentRes.data as {
    id: string; full_name: string; admission_no: string; status: string;
    class_id: string | null; branch_id: string;
  };

  const [classRes, branchRes] = await Promise.all([
    student.class_id
      ? supabase.from("classes").select("name").eq("id", student.class_id).maybeSingle()
      : Promise.resolve({ data: null, error: null } as const),
    supabase.from("branches").select("name").eq("id", student.branch_id).maybeSingle(),
  ]);
  if (classRes.error) throw new Error(classRes.error.message);
  if (branchRes.error) throw new Error(branchRes.error.message);
  const className = (classRes.data as { name?: string } | null)?.name ?? null;
  const branchName = (branchRes.data as { name?: string } | null)?.name ?? null;

  let courses: ReportCourse[] = [];
  let homework: ReportHomework[] = [];
  let grades: ReportGrade[] = [];
  let overallPercent = 0;
  let averageGrade: number | null = null;

  if (student.class_id) {
    const courseRes = await supabase
      .from("learning_courses")
      .select("id,title,level")
      .eq("class_id", student.class_id)
      .eq("is_active", true)
      .order("title");
    if (courseRes.error) throw new Error(courseRes.error.message);
    const courseRows = (courseRes.data ?? []) as { id: string; title: string; level: string | null }[];
    const courseIds = courseRows.map((c) => c.id);
    const titleById = new Map(courseRows.map((c) => [c.id, c.title]));

    const [lessonRes, progressRes, homeworkRes, submissionRes] = await Promise.all([
      courseIds.length
        ? supabase.from("learning_lessons").select("id,course_id").in("course_id", courseIds).eq("is_published", true)
        : Promise.resolve({ data: [], error: null } as const),
      supabase.from("learning_lesson_progress").select("lesson_id,status").eq("student_id", studentId),
      courseIds.length
        ? supabase.from("learning_homework").select("id,course_id,title,due_at").in("course_id", courseIds).eq("is_published", true).order("due_at")
        : Promise.resolve({ data: [], error: null } as const),
      supabase.from("learning_homework_submissions").select("homework_id,status,score,feedback").eq("student_id", studentId),
    ]);
    if (lessonRes.error) throw new Error(lessonRes.error.message);
    if (progressRes.error) throw new Error(progressRes.error.message);
    if (homeworkRes.error) throw new Error(homeworkRes.error.message);
    if (submissionRes.error) throw new Error(submissionRes.error.message);

    const lessons = (lessonRes.data ?? []) as { id: string; course_id: string }[];
    const progress = (progressRes.data ?? []) as { lesson_id: string; status: string }[];
    const completedLessonIds = new Set(progress.filter((p) => p.status === "completed").map((p) => p.lesson_id));
    const homeworkRows = (homeworkRes.data ?? []) as { id: string; course_id: string; title: string; due_at: string }[];
    const submissions = (submissionRes.data ?? []) as {
      homework_id: string; status: string; score: number | null; feedback: string | null;
    }[];
    const subByHw = new Map(submissions.map((s) => [s.homework_id, s]));

    courses = courseRows.map((course) => {
      const courseLessons = lessons.filter((l) => l.course_id === course.id);
      const completed = courseLessons.filter((l) => completedLessonIds.has(l.id)).length;
      const total = courseLessons.length;
      return {
        id: course.id,
        title: course.title,
        level: course.level,
        totalLessons: total,
        completed,
        percent: total ? Math.round((completed / total) * 100) : 0,
      };
    });
    const totalLessons = courses.reduce((s, c) => s + c.totalLessons, 0);
    const totalCompleted = courses.reduce((s, c) => s + c.completed, 0);
    overallPercent = totalLessons ? Math.round((totalCompleted / totalLessons) * 100) : 0;

    const now = Date.now();
    homework = homeworkRows.map((hw) => {
      const sub = subByHw.get(hw.id);
      const done = !!sub && (sub.status === "submitted" || sub.status === "graded" || sub.status === "returned");
      const overdue = !done && new Date(hw.due_at).getTime() < now;
      const statusLabel = done
        ? (sub?.status === "graded" ? "مُصحَّح" : sub?.status === "returned" ? "أُعيد للمراجعة" : "مُسلَّم")
        : overdue ? "متأخر" : "مستحق";
      return { title: hw.title, courseTitle: titleById.get(hw.course_id) ?? "—", dueAt: hw.due_at, done, overdue, statusLabel };
    });

    // Grades: use the homework max_score; fetch it for graded submissions.
    const gradedSubs = submissions.filter((s) => s.status === "graded" && s.score !== null);
    if (gradedSubs.length) {
      const hwIds = gradedSubs.map((s) => s.homework_id);
      const maxRes = await supabase.from("learning_homework").select("id,title,course_id,max_score").in("id", hwIds);
      if (maxRes.error) throw new Error(maxRes.error.message);
      const hwInfo = new Map((maxRes.data ?? []).map((row: { id: string; title: string; course_id: string; max_score: number }) =>
        [row.id, row]));
      grades = gradedSubs.map((s) => {
        const info = hwInfo.get(s.homework_id);
        const max = num(info?.max_score) || 100;
        const score = num(s.score);
        return {
          homeworkTitle: info?.title ?? "—",
          courseTitle: info ? (titleById.get(info.course_id) ?? "—") : "—",
          score,
          maxScore: max,
          percent: max ? Math.round((score / max) * 100) : 0,
          feedback: s.feedback,
        };
      });
      const avg = grades.reduce((s, g) => s + g.percent, 0) / grades.length;
      averageGrade = Math.round(avg);
    }
  }

  const attendanceRes = await supabase
    .from("attendance_records")
    .select("status")
    .eq("student_id", studentId);
  if (attendanceRes.error) throw new Error(attendanceRes.error.message);
  const records = (attendanceRes.data ?? []) as { status: string }[];
  const attendance: ReportAttendance[] = (Object.keys(attendanceStatuses) as AttendanceStatus[]).map((key) => ({
    label: attendanceStatuses[key],
    count: records.filter((r) => r.status === key).length,
  }));
  const attendanceTotal = records.length;

  const homeworkDone = homework.filter((h) => h.done).length;
  const homeworkPending = homework.length - homeworkDone;

  return {
    student: { full_name: student.full_name, admission_no: student.admission_no, status: student.status },
    className, branchName, courses, overallPercent,
    homework, homeworkDone, homeworkPending,
    grades, averageGrade, attendance, attendanceTotal,
  };
}