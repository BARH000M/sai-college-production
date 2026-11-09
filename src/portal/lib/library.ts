import { supabase } from "./supabase";

export type LibraryItem = {
  id: string;
  branch_id: string;
  title: string;
  author: string | null;
  category: string | null;
  isbn: string | null;
  shelf_code: string | null;
  copies_total: number;
  copies_available: number;
  is_active: boolean;
};

export type LibraryLoan = {
  id: string;
  item_id: string;
  branch_id: string;
  student_id: string;
  issued_at: string;
  due_date: string;
  returned_at: string | null;
  notes: string | null;
  studentName: string;
  admissionNo: string;
  itemTitle: string;
};

export type LibraryStudent = {
  id: string;
  full_name: string;
  admission_no: string;
};

export type LibraryDraft = {
  title: string;
  author: string;
  category: string;
  isbn: string;
  shelf_code: string;
  copies_total: string;
};

export function libraryPermissions(roles: readonly string[]) {
  const superAdmin = roles.includes("super_admin");
  const admin = roles.includes("admin");
  const librarian = roles.includes("librarian");
  return {
    canManage: superAdmin || admin || librarian,
    canViewLoans: superAdmin || admin || librarian || roles.includes("teacher") || roles.includes("receptionist")
      || roles.includes("student") || roles.includes("parent"),
  };
}

export function emptyLibraryDraft(): LibraryDraft {
  return { title: "", author: "", category: "", isbn: "", shelf_code: "", copies_total: "1" };
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function validateLibraryDraft(draft: LibraryDraft): string | null {
  if (!draft.title.trim()) return "عنوان الكتاب مطلوب.";
  const copies = Number(draft.copies_total);
  if (!Number.isInteger(copies) || copies < 1 || copies > 500) return "عدد النسخ يجب أن يكون رقماً صحيحاً بين 1 و500.";
  return null;
}

export async function loadLibraryItems(branch: string): Promise<LibraryItem[]> {
  if (!branch) return [];
  const result = await supabase.from("library_items")
    .select("id,branch_id,title,author,category,isbn,shelf_code,copies_total,copies_available,is_active")
    .eq("branch_id", branch)
    .eq("is_active", true)
    .order("title");
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as LibraryItem[];
}

async function decorateLoans(rows: {
  id: string; item_id: string; branch_id: string; student_id: string; issued_at: string;
  due_date: string; returned_at: string | null; notes: string | null;
}[]): Promise<LibraryLoan[]> {
  if (!rows.length) return [];
  const itemIds = Array.from(new Set(rows.map((row) => row.item_id)));
  const studentIds = Array.from(new Set(rows.map((row) => row.student_id)));
  const [itemsRes, studentsRes] = await Promise.all([
    supabase.from("library_items").select("id,title").in("id", itemIds),
    supabase.from("students").select("id,full_name,admission_no").in("id", studentIds),
  ]);
  if (itemsRes.error) throw new Error(itemsRes.error.message);
  if (studentsRes.error) throw new Error(studentsRes.error.message);
  const titles = new Map(((itemsRes.data ?? []) as { id: string; title: string }[]).map((row) => [row.id, row.title]));
  const students = new Map(
    ((studentsRes.data ?? []) as { id: string; full_name: string; admission_no: string }[])
      .map((row) => [row.id, row]),
  );
  return rows.map((row) => ({
    ...row,
    itemTitle: titles.get(row.item_id) ?? "—",
    studentName: students.get(row.student_id)?.full_name ?? "—",
    admissionNo: students.get(row.student_id)?.admission_no ?? "—",
  }));
}

export async function loadLoans(branch: string, scope: "open" | "returned" | "all"): Promise<LibraryLoan[]> {
  if (!branch) return [];
  let query = supabase.from("library_loans")
    .select("id,item_id,branch_id,student_id,issued_at,due_date,returned_at,notes")
    .eq("branch_id", branch);
  if (scope === "open") query = query.is("returned_at", null);
  if (scope === "returned") query = query.not("returned_at", "is", null);
  const result = await query.order("issued_at", { ascending: false }).limit(300);
  if (result.error) throw new Error(result.error.message);
  return decorateLoans((result.data ?? []) as Parameters<typeof decorateLoans>[0]);
}

export async function loadStudentLoanHistory(studentId: string): Promise<LibraryLoan[]> {
  if (!studentId) return [];
  const result = await supabase.from("library_loans")
    .select("id,item_id,branch_id,student_id,issued_at,due_date,returned_at,notes")
    .eq("student_id", studentId)
    .order("issued_at", { ascending: false })
    .limit(300);
  if (result.error) throw new Error(result.error.message);
  return decorateLoans((result.data ?? []) as Parameters<typeof decorateLoans>[0]);
}

export async function loadLibraryStudents(branch: string): Promise<LibraryStudent[]> {
  if (!branch) return [];
  const result = await supabase.from("students")
    .select("id,full_name,admission_no")
    .eq("branch_id", branch)
    .eq("status", "active")
    .order("full_name");
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as LibraryStudent[];
}

export async function createLibraryItem(branch: string, draft: LibraryDraft, userId: string | null): Promise<void> {
  const error = validateLibraryDraft(draft);
  if (error) throw new Error(error);
  if (!branch) throw new Error("اختر الفرع أولاً.");
  const copies = Number(draft.copies_total);
  const optional = (value: string) => value.trim() || null;
  const result = await supabase.from("library_items").insert({
    branch_id: branch,
    title: draft.title.trim(),
    author: optional(draft.author),
    category: optional(draft.category),
    isbn: optional(draft.isbn),
    shelf_code: optional(draft.shelf_code),
    copies_total: copies,
    copies_available: copies,
    created_by: userId,
  }).select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُضف الكتاب؛ قد لا تملك صلاحية هذا الفرع.");
}

export async function issueLoan(itemId: string, studentId: string, dueDate: string): Promise<void> {
  if (!itemId || !studentId) throw new Error("اختر الكتاب والطالب.");
  if (!dueDate) throw new Error("تاريخ الإرجاع مطلوب.");
  if (dueDate < new Date().toISOString().slice(0, 10)) throw new Error("تاريخ الإرجاع لا يمكن أن يكون في الماضي.");
  const result = await supabase.rpc("sai_library_issue", {
    p_item: itemId, p_student: studentId, p_due: dueDate,
  });
  if (result.error) {
    const text = result.error.message;
    if (text.includes("one_open_per_student") || text.includes("duplicate key")) {
      throw new Error("هذا الطالب يحمل نسخة غير مُعادة من الكتاب نفسه.");
    }
    if (text.includes("row-level security") || text.includes("permission")) {
      throw new Error("لا تملك صلاحية الإعارة في هذا الفرع.");
    }
    throw new Error(message(result.error));
  }
  if (!result.data) throw new Error("لا توجد نسخ متاحة من هذا الكتاب حالياً.");
}

export async function returnLoan(loanId: string): Promise<void> {
  const result = await supabase.rpc("sai_library_return", { p_loan: loanId });
  if (result.error) throw new Error(message(result.error));
}