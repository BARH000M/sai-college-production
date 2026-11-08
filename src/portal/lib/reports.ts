import { supabase } from "./supabase";
import { attendanceStatuses } from "./attendance";
import { loadAdmissionRoster, type AdmissionRosterRow } from "./admissions";

export type ReportOption = { id: string; name: string };

export type EnrollmentRow = {
  id: string;
  full_name: string;
  admission_no: string;
  status: string;
  date_of_birth: string | null;
};

export type EnrollmentReport = {
  className: string;
  branchName: string;
  capacity: number | null;
  rows: EnrollmentRow[];
  counts: { active: number; inactive: number; graduated: number; withdrawn: number; total: number };
};

export type AttendanceRow = {
  studentId: string;
  full_name: string;
  admission_no: string;
  counts: Record<string, number>;
  total: number;
  percent: number;
};

export type AttendanceReport = {
  className: string;
  from: string;
  to: string;
  sessionCount: number;
  rows: AttendanceRow[];
  totals: Record<string, number>;
  totalRecords: number;
};

export type HomeworkReportRow = {
  id: string;
  title: string;
  courseTitle: string;
  dueAt: string;
  maxScore: number;
  graded: number;
  submitted: number;
  pending: number;
};

export type HomeworkReport = {
  className: string;
  rosterSize: number;
  rows: HomeworkReportRow[];
  totalGraded: number;
  totalSubmitted: number;
  totalPending: number;
};

export type AdmissionsReport = {
  rows: AdmissionRosterRow[];
  counts: Record<string, number>;
  total: number;
  from: string;
  to: string;
};

export type DistributionRow = {
  branchName: string;
  program: string;
  classCount: number;
  active: number;
  other: number;
  total: number;
};

export type DistributionReport = {
  rows: DistributionRow[];
  branchTotals: { branchName: string; active: number; other: number; total: number }[];
  programTotals: { program: string; active: number; other: number; total: number }[];
  totals: { active: number; other: number; total: number; classes: number; branches: number; programs: number };
};

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function reportError(context: string, error: unknown): string {
  return `${context}: ${message(error)}`;
}

export async function loadReportBranches(): Promise<ReportOption[]> {
  const result = await supabase.from("branches").select("id,name").eq("is_active", true).order("name");
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as ReportOption[];
}

export async function loadReportSessions(): Promise<ReportOption[]> {
  const result = await supabase.from("academic_sessions").select("id,name").eq("is_active", true).order("name");
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as ReportOption[];
}

export async function loadReportClasses(branch: string, session: string): Promise<ReportOption[]> {
  if (!branch || !session) return [];
  const result = await supabase.from("classes").select("id,name")
    .eq("branch_id", branch).eq("session_id", session).eq("is_active", true).order("name");
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as ReportOption[];
}

async function loadClassContext(classId: string): Promise<{
  className: string; branchName: string; capacity: number | null; branchId: string;
}> {
  const classRes = await supabase.from("classes").select("name,branch_id,capacity").eq("id", classId).maybeSingle();
  if (classRes.error) throw new Error(classRes.error.message);
  if (!classRes.data) throw new Error("الصف المحدد غير متاح.");
  const row = classRes.data as { name: string; branch_id: string; capacity: number | null };
  const branchRes = await supabase.from("branches").select("name").eq("id", row.branch_id).maybeSingle();
  if (branchRes.error) throw new Error(branchRes.error.message);
  const branchName = (branchRes.data as { name?: string } | null)?.name ?? "—";
  return { className: row.name, branchName, capacity: row.capacity, branchId: row.branch_id };
}

export async function loadEnrollmentReport(classId: string): Promise<EnrollmentReport> {
  const context = await loadClassContext(classId);
  const result = await supabase.from("students")
    .select("id,full_name,admission_no,status,date_of_birth")
    .eq("class_id", classId)
    .order("full_name");
  if (result.error) throw new Error(result.error.message);
  const rows = (result.data ?? []) as EnrollmentRow[];
  const count = (status: string) => rows.filter((row) => row.status === status).length;
  return {
    className: context.className,
    branchName: context.branchName,
    capacity: context.capacity,
    rows,
    counts: {
      active: count("active"),
      inactive: count("inactive"),
      graduated: count("graduated"),
      withdrawn: count("withdrawn"),
      total: rows.length,
    },
  };
}

const statusKeys = Object.keys(attendanceStatuses);

