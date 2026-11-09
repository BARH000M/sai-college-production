import { supabase } from "./supabase";

export type Option = { id: string; name: string };

type ClassRow = {
  id: string;
  name: string;
  program: string;
  capacity: number;
  teacher_id: string | null;
  branch_id: string;
  session_id: string;
  is_active: boolean;
};

type StudentRow = {
  id: string;
  full_name: string;
  admission_no: string;
  class_id: string | null;
  branch_id: string;
  date_of_birth: string | null;
  user_id: string | null;
};

export type EnquiryRow = {
  id: string;
  application_no: string;
  applicant_full_name: string;
  status: string;
  created_at: string;
  phone: string | null;
  preferred_program: string | null;
};

export type SectionView = {
  id: string;
  name: string;
  program: string;
  capacity: number;
  enrolled: number;
  isActive: boolean;
  branchName: string;
  sessionName: string;
};

export type StaffHome = {
  activeStudents: number;
  runningClasses: number;
  newEnquiries: number;
  enquiries: EnquiryRow[];
  branches: Option[];
  sessions: Option[];
  sections: SectionView[];
};

export type RosterStudent = { id: string; fullName: string; admissionNo: string };

export type TeacherSection = SectionView & { students: RosterStudent[] };

export type ChildRecord = {
  id: string;
  fullName: string;
  admissionNo: string;
  dateOfBirth: string | null;
  className: string | null;
  program: string | null;
  sessionName: string | null;
  branchName: string | null;
  status: string;
};

type QueryResult<T> = { data: T[] | null; error: { message: string } | null };

/**
 * Reads every page of a filtered list so counters and rosters stay complete even
 * when a branch has more rows than one PostgREST page returns.
 */
async function paged<T>(run: (from: number, to: number) => PromiseLike<QueryResult<T>>): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; from < 8000; from += 1000) {
    const result = await run(from, from + 999);
    if (result.error) throw new Error(result.error.message);
    const batch = result.data ?? [];
    rows.push(...batch);
    if (batch.length < 1000) break;
  }
  return rows;
}

function countOf(result: { count: number | null; error: { message: string } | null }): number {
  if (result.error) throw new Error(result.error.message);
  return result.count ?? 0;
}

async function loadDirectories(): Promise<{ branches: Option[]; sessions: Option[] }> {
  const [branches, sessions] = await Promise.all([
    supabase.from("branches").select("id,name,is_active").order("name"),
    supabase.from("academic_sessions").select("id,name,starts_on").order("starts_on", { ascending: false }),
  ]);
  if (branches.error) throw new Error(branches.error.message);
  if (sessions.error) throw new Error(sessions.error.message);
  return {
    branches: (branches.data ?? []) as Option[],
    sessions: (sessions.data ?? []) as Option[],
  };
}

async function loadClassRows(): Promise<ClassRow[]> {
  return paged<ClassRow>((from, to) =>
    supabase
      .from("classes")
      .select("id,name,program,capacity,teacher_id,branch_id,session_id,is_active")
      .order("name")
      .order("id")
      .range(from, to),
  );
}

async function loadActiveStudents(): Promise<StudentRow[]> {
  return paged<StudentRow>((from, to) =>
    supabase
      .from("students")
      .select("id,full_name,admission_no,class_id,branch_id,date_of_birth,user_id")
      .eq("status", "active")
      .order("full_name")
      .order("id")
      .range(from, to),
  );
}

function buildSections(
  classes: ClassRow[],
  students: StudentRow[],
  branches: Option[],
  sessions: Option[],
): SectionView[] {
  const enrolledByClass = new Map<string, number>();
  students.forEach((student) => {
    if (!student.class_id) return;
    enrolledByClass.set(student.class_id, (enrolledByClass.get(student.class_id) ?? 0) + 1);
  });
  const branchNames = new Map(branches.map((branch) => [branch.id, branch.name]));
  const sessionNames = new Map(sessions.map((session) => [session.id, session.name]));
  return classes.map((item) => ({
    id: item.id,
    name: item.name,
    program: item.program,
    capacity: item.capacity,
    enrolled: enrolledByClass.get(item.id) ?? 0,
    isActive: item.is_active,
    branchName: branchNames.get(item.branch_id) ?? "—",
    sessionName: sessionNames.get(item.session_id) ?? "—",
  }));
}

