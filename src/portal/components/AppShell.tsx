import { useState, type ReactNode } from "react";
import { NavLink } from "react-router-dom";
import logo from "../assets/saiLogo";
import { isAppRole, modulePath, roleLabels, visibleNavigation } from "../lib/navigation";
import { useLearningNotifications } from "../hooks/useLearningNotifications";

export function AppShell({ profileName, email, roles, onSignOut, busy, signOutError, children }: {
  profileName: string; email: string | null; roles: readonly string[]; onSignOut: () => void; busy: boolean;
  signOutError: string | null; children: ReactNode;
}) {
  const [collapsed, setCollapsed] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [search, setSearch] = useState("");
  const { count: unreadCount } = useLearningNotifications(roles);
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
        {links.map((item) => <NavLink key={item.id} className="nav-link" to={modulePath(item)} onClick={() => setMenuOpen(false)} title={item.label}><i className={item.icon} aria-hidden="true"></i><span className="sidebar-label">{item.label}{item.id === "homework" && unreadCount > 0 && <small className="nav-badge" aria-label={`${unreadCount} تحديث جديد`}>{unreadCount}</small>}</span></NavLink>)}
      </nav>
      <p className="sidebar-note sidebar-label"><NavLink to="/" className="nav-link"><i className="ri-arrow-go-back-line" aria-hidden="true"></i><span className="sidebar-label">الموقع التعريفي</span></NavLink>{names}</p>
    </aside>
    <div className="main-area">
      <header className="topbar">
        <button className="icon-button mobile-menu" onClick={() => setMenuOpen(true)} aria-label="فتح القائمة" aria-controls="sidebar" aria-expanded={menuOpen}>☰</button>
        <div className="mobile-brand"><img src={logo} alt="" /><strong>كلية ساي</strong></div>
        <div className="search-wrap"><label className="sr-only" htmlFor="global-search">البحث في أقسام اللوحة</label><input id="global-search" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="البحث في أقسام اللوحة" />
          {search.trim() && <div className="search-results">{matches.length ? matches.map((item) => <NavLink key={item.id} to={modulePath(item)} onClick={() => setSearch("")}>{item.label}</NavLink>) : <span>لا توجد أقسام مطابقة.</span>}</div>}
        </div>
        {unreadCount > 0
          ? <NavLink className="icon-button notice-link" to="/portal/modules/homework" title={`${unreadCount} تحديثاً جديداً في الواجبات`} aria-label={`${unreadCount} تحديثاً جديداً في الواجبات`}>
            <span aria-hidden="true">♧</span>
            <span className="notice-badge" aria-hidden="true">{unreadCount}</span>
          </NavLink>
          : <button className="icon-button" disabled title="لا توجد إشعارات جديدة" aria-label="لا توجد إشعارات جديدة">♧</button>}
        <details className="profile-menu"><summary>{profileName}</summary><div><span dir="ltr">{email ?? "البريد غير متاح"}</span><button onClick={onSignOut} disabled={busy}>{busy ? "جارٍ تسجيل الخروج..." : "تسجيل الخروج"}</button></div></details>
      </header>
      {signOutError && <p className="error-box global-error" role="alert">تعذر تسجيل الخروج: {signOutError}</p>}
      {children}
    </div>
    <nav className="bottom-nav" aria-label="التنقل على الهاتف">
      {links.slice(0, 5).map((item) => <NavLink key={item.id} to={modulePath(item)}><i className={item.icon} aria-hidden="true"></i><small>{item.label}</small></NavLink>)}
    </nav>
  </div>;
}
