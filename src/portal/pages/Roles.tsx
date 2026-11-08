import { useEffect, useMemo, useState } from "react";
import {
  assignableRoles, changeUserRole, loadDirectoryUsers,
  type AssignableRole, type DirectoryUser,
} from "../lib/roles";
import { isAppRole, roleLabels } from "../lib/navigation";
import { LearningAccountPanel } from "./roles/LearningAccountPanel";
import { TeacherAccountPanel } from "./roles/TeacherAccountPanel";

function displayRole(role: string): string {
  return isAppRole(role) ? roleLabels[role] : role;
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

  async function toggle(user: DirectoryUser, role: AssignableRole, grant: boolean) {
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
        <p className="muted">امنح الحسابات الجديدة وصول معلم أو ولي أمر أو طالب. تُطبَّق الصلاحيات فوراً عند تسجيل الدخول.</p>
      </div>
      <button className="button secondary" onClick={() => setRetry((value) => value + 1)} disabled={loading}>تحديث القائمة</button>
    </div>
    <p className="data-note">هذه الشاشة متاحة للمسؤول العام فقط؛ وتُسجَّل كل عملية منح أو سحب في سجل التدقيق.</p>
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
    {!loading && !error && !filtered.length && <section className="panel"><p className="muted">لا توجد حسابات مطابقة.</p></section>}
    {!loading && !!filtered.length && <section className="panel">
      <div className="table-scroll">
        <table className="management-table">
          <thead>
            <tr>
              <th>الحساب</th>
              <th>البريد الإلكتروني</th>
              <th>الأدوار الحالية</th>
              <th>منح / سحب الوصول</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((user) => (
              <tr key={user.id}>
                <td>{user.fullName || "بدون اسم"}{user.profileMissing && <small className="nav-unavailable">لم يكمل الملف الشخصي</small>}</td>
                <td dir="ltr">{user.email || "—"}</td>
                <td>
                  <div className="role-chips">
                    {user.roles.length
                      ? user.roles.map((role) => <span className="role-chip" key={role}>{displayRole(role)}</span>)
                      : <span className="muted">لا توجد أدوار</span>}
                  </div>
                </td>
                <td>
                  <div className="role-actions">
                    {assignableRoles.map((role) => {
                      const granted = user.roles.includes(role.id);
                      return (
                        <button
                          key={role.id}
                          type="button"
                          className={`button ${granted ? "secondary" : "primary"}`}
                          disabled={!!busyKey}
                          onClick={() => void toggle(user, role.id, !granted)}
                        >
                          {granted ? `سحب ${role.label}` : `منح ${role.label}`}
                        </button>
                      );
                    })}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>}
  </main>;
}