export async function loadStaffHome(): Promise<StaffHome> {
  const [studentsCount, classCount, enquiryCount] = await Promise.all([
    supabase.from("students").select("id", { count: "exact", head: true }).eq("status", "active"),
    supabase.from("classes").select("id", { count: "exact", head: true }).eq("is_active", true),
    supabase.from("admissions_enquiries").select("id", { count: "exact", head: true }).eq("status", "new"),
  ]);

  const [directories, classes, students, enquiries] = await Promise.all([
    loadDirectories(),
    loadClassRows(),
    loadActiveStudents(),
    supabase
      .from("admissions_enquiries")
      .select("id,application_no,applicant_full_name,status,created_at,phone,preferred_program")
      .order("created_at", { ascending: false })
      .limit(6),
  ]);
  if (enquiries.error) throw new Error(enquiries.error.message);

  return {
    activeStudents: countOf(studentsCount),
    runningClasses: countOf(classCount),
    newEnquiries: countOf(enquiryCount),
    enquiries: (enquiries.data ?? []) as EnquiryRow[],
    branches: directories.branches,
    sessions: directories.sessions,
    sections: buildSections(classes, students, directories.branches, directories.sessions),
  };
}

export async function loadTeacherHome(userId: string): Promise<TeacherSection[]> {
  const [directories, allClasses, students] = await Promise.all([
    loadDirectories(),
    loadClassRows(),
    loadActiveStudents(),
  ]);
  const mine = allClasses.filter((item) => item.teacher_id === userId);
  const sections = buildSections(mine, students, directories.branches, directories.sessions);
  const roster = new Map<string, RosterStudent[]>();
  students.forEach((student) => {
    if (!student.class_id) return;
    const list = roster.get(student.class_id) ?? [];
    list.push({ id: student.id, fullName: student.full_name, admissionNo: student.admission_no });
    roster.set(student.class_id, list);
  });
  return sections.map((section) => ({ ...section, students: roster.get(section.id) ?? [] }));
}

async function toChildRecords(students: StudentRow[]): Promise<ChildRecord[]> {
  if (!students.length) return [];
  const classIds = Array.from(new Set(students.map((student) => student.class_id).filter((id): id is string => !!id)));
  const directories = await loadDirectories();
  let classRows: { id: string; name: string; program: string; session_id: string; branch_id: string }[] = [];
  if (classIds.length) {
    const result = await supabase
      .from("classes")
      .select("id,name,program,session_id,branch_id")
      .in("id", classIds);
    if (result.error) throw new Error(result.error.message);
    classRows = (result.data ?? []) as typeof classRows;
  }
  const classMap = new Map(classRows.map((row) => [row.id, row]));
  const branchNames = new Map(directories.branches.map((branch) => [branch.id, branch.name]));
  const sessionNames = new Map(directories.sessions.map((session) => [session.id, session.name]));

  return students.map((student) => {
    const category = student.class_id ? classMap.get(student.class_id) ?? null : null;
    return {
      id: student.id,
      fullName: student.full_name,
      admissionNo: student.admission_no,
      dateOfBirth: student.date_of_birth,
      className: category?.name ?? null,
      program: category?.program ?? null,
      sessionName: category ? sessionNames.get(category.session_id) ?? null : null,
      branchName: branchNames.get(category ? category.branch_id : student.branch_id) ?? null,
      status: "active",
    };
  });
}

export async function loadParentChildren(userId: string): Promise<ChildRecord[]> {
  const links = await paged<{ student_id: string }>((from, to) =>
    supabase
      .from("parent_student_links")
      .select("student_id")
      .eq("parent_user_id", userId)
      .not("verified_at", "is", null)
      .order("student_id")
      .range(from, to),
  );
  const studentIds = Array.from(new Set(links.map((link) => link.student_id)));
  if (!studentIds.length) return [];
  const students = await paged<StudentRow>((from, to) =>
    supabase
      .from("students")
      .select("id,full_name,admission_no,class_id,branch_id,date_of_birth,user_id")
      .in("id", studentIds)
      .order("full_name")
      .order("id")
      .range(from, to),
  );
  return toChildRecords(students);
}

export async function loadStudentRecord(userId: string): Promise<ChildRecord | null> {
  const result = await supabase
    .from("students")
    .select("id,full_name,admission_no,class_id,branch_id,date_of_birth,user_id")
    .eq("user_id", userId)
    .maybeSingle<StudentRow>();
  if (result.error) throw new Error(result.error.message);
  if (!result.data) return null;
  const records = await toChildRecords([result.data]);
  return records[0] ?? null;
}