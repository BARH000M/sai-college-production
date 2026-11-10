import { admissionStatuses } from "../../lib/admissions";

export function OccupancyBar({ enrolled, capacity }: { enrolled: number; capacity: number }) {
  const percent = capacity > 0 ? Math.round((enrolled / capacity) * 100) : 0;
  const tone = percent >= 100 ? "full" : percent >= 80 ? "warn" : "ok";
  return (
    <div className="occupancy">
      <div className="learn-bar">
        <span className={`occupancy-fill ${tone}`} style={{ width: `${Math.min(percent, 100)}%` }} />
      </div>
      <small>{enrolled} / {capacity} · {percent}%</small>
    </div>
  );
}

const statusTones: Record<string, string> = {
  new: "status-warn",
  contacted: "status-ok",
  assessment: "status-ok",
  accepted: "status-ok",
  enrolled: "status-ok",
  rejected: "status-danger",
  withdrawn: "status-neutral",
};

export function AdmissionChip({ status }: { status: string }) {
  const label = admissionStatuses[status as keyof typeof admissionStatuses] ?? status;
  return <span className={`lab-status ${statusTones[status] ?? "status-neutral"}`}>{label}</span>;
}

export function formatDate(value: string | null): string {
  if (!value) return "—";
  return new Date(value).toLocaleDateString("ar", { year: "numeric", month: "short", day: "numeric" });
}

export function formatDateTime(value: string | null): string {
  if (!value) return "—";
  return new Date(value).toLocaleString("ar", { year: "numeric", month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
}