export async function loadAttendanceReport(classId: string, from: string, to: string): Promise<AttendanceReport> {
  const context = await loadClassContext(classId);
  const rosterRes = await supabase.from("students")
    .select("id,full_name,admission_no").eq("class_id", classId).eq("status", "active").order("full_name");
  if (rosterRes.error) throw new Error(rosterRes.error.message);
  const roster = (rosterRes.data ?? []) as { id: string; full_name: string; admission_no: string }[];

  const sessionRes = await supabase.from("attendance_sessions")
    .select("id,attendance_date")
    .eq("class_id", classId)
    .gte("attendance_date", from)
    .lte("attendance_date", to)
    .order("attendance_date");
  if (sessionRes.error) throw new Error(sessionRes.error.message);
  const sessions = (sessionRes.data ?? []) as { id: string; attendance_date: string }[];

  let records: { student_id: string; status: string }[] = [];
  if (sessions.length) {
    const recordRes = await supabase.from("attendance_records")
      .select("student_id,status")
      .in("attendance_session_id", sessions.map((session) => session.id));
    if (recordRes.error) throw new Error(recordRes.error.message);
    records = (recordRes.data ?? []) as { student_id: string; status: string }[];
  }

  const totals: Record<string, number> = {};
  statusKeys.forEach((key) => { totals[key] = 0; });
  records.forEach((record) => {
    if (record.status in totals) totals[record.status] += 1;
  });

  const rows: AttendanceRow[] = roster.map((student) => {
    const counts: Record<string, number> = {};
    statusKeys.forEach((key) => { counts[key] = 0; });
    let total = 0;
    records.forEach((record) => {
      if (record.student_id !== student.id) return;
      if (record.status in counts) counts[record.status] += 1;
      total += 1;
    });
    const attended = (counts.present ?? 0) + (counts.excused ?? 0);
    return {
      studentId: student.id,
      full_name: student.full_name,
      admission_no: student.admission_no,
      counts,
      total,
      percent: total ? Math.round((attended / total) * 100) : 0,
    };
  });

  return {
    className: context.className,
    from,
    to,
    sessionCount: sessions.length,
    rows,
    totals,
    totalRecords: records.length,
  };
}

export async function loadHomeworkReport(classId: string): Promise<HomeworkReport> {
  const context = await loadClassContext(classId);
  const rosterRes = await supabase.from("students")
    .select("id", { count: "exact", head: true }).eq("class_id", classId).eq("status", "active");
  if (rosterRes.error) throw new Error(rosterRes.error.message);
  const rosterSize = rosterRes.count ?? 0;

  const courseRes = await supabase.from("learning_courses")
    .select("id,title").eq("class_id", classId).eq("is_active", true).order("title");
  if (courseRes.error) throw new Error(courseRes.error.message);
  const courses = (courseRes.data ?? []) as { id: string; title: string }[];
  const courseTitles = new Map(courses.map((course) => [course.id, course.title]));

  if (!courses.length) {
    return { className: context.className, rosterSize, rows: [], totalGraded: 0, totalSubmitted: 0, totalPending: 0 };
  }

  const homeworkRes = await supabase.from("learning_homework")
    .select("id,title,course_id,due_at,max_score")
    .in("course_id", courses.map((course) => course.id))
    .eq("is_published", true)
    .order("due_at");
  if (homeworkRes.error) throw new Error(homeworkRes.error.message);
  const homework = (homeworkRes.data ?? []) as {
    id: string; title: string; course_id: string; due_at: string; max_score: number;
  }[];

  let submissions: { homework_id: string; status: string }[] = [];
  if (homework.length) {
    const submissionRes = await supabase.from("learning_homework_submissions")
      .select("homework_id,status")
      .in("homework_id", homework.map((item) => item.id));
    if (submissionRes.error) throw new Error(submissionRes.error.message);
    submissions = (submissionRes.data ?? []) as { homework_id: string; status: string }[];
  }

  const rows: HomeworkReportRow[] = homework.map((item) => {
    const forItem = submissions.filter((submission) => submission.homework_id === item.id);
    const graded = forItem.filter((submission) => submission.status === "graded").length;
    const delivered = forItem.filter((submission) => ["submitted", "graded", "returned"].includes(submission.status)).length;
    return {
      id: item.id,
      title: item.title,
      courseTitle: courseTitles.get(item.course_id) ?? "—",
      dueAt: item.due_at,
      maxScore: item.max_score,
      graded,
      submitted: delivered,
      pending: Math.max(rosterSize - delivered, 0),
    };
  });

  return {
    className: context.className,
    rosterSize,
    rows,
    totalGraded: rows.reduce((sum, row) => sum + row.graded, 0),
    totalSubmitted: rows.reduce((sum, row) => sum + row.submitted, 0),
    totalPending: rows.reduce((sum, row) => sum + row.pending, 0),
  };
}

export async function loadAdmissionsReport(options: {
  branch: string | null;
  session: string | null;
  from: string;
  to: string;
}): Promise<AdmissionsReport> {
  const rows = await loadAdmissionRoster({
    branch: options.branch,
    session: options.session,
    status: null,
    from: options.from,
    to: options.to,
  });
  const counts: Record<string, number> = {};
  rows.forEach((row) => { counts[row.status] = (counts[row.status] ?? 0) + 1; });
  return { rows, counts, total: rows.length, from: options.from, to: options.to };
}

