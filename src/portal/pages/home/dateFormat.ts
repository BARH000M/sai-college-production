export function formatDate(value: string | null): string {
  if (!value) return "—";
  return new Date(value).toLocaleDateString("ar", { year: "numeric", month: "short", day: "numeric" });
}

export function formatDateTime(value: string | null): string {
  if (!value) return "—";
  return new Date(value).toLocaleString("ar", { year: "numeric", month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
}
