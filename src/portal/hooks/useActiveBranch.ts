import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/portal/lib/supabase";

export type BranchOption = { id: string; name: string };

/**
 * Resolves the branch a screen should operate on.
 *
 * `branches` is already protected by row-level security, so this returns only
 * the branches the signed-in account may read. A screen must never fall back to
 * an invented branch identifier — if none is readable the caller shows an
 * unavailable state instead of writing against the wrong institution.
 */
export function useActiveBranch() {
  const [branches, setBranches] = useState<BranchOption[]>([]);
  const [branchId, setBranchId] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const result = await supabase
          .from("branches")
          .select("id,name")
          .eq("is_active", true)
          .order("name");
        if (result.error) throw new Error(result.error.message);
        if (cancelled) return;
        const rows = (result.data ?? []) as BranchOption[];
        setBranches(rows);
        setBranchId((current) => current || rows[0]?.id || "");
      } catch (caught) {
        if (!cancelled) setError(caught instanceof Error ? caught.message : String(caught));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await supabase.from("branches").select("id,name").eq("is_active", true).order("name");
      if (result.error) throw new Error(result.error.message);
      const rows = (result.data ?? []) as BranchOption[];
      setBranches(rows);
      setBranchId((current) => current || rows[0]?.id || "");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
    } finally {
      setLoading(false);
    }
  }, []);

  return { branches, branchId, setBranchId, loading, error, reload };
}