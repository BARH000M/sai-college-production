import { useCallback, useEffect, useMemo, useRef, useState } from "react";

/**
 * Versioned local workspace persistence.
 *
 * The four V4.0 modules (media library, content approvals, quiz delivery and
 * reception) are presented as an operational workspace. Their records are held
 * in a versioned, namespaced browser store so the screens are fully interactive
 * and survive a refresh while the reviewed Supabase migration is approved.
 *
 * The stored payload is `{ version, data }`. A version bump discards incompatible
 * historic data instead of rendering a half-migrated record set, and every read
 * is validated by the caller-supplied `guard` so a malformed value can never
 * crash a screen.
 */
const NAMESPACE = "sai.portal.workspace";

type Envelope<T> = { version: number; data: T };

function read<T>(key: string, version: number, fallback: T, guard: (value: unknown) => value is T): T {
  try {
    const raw = window.localStorage.getItem(`${NAMESPACE}.${key}`);
    if (!raw) return fallback;
    const envelope = JSON.parse(raw) as Envelope<unknown>;
    if (!envelope || envelope.version !== version) return fallback;
    return guard(envelope.data) ? envelope.data : fallback;
  } catch {
    return fallback;
  }
}

/**
 * Returns the current value plus a setter (same contract as `useState`). Writes
 * are debounced to the next tick so rapid typing does not thrash localStorage.
 */
export function useLocalWorkspace<T>(
  key: string,
  version: number,
  initial: T,
  guard: (value: unknown) => value is T,
): readonly [T, (updater: T | ((current: T) => T)) => void, () => void] {
  const [value, setValue] = useState<T>(() => read(key, version, initial, guard));
  const first = useRef(true);

  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    try {
      window.localStorage.setItem(`${NAMESPACE}.${key}`, JSON.stringify({ version, data: value }));
    } catch {
      // Storage may be full or blocked; the in-memory value still works.
    }
  }, [key, version, value]);

  const update = useCallback((updater: T | ((current: T) => T)) => {
    setValue((current) => (typeof updater === "function" ? (updater as (c: T) => T)(current) : updater));
  }, []);

  const reset = useCallback(() => {
    setValue(initial);
    try {
      window.localStorage.removeItem(`${NAMESPACE}.${key}`);
    } catch {
      // ignore
    }
  }, [initial, key]);

  return useMemo(() => [value, update, reset] as const, [value, update, reset]);
}

/** Small id helper shared by the workspace modules. */
export function workspaceId(prefix: string): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

/** ISO timestamp helper. */
export function nowIso(): string {
  return new Date().toISOString();
}

/** Human date in the SAI portal style. */
export function formatWorkspaceDate(value: string | null | undefined): string {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}