import { buildCsv, downloadCsv } from "./csv";
import {
  formatDate, submissionStatusLabels,
  type LearningHomework, type LearningScope,
} from "./learning";

export type CourseExportResult = {
  fileName: string;
  homeworks: number;
  students: number;
  rows: number;
  graded: number;
};

export type HomeworkExportResult = {
  fileName: string;
  students: number;
  submitted: number;
  graded: number;
};

const headers = [
  "#",
  "اسم الطالب",
  "الرقم الأكاديمي",
  "الحالة",
  "تاريخ التسليم",
  "نص التسليم",
  "الدرجة",
  "الدرجة العظمى",
  "ملاحظات المعلم",
  "تاريخ التصحيح",
] as const;

function fileStamp(): string {
  const date = new Date();
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function fileSlug(homework: LearningHomework): string {
  const ascii = homework.title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40);
  return ascii || `homework-${homework.id.slice(0, 8)}`;
}

/**
 * Exports one homework's full record: every student in the class, their submission
 * text, the score, the teacher feedback and the grading timestamp.
 */
export function exportHomeworkSubmissions(
  scope: LearningScope,
  homework: LearningHomework,
): HomeworkExportResult {
  const { workspace } = scope;
  const course = workspace.courses.find((item) => item.id === homework.course_id) ?? null;
  const submissions = workspace.submissions.filter((row) => row.homework_id === homework.id);
  const submittedIds = new Set(submissions.map((row) => row.student_id));

  let students = course
    ? workspace.students.filter((student) => student.class_id === course.class_id)
    : [];
  students = students.slice().sort((a, b) => a.full_name.localeCompare(b.full_name, "ar"));

  if (!students.length) {
    students = workspace.students
      .filter((student) => submittedIds.has(student.id))
      .slice()
      .sort((a, b) => a.full_name.localeCompare(b.full_name, "ar"));
  }

  const byStudent = new Map(submissions.map((row) => [row.student_id, row]));

  const rows = students.map((student, index) => {
    const submission = byStudent.get(student.id) ?? null;
    return [
      String(index + 1),
      student.full_name,
      student.admission_no,
      submission ? submissionStatusLabels[submission.status] : "لم يُسلَّم",
      submission ? formatDate(submission.submitted_at, true) : "",
      submission?.content ?? "",
      submission?.score === null || submission?.score === undefined ? "" : String(submission.score),
      String(homework.max_score),
      submission?.feedback ?? "",
      submission?.graded_at ? formatDate(submission.graded_at, true) : "",
    ];
  });

  const fileName = `homework-${fileSlug(homework)}-${fileStamp()}.csv`;
  downloadCsv(fileName, buildCsv(headers, rows));

  return {
    fileName,
    students: students.length,
    submitted: submissions.length,
    graded: submissions.filter((row) => row.status === "graded").length,
  };
}

const courseHeaders = [
  "اسم الطالب",
  "الرقم الأكاديمي",
  "الواجب",
  "تاريخ التسليم المطلوب",
  "حالة التسليم",
  "تاريخ التسليم الفعلي",
  "الدرجة",
  "الدرجة العظمى",
  "النسبة",
  "ملاحظات المعلم",
  "تاريخ التصحيح",
] as const;

const courseSummaryHeaders = [
  "ملخص الواجب",
  "عدد الطلاب",
  "عدد التسليمات",
  "عدد المصحّح",
  "المتوسط",
  "الدرجة العظمى",
] as const;

function stripBom(value: string): string {
  return value.replace(/^\uFEFF/, "");
}

/**
 * Bundles one course into a single file: every student against every homework,
 * followed by a per-homework summary block so the teacher keeps one record.
 */
export function exportCourseGrades(scope: LearningScope, courseId: string): CourseExportResult {
  const { workspace } = scope;
  const course = workspace.courses.find((item) => item.id === courseId);
  if (!course) throw new Error("اختر مقرراً صالحاً أولاً.");

  const homeworks = workspace.homework
    .filter((item) => item.course_id === course.id)
    .slice()
    .sort((a, b) => new Date(a.due_at).getTime() - new Date(b.due_at).getTime() || a.position - b.position);

  if (!homeworks.length) throw new Error("لا توجد واجبات في هذا المقرر لتصديرها.");

  const students = workspace.students
    .filter((student) => student.class_id === course.class_id)
    .slice()
    .sort((a, b) => a.full_name.localeCompare(b.full_name, "ar"));

  const byKey = new Map(
    workspace.submissions.map((row) => [`${row.homework_id}:${row.student_id}`, row]),
  );

  const detailRows: string[][] = [];
  let graded = 0;

  for (const student of students) {
    for (const homework of homeworks) {
      const submission = byKey.get(`${homework.id}:${student.id}`) ?? null;
      if (submission?.status === "graded") graded += 1;
      detailRows.push([
        student.full_name,
        student.admission_no,
        homework.title,
        formatDate(homework.due_at, true),
        submission ? submissionStatusLabels[submission.status] : "لم يُسلَّم",
        submission ? formatDate(submission.submitted_at, true) : "",
        submission?.score === null || submission?.score === undefined ? "" : String(submission.score),
        String(homework.max_score),
        submission?.score === null || submission?.score === undefined
          ? ""
          : `${Math.round((submission.score / homework.max_score) * 100)}%`,
        submission?.feedback ?? "",
        submission?.graded_at ? formatDate(submission.graded_at, true) : "",
      ]);
    }
  }

  const summaryRows = homeworks.map((homework) => {
    const rows = workspace.submissions.filter((row) => row.homework_id === homework.id);
    const gradedRows = rows.filter((row) => row.status === "graded" && row.score !== null);
    const average = gradedRows.length
      ? Math.round(gradedRows.reduce((total, row) => total + (row.score ?? 0), 0) / gradedRows.length)
      : null;
    return [
      homework.title,
      String(students.length),
      String(rows.length),
      String(gradedRows.length),
      average === null ? "—" : `${average} من ${homework.max_score}`,
      String(homework.max_score),
    ];
  });

  const detail = stripBom(buildCsv(courseHeaders, detailRows));
  const summary = stripBom(buildCsv(courseSummaryHeaders, summaryRows));
  const slug = course.title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40) || `course-${course.id.slice(0, 8)}`;
  const fileName = `course-${slug}-${fileStamp()}.csv`;

  downloadCsv(fileName, `\uFEFF${detail}\r\n\r\n${summary}`);

  return {
    fileName,
    homeworks: homeworks.length,
    students: students.length,
    rows: detailRows.length,
    graded,
  };
}