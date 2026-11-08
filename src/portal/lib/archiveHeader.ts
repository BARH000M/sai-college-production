/**
 * Remembers the term/semester and prepared-by values used on printed sheets,
 * so staff don't retype them on every print. Values are kept locally on this
 * browser only and never leave the device.
 */
export type SavedArchive = { term: string; preparedBy: string };

const LAST_KEY = "sai.archiveHeader.last";
const LIST_KEY = "sai.archiveHeader.list";
const MAX_SAVED = 12;

function safeParse<T>(raw: string | null, fallback: T): T {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function clean(value: SavedArchive): SavedArchive {
  return { term: value.term.trim(), preparedBy: value.preparedBy.trim() };
}

function isUsable(value: SavedArchive): boolean {
  return Boolean(value.term || value.preparedBy);
}

function sameEntry(a: SavedArchive, b: SavedArchive): boolean {
  return a.term === b.term && a.preparedBy === b.preparedBy;
}

/** The most recently used term / prepared-by pair, if any. */
export function loadLastArchive(): SavedArchive | null {
  if (typeof window === "undefined") return null;
  const value = clean(safeParse<SavedArchive>(window.localStorage.getItem(LAST_KEY), { term: "", preparedBy: "" }));
  return isUsable(value) ? value : null;
}

/** Recently used pairs, newest first, de-duplicated. */
export function loadArchiveList(): SavedArchive[] {
  if (typeof window === "undefined") return [];
  const list = safeParse<SavedArchive[]>(window.localStorage.getItem(LIST_KEY), []);
  if (!Array.isArray(list)) return [];
  return list.map(clean).filter(isUsable).slice(0, MAX_SAVED);
}

/** Saves a pair as the latest used entry and prepends it to the recent list. */
export function rememberArchive(value: SavedArchive): SavedArchive[] {
  if (typeof window === "undefined") return [];
  const entry = clean(value);
  if (!isUsable(entry)) return loadArchiveList();
  const next = [entry, ...loadArchiveList().filter((item) => !sameEntry(item, entry))].slice(0, MAX_SAVED);
  window.localStorage.setItem(LAST_KEY, JSON.stringify(entry));
  window.localStorage.setItem(LIST_KEY, JSON.stringify(next));
  return next;
}

/** Human label for a saved pair shown in the dropdown. */
export function archiveLabel(value: SavedArchive): string {
  const term = value.term || "بدون فصل";
  return value.preparedBy ? `${term} — ${value.preparedBy}` : term;
}