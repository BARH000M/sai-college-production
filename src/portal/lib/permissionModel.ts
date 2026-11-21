/**
 * Pure permission model — no React, no network.
 *
 * The portal separates three concerns that must never be conflated:
 *   1. module activation (global toggle + per-role override),
 *   2. sidebar presentation (order, labels, quick links),
 *   3. security permissions (action × record scope).
 *
 * This module models #3. A role is granted a set of actions on a module together
 * with one record scope. Effective authorization is evaluated per role so a
 * multi-role account can never combine one role's action with another role's
 * unrelated, wider record scope.
 */
import { navigation, roleLabels, type AppRole } from "./navigation";

export type PermissionAction =
  | "view" | "create" | "edit" | "delete" | "archive" | "restore"
  | "approve" | "reject" | "assign" | "publish" | "unpublish"
  | "print" | "download" | "export" | "import" | "manage"
  | "financial_approval" | "administrative_approval";

export type RecordScope =
  | "institution" | "branch" | "academic_session" | "department" | "class"
  | "course" | "assigned_student" | "guardian_relationship" | "own_records";

export type ModulePermission = { actions: PermissionAction[]; scope: RecordScope };
export type PermissionMatrix = Record<AppRole, Record<string, ModulePermission>>;

export const permissionActions: readonly { id: PermissionAction; ar: string; en: string; zh: string; sensitive?: boolean }[] = [
  { id: "view", ar: "عرض", en: "View", zh: "查看" },
  { id: "create", ar: "إنشاء", en: "Create", zh: "创建" },
  { id: "edit", ar: "تعديل", en: "Edit", zh: "编辑" },
  { id: "delete", ar: "حذف", en: "Delete", zh: "删除", sensitive: true },
  { id: "archive", ar: "أرشفة", en: "Archive", zh: "归档" },
  { id: "restore", ar: "استعادة", en: "Restore", zh: "恢复", sensitive: true },
  { id: "approve", ar: "اعتماد", en: "Approve", zh: "批准", sensitive: true },
  { id: "reject", ar: "رفض", en: "Reject", zh: "驳回" },
  { id: "assign", ar: "إسناد", en: "Assign", zh: "分配" },
  { id: "publish", ar: "نشر", en: "Publish", zh: "发布", sensitive: true },
  { id: "unpublish", ar: "إلغاء النشر", en: "Unpublish", zh: "取消发布" },
  { id: "print", ar: "طباعة", en: "Print", zh: "打印" },
  { id: "download", ar: "تنزيل", en: "Download", zh: "下载" },
  { id: "export", ar: "تصدير", en: "Export", zh: "导出" },
  { id: "import", ar: "استيراد", en: "Import", zh: "导入", sensitive: true },
  { id: "manage", ar: "إدارة كاملة", en: "Manage", zh: "管理", sensitive: true },
  { id: "financial_approval", ar: "اعتماد مالي", en: "Financial approval", zh: "财务审批", sensitive: true },
  { id: "administrative_approval", ar: "اعتماد إداري", en: "Administrative approval", zh: "行政审批", sensitive: true },
];

export const recordScopes: readonly { id: RecordScope; ar: string; en: string; zh: string; rank: number }[] = [
  { id: "institution", ar: "المؤسسة كاملة", en: "Institution", zh: "全机构", rank: 100 },
  { id: "branch", ar: "الفرع", en: "Branch", zh: "校区", rank: 80 },
  { id: "academic_session", ar: "الجلسة الأكاديمية", en: "Academic session", zh: "学期", rank: 70 },
  { id: "department", ar: "القسم", en: "Department", zh: "部门", rank: 60 },
  { id: "class", ar: "الصف", en: "Class", zh: "班级", rank: 50 },
  { id: "course", ar: "المقرر", en: "Course", zh: "课程", rank: 45 },
  { id: "assigned_student", ar: "الطالب المسند", en: "Assigned student", zh: "分配学生", rank: 30 },
  { id: "guardian_relationship", ar: "علاقة ولي الأمر", en: "Verified guardian relationship", zh: "已核验监护关系", rank: 20 },
  { id: "own_records", ar: "سجلاتي", en: "Own records", zh: "本人记录", rank: 10 },
];

