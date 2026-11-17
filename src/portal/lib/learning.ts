import { supabase } from "./supabase";
import { visibleLearningItems } from "./studentLearning";

export type LessonStatus = "not_started" | "in_progress" | "completed";

export const lessonStatusLabels: Record<LessonStatus, string> = {
  not_started: "لم يبدأ",
  in_progress: "قيد الدراسة",
  completed: "حالة إكمال سابقة غير متحققة",
};

export const lessonKindLabels: Record<string, string> = {
  lesson: "درس",
  listening: "استماع",
  speaking: "تحدث",
  vocabulary: "مفردات",
  reading: "قراءة",
  review: "مراجعة",
};

export type LessonContentKind = "none" | "video" | "reading" | "audio" | "link";

export const lessonContentLabels: Record<LessonContentKind, string> = {
  none: "لا يوجد محتوى",
  video: "فيديو",
  reading: "مادة قراءة",
  audio: "تسجيل صوتي",
  link: "رابط خارجي",
};

export function isLessonContentKind(value: unknown): value is LessonContentKind {
  return value === "none" || value === "video" || value === "reading"
    || value === "audio" || value === "link";
}

export type LearningStudent = {
  id: string;
  full_name: string;
  admission_no: string;
  class_id: string | null;
  branch_id: string;
};

export type LearningClass = { id: string; name: string; program: string; teacher_id: string | null };
export type LearningBranch = { id: string; name: string };

export type LearningCourse = {
  id: string;
  class_id: string;
  branch_id: string;
  session_id: string;
  title: string;
  description: string | null;
  level: string | null;
  is_active: boolean;
  teacher_id: string | null;
};

export type LearningLesson = {
  id: string;
  course_id: string;
  title: string;
  summary: string | null;
  kind: string;
  position: number;
  duration_minutes: number;
  is_published: boolean;
  content_kind: string;
  content_url: string | null;
  content_body: string | null;
  content_path: string | null;
  content_file_name: string | null;
  content_updated_at: string | null;
};

export type LessonProgress = {
  lesson_id: string;
  student_id: string;
  status: LessonStatus;
  updated_at: string;
  completion_basis: string | null;
};

/** Exercise-flow completions are self-reported by the student's account; older rows stay unverified. */
export function lessonProgressLabel(row: LessonProgress | null | undefined): string {
  if (!row) return lessonStatusLabels.not_started;
  if (row.status === "completed" && row.completion_basis === "self_reported") return "أكمل التمارين ذاتياً (غير معتمد)";
  if (row.status === "completed" && row.completion_basis === "assessed") return "مكتمل بتقييم مُصحَّح";
  return lessonStatusLabels[row.status];
}

export type LearningHomework = {
  id: string;
  course_id: string;
  title: string;
  instructions: string | null;
  due_at: string;
  max_score: number;
  position: number;
  is_published: boolean;
  published_at: string | null;
  created_at: string;
  updated_at: string;
  attachment_path: string | null;
  attachment_file_name: string | null;
};

export type SubmissionStatus = "submitted" | "graded" | "returned";

export type HomeworkSubmission = {
  id: string;
  homework_id: string;
  student_id: string;
  status: SubmissionStatus;
  content: string | null;
  submitted_at: string;
  score: number | null;
  feedback: string | null;
  graded_at: string | null;
  submission_path: string | null;
  submission_file_name: string | null;
  submission_mime_type: string | null;
};

export type LearningWorkspace = {
  students: LearningStudent[];
  classes: LearningClass[];
  branches: LearningBranch[];
  courses: LearningCourse[];
  lessons: LearningLesson[];
  homework: LearningHomework[];
  progress: LessonProgress[];
  submissions: HomeworkSubmission[];
};

export type LearningScope = {
  workspace: LearningWorkspace;
  mode: "staff" | "learner";
  learnerId: string | null;
  canTrack: boolean;
  canSubmit: boolean;
  canManageContent: boolean;
  reload: () => void;
};

