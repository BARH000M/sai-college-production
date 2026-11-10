import { useEffect, useMemo, useState } from "react";
import {
  assignableRoles, changeUserRole, isAssignableRole, loadDirectoryUsers,
  type AssignableRole, type DirectoryUser,
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
  user, busyKey, onGrant, onRevoke,
}: {
  user: DirectoryUser;
  busyKey: string | null;
  onGrant: (user: DirectoryUser, role: AssignableRole) => void;
  onRevoke: (user: DirectoryUser, role: AssignableRole) => void;
}) {
  const [choice, setChoice] = useState<AssignableRole | "">("");
  const addable = assignableRoles.filter((role) => !user.roles.includes(role.id));
  return (
    <div className="role-grant-row">
      <div className="role-grant-main">
        <div className="role-grant-id">
          <strong>{user.fullName || "بدون اسم"}</strong>
          <small dir="ltr">{user.email || "—"}</small>
          {!user.emailConfirmed && <span className="role-flag">لم يؤكد بريده بعد</span>}
          {user.profileMissing && <span className="role-flag">لم يكمل الملف الشخصي</span>}
        </div>
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
        <button
          type="button"
          className="button primary"
          disabled={!!busyKey || !choice}
          onClick={() => { if (choice) { onGrant(user, choice); setChoice(""); } }}
        >
          منح الوصول
        </button>
      </div>
    </div>
  );
}

export function Roles() {
  const [users, setUsers] = useState<DirectoryUser[]>([]);
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
      .then((rows) => { if (active) setUsers(rows); })
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

  async function apply(user: DirectoryUser, role: AssignableRole, grant: boolean) {
    const key = `${user.id}:${role}`;
    if (busyKey) return;
    setBusyKey(key);
    setError(null);
    setSuccess(null);
    try {
      await changeUserRole(user.id, role, grant);
      setUsers((current) => current.map((row) => row.id === user.id
        ? {
            ...row,
            roles: grant ? [...new Set([...row.roles, role])] : row.roles.filter((item) => item !== role),
          }
        : row));
      setSuccess(`${grant ? "تم منح" : "تم سحب"} دور «${displayRole(role)}» ${grant ? "إلى" : "من"} ${user.fullName || user.email}.`);
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : String(failure));
    } finally {
      setBusyKey(null);
    }
  }

  return <main className="workspace">
    <div className="page-heading">
      <div>
        <p className="eyebrow">الإدارة العامة</p>
        <h1>إدارة الأدوار والصلاحيات</h1>
        <p className="muted">امنح الحسابات الجديدة الوصول المناسب، واسحب أي دور بالنقر على × في شارته. تُطبَّق الصلاحيات فوراً عند تسجيل الدخول.</p>
      </div>
      <button className="button secondary" onClick={() => setRetry((value) => value + 1)} disabled={loading}>تحديث القائمة</button>
    </div>
    <p className="data-note">هذه الشاشة متاحة للمسؤول العام فقط؛ ومنح أي دور موظف يضع الحساب في فريق الحرم ليصبح قابلاً للإسناد. تُسجَّل كل عملية في سجل التدقيق.</p>
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
        <p className="data-note">حسابات سجّلت للتو ولم يُمنح لها أي دور بعد، بما فيها من لم يؤكد بريده الإلكتروني.</p>
        {!waiting.length
          ? <p className="muted">لا توجد حسابات تنتظر الوصول حالياً.</p>
          : <div className="role-grant-list">
            {waiting.map((user) => <GrantRow key={user.id} user={user} busyKey={busyKey}
              onGrant={(u, role) => void apply(u, role, true)} onRevoke={(u, role) => void apply(u, role, false)} />)}
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
            {active.map((user) => <GrantRow key={user.id} user={user} busyKey={busyKey}
              onGrant={(u, role) => void apply(u, role, true)} onRevoke={(u, role) => void apply(u, role, false)} />)}
          </div>}
      </section>
    </>}
  </main>;
}