const actionIds = new Set<string>(permissionActions.map((action) => action.id));
const scopeIds = new Set<string>(recordScopes.map((scope) => scope.id));
export const appRoles = Object.keys(roleLabels) as AppRole[];

export function isPermissionAction(value: string): value is PermissionAction {
  return actionIds.has(value);
}
export function isRecordScope(value: string): value is RecordScope {
  return scopeIds.has(value);
}
export function scopeRank(scope: RecordScope): number {
  return recordScopes.find((entry) => entry.id === scope)?.rank ?? 0;
}

/** Default action set per role. Sensitive actions are granted only where the role runs them. */
const roleActionPresets: Record<AppRole, PermissionAction[]> = {
  super_admin: permissionActions.map((action) => action.id),
  admin: ["view", "create", "edit", "archive", "restore", "approve", "reject", "assign", "publish", "unpublish", "print", "download", "export", "import", "manage", "administrative_approval"],
  teacher: ["view", "create", "edit", "print", "download", "export", "assign"],
  accountant: ["view", "create", "edit", "approve", "print", "download", "export", "import", "financial_approval"],
  receptionist: ["view", "create", "edit", "print", "download"],
  librarian: ["view", "create", "edit", "archive", "print", "download", "export"],
  student: ["view", "download"],
  parent: ["view", "download"],
  content_editor: ["view", "create", "edit", "delete", "publish", "unpublish", "export", "import"],
};

const roleScopePreset: Record<AppRole, RecordScope> = {
  super_admin: "institution",
  admin: "branch",
  teacher: "class",
  accountant: "branch",
  receptionist: "branch",
  librarian: "institution",
  student: "own_records",
  parent: "guardian_relationship",
  content_editor: "institution",
};

/** Every module id the registry can authorize (navigation catalogue). */
export function catalogueModuleIds(): string[] {
  return navigation.map((item) => item.id);
}

/**
 * Builds the default matrix from the approved role→module mapping. A role only
 * receives actions on modules it is approved for, so the default matrix can never
 * expose a module the navigation already blocks.
 */
export function buildDefaultMatrix(): PermissionMatrix {
  const matrix = {} as PermissionMatrix;
  for (const role of appRoles) {
    const modules: Record<string, ModulePermission> = {};
    for (const item of navigation) {
      if (!item.roles.includes(role)) continue;
      modules[item.id] = { actions: [...roleActionPresets[role]], scope: roleScopePreset[role] };
    }
    matrix[role] = modules;
  }
  return matrix;
}

/**
 * Validates and normalises an untrusted matrix (e.g. loaded JSON). Unknown roles,
 * modules, actions and scopes are dropped; a module missing from a role stays
 * unauthorized rather than silently inheriting a wider default.
 */
export function normalizeMatrix(raw: unknown): PermissionMatrix | null {
  if (!raw || typeof raw !== "object") return null;
  const source = raw as Record<string, unknown>;
  const matrix = {} as PermissionMatrix;
  for (const role of appRoles) {
    const roleRow = source[role];
    if (!roleRow || typeof roleRow !== "object") { matrix[role] = {}; continue; }
    const modules: Record<string, ModulePermission> = {};
    for (const [moduleId, value] of Object.entries(roleRow as Record<string, unknown>)) {
      const item = navigation.find((entry) => entry.id === moduleId);
      if (!item || !item.roles.includes(role)) continue;
      if (!value || typeof value !== "object") continue;
      const { actions, scope } = value as { actions?: unknown; scope?: unknown };
      if (!Array.isArray(actions)) continue;
      const cleanActions = [...new Set(actions.filter((action): action is PermissionAction => typeof action === "string" && isPermissionAction(action)))];
      if (cleanActions.length === 0) continue;
      modules[moduleId] = {
        actions: cleanActions,
        scope: typeof scope === "string" && isRecordScope(scope) ? scope : roleScopePreset[role],
      };
    }
    matrix[role] = modules;
  }
  return matrix;
}