const workspaceColumns = {
  students: "id,full_name,admission_no,class_id,branch_id",
  classes: "id,name,program,teacher_id",
  branches: "id,name",
  courses: "id,class_id,branch_id,session_id,title,description,level,is_active,teacher_id",
  lessons: "id,course_id,title,summary,kind,position,duration_minutes,is_published,content_kind,content_url,content_body,content_path,content_file_name,content_updated_at",
  homework: "id,course_id,title,instructions,due_at,max_score,position,is_published,published_at,created_at,updated_at,attachment_path,attachment_file_name",
  progress: "lesson_id,student_id,status,updated_at,completion_basis",
  submissions: "id,homework_id,student_id,status,content,submitted_at,score,feedback,graded_at,submission_path,submission_file_name,submission_mime_type",
} as const;

type QueryResult<T> = { data: T | null; error: { message: string } | null };

function pick<T>(result: QueryResult<T>, label: string): T {
  if (result.error) throw new Error(`${label}: ${result.error.message}`);
  if (result.data === null) throw new Error(`تعذر تحميل ${label}.`);
  return result.data;
}

function isLessonStatus(value: unknown): value is LessonStatus {
  return value === "not_started" || value === "in_progress" || value === "completed";
}

function isSubmissionStatus(value: unknown): value is SubmissionStatus {
  return value === "submitted" || value === "graded" || value === "returned";
}

export async function loadLearningWorkspace(learnerOnly = false, studentUserId?: string, teacherUserId?: string): Promise<LearningWorkspace> {
  const studentQuery = supabase.from("students").select(workspaceColumns.students).order("full_name");
  if (teacherUserId) {
    const assigned = await supabase.from("classes").select("id").eq("teacher_id", teacherUserId);
    if (assigned.error) throw new Error(assigned.error.message);
    const ids = (assigned.data ?? []).map((row) => row.id);
    if (!ids.length) return { students: [], classes: [], branches: [], courses: [], lessons: [], homework: [], progress: [], submissions: [] };
    const [students, classes, branches, courses] = await Promise.all([
      studentQuery.in("class_id", ids),
      supabase.from("classes").select(workspaceColumns.classes).in("id", ids),
      supabase.from("branches").select(workspaceColumns.branches),
      supabase.from("learning_courses").select(workspaceColumns.courses).eq("is_active", true).in("class_id", ids).order("title"),
    ]);
    const studentRows = pick(students, "الطلاب");
    const courseRows = pick(courses, "المقررات");
    const courseIds = courseRows.map((course) => course.id);
    const studentIds = studentRows.map((student) => student.id);
    const empty = { data: [], error: null };
    const [lessons, homework, progress, submissions] = await Promise.all([
      courseIds.length ? supabase.from("learning_lessons").select(workspaceColumns.lessons).in("course_id", courseIds).order("position") : empty,
      courseIds.length ? supabase.from("learning_homework").select(workspaceColumns.homework).in("course_id", courseIds).order("due_at") : empty,
      studentIds.length ? supabase.from("learning_lesson_progress").select(workspaceColumns.progress).in("student_id", studentIds) : empty,
      studentIds.length ? supabase.from("learning_homework_submissions").select(workspaceColumns.submissions).in("student_id", studentIds) : empty,
    ]);
    const homeworkRows = pick(homework, "الواجبات");
    const lessonRows = pick(lessons, "الدروس");
    const classByStudent = new Map(studentRows.map((row) => [row.id, row.class_id]));
    const classByCourse = new Map(courseRows.map((row) => [row.id, row.class_id]));
    const classByHomework = new Map(homeworkRows.map((row) => [row.id, classByCourse.get(row.course_id)]));
    const classByLesson = new Map(lessonRows.map((row) => [row.id, classByCourse.get(row.course_id)]));
    return {
      students: studentRows, classes: pick(classes, "الصفوف"), branches: pick(branches, "الفروع"),
      courses: courseRows, lessons: lessonRows, homework: homeworkRows,
      progress: pick(progress, "سجل التقدم").filter((row) => classByLesson.has(row.lesson_id)
        && classByLesson.get(row.lesson_id) === classByStudent.get(row.student_id) && isLessonStatus(row.status)) as LessonProgress[],
      submissions: pick(submissions, "الواجبات المسلَّمة").filter((row) => classByHomework.has(row.homework_id)
        && classByHomework.get(row.homework_id) === classByStudent.get(row.student_id) && isSubmissionStatus(row.status)) as HomeworkSubmission[],
    };
  }
  const [students, classes, branches, courses] = await Promise.all([
    studentUserId ? studentQuery.eq("user_id", studentUserId) : studentQuery,
    supabase.from("classes").select(workspaceColumns.classes),
    supabase.from("branches").select(workspaceColumns.branches),
    supabase.from("learning_courses").select(workspaceColumns.courses).eq("is_active", true).order("title"),
  ]);

  const studentRows = pick(students, "الطلاب");
  const classIds = new Set(studentRows.map((student) => student.class_id));
  const courseRows = pick(courses, "المقررات").filter((course) => !learnerOnly || classIds.has(course.class_id));
  const courseIds = courseRows.map((course) => course.id);
  const studentIds = studentRows.map((student) => student.id);
  const empty = { data: [], error: null };
  const lessonQuery = supabase.from("learning_lessons").select(workspaceColumns.lessons).order("position");
  const homeworkQuery = supabase.from("learning_homework").select(workspaceColumns.homework).order("due_at");
  const progressQuery = supabase.from("learning_lesson_progress").select(workspaceColumns.progress);
  const submissionsQuery = supabase.from("learning_homework_submissions").select(workspaceColumns.submissions);
  const [lessons, homework, progress, submissions] = await Promise.all([
    learnerOnly ? (courseIds.length ? lessonQuery.in("course_id", courseIds).eq("is_published", true) : empty) : lessonQuery,
    learnerOnly ? (courseIds.length ? homeworkQuery.in("course_id", courseIds).eq("is_published", true) : empty) : homeworkQuery,
    learnerOnly ? (studentIds.length ? progressQuery.in("student_id", studentIds) : empty) : progressQuery,
    learnerOnly ? (studentIds.length ? submissionsQuery.in("student_id", studentIds) : empty) : submissionsQuery,
  ]);
  const progressRows = pick(progress, "سجل التقدم").filter((row) => isLessonStatus(row.status));
  const submissionRows = pick(submissions, "الواجبات المسلَّمة").filter((row) => isSubmissionStatus(row.status));

  return {
    students: studentRows,
    classes: pick(classes, "الصفوف"),
    branches: pick(branches, "الفروع"),
    courses: courseRows,
    lessons: visibleLearningItems(pick(lessons, "الدروس"), learnerOnly),
    homework: visibleLearningItems(pick(homework, "الواجبات"), learnerOnly),
    progress: progressRows as LessonProgress[],
    submissions: submissionRows as HomeworkSubmission[],
  };
}

