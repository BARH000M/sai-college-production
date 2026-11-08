import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import logo from "../assets/saiLogo";

export function StatusCard({ title, message, onRetry, link, children }: {
  title: string; message: string; onRetry?: () => void; link?: string; children?: ReactNode;
}) {
  return <main className="centered"><section className="auth-card" role="status">
    <img className="brand-logo" src={logo} alt="شعار كلية ساي" />
    <h1>{title}</h1><p className="muted">{message}</p>
    <div className="actions">
      {onRetry && <button className="button primary" onClick={onRetry}>إعادة المحاولة</button>}
      {link && <Link className="button primary" to={link}>العودة للرئيسية</Link>}
      {children}
    </div>
  </section></main>;
}
