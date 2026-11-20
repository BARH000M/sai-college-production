import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "../../lib/supabase";
import { roleLabels, toggleableModules, type AppRole } from "../../lib/navigation";

type ToggleRow = { module_id: string; enabled: boolean };
type OverrideRow = { module_id: string; role: string; enabled: boolean };

const alwaysEnabledNote = "الوحدات الأساسية (الرئيسية، الملف الشخصي، الإشعارات، الإعدادات، إدارة الأدوار، النسخ الاحتياطي) لا يمكن تعطيلها حتى تبقى الإدارة قابلة للوصول.";
const overrideNote = "يمكن تخصيص كل وحدة لكل دور: «افتراضي» يتبع الحالة العامة، و«مفعّل» أو «معطّل» يتجاوزها لهذا الدور فقط. إذا كان للمستخدم أكثر من دور، تُتاح الوحدة إذا كان أي دور منها يسمح بها.";

/** inherit (null) → enabled (true) → disabled (false) → inherit */
function nextOverride(current: boolean | null): boolean | null {
  if (current === null) return true;
  if (current === true) return false;
  return null;
}

const overrideLabels = {
  inherit: "افتراضي",
  on: "مفعّل",
  off: "معطّل",
} as const;

export function ModuleTogglesPanel({ roles, userId }: { roles: readonly string[]; userId: string | null }) {
  const canWrite = roles.includes("super_admin");
  const modules = toggleableModules();
  const [state, setState] = useState<Record<string, boolean>>({});
  const [overrides, setOverrides] = useState<Record<string, Record<string, boolean>>>({});
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [globalResult, overrideResult] = await Promise.all([
        supabase.from("sai_module_toggles").select("module_id,enabled"),
        supabase.from("sai_module_role_overrides").select("module_id,role,enabled"),
      ]);
      if (globalResult.error) throw new Error(globalResult.error.message);

      const next: Record<string, boolean> = {};
      for (const row of (globalResult.data ?? []) as ToggleRow[]) next[row.module_id] = row.enabled;
      setState(next);

      const nextOverrides: Record<string, Record<string, boolean>> = {};
      if (!overrideResult.error) {
        for (const row of (overrideResult.data ?? []) as OverrideRow[]) {
          nextOverrides[row.module_id] = { ...(nextOverrides[row.module_id] ?? {}), [row.role]: row.enabled };
        }
      }
      setOverrides(nextOverrides);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  function announce(message: string) {
    setNotice(message);
    window.dispatchEvent(new Event("sai:module-toggles-changed"));
  }

  function toggleExpanded(moduleId: string) {
    setExpanded((previous) => {
      const next = new Set(previous);
      if (next.has(moduleId)) next.delete(moduleId); else next.add(moduleId);
      return next;
    });
  }

  async function toggle(moduleId: string, nextEnabled: boolean) {
    if (!canWrite || busy) return;
    setBusy(moduleId);
    setError(null);
    setNotice(null);
    try {
      const { data, error: writeError } = await supabase
        .from("sai_module_toggles")
        .upsert(
          { module_id: moduleId, enabled: nextEnabled, updated_by: userId, updated_at: new Date().toISOString() },
          { onConflict: "module_id" },
        )
        .select("module_id");
      if (writeError) throw new Error(writeError.message);
      if (!data?.length) throw new Error("لم تسمح صلاحيات قاعدة البيانات بتغيير حالة الوحدة.");
      setState((previous) => ({ ...previous, [moduleId]: nextEnabled }));
      announce(`تم ${nextEnabled ? "تفعيل" : "تعطيل"} الوحدة. سينعكس التغيير على القوائم فوراً.`);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(null);
    }
  }

  async function setOverride(moduleId: string, role: AppRole, value: boolean | null) {
    if (!canWrite || busy) return;
    const key = `${moduleId}:${role}`;
    setBusy(key);
    setError(null);
    setNotice(null);
    try {
      if (value === null) {
        const { error: deleteError } = await supabase
          .from("sai_module_role_overrides")
          .delete()
          .eq("module_id", moduleId)
          .eq("role", role);
        if (deleteError) throw new Error(deleteError.message);
        setOverrides((previous) => {
          const inner = { ...(previous[moduleId] ?? {}) };
          delete inner[role];
          const next = { ...previous };
          if (Object.keys(inner).length === 0) delete next[moduleId]; else next[moduleId] = inner;
          return next;
        });
        announce(`تم إرجاع «${roleLabels[role]}» إلى الحالة الافتراضية في هذه الوحدة.`);
      } else {
        const { data, error: writeError } = await supabase
          .from("sai_module_role_overrides")
          .upsert(
            { module_id: moduleId, role, enabled: value, updated_by: userId, updated_at: new Date().toISOString() },
            { onConflict: "module_id,role" },
          )
          .select("module_id");
        if (writeError) throw new Error(writeError.message);
        if (!data?.length) throw new Error("لم تسمح صلاحيات قاعدة البيانات بحفظ تخصيص الدور.");
        setOverrides((previous) => ({ ...previous, [moduleId]: { ...(previous[moduleId] ?? {}), [role]: value } }));
        announce(`تم ${value ? "تفعيل" : "تعطيل"} الوحدة لدور «${roleLabels[role]}».`);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(null);
    }
  }

  const enabledCount = modules.filter((item) => state[item.id] !== false).length;
  const customizedCount = useMemo(() => Object.keys(overrides).length, [overrides]);

  return <section className="panel" style={{ marginTop: 20 }}>
    <div className="home-panel-head">
      <h2>تفعيل الوحدات</h2>
      <p className="muted">{enabledCount} من {modules.length} وحدة مفعّلة · {customizedCount} وحدة بتخصيص أدوار</p>
    </div>
    <p className="data-note">{alwaysEnabledNote}</p>
    <p className="data-note">{overrideNote}</p>
    {!canWrite && <p className="data-note" role="status">يمكنك الاطلاع على حالة الوحدات فقط؛ التغيير متاح للمدير العام.</p>}
    {loading && <p role="status">جارٍ تحميل حالة الوحدات...</p>}
    {error && <p className="error-box" role="alert">{error}</p>}
    {notice && <p role="status">{notice}</p>}
    {!loading && <div style={{ display: "grid", gap: 10, marginTop: 12, gridTemplateColumns: "repeat(auto-fill, minmax(300px, 1fr))" }}>
      {modules.map((item) => {
        const enabled = state[item.id] !== false;
        const moduleOverrides = overrides[item.id] ?? {};
        const isOpen = expanded.has(item.id);
        const overrideCount = Object.keys(moduleOverrides).length;
        const effectiveRoleCount = item.roles.filter((role) => {
          const value = moduleOverrides[role];
          return value === undefined ? enabled : value;
        }).length;
        return <div key={item.id} className="panel" style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
            <span style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <i className={item.icon} aria-hidden="true" />
              <strong>{item.label}</strong>
            </span>
            <button
              type="button"
              className={`button ${enabled ? "" : "secondary"}`}
              disabled={!canWrite || busy !== null}
              aria-pressed={enabled}
              onClick={() => void toggle(item.id, !enabled)}
            >
              {busy === item.id ? "جارٍ الحفظ..." : enabled ? "مفعّلة" : "معطّلة"}
            </button>
          </div>

          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8 }}>
            <span className="muted" style={{ fontSize: 13 }}>
              {effectiveRoleCount} من {item.roles.length} دور يراه{overrideCount > 0 ? ` · ${overrideCount} تخصيص` : ""}
            </span>
            <button type="button" className="button secondary" onClick={() => toggleExpanded(item.id)} aria-expanded={isOpen}>
              {isOpen ? "إخفاء الأدوار" : "تخصيص الأدوار"}
            </button>
          </div>

          {isOpen && <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
            {item.roles.map((role) => {
              const value = moduleOverrides[role] ?? null;
              const key = `${item.id}:${role}`;
              const label = value === null ? overrideLabels.inherit : value ? overrideLabels.on : overrideLabels.off;
              return <button
                key={role}
                type="button"
                className={`button ${value === true ? "" : "secondary"}`}
                style={{ fontSize: 12 }}
                disabled={!canWrite || busy !== null}
                title={`${roleLabels[role]} — ${label}`}
                aria-label={`${item.label}: ${roleLabels[role]} — ${label}`}
                onClick={() => void setOverride(item.id, role, nextOverride(value))}
              >
                {busy === key ? "..." : `${roleLabels[role]}: ${label}`}
              </button>;
            })}
          </div>}
        </div>;
      })}
    </div>}
  </section>;
}