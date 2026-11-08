export type RecentScan = { reference: string; scannedAt: string };

const storageKey = "sai.scanner.recent.v1";
const maxEntries = 6;

function isRecent(value: unknown): value is RecentScan {
  if (typeof value !== "object" || value === null) return false;
  const row = value as Record<string, unknown>;
  return typeof row.reference === "string" && row.reference.length > 0
    && typeof row.scannedAt === "string" && row.scannedAt.length > 0;
}

export function loadRecentScans(): RecentScan[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(storageKey);
    if (!raw) return [];
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(isRecent).slice(0, maxEntries);
  } catch {
    return [];
  }
}

function persist(items: RecentScan[]): RecentScan[] {
  if (typeof window === "undefined") return items;
  try {
    window.localStorage.setItem(storageKey, JSON.stringify(items));
  } catch {
    return items;
  }
  return items;
}

export function rememberScan(reference: string): RecentScan[] {
  const trimmed = reference.trim();
  if (!trimmed) return loadRecentScans();
  const entry: RecentScan = { reference: trimmed, scannedAt: new Date().toISOString() };
  const next = [entry, ...loadRecentScans().filter((item) => item.reference.toUpperCase() !== trimmed.toUpperCase())]
    .slice(0, maxEntries);
  return persist(next);
}

export function clearRecentScans(): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.removeItem(storageKey);
  } catch {
    // Ignore storage failures; the list simply stays as it is.
  }
}