import { useState, type ReactNode } from "react";
import { NavLink } from "react-router-dom";
import logo from "../assets/sai-logo.png";
import { isAppRole, isModuleAvailable, modulePath, roleLabels, visibleNavigation } from "../lib/navigation";

export function AppShell({ profileName, email, roles, onSignOut, busy, signOutError, children }: {
  profileName: string; email: string | null; roles: readonly string[]; onSignOut: () => void; busy: boolean;
  signOutError: string | null; children: ReactNode;
}) {
  const [collapsed, setCollapsed] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [search, setSearch] = useState("");
  const links = visibleNavigation(roles);
  const matches = links.filter((item) => item.label.includes(search.trim()));
  const names = roles.filter(isAppRole).map((role) => roleLabels[role]).join(" · ");

  return <div className={`layout ${collapsed ? "collapsed" : ""}`}>
    {menuOpen && <button className="drawer-backdrop" aria-label="إغلاق القائمة" onClick={() => setMenuOpen(false)} />}
    <aside className={`sidebar ${menuOpen ? "open" : ""}`} id="sidebar">
      <div className="sidebar-brand">
        <img className="brand-logo" src={logo} alt="شعار كلية ساي" />
        <div className="sidebar-label"><strong>كلية ساي</strong><small>{names}</small></div>
        <button className="icon-button collapse-button" onClick={() => setCollapsed(!collapsed)} aria-label={collapsed ? "توسيع القائمة" : "طي القائمة"} aria-expanded={!collapsed}>☰</button>
      </div>
      <p className="nav-heading sidebar-label">القائمة الرئيسية</p>
      <nav aria-label="التنقل الرئيسي">
        {links.map((item) => <NavLink key={item.id} className="nav-link" to={modulePath(item)} onClick={() => setMenuOpen(false)} title={item.label}><span aria-hidden="true">{item.icon}</span><span className="sidebar-label">{item.label}{!isModuleAvailable(item.id) && <small className="nav-unavailable">غير متاح بعد</small>}</span></NavLink>)}
      </nav>
      <p className="sidebar-note sidebar-label">{names}</p>
    </aside>
    <div className="main-area">
      <header className="topbar">
        <button className="icon-button mobile-menu" onClick={() => setMenuOpen(true)} aria-label="فتح القائمة" aria-controls="sidebar" aria-expanded={menuOpen}>☰</button>
        <div className="mobile-brand"><img src={logo} alt="" /><strong>كلية ساي</strong></div>
        <div className="search-wrap"><label className="sr-only" htmlFor="global-search">البحث في أقسام اللوحة</label><input id="global-search" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="البحث في أقسام اللوحة" />
          {search.trim() && <div className="search-results">{matches.length ? matches.map((item) => <NavLink key={item.id} to={modulePath(item)} onClick={() => setSearch("")}>{item.label}{!isModuleAvailable(item.id) ? " — غير متاح بعد" : ""}</NavLink>) : <span>لا توجد أقسام مطابقة.</span>}</div>}
        </div>
        <button className="icon-button" disabled title="الإشعارات غير متاحة بعد" aria-label="الإشعارات غير متاحة بعد">♧</button>
        <details className="profile-menu"><summary>{profileName}</summary><div><span dir="ltr">{email ?? "البريد غير متاح"}</span><button onClick={onSignOut} disabled={busy}>{busy ? "جارٍ تسجيل الخروج..." : "تسجيل الخروج"}</button></div></details>
      </header>
      {signOutError && <p className="error-box global-error" role="alert">تعذر تسجيل الخروج: {signOutError}</p>}
      {children}
    </div>
    <nav className="bottom-nav" aria-label="التنقل على الهاتف">
      {links.slice(0, 5).map((item) => <NavLink key={item.id} to={modulePath(item)}><span aria-hidden="true">{item.icon}</span><small>{item.label}</small></NavLink>)}
    </nav>
  </div>;
}
