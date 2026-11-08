import { supabase } from "./supabase";

export type Branch = { id: string; name: string; is_active: boolean };
export type AcademicSession = { id: string; name: string; is_active: boolean };
export type AuditEntry = { id: string; action: string; entity_type: string; created_at: string };
export type Result<T> = { data: T | null; error: string | null };

function failure(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export async function loadContext(): Promise<{
  branches: Result<Branch[]>; sessions: Result<AcademicSession[]>;
}> {
  try {
    const [branches, sessions] = await Promise.all([
      supabase.from("branches").select("id,name,is_active").order("name"),
      supabase.from("academic_sessions").select("id,name,is_active").order("starts_on", { ascending: false }),
    ]);
    return {
      branches: { data: branches.data, error: branches.error?.message ?? null },
      sessions: { data: sessions.data, error: sessions.error?.message ?? null },
    };
  } catch (error) {
    const message = failure(error);
    return { branches: { data: null, error: message }, sessions: { data: null, error: message } };
  }
}

export async function loadDashboard(branchId: string, sessionId: string): Promise<{
  students: Result<number>; classes: Result<number>; audit: Result<AuditEntry[]>;
}> {
  try {
    const [students, classes, audit] = await Promise.all([
      supabase.from("students").select("id,classes!inner(session_id)", { count: "exact", head: true })
        .eq("status", "active").eq("branch_id", branchId).eq("classes.branch_id", branchId).eq("classes.session_id", sessionId),
      supabase.from("classes").select("id", { count: "exact", head: true })
        .eq("branch_id", branchId).eq("session_id", sessionId),
      supabase.from("audit_logs").select("id,action,entity_type,created_at")
        .order("created_at", { ascending: false }).limit(5),
    ]);
    return {
      students: { data: students.count, error: students.error?.message ?? null },
      classes: { data: classes.count, error: classes.error?.message ?? null },
      audit: { data: audit.data, error: audit.error?.message ?? null },
    };
  } catch (error) {
    const message = failure(error);
    return {
      students: { data: null, error: message },
      classes: { data: null, error: message },
      audit: { data: null, error: message },
    };
  }
}
