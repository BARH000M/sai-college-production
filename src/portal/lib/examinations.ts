import { supabase } from "./supabase";

export const examStatuses = {
  draft: "مسودة",
  marks_entry: "رصد الدرجات",
  review: "قيد المراجعة",
  published: "منشورة",
  cancelled: "ملغاة",
} as const;
export type ExamStatus = keyof typeof examStatuses;
export function isExamStatus(value: string): value is ExamStatus {
  return Object.prototype.hasOwnProperty.call(examStatuses, value);
}

export const gradeLabels = {
  excellent: "ممتاز",
  very_good: "جيد جداً",
  good: "جيد",
  acceptable: "مقبول",
  weak: "ضعيف",
  fail: "راسب",
} as const;
export type GradeCode = keyof typeof gradeLabels;
export function isGradeCode(value: unknown): value is GradeCode {
  return typeof value === "string" && Object.prototype.hasOwnProperty.call(gradeLabels, value);
}

/** Mirrors the server bands in private.sai_exam_grade; the database stays authoritative. */
export function gradeForScore(score: number | null, maxScore: number): GradeCode | null {
  if (score === null || maxScore <= 0) return null;
  const ratio = score / maxScore;
  if (ratio >= 0.9) return "excellent";
  if (ratio >= 0.8) return "very_good";
  if (ratio >= 0.7) return "good";
  if (ratio >= 0.6) return "acceptable";
  if (ratio >= 0.5) return "weak";
  return "fail";
}

export type ExamClass = { id: string; name: string; branch_id: string; academic_session_id: string; teacher_id: string | null };
export type ExamCourse = { id: string; title: string };
export type ExamSessionWindow = { id: string; name: string; starts_on: string; ends_on: string };
export type Exam = {
  id: string;
  branch_id: string;
  academic_session_id: string;
  class_id: string;
  course_id: string | null;
  subject: string;
  title: string;
  exam_date: string;
  start_time: string | null;
  end_time: string | null;
  room: string | null;
  max_score: number;
  status: ExamStatus;
  published_at: string | null;
};
export type ExamRosterEntry = {
  student_id: string;
  full_name: string;
  admission_no: string;
  result_id: string | null;
  score: number | null;
  grade: GradeCode | null;
  note: string | null;
};
export type FamilyResult = {
  id: string;
  exam_id: string;
  student_id: string;
  score: number | null;
  grade: GradeCode | null;
  note: string | null;
  exam: { title: string; subject: string; exam_date: string; max_score: number } | null;
};
export type ExamFilters = { branch: string; session: string; classId: string; status: ExamStatus | ""; page: number };
export const examPageSize = 25;

export const examTransitions: Record<ExamStatus, readonly ExamStatus[]> = {
  draft: ["marks_entry", "cancelled"],
  marks_entry: ["review", "cancelled"],
  review: ["marks_entry", "published"],
  published: ["review"],
  cancelled: [],
};
export function canTransition(from: ExamStatus, to: ExamStatus): boolean {
  return examTransitions[from].includes(to);
}

const hasControl = (value: string) => Array.from(value).some((ch) => ch.charCodeAt(0) < 32 || ch.charCodeAt(0) === 127);

export type ExamDraft = {
  classId: string;
  courseId: string;
  subject: string;
  title: string;
  date: string;
  startTime: string;
  endTime: string;
  room: string;
  maxScore: string;
};

export function validateExamDraft(draft: ExamDraft, window?: ExamSessionWindow): string | null {
  const title = draft.title.trim();
  if (Array.from(title).length < 2 || Array.from(title).length > 160 || hasControl(title)) {
    return "عنوان الاختبار يجب أن يكون بين حرفين و١٦٠ حرفاً دون محارف تحكم.";
  }
  const subject = draft.subject.trim();
  if (Array.from(subject).length < 2 || Array.from(subject).length > 120 || hasControl(subject)) {
    return "اسم المادة يجب أن يكون بين حرفين و١٢٠ حرفاً دون محارف تحكم.";
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(draft.date) || Number.isNaN(Date.parse(`${draft.date}T00:00:00Z`))) {
    return "تاريخ الاختبار غير صالح.";
  }
  if (window && (draft.date < window.starts_on || draft.date > window.ends_on)) {
    return `تاريخ الاختبار خارج الجلسة الأكاديمية (${window.starts_on} — ${window.ends_on}).`;
  }
  if (draft.startTime && draft.endTime && draft.endTime <= draft.startTime) {
    return "وقت النهاية يجب أن يكون بعد وقت البداية.";
  }
  const room = draft.room.trim();
  if (room && (Array.from(room).length > 60 || hasControl(room))) return "اسم القاعة غير صالح.";
  const max = Number(draft.maxScore);
  if (!Number.isFinite(max) || max <= 0 || max > 1000) return "الدرجة العظمى يجب أن تكون بين ١ و١٠٠٠.";
  return null;
}