export async function submitHomework(
  homeworkId: string,
  studentId: string,
  content: string,
  file?: File | null,
): Promise<void> {
  const text = content.trim();
  if (!file && text.length < 10) throw new Error("اكتب إجابة لا تقل عن عشرة أحرف أو أرفق ملفاً.");
  if (text.length > 2000) throw new Error("الإجابة أطول من الحد المسموح (٢٠٠٠ حرف).");
  const uploaded = file
    ? await uploadHomeworkFile(`${homeworkId}/submissions/${studentId}`, file)
    : null;
  const result = await supabase
    .from("learning_homework_submissions")
    .upsert(
      {
        homework_id: homeworkId,
        student_id: studentId,
        status: "submitted",
        content: text || null,
        score: null,
        feedback: null,
        graded_at: null,
        graded_by: null,
        ...(uploaded ? {
          submission_path: uploaded.path,
          submission_file_name: uploaded.fileName,
          submission_mime_type: uploaded.mimeType,
        } : {}),
      },
      { onConflict: "homework_id,student_id" },
    )
    .select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُسجّل التسليم؛ قد تكون المهلة انتهت أو لا تملك الصلاحية.");
}

export const homeworkFileBucket = "homework-files";
export const homeworkFileAccept = ".pdf,.txt,.doc,.docx,.xls,.xlsx,.png,.jpg,.jpeg";
const homeworkFileExtensions = new Set(["pdf", "txt", "doc", "docx", "xls", "xlsx", "png", "jpg", "jpeg"]);
const homeworkFileLimit = 20 * 1024 * 1024;

export type UploadedHomeworkFile = { path: string; fileName: string; mimeType: string };

