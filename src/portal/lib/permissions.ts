import { supabase } from "./supabase";
import { buildDefaultMatrix, normalizeMatrix, type PermissionMatrix, type AppRole } from "./permissionModel";
import { roleLabels } from "./navigation";

/** Settings category and key used to persist the reviewed permission matrix. */
export const PERMISSION_CATEGORY = "access";
export const PERMISSION_KEY = "role_permissions_matrix";

export type PermissionAuditRow = {
  category: string;
  setting_key: string;
  action: string;
  actor_user_id: string | null;
  happened_at: string;
};

function friendly(error: { code?: string; message: string }): Error {
  if (error.code === "PGRST205" || error.code === "42P01") {
    return new Error("تخزين الصلاحيات غير مثبت في هذه البيئة. تُعرض المصفوفة الافتراضية مع تعطيل الحفظ حتى تجهيز الخادم.");
  }
  if (error.code === "42501") return new Error("لا تملك صلاحية تعديل صلاحيات الأدوار. هذه الشاشة للمسؤول العام فقط.");
  return new Error(`تعذر تنفيذ عملية الصلاحيات: ${error.message}`);
}

/**
 * Loads the saved matrix. A missing row (first run) or an unreadable payload
 * falls back to the approved defaults so the editor always opens on a safe,
 * least-privilege baseline instead of an empty screen.
 */
export async function loadPermissionMatrix(): Promise<{ matrix: PermissionMatrix; persisted: boolean }> {
  const { data, error } = await supabase
    .from("sai_system_settings")
    .select("value_text")
    .eq("category", PERMISSION_CATEGORY)
    .eq("setting_key", PERMISSION_KEY)
    .maybeSingle();
  if (error) throw friendly(error);
  if (!data?.value_text) return { matrix: buildDefaultMatrix(), persisted: false };
  try {
    const parsed = normalizeMatrix(JSON.parse(data.value_text as string));
    if (!parsed) return { matrix: buildDefaultMatrix(), persisted: false };
    return { matrix: parsed, persisted: true };
  } catch {
    return { matrix: buildDefaultMatrix(), persisted: false };
  }
}

/** Persists the matrix atomically as one reviewed JSON document. */
export async function savePermissionMatrix(matrix: PermissionMatrix, userId: string | null): Promise<void> {
  const normalized = normalizeMatrix(matrix);
  if (!normalized) throw new Error("مصفوفة الصلاحيات غير صالحة؛ أعد المحاولة بعد إعادة التحميل.");
  const { data, error } = await supabase
    .from("sai_system_settings")
    .upsert(
      {
        category: PERMISSION_CATEGORY,
        setting_key: PERMISSION_KEY,
        value_text: JSON.stringify(normalized),
        value_type: "json",
        scope: "institution",
        updated_by: userId,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "category,setting_key" },
    )
    .select("setting_key");
  if (error) throw friendly(error);
  if (data?.length !== 1) throw new Error("لم يؤكد الخادم حفظ مصفوفة الصلاحيات.");
}

/** Recent audit history for the matrix, newest first. */
export async function loadPermissionAudit(limit = 20): Promise<PermissionAuditRow[]> {
  const { data, error } = await supabase
    .from("sai_system_settings_audit")
    .select("category,setting_key,action,actor_user_id,happened_at")
    .eq("category", PERMISSION_CATEGORY)
    .eq("setting_key", PERMISSION_KEY)
    .order("happened_at", { ascending: false })
    .limit(limit);
  if (error) {
    // Audit history is read-only context; a failure must not block the editor.
    if (error.code === "PGRST205" || error.code === "42P01" || error.code === "42501") return [];
    throw friendly(error);
  }
  return (data ?? []) as PermissionAuditRow[];
}

/** Resets the matrix to the approved defaults (persisted immediately). */
export function defaultMatrixForRole(role: AppRole): PermissionMatrix[AppRole] {
  return buildDefaultMatrix()[role];
}

export function roleDisplayName(role: string): string {
  return roleLabels[role as AppRole] ?? role;
}