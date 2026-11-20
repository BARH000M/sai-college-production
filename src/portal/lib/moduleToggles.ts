import { useCallback, useEffect, useState } from "react";
import { supabase } from "./supabase";
import { applyModuleToggleSnapshot } from "./navigation";

export type ModuleToggleRow = { module_id: string; enabled: boolean; updated_at: string; updated_by: string | null };
export type ModuleRoleOverrideRow = { module_id: string; role: string; enabled: boolean };

type LoadState = { ready: boolean; error: string | null };

/**
 * Loads the global module toggles plus the per-role overrides once and keeps the
 * navigation store in sync.
 *
 * On the first failure of a session the navigation stays open (nothing is hidden)
 * so the portal remains reachable. After a successful load, a later failure keeps
 * the last known state, so a transient error cannot re-expose a module an
 * administrator disabled. The error is surfaced to the caller either way.
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

        if (active) {
          applyModuleToggleSnapshot({
            toggles: (globalResult.data ?? []) as ModuleToggleRow[],
            // A failed override read is not fatal: every role inherits the global state.
            overrides: overrideResult.error ? null : ((overrideResult.data ?? []) as ModuleRoleOverrideRow[]),
          });
          setError(null);
        }
      } catch (e) {
        if (active) {
          // Keep the last applied state; only a first-load failure leaves it empty.
          applyModuleToggleSnapshot({ toggles: null, overrides: null });
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