import { useCallback, useEffect, useState } from "react";
import { supabase } from "./supabase";
import { applyModuleToggles } from "./navigation";

export type ModuleToggleRow = { module_id: string; enabled: boolean; updated_at: string; updated_by: string | null };
export type ModuleRoleOverrideRow = { module_id: string; role: string; enabled: boolean };

type LoadState = { ready: boolean; error: string | null };

/**
 * Loads the global module toggles plus the per-role overrides once and keeps the
 * navigation store in sync. Fails open: if the tables are unreachable, no module
 * is hidden and every role inherits the global state.
 */
export function useModuleToggles(): LoadState & { reload: () => void } {
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const reload = useCallback(() => setNonce((value) => value + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const [globalResult, overrideResult] = await Promise.all([
          supabase.from("sai_module_toggles").select("module_id,enabled"),
          supabase.from("sai_module_role_overrides").select("module_id,role,enabled"),
        ]);
        if (globalResult.error) throw new Error(globalResult.error.message);

        const disabled = ((globalResult.data ?? []) as ModuleToggleRow[])
          .filter((row) => row.enabled === false)
          .map((row) => row.module_id);

        const overrides: Record<string, Record<string, boolean>> = {};
        if (!overrideResult.error) {
          for (const row of (overrideResult.data ?? []) as ModuleRoleOverrideRow[]) {
            overrides[row.module_id] = { ...(overrides[row.module_id] ?? {}), [row.role]: row.enabled === true };
          }
        }

        if (active) {
          applyModuleToggles(disabled, overrides);
          setError(null);
        }
      } catch (e) {
        if (active) {
          applyModuleToggles([], {});
          setError(e instanceof Error ? e.message : String(e));
        }
      } finally {
        if (active) setReady(true);
      }
    })();
    return () => { active = false; };
  }, [nonce]);

  useEffect(() => {
    const channel = supabase
      .channel("sai-module-toggles")
      .on("postgres_changes", { event: "*", schema: "public", table: "sai_module_toggles" }, () => reload())
      .on("postgres_changes", { event: "*", schema: "public", table: "sai_module_role_overrides" }, () => reload())
      .subscribe();
    const onLocal = () => reload();
    window.addEventListener("sai:module-toggles-changed", onLocal);
    return () => { void supabase.removeChannel(channel); window.removeEventListener("sai:module-toggles-changed", onLocal); };
  }, [reload]);

  return { ready, error, reload };
}