export function validateMark(score: string, maxScore: number): string | null {
  if (!score.trim()) return null;
  const value = Number(score);
  if (!Number.isFinite(value)) return "الدرجة غير صالحة.";
  if (value < 0 || value > maxScore) return `الدرجة يجب أن تكون بين صفر و${maxScore}.`;
  return null;
}

export function canManageExams(roles: readonly string[], userId: string | null, memberships: readonly string[], item: ExamClass): boolean {
  return roles.includes("super_admin") || (memberships.includes(item.branch_id)
    && (roles.includes("admin") || (roles.includes("teacher") && item.teacher_id === userId && !!userId)));
}
export function canReviewExams(roles: readonly string[]): boolean {
  return roles.includes("super_admin") || roles.includes("admin");
}

function isExamClass(value: unknown): value is ExamClass {
  return typeof value === "object" && value !== null && "id" in value && typeof value.id === "string"
    && "name" in value && typeof value.name === "string" && "branch_id" in value && typeof value.branch_id === "string"
    && "academic_session_id" in value && typeof value.academic_session_id === "string"
    && "teacher_id" in value && (typeof value.teacher_id === "string" || value.teacher_id === null);
}
function isRosterEntry(value: unknown): value is ExamRosterEntry {
  if (typeof value !== "object" || value === null || !("student_id" in value) || typeof value.student_id !== "string"
    || !("full_name" in value) || typeof value.full_name !== "string"
    || !("admission_no" in value) || typeof value.admission_no !== "string"
    || !("result_id" in value) || !(typeof value.result_id === "string" || value.result_id === null)
    || !("score" in value) || !(typeof value.score === "number" || value.score === null)
    || !("note" in value) || !(typeof value.note === "string" || value.note === null)) return false;
  if (!("grade" in value)) return false;
  const grade = value.grade;
  return grade === null || isGradeCode(grade);
}

async function loadAll<T>(guard: (value: unknown) => value is T, run: (from: number, to: number) => PromiseLike<{ data: unknown; error: { message: string } | null; count: number | null }>): Promise<T[]> {
  const rows: T[] = [];
  let total = 0;
  do {
    const result = await run(rows.length, rows.length + 999);
    if (result.error) throw new Error(result.error.message);
    if (!Array.isArray(result.data) || !result.data.every(guard) || result.count === null) throw new Error("تعذر تحميل البيانات وعددها.");
    total = result.count;
    if (!result.data.length && rows.length < total) throw new Error("تعذر تحميل جميع البيانات.");
    rows.push(...result.data);
  } while (rows.length < total);
  return rows;
}

export const loadExamClasses = () => loadAll(isExamClass,
  (from, to) => supabase.rpc("sai_exams_classes", {}, { count: "exact" }).range(from, to));
export const loadExamRoster = (examId: string) => loadAll(isRosterEntry,
  (from, to) => supabase.rpc("sai_exam_roster", { wanted_exam: examId }, { count: "exact" }).range(from, to));

export async function loadExamSessionWindows(): Promise<ExamSessionWindow[]> {
  return loadAll(
    (value: unknown): value is ExamSessionWindow => typeof value === "object" && value !== null
      && "id" in value && typeof value.id === "string" && "name" in value && typeof value.name === "string"
      && "starts_on" in value && typeof value.starts_on === "string"
      && "ends_on" in value && typeof value.ends_on === "string",
    (from, to) => supabase.from("academic_sessions").select("id,name,starts_on,ends_on", { count: "exact" })
      .order("starts_on", { ascending: false }).range(from, to),
  );
}

export async function loadExamCourses(classId: string): Promise<ExamCourse[]> {
  if (!classId) return [];
  return loadAll(
    (value: unknown): value is ExamCourse => typeof value === "object" && value !== null
      && "id" in value && typeof value.id === "string" && "title" in value && typeof value.title === "string",
    (from, to) => supabase.from("learning_courses").select("id,title", { count: "exact" })
      .eq("class_id", classId).eq("is_active", true).order("title").range(from, to),
  );
}

const examColumns = "id,branch_id,academic_session_id,class_id,course_id,subject,title,exam_date,start_time,end_time,room,max_score,status,published_at";
export async function loadExams(filters: ExamFilters, classIds?: string[]): Promise<{ rows: Exam[]; count: number }> {
  if (classIds && !classIds.length) return { rows: [], count: 0 };
  let query = supabase.from("exams").select(examColumns, { count: "exact" });
  if (classIds) query = query.in("class_id", classIds);
  if (filters.branch) query = query.eq("branch_id", filters.branch);
  if (filters.session) query = query.eq("academic_session_id", filters.session);
  if (filters.classId) query = query.eq("class_id", filters.classId);
  if (filters.status) query = query.eq("status", filters.status);
  const start = filters.page * examPageSize;
  const result = await query.order("exam_date", { ascending: false }).order("id")
    .range(start, start + examPageSize - 1).returns<Exam[]>();
  if (result.error) throw new Error(result.error.message);
  if (!result.data || result.count === null) throw new Error("تعذر تحميل الاختبارات وعددها.");
  return { rows: result.data, count: result.count };
}

