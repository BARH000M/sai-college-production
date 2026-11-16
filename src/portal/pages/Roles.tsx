import { useEffect, useMemo, useState } from "react";
import {
  assignableRoles, changeUserRole, isAssignableRole, isBranchScopedRole, loadDirectoryUsers,
  type AssignableRole, type BranchOption, type DirectoryUser,
} from "../lib/roles";
import { isAppRole, roleLabels } from "../lib/navigation";
import { LearningAccountPanel } from "./roles/LearningAccountPanel";
import { TeacherAccountPanel } from "./roles/TeacherAccountPanel";

function displayRole(role: string): string {
  const assignable = assignableRoles.find((item) => item.id === role);
  if (assignable) return assignable.label;
  return isAppRole(role) ? roleLabels[role] : role;
}

function GrantRow({
  user, busyKey, branches, onGrant, onRevoke,
}: {
  user: DirectoryUser;
  busyKey: string | null;
  branches: BranchOption[];
  onGrant: (user: DirectoryUser, role: AssignableRole, branchIds: string[]) => Promise<boolean>;
  onRevoke: (user: DirectoryUser, role: AssignableRole) => Promise<boolean>;
}) {
  const [choice, setChoice] = useState<AssignableRole | "">("");
  const [selectedBranches, setSelectedBranches] = useState<string[]>(user.branchIds);
  const addable = assignableRoles.filter((role) => !user.roles.includes(role.id));
  const selectedRole = choice ? assignableRoles.find((role) => role.id === choice) : undefined;

  useEffect(() => {
    setSelectedBranches(user.branchIds);
  }, [user.id, user.branchIds]);

  return (
    <div className="role-grant-row">
      <div className="role-grant-main">
        <div className="role-grant-id">
          <strong>{user.fullName || "بدون اسم"}</strong>
          <small dir="ltr">{user.email || "—"}</small>
          {!user.emailConfirmed && <span className="role-flag">لم يؤكد بريده بعد</span>}
          {user.profileMissing && <span className="role-flag">لم يكمل الملف الشخصي</span>}
        </div>
        {!!user.branchIds.length && <small className="muted">
          نطاق الفروع الحالي: {user.branchIds.map((id) => branches.find((branch) => branch.id === id)?.name ?? "فرع غير نشط").join("، ")}
        </small>}
        <div className="role-chips">
          {user.roles.length
            ? user.roles.map((role) => (
              <span className="role-chip" key={role}>
                {displayRole(role)}
                {isAssignableRole(role) && (
                  <button
                    type="button"
                    className="role-chip-remove"
                    aria-label={`سحب دور ${displayRole(role)}`}
                    disabled={!!busyKey}
                    onClick={() => onRevoke(user, role)}
                  >×</button>
                )}
              </span>
            ))
            : <span className="muted">لا توجد أدوار بعد</span>}
        </div>
      </div>
      <div className="role-grant-action">
        <select
          aria-label={`اختر دوراً لمنحه ${user.fullName || user.email}`}
          value={choice}
          disabled={!!busyKey || !addable.length}
          onChange={(event) => setChoice(event.target.value as AssignableRole | "")}
        >
          <option value="">اختر دوراً...</option>
          {addable.map((role) => <option key={role.id} value={role.id}>{role.label}</option>)}
        </select>
        {selectedRole && isBranchScopedRole(selectedRole.id) && (
          <label className="role-branch-picker">نطاق الفروع لهذا الحساب
            <select
              aria-label={`اختر نطاق الفروع لحساب ${user.fullName || user.email}`}
              multiple
              size={Math.min(Math.max(branches.length, 2), 5)}
              value={selectedBranches}
              disabled={!!busyKey || !branches.length}
              onChange={(event) => setSelectedBranches(
                Array.from(event.currentTarget.selectedOptions, (option) => option.value),
              )}
            >
              {branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>)}
            </select>
          </label>
        )}
        <button
          type="button"
          className="button primary"
          disabled={
            !!busyKey || !choice || !user.emailConfirmed
            || (!!selectedRole && isBranchScopedRole(selectedRole.id) && (!branches.length || !selectedBranches.length))
          }
          onClick={() => {
            if (!choice) return;
            void onGrant(user, choice, selectedRole && isBranchScopedRole(selectedRole.id) ? selectedBranches : [])
              .then((succeeded) => { if (succeeded) setChoice(""); });
          }}
        >
          منح الوصول
        </button>
        {selectedRole && isBranchScopedRole(selectedRole.id) && !branches.length && (
          <small className="role-branch-warning">لا يوجد فرع نشط؛ لن يُمنح دور موظف قبل إعداد فرع معتمد.</small>
        )}
      </div>
    </div>
  );
}

