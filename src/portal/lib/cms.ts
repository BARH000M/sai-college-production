import { supabase } from "./supabase";

export type SiteContentRow = {
  key: string;
  section: string;
  label_ar: string;
  value_ar: string;
  value_en: string;
  sort_order: number;
};

export type CmsProgram = {
  id: string;
  title_ar: string;
  title_en: string;
  summary_ar: string;
  summary_en: string;
  duration_ar: string;
  duration_en: string;
  icon: string;
  is_published: boolean;
  sort_order: number;
};

export type CmsNews = {
  id: string;
  title_ar: string;
  title_en: string;
  summary_ar: string;
  summary_en: string;
  tag_ar: string;
  tag_en: string;
  image_url: string | null;
  published_at: string;
  is_published: boolean;
  sort_order: number;
};

export type ProgramDraft = Omit<CmsProgram, "id">;
export type NewsDraft = Omit<CmsNews, "id">;

export const cmsSections: Record<string, string> = {
  hero: "الواجهة الرئيسية",
  stats: "الأرقام والإحصاءات",
  about: "قسم عن الكلية ونقاطه",
  campus: "قسم الحياة الجامعية والمعرض",
};

 const programColumns = "id,title_ar,title_en,summary_ar,summary_en,duration_ar,duration_en,icon,is_published,sort_order";
const newsColumns = "id,title_ar,title_en,summary_ar,summary_en,tag_ar,tag_en,image_url,published_at,is_published,sort_order";

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function cmsError(context: string, error: unknown): string {
  return `${context}: ${message(error)}`;
}

export function emptyProgramDraft(): ProgramDraft {
  return {
    title_ar: "", title_en: "", summary_ar: "", summary_en: "",
    duration_ar: "سنتان · دبلوم", duration_en: "2 years · Diploma",
    icon: "ri-book-open-line", is_published: true, sort_order: 0,
  };
}

export function emptyNewsDraft(): NewsDraft {
  const today = new Date();
  const offset = today.getTimezoneOffset() * 60000;
  return {
    title_ar: "", title_en: "", summary_ar: "", summary_en: "",
    tag_ar: "أخبار", tag_en: "News", image_url: null,
    published_at: new Date(today.getTime() - offset).toISOString().slice(0, 10),
    is_published: true, sort_order: 0,
  };
}

export function programToDraft(row: CmsProgram): ProgramDraft {
  const { id: _id, ...rest } = row;
  return rest;
}

export function newsToDraft(row: CmsNews): NewsDraft {
  const { id: _id, ...rest } = row;
  return rest;
}

export function validateProgram(draft: ProgramDraft): string | null {
  if (!draft.title_ar.trim()) return "الاسم العربي للبرنامج مطلوب.";
  if (!draft.summary_ar.trim()) return "الوصف العربي للبرنامج مطلوب.";
  if (!draft.icon.trim()) return "أيقونة البرنامج مطلوبة.";
  return null;
}

export function validateNews(draft: NewsDraft): string | null {
  if (!draft.title_ar.trim()) return "العنوان العربي مطلوب.";
  if (!draft.summary_ar.trim()) return "الملخص العربي مطلوب.";
  if (!draft.published_at) return "تاريخ النشر مطلوب.";
  return null;
}

export async function loadSiteContent(): Promise<SiteContentRow[]> {
  const result = await supabase.from("cms_site_content")
    .select("key,section,label_ar,value_ar,value_en,sort_order")
    .order("sort_order");
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as SiteContentRow[];
}

export async function saveSiteContent(rows: SiteContentRow[]): Promise<void> {
  const results = await Promise.all(rows.map((row) => supabase.from("cms_site_content")
    .update({ value_ar: row.value_ar, value_en: row.value_en, updated_at: new Date().toISOString() })
    .eq("key", row.key)
    .select("key")));
  const failure = results.find((result) => result.error);
  if (failure?.error) throw new Error(failure.error.message);
  if (results.some((result) => !result.data?.length)) {
    throw new Error("لم تُحفظ بعض الحقول؛ تأكد من صلاحية حسابك للنشر.");
  }
}

export async function loadPrograms(includeUnpublished: boolean): Promise<CmsProgram[]> {
  let query = supabase.from("cms_programs").select(programColumns).order("sort_order").order("created_at");
  if (!includeUnpublished) query = query.eq("is_published", true);
  const result = await query;
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as CmsProgram[];
}

export async function saveProgram(draft: ProgramDraft, id: string | null): Promise<void> {
  const error = validateProgram(draft);
  if (error) throw new Error(error);
  const values = { ...draft, updated_at: new Date().toISOString() };
  if (id) {
    const result = await supabase.from("cms_programs").update(values).eq("id", id).select("id");
    if (result.error) throw new Error(result.error.message);
    if (!result.data?.length) throw new Error("لم يُحفظ البرنامج؛ قد لا تملك صلاحية النشر.");
    return;
  }
  const result = await supabase.from("cms_programs").insert(values).select("id");
  if (result.error) throw new Error(result.error.message);
}

export async function deleteProgram(id: string): Promise<void> {
  const result = await supabase.from("cms_programs").delete().eq("id", id).select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحذف البرنامج؛ قد لا تملك صلاحية الحذف.");
}

export async function loadNews(includeUnpublished: boolean): Promise<CmsNews[]> {
  let query = supabase.from("cms_news").select(newsColumns).order("sort_order").order("published_at", { ascending: false });
  if (!includeUnpublished) query = query.eq("is_published", true);
  const result = await query;
  if (result.error) throw new Error(result.error.message);
  return (result.data ?? []) as CmsNews[];
}

export async function saveNews(draft: NewsDraft, id: string | null): Promise<void> {
  const error = validateNews(draft);
  if (error) throw new Error(error);
  const values = { ...draft, image_url: draft.image_url?.trim() ? draft.image_url.trim() : null, updated_at: new Date().toISOString() };
  if (id) {
    const result = await supabase.from("cms_news").update(values).eq("id", id).select("id");
    if (result.error) throw new Error(result.error.message);
    if (!result.data?.length) throw new Error("لم يُحفظ الخبر؛ قد لا تملك صلاحية النشر.");
    return;
  }
  const result = await supabase.from("cms_news").insert(values).select("id");
  if (result.error) throw new Error(result.error.message);
}

export async function deleteNews(id: string): Promise<void> {
  const result = await supabase.from("cms_news").delete().eq("id", id).select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحذف الخبر؛ قد لا تملك صلاحية الحذف.");
}