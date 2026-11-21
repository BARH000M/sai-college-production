import { useCallback, useEffect, useState } from "react";
import { supabase } from "../lib/supabase";
import { applySidebarLayout, emptySidebarLayout, loadSidebarLayout, type SidebarLayout } from "../lib/sidebarLayout";

/**
 * Loads the presentation layout once per session, applies it to the shared store
 * and keeps it in sync with settings changes made by another administrator.
 * A failure falls back to the empty default so navigation never breaks.
 */
export function useSidebarLayout(): { ready: boolean; layout: SidebarLayout; reload: () => void } {
  const [layout, setLayout] = useState<SidebarLayout>(emptySidebarLayout);
  const [ready, setReady] = useState(false);
  const [nonce, setNonce] = useState(0);
  const reload = useCallback(() => setNonce((value) => value + 1), []);

  useEffect(() => {
    let active = true;
    void loadSidebarLayout()
      .then((next) => {
        if (!active) return;
        applySidebarLayout(next);
        setLayout(next);
      })
      .catch(() => {
        if (!active) return;
        applySidebarLayout(null);
        setLayout(emptySidebarLayout);
      })
      .finally(() => { if (active) setReady(true); });
    return () => { active = false; };
  }, [nonce]);

  useEffect(() => {
    const channel = supabase
      .channel("sai-sidebar-layout")
      .on("postgres_changes", { event: "*", schema: "public", table: "sai_system_settings" }, () => reload())
      .subscribe();
    const onLocal = () => reload();
    window.addEventListener("sai:sidebar-layout-changed", onLocal);
    return () => {
      void supabase.removeChannel(channel);
      window.removeEventListener("sai:sidebar-layout-changed", onLocal);
    };
  }, [reload]);

  return { ready, layout, reload };
}