const noProgram = "بدون صف";

function cleanProgram(value: string | null): string {
  const trimmed = value?.trim();
  return trimmed ? trimmed : noProgram;
}

/**
 * College-wide distribution of students across branches and academic programs.
 * Counts come from classes (program + branch) joined to students; students with no
 * class are grouped under a "بدون صف" bucket so the totals always add up.
 */
export async function loadDistributionReport(options: {
  branch: string | null;
  session: string | null;
}): Promise<DistributionReport> {
  const branchRes = await supabase.from("branches").select("id,name");
  if (branchRes.error) throw new Error(branchRes.error.message);
  const branchNames = new Map(
    ((branchRes.data ?? []) as { id: string; name: string }[]).map((row) => [row.id, row.name]),
  );

  let classQuery = supabase.from("classes").select("id,program,branch_id,session_id,is_active");
  if (options.branch) classQuery = classQuery.eq("branch_id", options.branch);
  if (options.session) classQuery = classQuery.eq("session_id", options.session);
  const classRes = await classQuery;
  if (classRes.error) throw new Error(classRes.error.message);
  const classes = (classRes.data ?? []) as {
    id: string; program: string | null; branch_id: string; session_id: string;
  }[];
  const classMap = new Map(classes.map((row) => [row.id, row]));

  let studentQuery = supabase.from("students").select("id,status,class_id,branch_id");
  if (options.branch) studentQuery = studentQuery.eq("branch_id", options.branch);
  const studentRes = await studentQuery;
  if (studentRes.error) throw new Error(studentRes.error.message);
  const students = (studentRes.data ?? []) as {
    id: string; status: string; class_id: string | null; branch_id: string;
  }[];

  const grouped = new Map<string, DistributionRow>();

  function ensureRow(branchName: string, program: string): DistributionRow {
    const key = `${branchName}|||${program}`;
    let row = grouped.get(key);
    if (!row) {
      row = { branchName, program, classCount: 0, active: 0, other: 0, total: 0 };
      grouped.set(key, row);
    }
    return row;
  }

  classes.forEach((cls) => {
    const branchName = branchNames.get(cls.branch_id) ?? "—";
    ensureRow(branchName, cleanProgram(cls.program)).classCount += 1;
  });

  students.forEach((student) => {
    const cls = student.class_id ? classMap.get(student.class_id) ?? null : null;
    if (student.class_id && !cls) return;
    const branchName = cls
      ? branchNames.get(cls.branch_id) ?? "—"
      : branchNames.get(student.branch_id) ?? "—";
    const program = cls ? cleanProgram(cls.program) : noProgram;
    const row = ensureRow(branchName, program);
    row.total += 1;
    if (student.status === "active") row.active += 1;
    else row.other += 1;
  });

  const rows = Array.from(grouped.values()).sort(
    (a, b) => a.branchName.localeCompare(b.branchName, "ar") || a.program.localeCompare(b.program, "ar"),
  );

  function reduceBy(keyOf: (row: DistributionRow) => string) {
    const map = new Map<string, { active: number; other: number; total: number }>();
    rows.forEach((row) => {
      const key = keyOf(row);
      const bucket = map.get(key) ?? { active: 0, other: 0, total: 0 };
      bucket.active += row.active;
      bucket.other += row.other;
      bucket.total += row.total;
      map.set(key, bucket);
    });
    return map;
  }

  const branchMap = reduceBy((row) => row.branchName);
  if (!options.branch) {
    branchNames.forEach((name) => {
      if (!branchMap.has(name)) branchMap.set(name, { active: 0, other: 0, total: 0 });
    });
  }
  const programMap = reduceBy((row) => row.program);

  const branchTotals = Array.from(branchMap.entries())
    .map(([branchName, value]) => ({ branchName, ...value }))
    .sort((a, b) => a.branchName.localeCompare(b.branchName, "ar"));

  const programTotals = Array.from(programMap.entries())
    .map(([program, value]) => ({ program, ...value }))
    .sort((a, b) => a.program.localeCompare(b.program, "ar"));

  const totals = rows.reduce(
    (acc, row) => ({
      active: acc.active + row.active,
      other: acc.other + row.other,
      total: acc.total + row.total,
    }),
    { active: 0, other: 0, total: 0 },
  );

  return {
    rows,
    branchTotals,
    programTotals,
    totals: {
      ...totals,
      classes: classes.length,
      branches: branchTotals.length,
      programs: programTotals.filter((row) => row.program !== noProgram).length,
    },
  };
}