export function Roles() {
  const [users, setUsers] = useState<DirectoryUser[]>([]);
  const [branches, setBranches] = useState<BranchOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    void loadDirectoryUsers()
      .then((result) => {
        if (active) {
          setUsers(result.users);
          setBranches(result.branches);
        }
      })
      .catch((failure: unknown) => {
        if (active) setError(failure instanceof Error ? failure.message : String(failure));
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [retry]);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return users;
    return users.filter((user) => `${user.fullName} ${user.email}`.toLowerCase().includes(term));
  }, [users, search]);

  const waiting = filtered.filter((user) => !user.roles.some((role) => isAppRole(role)));
  const active = filtered.filter((user) => user.roles.some((role) => isAppRole(role)));

  async function apply(user: DirectoryUser, role: AssignableRole, grant: boolean, branchIds: string[] = []) {
    const key = `${user.id}:${role}`;
    if (busyKey) return false;
    if (grant && !user.emailConfirmed) {
      setError("يجب تأكيد البريد الإلكتروني قبل منح أي دور.");
      return false;
    }
    if (grant && isBranchScopedRole(role) && !branchIds.length) {
      setError("اختر فرعاً نشطاً واحداً على الأقل لهذا الحساب.");
      return false;
    }
    const roleLabel = displayRole(role);
    const branchNames = branchIds.map((id) => branches.find((branch) => branch.id === id)?.name ?? id);
    const actionText = grant ? `منح دور «${roleLabel}» إلى ${user.fullName || user.email}` : `سحب دور «${roleLabel}» من ${user.fullName || user.email}`;
    if (!window.confirm(`هل تؤكد ${actionText}${grant && branchNames.length ? ` ضمن الفروع: ${branchNames.join("، ")}` : ""}؟`)) {
      return false;
    }
    if (grant && role === "super_admin" && !window.confirm(
      `تأكيد إضافي: سيحصل ${user.fullName || user.email} على صلاحيات المسؤول العام على مستوى النظام. هل تريد المتابعة؟`,
    )) {
      return false;
    }

    setBusyKey(key);
    setError(null);
    setSuccess(null);
    try {
      await changeUserRole(user.id, role, grant, branchIds, grant && role === "super_admin");
      try {
        const refreshed = await loadDirectoryUsers();
        setUsers(refreshed.users);
        setBranches(refreshed.branches);
      } catch {
        setError(`تم تنفيذ العملية، لكن تعذر تحديث القائمة. استخدم «تحديث القائمة» للتحقق من الحالة.`);
        return true;
      }
      setSuccess(`${grant ? "تم منح" : "تم سحب"} دور «${roleLabel}» ${grant ? "إلى" : "من"} ${user.fullName || user.email}.`);
      return true;
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : String(failure));
      return false;
    } finally {
      setBusyKey(null);
    }
  }

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">الإدارة العامة</p>
        <h1>إدارة الأدوار والصلاحيات</h1>
        <p className="muted">راجع حالة تأكيد البريد ونطاق الفروع قبل منح الدور. لا يُمنح الوصول قبل تأكيد العملية.</p>
      </div>
      <button className="button secondary" onClick={() => setRetry((value) => value + 1)} disabled={loading}>تحديث القائمة</button>
    </div>
    <p className="data-note">هذه الشاشة متاحة للمسؤول العام فقط. نطاق الفروع مشترك بين أدوار الموظفين في الحساب ويُحدّث حصراً من الخادم. دور الطالب أو ولي الأمر لا يثبت وحده وجود تسجيل أكاديمي أو علاقة أسرية؛ يجب إكمال الربط المعتمد بشكل منفصل.</p>
    <LearningAccountPanel />
    <TeacherAccountPanel />

    <fieldset className="context-card" disabled={loading}>
      <label>البحث بالاسم أو البريد الإلكتروني
        <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="اكتب للبحث" />
      </label>
    </fieldset>

    {loading && <p role="status">جارٍ تحميل الحسابات...</p>}
    {error && <p className="error-box" role="alert">{error} <button type="button" className="text-button" onClick={() => setRetry((value) => value + 1)}>إعادة المحاولة</button></p>}
    {success && <p className="success-box" role="status">{success}</p>}

    {!loading && !error && <>
      <section className="panel">
        <div className="home-panel-head">
          <h2>بانتظار الوصول</h2>
          <span className="role-count">{waiting.length}</span>
        </div>
        <p className="data-note">الحسابات بلا دور. لا يمكن منح الدور قبل تأكيد البريد الإلكتروني، ويظل الربط الأكاديمي أو الأسري خطوة منفصلة.</p>
        {!waiting.length
          ? <p className="muted">لا توجد حسابات تنتظر الوصول حالياً.</p>
          : <div className="role-grant-list">
            {waiting.map((user) => <GrantRow key={user.id} user={user} busyKey={busyKey} branches={branches}
              onGrant={(u, role, branchIds) => apply(u, role, true, branchIds)}
              onRevoke={(u, role) => apply(u, role, false)} />)}
          </div>}
      </section>

      <section className="panel">
        <div className="home-panel-head">
          <h2>حسابات لديها وصول</h2>
          <span className="role-count">{active.length}</span>
        </div>
        {!active.length
          ? <p className="muted">لا توجد حسابات ذات وصول مطابقة للبحث.</p>
          : <div className="role-grant-list">
            {active.map((user) => <GrantRow key={user.id} user={user} busyKey={busyKey} branches={branches}
              onGrant={(u, role, branchIds) => apply(u, role, true, branchIds)}
              onRevoke={(u, role) => apply(u, role, false)} />)}
          </div>}
      </section>
    </>}
  </main>;
}