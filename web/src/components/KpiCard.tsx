export function KpiCard({ label, value, detail, error }: {
  label: string; value: string | number; detail: string; error?: string | null;
}) {
  return <article className="kpi-card">
    <span>{label}</span>
    <strong>{value}</strong>
    {error ? <p className="error-text" role="alert">{error}</p> : <small>{detail}</small>}
  </article>;
}
