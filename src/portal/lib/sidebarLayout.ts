/**
 * Presentation-only sidebar layout.
 *
 * A super administrator can reorder main modules, hide a module from the menu,
 * rename and re-icon it, pin quick links and choose which modules start open.
 * This is stored as one reviewed JSON document in the shared settings table.
 *
 * It is presentation only: hiding a module from the menu never changes security
 * permissions, and the record scope is still enforced by the database.
 */
import { supabase } from "./supabase";
import { portalModules } from "./portalRegistry";
import { navigation } from "./navigation";

export const LAYOUT_CATEGORY = "access";
export const LAYOUT_KEY = "sidebar_layout";

export type SidebarLabelOverride = { ar: string; en: string; zh: string };

export type SidebarLayout = {
  order: string[];
  hidden: string[];
  labels: Record<string, SidebarLabelOverride>;
  icons: Record<string, string>;
  quickLinks: string[];
  defaultExpanded: string[];
};

export const emptySidebarLayout: SidebarLayout = {
  order: [], hidden: [], labels: {}, icons: {}, quickLinks: [], defaultExpanded: [],
};

const moduleIds = new Set(portalModules.map((module) => module.id));
const pageIds = new Set(navigation.map((item) => item.id));

function uniqueKnown(values: unknown, allowed: Set<string>): string[] {
  if (!Array.isArray(values)) return [];
  return [...new Set(values.filter((value): value is string => typeof value === "string" && allowed.has(value)))];
}

function cleanLabel(value: unknown, fallback: SidebarLabelOverride): SidebarLabelOverride {
  if (!value || typeof value !== "object") return fallback;
  const source = value as Record<string, unknown>;
  const clean = (key: keyof SidebarLabelOverride) => (
    typeof source[key] === "string" ? (source[key] as string).trim().slice(0, 80) : ""
  );
  return { ar: clean("ar"), en: clean("en"), zh: clean("zh") };
}

/** Validates an untrusted layout against the live registry. */
export function normalizeSidebarLayout(raw: unknown): SidebarLayout {
  if (!raw || typeof raw !== "object") return { ...emptySidebarLayout };
  const source = raw as Record<string, unknown>;

  const labels: Record<string, SidebarLabelOverride> = {};
  if (source.labels && typeof source.labels === "object") {
    for (const [moduleId, value] of Object.entries(source.labels as Record<string, unknown>)) {
      if (!moduleIds.has(moduleId)) continue;
      const cleaned = cleanLabel(value, { ar: "", en: "", zh: "" });
      if (cleaned.ar || cleaned.en || cleaned.zh) labels[moduleId] = cleaned;
    }
  }

  const icons: Record<string, string> = {};
  if (source.icons && typeof source.icons === "object") {
    for (const [moduleId, value] of Object.entries(source.icons as Record<string, unknown>)) {
      if (!moduleIds.has(moduleId)) continue;
      if (typeof value === "string" && /^ri-[a-z0-9-]+$/.test(value)) icons[moduleId] = value;
    }
  }

  return {
    order: uniqueKnown(source.order, moduleIds),
    hidden: uniqueKnown(source.hidden, moduleIds),
    labels,
    icons,
    quickLinks: uniqueKnown(source.quickLinks, pageIds).slice(0, 12),
    defaultExpanded: uniqueKnown(source.defaultExpanded, moduleIds),
  };
}

export async function loadSidebarLayout(): Promise<SidebarLayout> {
  const { data, error } = await supabase
    .from("sai_system_settings")
    .select("value_text")
    .eq("category", LAYOUT_CATEGORY)
    .eq("setting_key", LAYOUT_KEY)
    .maybeSingle();
  if (error) {
    if (error.code === "PGRST205" || error.code === "42P01" || error.code === "42501") return { ...emptySidebarLayout };
    throw new Error(`تعذر تحميل تهيئة القائمة الجانبية: ${error.message}`);
  }
  if (!data?.value_text) return { ...emptySidebarLayout };
  try {
    return normalizeSidebarLayout(JSON.parse(data.value_text as string));
  } catch {
    return { ...emptySidebarLayout };
  }
}

export async function saveSidebarLayout(layout: SidebarLayout, userId: string | null): Promise<void> {
  const normalized = normalizeSidebarLayout(layout);
  const { data, error } = await supabase
    .from("sai_system_settings")
    .upsert(
      {
        category: LAYOUT_CATEGORY,
        setting_key: LAYOUT_KEY,
        value_text: JSON.stringify(normalized),
        value_type: "json",
        scope: "institution",
        updated_by: userId,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "category,setting_key" },
    )
    .select("setting_key");
  if (error) throw new Error(`تعذر حفظ تهيئة القائمة الجانبية: ${error.message}`);
  if (data?.length !== 1) throw new Error("لم يؤكد الخادم حفظ تهيئة القائمة الجانبية.");
}

export type LayoutAuditRow = { action: string; actor_user_id: string | null; happened_at: string };

export async function loadLayoutAudit(limit = 15): Promise<LayoutAuditRow[]> {
  const { data, error } = await supabase
    .from("sai_system_settings_audit")
    .select("action,actor_user_id,happened_at")
    .eq("category", LAYOUT_CATEGORY)
    .eq("setting_key", LAYOUT_KEY)
    .order("happened_at", { ascending: false })
    .limit(limit);
  if (error) return [];
  return (data ?? []) as LayoutAuditRow[];
}

/** Orders modules by the saved layout, keeping unlisted modules in registry order. */
export function orderedModuleIds(order: readonly string[]): string[] {
  const known = order.filter((id) => moduleIds.has(id));
  const rest = portalModules.map((module) => module.id).filter((id) => !known.includes(id));
  return [...known, ...rest];
}

export function isLayoutHidden(hidden: readonly string[], moduleId: string): boolean {
  return hidden.includes(moduleId);
}

/** Applies a saved label/icon override, returning undefined when none is set. */
export function labelOverrideFor(layout: SidebarLayout, moduleId: string): SidebarLabelOverride | undefined {
  const entry = layout.labels[moduleId];
  if (!entry) return undefined;
  return entry;
}

export function iconOverrideFor(layout: SidebarLayout, moduleId: string): string | undefined {
  return layout.icons[moduleId];
}

// In-memory active layout, applied once per session after loading from the server.
let activeLayout: SidebarLayout = { ...emptySidebarLayout };

/** Applies a loaded layout (or resets to the empty default when null). */
export function applySidebarLayout(layout: SidebarLayout | null): void {
  activeLayout = layout ? normalizeSidebarLayout(layout) : { ...emptySidebarLayout };
}

export function currentSidebarLayout(): SidebarLayout {
  return activeLayout;
}