async function uploadHomeworkFile(folder: string, file: File): Promise<UploadedHomeworkFile> {
  if (!file.size || file.size > homeworkFileLimit) {
    throw new Error("يجب أن يكون الملف أكبر من صفر وألا يتجاوز ٢٠ ميجابايت.");
  }
  const extension = file.name.includes(".") ? file.name.split(".").pop()?.toLowerCase() ?? "" : "";
  if (!homeworkFileExtensions.has(extension)) {
    throw new Error("صيغة الملف غير مدعومة. المسموح PDF وTXT وWord وExcel وPNG وJPEG.");
  }
  const safeName = file.name.replace(/[^A-Za-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "").slice(-70)
    || `attachment.${extension}`;
  const path = `${folder}/${Date.now()}-${safeName}`;
  const { error } = await supabase.storage.from(homeworkFileBucket)
    .upload(path, file, { contentType: file.type || undefined, upsert: false, cacheControl: "3600" });
  if (error) throw new Error(`${error.message} — تحقق من الصلاحيات أو جرّب ملفاً أصغر.`);
  return { path, fileName: file.name, mimeType: file.type || "application/octet-stream" };
}

export async function uploadHomeworkAttachment(
  homeworkId: string,
  file: File,
): Promise<void> {
  const uploaded = await uploadHomeworkFile(`${homeworkId}/instructions`, file);
  const result = await supabase.from("learning_homework")
    .update({ attachment_path: uploaded.path, attachment_file_name: uploaded.fileName })
    .eq("id", homeworkId)
    .select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("رُفع الملف لكن تعذر ربطه بالواجب؛ حدّث الصفحة ثم حاول مجدداً.");
}

export async function homeworkFileUrl(path: string): Promise<string> {
  const { data, error } = await supabase.storage.from(homeworkFileBucket).createSignedUrl(path, 300);
  if (error || !data?.signedUrl) throw new Error(error?.message ?? "تعذر إنشاء رابط آمن للملف.");
  return data.signedUrl;
}

export async function saveLessonContent(
  lessonId: string,
  kind: LessonContentKind,
  url: string,
  body: string,
): Promise<void> {
  const cleanUrl = url.trim();
  const cleanBody = body.trim();

  if (kind !== "none" && kind !== "reading" && !/^https?:\/\/\S+$/i.test(cleanUrl)) {
    throw new Error("أدخل رابطاً صحيحاً يبدأ بـ http:// أو https://");
  }
  if (kind === "reading" && cleanBody.length < 20) {
    throw new Error("اكتب مادة القراءة أولاً (٢٠ حرفاً على الأقل).");
  }
  if (kind === "reading" && cleanBody.length > 8000) {
    throw new Error("مادة القراءة أطول من الحد المسموح (٨٠٠٠ حرف).");
  }

  const result = await supabase
    .from("learning_lessons")
    .update({
      content_kind: kind,
      content_url: kind === "none" || kind === "reading" ? null : cleanUrl,
      content_body: kind === "reading" ? cleanBody : null,
      content_path: null,
      content_file_name: null,
      content_updated_at: new Date().toISOString(),
    })
    .eq("id", lessonId)
    .select("id");

  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحفظ المحتوى؛ تحقق من صلاحيتك على هذا المقرر.");
}

export const lessonMediaBucket = "lesson-media";
export const lessonMediaAccept = "video/mp4,video/webm,audio/mpeg,audio/mp4,audio/ogg,audio/wav,image/png,image/jpeg,application/pdf";
const lessonMediaExtensions = ["mp4", "webm", "ogg", "mp3", "m4a", "wav", "png", "jpg", "jpeg", "pdf"];
const lessonMediaLimit = 100 * 1024 * 1024;

export type UploadedLessonMedia = { path: string; fileName: string; size: number };

export async function uploadLessonMedia(lessonId: string, file: File): Promise<UploadedLessonMedia> {
  if (!lessonId) throw new Error("اختر الدرس أولاً.");
  if (file.size === 0) throw new Error("الملف فارغ؛ اختر ملفاً صالحاً.");
  if (file.size > lessonMediaLimit) throw new Error("حجم الملف أكبر من الحد المسموح (١٠٠ ميجابايت).");

  const extension = file.name.includes(".") ? file.name.split(".").pop()?.toLowerCase() ?? "" : "";
  if (!lessonMediaExtensions.includes(extension)) {
    throw new Error("صيغة الملف غير مدعومة. المسموح: MP4 وWebM وMP3 وM4A وWAV وPDF والصور.");
  }

  const safeName = file.name
    .replace(/[^A-Za-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(-70) || `media.${extension}`;
  const path = `${lessonId}/${Date.now()}-${safeName}`;

  const { error } = await supabase.storage
    .from(lessonMediaBucket)
    .upload(path, file, { contentType: file.type || undefined, upsert: false, cacheControl: "3600" });

  if (error) throw new Error(`${error.message} — تحقق من صلاحيتك على المقرر أو جرّب ملفاً أصغر.`);
  return { path, fileName: file.name, size: file.size };
}

export async function lessonMediaUrl(path: string, expiresIn = 21600): Promise<string> {
  const { data, error } = await supabase.storage.from(lessonMediaBucket).createSignedUrl(path, expiresIn);
  if (error || !data?.signedUrl) throw new Error(error?.message ?? "تعذر إنشاء رابط للملف المرفوع.");
  return data.signedUrl;
}

export async function saveLessonMedia(
  lessonId: string,
  kind: LessonContentKind,
  media: UploadedLessonMedia,
): Promise<void> {
  const result = await supabase
    .from("learning_lessons")
    .update({
      content_kind: kind,
      content_url: null,
      content_body: null,
      content_path: media.path,
      content_file_name: media.fileName,
      content_updated_at: new Date().toISOString(),
    })
    .eq("id", lessonId)
    .select("id");

  if (result.error) {
    await supabase.storage.from(lessonMediaBucket).remove([media.path]);
    throw new Error(result.error.message);
  }
  if (!result.data?.length) {
    await supabase.storage.from(lessonMediaBucket).remove([media.path]);
    throw new Error("لم يُحفظ الملف؛ تحقق من صلاحيتك على هذا المقرر.");
  }
}

export type NewHomeworkInput = {
  courseId: string;
  title: string;
  instructions: string;
  dueAt: string;
  maxScore: number;
  isPublished: boolean;
};

export async function createHomework(input: NewHomeworkInput): Promise<string> {
  const title = input.title.trim();
  const instructions = input.instructions.trim();
  const due = new Date(input.dueAt);

  if (!input.courseId) throw new Error("اختر المقرر الذي ينتمي إليه الواجب.");
  if (title.length < 4) throw new Error("اكتب عنواناً واضحاً للواجب (٤ أحرف على الأقل).");
  if (title.length > 120) throw new Error("عنوان الواجب أطول من الحد المسموح (١٢٠ حرفاً).");
  if (instructions.length > 500) throw new Error("تعليمات الواجب أطول من الحد المسموح (٥٠٠ حرف).");
  if (Number.isNaN(due.getTime())) throw new Error("أدخل تاريخ تسليم صحيح.");
  if (!Number.isInteger(input.maxScore) || input.maxScore < 1 || input.maxScore > 1000) {
    throw new Error("الدرجة العظمى يجب أن تكون رقماً صحيحاً بين ١ و ١٠٠٠.");
  }

  const { data: lastRows, error: lastError } = await supabase
    .from("learning_homework")
    .select("position")
    .eq("course_id", input.courseId)
    .order("position", { ascending: false })
    .limit(1);
  if (lastError) throw new Error(lastError.message);

  const position = Number(lastRows?.[0]?.position ?? 0) + 1;
  const { data: userData } = await supabase.auth.getUser();

  const result = await supabase
    .from("learning_homework")
    .insert({
      course_id: input.courseId,
      title,
      instructions: instructions || null,
      due_at: due.toISOString(),
      max_score: input.maxScore,
      position,
      is_published: input.isPublished,
      created_by: userData.user?.id ?? null,
    })
    .select("id");

  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُنشر الواجب؛ لا تملك صلاحية النشر على هذا المقرر.");
  return result.data[0].id;
}

export type HomeworkUpdateInput = {
  title: string;
  instructions: string;
  dueAt: string;
  maxScore: number;
  isPublished: boolean;
};

function validateHomework(input: HomeworkUpdateInput): { title: string; instructions: string; due: Date } {
  const title = input.title.trim();
  const instructions = input.instructions.trim();
  const due = new Date(input.dueAt);

  if (title.length < 4) throw new Error("اكتب عنواناً واضحاً للواجب (٤ أحرف على الأقل).");
  if (title.length > 120) throw new Error("عنوان الواجب أطول من الحد المسموح (١٢٠ حرفاً).");
  if (instructions.length > 500) throw new Error("تعليمات الواجب أطول من الحد المسموح (٥٠٠ حرف).");
  if (Number.isNaN(due.getTime())) throw new Error("أدخل تاريخ تسليم صحيح.");
  if (!Number.isInteger(input.maxScore) || input.maxScore < 1 || input.maxScore > 1000) {
    throw new Error("الدرجة العظمى يجب أن تكون رقماً صحيحاً بين ١ و ١٠٠٠.");
  }
  return { title, instructions, due };
}

export async function updateHomework(homeworkId: string, input: HomeworkUpdateInput): Promise<void> {
  const { title, instructions, due } = validateHomework(input);
  const now = new Date().toISOString();

  const current = await supabase
    .from("learning_homework")
    .select("is_published,published_at")
    .eq("id", homeworkId)
    .maybeSingle();
  if (current.error) throw new Error(current.error.message);
  if (!current.data) throw new Error("لم يُعثر على الواجب؛ حدّث الصفحة وأعد المحاولة.");

  const patch: Record<string, unknown> = {
    title,
    instructions: instructions || null,
    due_at: due.toISOString(),
    max_score: input.maxScore,
    is_published: input.isPublished,
    updated_at: now,
  };
  if (!input.isPublished) {
    patch.published_at = null;
  } else if (!current.data.is_published) {
    patch.published_at = now;
  } else if (!current.data.published_at) {
    patch.published_at = now;
  }

  const result = await supabase
    .from("learning_homework")
    .update(patch)
    .eq("id", homeworkId)
    .select("id");

  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحفظ التعديل؛ لا تملك صلاحية تعديل هذا الواجب.");
}

export async function setHomeworkPublished(homeworkId: string, published: boolean): Promise<void> {
  const now = new Date().toISOString();
  const patch: Record<string, unknown> = {
    is_published: published,
    updated_at: now,
    published_at: published ? now : null,
  };

  const result = await supabase
    .from("learning_homework")
    .update(patch)
    .eq("id", homeworkId)
    .select("id");

  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم تتغير حالة النشر؛ تحقق من صلاحيتك على هذا المقرر.");
}

export async function deleteHomework(homeworkId: string): Promise<void> {
  const result = await supabase
    .from("learning_homework")
    .delete()
    .eq("id", homeworkId)
    .select("id");

  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحذف الواجب؛ تحقق من صلاحيتك على هذا المقرر.");
}

export type GradeInput = {
  submissionId: string;
  score: number | null;
  feedback: string;
  status: "graded" | "returned";
  maxScore: number;
};

export async function gradeSubmission(input: GradeInput): Promise<void> {
  const feedback = input.feedback.trim();
  if (feedback.length > 500) throw new Error("الملاحظات أطول من الحد المسموح (٥٠٠ حرف).");

  if (input.status === "graded") {
    if (input.score === null || Number.isNaN(input.score)) {
      throw new Error("أدخل درجة رقمية قبل حفظ التقييم.");
    }
    if (input.score < 0 || input.score > input.maxScore) {
      throw new Error(`يجب أن تكون الدرجة بين ٠ و ${input.maxScore}.`);
    }
  }
  if (input.status === "returned" && feedback.length < 10) {
    throw new Error("أضف سبب الإعادة (١٠ أحرف على الأقل) ليصل للطالب بوضوح.");
  }

  const { data: userData } = await supabase.auth.getUser();
  const result = await supabase
    .from("learning_homework_submissions")
    .update({
      status: input.status,
      score: input.status === "graded" ? input.score : null,
      feedback: feedback || null,
      graded_at: new Date().toISOString(),
      graded_by: userData.user?.id ?? null,
    })
    .eq("id", input.submissionId)
    .select("id");

  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) {
    throw new Error("لم يُحفظ التصحيح؛ قد لا تملك صلاحية التصحيح على هذا الواجب.");
  }
}

export const lessonKinds = ["lesson", "listening", "speaking", "vocabulary", "reading", "review"] as const;
export type LessonKind = typeof lessonKinds[number];

export type LessonInput = {
  courseId: string;
  title: string;
  summary: string;
  kind: LessonKind;
  durationMinutes: number;
  isPublished: boolean;
};

function cleanLessonInput(input: LessonInput): Omit<LessonInput, "courseId"> {
  const title = input.title.trim();
  const summary = input.summary.trim();
  if (!input.courseId) throw new Error("لم يُحدَّد المقرر الذي ينتمي إليه الدرس.");
  if (title.length < 3 || title.length > 80) throw new Error("عنوان الدرس يجب أن يكون بين ٣ و ٨٠ حرفاً.");
  if (summary.length > 300) throw new Error("ملخص الدرس أطول من الحد المسموح (٣٠٠ حرف).");
  if (!lessonKinds.includes(input.kind)) throw new Error("نوع الدرس غير صالح.");
  if (!Number.isInteger(input.durationMinutes) || input.durationMinutes < 1 || input.durationMinutes > 600) {
    throw new Error("مدة الدرس يجب أن تكون رقماً صحيحاً بين ١ و ٦٠٠ دقيقة.");
  }
  return { title, summary, kind: input.kind, durationMinutes: input.durationMinutes, isPublished: input.isPublished };
}

/** Creates a lesson at the end of the course order. RLS limits this to course managers. */
export async function createLesson(input: LessonInput): Promise<string> {
  const clean = cleanLessonInput(input);
  const last = await supabase
    .from("learning_lessons")
    .select("position")
    .eq("course_id", input.courseId)
    .order("position", { ascending: false })
    .limit(1);
  if (last.error) throw new Error(last.error.message);
  const position = Number(last.data?.[0]?.position ?? 0) + 1;

  const result = await supabase
    .from("learning_lessons")
    .insert({
      course_id: input.courseId,
      title: clean.title,
      summary: clean.summary || null,
      kind: clean.kind,
      position,
      duration_minutes: clean.durationMinutes,
      is_published: clean.isPublished,
    })
    .select("id");
  if (result.error) throw new Error(result.error.message);
  const id = result.data?.[0]?.id;
  if (!id) throw new Error("لم يُحفظ الدرس؛ تحقق من صلاحيتك على هذا المقرر.");
  return id;
}

/** Updates lesson basics only; teaching content is managed through saveLessonContent/saveLessonMedia. */
export async function updateLesson(lessonId: string, input: LessonInput, position: number): Promise<void> {
  if (!lessonId) throw new Error("لم يُحدَّد الدرس المطلوب تعديله.");
  const clean = cleanLessonInput(input);
  if (!Number.isInteger(position) || position < 1 || position > 500) {
    throw new Error("ترتيب الدرس يجب أن يكون رقماً صحيحاً بين ١ و ٥٠٠.");
  }
  const result = await supabase
    .from("learning_lessons")
    .update({
      title: clean.title,
      summary: clean.summary || null,
      kind: clean.kind,
      position,
      duration_minutes: clean.durationMinutes,
      is_published: clean.isPublished,
    })
    .eq("id", lessonId)
    .eq("course_id", input.courseId)
    .select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحفظ التعديل؛ تحقق من صلاحيتك على هذا المقرر.");
}

/** Marks a lesson as started without ever downgrading a completed record. */
export async function recordLessonStart(lessonId: string, studentId: string): Promise<void> {
  if (!lessonId || !studentId) return;
  const existing = await supabase
    .from("learning_lesson_progress")
    .select("status")
    .eq("lesson_id", lessonId)
    .eq("student_id", studentId)
    .maybeSingle();
  if (existing.error) throw new Error(existing.error.message);
  if (existing.data && existing.data.status !== "not_started") return;

  const result = await supabase
    .from("learning_lesson_progress")
    .upsert(
      { lesson_id: lessonId, student_id: studentId, status: "in_progress", updated_at: new Date().toISOString() },
      { onConflict: "lesson_id,student_id" },
    )
    .select("lesson_id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُسجَّل بدء الدرس؛ تحقق من ربط حسابك بسجل الطالب.");
}

/** Records self-reported exercise completion. The UI gates this on the lesson plan, but the write comes from the student's own account and is not server-verified. */
export async function recordLessonCompletion(lessonId: string, studentId: string): Promise<void> {
  if (!lessonId || !studentId) throw new Error("لا يمكن تسجيل الإكمال دون طالب مرتبط بالحساب.");
  const result = await supabase
    .from("learning_lesson_progress")
    .upsert(
      {
        lesson_id: lessonId,
        student_id: studentId,
        status: "completed",
        completion_basis: "self_reported",
        updated_at: new Date().toISOString(),
      },
      { onConflict: "lesson_id,student_id" },
    )
    .select("lesson_id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُسجَّل الإكمال؛ تحقق من صلاحيتك على هذا السجل.");
}

export type LessonExerciseId = "reading" | "listening" | "vocabulary";
export type LessonExercise = { id: LessonExerciseId; label: string; total: number };

export const lessonExerciseLabels: Record<LessonExerciseId, string> = {
  reading: "تمرين القراءة",
  listening: "تمرين الاستماع",
  vocabulary: "تمرين المفردات",
};

/**
 * Exercises available for a lesson, derived only from recorded content and
 * linked vocabulary. A lesson with none of these offers no completion.
 */
export function lessonExercisePlan(
  lesson: Pick<LearningLesson, "content_kind" | "content_body" | "content_path" | "content_url">,
  lessonWordCount: number,
): LessonExercise[] {
  const plan: LessonExercise[] = [];
  if ((lesson.content_body ?? "").trim().length >= 20) {
    plan.push({ id: "reading", label: lessonExerciseLabels.reading, total: 1 });
  }
  if (lesson.content_kind === "audio" && (lesson.content_path || lesson.content_url)) {
    plan.push({ id: "listening", label: lessonExerciseLabels.listening, total: 1 });
  }
  if (lessonWordCount > 0) {
    plan.push({ id: "vocabulary", label: lessonExerciseLabels.vocabulary, total: lessonWordCount });
  }
  return plan;
}

export function canCompleteLesson(
  plan: readonly LessonExercise[],
  done: Readonly<Partial<Record<LessonExerciseId, number>>>,
): boolean {
  return plan.length > 0 && plan.every((exercise) => (done[exercise.id] ?? 0) >= exercise.total);
}

export function formatDate(value: string, withTime = false): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString("ar-EG", {
    year: "numeric",
    month: "long",
    day: "numeric",
    ...(withTime ? { hour: "2-digit", minute: "2-digit" } : {}),
  });
}

export function daysUntil(value: string): number {
  const date = new Date(value).getTime();
  if (Number.isNaN(date)) return 0;
  return Math.ceil((date - Date.now()) / (24 * 60 * 60 * 1000));
}

export type CourseProgressSummary = {
  total: number;
  completed: number;
  inProgress: number;
  percent: number;
};

export function summarizeProgress(
  lessons: LearningLesson[],
  progress: LessonProgress[],
  studentId: string,
): CourseProgressSummary {
  const total = lessons.length;
  let completed = 0;
  let inProgress = 0;
  for (const lesson of lessons) {
    const row = progress.find((entry) => entry.lesson_id === lesson.id && entry.student_id === studentId);
    if (!row) continue;
    if (row.status === "completed") completed += 1;
    else if (row.status === "in_progress") inProgress += 1;
  }
  const percent = total ? Math.round((completed / total) * 100) : 0;
  return { total, completed, inProgress, percent };
}

export function statusForLesson(
  progress: LessonProgress[],
  lessonId: string,
  studentId: string | null,
): LessonStatus {
  if (!studentId) return "not_started";
  const row = progress.find((entry) => entry.lesson_id === lessonId && entry.student_id === studentId);
  return row?.status ?? "not_started";
}

export const submissionStatusLabels: Record<SubmissionStatus, string> = {
  submitted: "مُسلَّم — بانتظار التصحيح",
  graded: "مُصحَّح",
  returned: "أُعيد للمراجعة",
};