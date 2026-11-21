import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { buildLabDatasets, loadLabWorkspace, type LabDatasets, type LabWorkspace } from "@/portal/lib/labRepository";
import * as curated from "@/mocks/learningLabs";

/**
 * Curated sample content used only as a fallback when the database has nothing
 * published for a given lab, so a practice screen is never blank. The shape is
 * the same as `LabDatasets`; the cast documents that intent in one place.
 */
const fallback = curated as unknown as LabDatasets;

type LabDataState = {
  data: LabDatasets;
  loading: boolean;
  error: string | null;
  retry: () => void;
};

const LabDataContext = createContext<LabDataState | null>(null);

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/**
 * Loads the published curriculum once for the mounted lab and derives every
 * practice dataset from it. A failed load falls back to curated content, so the
 * lab stays usable while the error is surfaced for a retry.
 */
export function LabDataProvider({ children }: { children: ReactNode }) {
  const [workspace, setWorkspace] = useState<LabWorkspace | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);
    loadLabWorkspace()
      .then((next) => {
        if (active) setWorkspace(next);
      })
      .catch((failure: unknown) => {
        if (active) {
          setWorkspace(null);
          setError(message(failure));
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [attempt]);

  const data = useMemo(() => buildLabDatasets(workspace, fallback), [workspace]);
  const retry = useCallback(() => setAttempt((value) => value + 1), []);

  const value = useMemo<LabDataState>(() => ({ data, loading, error, retry }), [data, loading, error, retry]);

  return <LabDataContext.Provider value={value}>{children}</LabDataContext.Provider>;
}

/** Datasets for the current lab. Falls back to the curated sample while loading. */
export function useLabDatasets(): LabDatasets {
  const context = useContext(LabDataContext);
  return context?.data ?? fallback;
}

/** Load status for a lab that wants to show a spinner or a retry banner. */
export function useLabDataStatus(): LabDataState {
  const context = useContext(LabDataContext);
  return context ?? { data: fallback, loading: false, error: null, retry: () => {} };
}