/** Published results visible to the signed-in student or verified parent. */
export async function loadFamilyResults(): Promise<FamilyResult[]> {
  return loadAll(
    (value: unknown): value is FamilyResult => {
      if (typeof value !== "object" || value === null) return false;
      const row = value as Record<string, unknown>;
      const exam = row.exam;
      return typeof row.id === "string" && typeof row.exam_id === "string" && typeof row.student_id === "string"
        && (typeof row.score === "number" || row.score === null)
        && (row.grade === null || isGradeCode(row.grade))
        && (typeof row.note === "string" || row.note === null)
        && (exam === null || (typeof exam === "object" && typeof (exam as Record<string, unknown>).title === "string"
          && typeof (exam as Record<string, unknown>).subject === "string"
          && typeof (exam as Record<string, unknown>).exam_date === "string"
          && typeof (exam as Record<string, unknown>).max_score === "number"));
    },
    (from, to) => supabase.from("exam_results")
      .select("id,exam_id,student_id,score,grade,note,exam:exams(title,subject,exam_date,max_score)", { count: "exact" })
      .order("id").range(from, to),
  );
}

export async function createExam(item: ExamClass, draft: ExamDraft, window?: ExamSessionWindow): Promise<void> {
  const error = validateExamDraft(draft, window);
  if (error) throw new Error(error);
  const result = await supabase.from("exams").insert({
    branch_id: item.branch_id,
    academic_session_id: item.academic_session_id,
    class_id: item.id,
    course_id: draft.courseId || null,
    subject: draft.subject.trim(),
    title: draft.title.trim(),
    exam_date: draft.date,
    start_time: draft.startTime || null,
    end_time: draft.endTime || null,
    room: draft.room.trim() || null,
    max_score: Number(draft.maxScore),
  });
  if (result.error) throw new Error(result.error.message);
}

export async function transitionExam(exam: Exam, next: ExamStatus): Promise<void> {
  if (!canTransition(exam.status, next)) throw new Error("انتقال الحالة غير مسموح.");
  const result = await supabase.from("exams").update({ status: next }).eq("id", exam.id).eq("status", exam.status).select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم تُحدّث الحالة؛ قد تكون تغيّرت أو لا تملك الصلاحية.");
}

export async function saveMark(examId: string, entry: ExamRosterEntry, score: string, note: string, maxScore: number): Promise<void> {
  const error = validateMark(score, maxScore);
  if (error) throw new Error(error);
  const values = { score: score.trim() === "" ? null : Number(score), note: note.trim() || null };
  if (entry.result_id) {
    const result = await supabase.from("exam_results").update(values).eq("id", entry.result_id).eq("exam_id", examId).select("id");
    if (result.error) throw new Error(result.error.message);
    if (!result.data?.length) throw new Error("لم يُحدّث السجل؛ تحقق من الصلاحية وحالة الاختبار.");
  } else {
    const result = await supabase.from("exam_results").insert({ exam_id: examId, student_id: entry.student_id, ...values });
    if (result.error) throw new Error(result.error.message);
  }
}

/** Names of students the signed-in user may read (own record or verified children). */
export async function loadStudentNames(ids: readonly string[]): Promise<Record<string, string>> {
  if (!ids.length) return {};
  const result = await supabase.from("students").select("id,full_name").in("id", [...ids]);
  if (result.error) throw new Error(result.error.message);
  return Object.fromEntries((result.data ?? []).map((row) => [row.id, row.full_name]));
}

/** Report rows for the printable exam sheet, built from the marks roster. */
export function rosterToReportRows(entries: readonly ExamRosterEntry[]): {
  key: string;
  name: string;
  admissionNo: string;
  score: number | null;
  grade: GradeCode | null;
  note: string | null;
}[] {
  return entries.map((entry) => ({
    key: entry.student_id,
    name: entry.full_name,
    admissionNo: entry.admission_no,
    score: entry.score,
    grade: entry.grade,
    note: entry.note,
  }));
}

export type MarkBatchItem = { row: ExamRosterEntry; score: string; note: string };

/** Saves entered marks one by one so a single rejected row cannot roll back the rest. */
export async function saveMarksBatch(examId: string, items: readonly MarkBatchItem[], maxScore: number): Promise<number> {
  if (!items.length) throw new Error("لا توجد درجات جاهزة للحفظ.");
  let saved = 0;
  const failures: string[] = [];
  for (const item of items) {
    try {
      await saveMark(examId, item.row, item.score, item.note, maxScore);
      saved += 1;
    } catch (failure) {
      const name = item.row.full_name || item.row.student_id;
      failures.push(`${name}: ${failure instanceof Error ? failure.message : String(failure)}`);
    }
  }
  if (failures.length) {
    throw new Error(`حُفظ ${saved} درجة، وتعذّر حفظ ${failures.length}. أول خطأ — ${failures[0]}`);
  }
  return saved;
}
