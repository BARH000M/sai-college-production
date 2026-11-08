import type { ReactNode } from "react";

export function KpiCard({ label, value, detail, error, action }: {
  label: string; value: string | number; detail: string; error?: string | null; action?: ReactNode;
}) {
  return <article className="kpi-card">
    <span>{label}</span>
    <strong>{value}</strong>
    {error ? <p className="error-text" role="alert">{error}</p> : <small>{detail}</small>}
    {action}
  </article>;
}