export type EffectiveGrant = { role: AppRole; scope: RecordScope };

/**
 * Effective authorization for a set of roles. Each grant carries the scope of the
 * role that produced it, so the caller can require that the record satisfies at
 * least one granting role's scope — never a cross-role combination.
 */
export function evaluatePermission(
  matrix: PermissionMatrix,
  roles: readonly string[],
  moduleId: string,
  action: PermissionAction,
): { granted: boolean; grants: EffectiveGrant[] } {
  const grants: EffectiveGrant[] = [];
  for (const role of roles) {
    if (!appRoles.includes(role as AppRole)) continue;
    const typed = role as AppRole;
    const permission = matrix[typed]?.[moduleId];
    if (!permission || !permission.actions.includes(action)) continue;
    grants.push({ role: typed, scope: permission.scope });
  }
  return { granted: grants.length > 0, grants };
}

/** True when the record scope is satisfied by at least one granting role. */
export function isScopeSatisfied(grants: readonly EffectiveGrant[], requiredRank: number): boolean {
  return grants.some((grant) => scopeRank(grant.scope) >= requiredRank);
}

export type MatrixChange = { role: AppRole; moduleId: string; action: PermissionAction | null; before: string; after: string };

function actionsOf(matrix: PermissionMatrix, role: AppRole, moduleId: string): PermissionAction[] {
  return matrix[role]?.[moduleId]?.actions ?? [];
}

/** Human-readable summary of what changed between two matrices. */
export function diffMatrix(before: PermissionMatrix, after: PermissionMatrix): MatrixChange[] {
  const changes: MatrixChange[] = [];
  for (const role of appRoles) {
    const moduleIds = new Set([...Object.keys(before[role] ?? {}), ...Object.keys(after[role] ?? {})]);
    for (const moduleId of moduleIds) {
      const beforeActions = new Set(actionsOf(before, role, moduleId));
      const afterActions = new Set(actionsOf(after, role, moduleId));
      for (const action of permissionActions.map((entry) => entry.id)) {
        const had = beforeActions.has(action);
        const has = afterActions.has(action);
        if (had === has) continue;
        changes.push({ role, moduleId, action, before: had ? "granted" : "denied", after: has ? "granted" : "denied" });
      }
      const beforeScope = before[role]?.[moduleId]?.scope ?? "—";
      const afterScope = after[role]?.[moduleId]?.scope ?? "—";
      if (beforeScope !== afterScope && afterScope !== "—") {
        changes.push({ role, moduleId, action: null, before: beforeScope, after: afterScope });
      }
    }
  }
  return changes;
}

/** True when a change touches a sensitive action or widens a record scope. */
export function hasSensitiveChange(changes: readonly MatrixChange[], before: PermissionMatrix): boolean {
  return changes.some((change) => {
    if (change.action === null) {
      return scopeRank(change.after as RecordScope) > scopeRank(change.before as RecordScope);
    }
    if (change.after !== "granted") return false;
    return permissionActions.find((action) => action.id === change.action)?.sensitive === true
      || change.action === "manager"
      || before[change.role]?.[change.moduleId] === undefined;
  });
}

export function countGranted(matrix: PermissionMatrix, role: AppRole): number {
  return Object.values(matrix[role] ?? {}).reduce((sum, permission) => sum + permission.actions.length, 0);
}

export function isMatrixEmpty(matrix: PermissionMatrix): boolean {
  return appRoles.every((role) => Object.keys(matrix[role] ?? {}).length === 0);
}