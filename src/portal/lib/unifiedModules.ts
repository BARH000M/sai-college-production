import { supabase } from "./supabase";

// EXACT table names and record columns used by the Yemen SAI Flutter v1.2 package.
// These eight tables are defined by the proposed 029 migration and must be installed
// before enabling the pages in production. Existing homework/library/finance stay unchanged.
export type UnifiedId = "downloads" | "inventory" | "transport" | "portfolio" | "housing" | "certificates" | "frontCms" | "alumni";
export type Field = { key: string; label: string; kind?: "number" | "date" | "boolean" | "text" };
export type UnifiedSpec = {
  id: UnifiedId; title: string; table: string; roles: readonly string[];
  writeRoles: readonly string[]; fields: readonly Field[]; allowDelete?: boolean;
};
const campus = ["super_admin", "admin"] as const;
const operations = ["super_admin", "admin", "receptionist"] as const;
const editors = ["super_admin", "admin", "content_editor"] as const;
export const unifiedModules: Record<UnifiedId, UnifiedSpec> = {
  downloads: { id: "downloads", title: "مركز التحميل", table: "sai_download_resources", roles: ["super_admin","admin","teacher","student","parent","librarian","content_editor"], writeRoles: ["super_admin","admin","content_editor","librarian"], fields: [{key:"category",label:"التصنيف"},{key:"storage_path",label:"مسار الملف الخاص"},{key:"is_published",label:"منشور",kind:"boolean"}], allowDelete: true },
  inventory: { id:"inventory", title:"المخزون", table:"sai_inventory_items", roles:["super_admin","admin","accountant"], writeRoles:["super_admin","admin","accountant"], fields:[{key:"sku",label:"رمز الصنف"},{key:"quantity",label:"الكمية",kind:"number"},{key:"warehouse",label:"المخزن"}] },
  transport: { id:"transport", title:"النقل", table:"sai_transport_routes", roles:[...campus,"receptionist","student","parent"], writeRoles:[...operations], fields:[{key:"vehicle",label:"المركبة"},{key:"driver_name",label:"السائق"},{key:"capacity",label:"السعة",kind:"number"}], allowDelete: true },
  portfolio: { id:"portfolio", title:"ملف إنجاز الطالب", table:"sai_student_portfolios", roles:[...campus,"teacher","student","parent"], writeRoles:[...campus,"teacher"], fields:[{key:"student_id",label:"معرّف الطالب (UUID)"},{key:"category",label:"نوع الإنجاز"}] },
  housing: { id:"housing", title:"السكن", table:"sai_housing_rooms", roles:[...operations,"student","parent"], writeRoles:[...operations], fields:[{key:"building",label:"المبنى"},{key:"capacity",label:"السعة",kind:"number"}] },
  certificates: { id:"certificates", title:"الشهادات", table:"sai_certificates", roles:[...operations,"student","parent"], writeRoles:[...operations], fields:[{key:"student_id",label:"معرّف الطالب (UUID)"},{key:"serial_code",label:"الرقم التسلسلي"},{key:"issued_on",label:"تاريخ الإصدار",kind:"date"}] },
  frontCms: { id:"frontCms", title:"صفحات Front CMS", table:"sai_cms_pages", roles:[...editors], writeRoles:[...editors], fields:[{key:"slug",label:"الرابط المختصر"},{key:"body",label:"المحتوى"},{key:"is_published",label:"منشور",kind:"boolean"}], allowDelete:true },
  alumni: { id:"alumni", title:"سجل الخريجين", table:"sai_alumni", roles:[...operations], writeRoles:[...operations], fields:[{key:"student_id",label:"معرّف الطالب (UUID)"},{key:"graduation_year",label:"سنة التخرج",kind:"number"}] },
};
export type UnifiedRow = Record<string, unknown> & { id: string; branch_id: string; title: string; description?: string | null };

export async function loadUnifiedRows(spec: UnifiedSpec, branchId: string): Promise<UnifiedRow[]> {
  const { data, error } = await supabase.from(spec.table).select("*").eq("branch_id", branchId)
    .order("created_at", { ascending: false }).limit(200);
  if (error) throw new Error(error.message);
  return (data ?? []) as UnifiedRow[];
}
export async function saveUnifiedRow(spec: UnifiedSpec, branchId: string, id: string | null, draft: Record<string, unknown>) {
  if (!branchId || !String(draft.title ?? "").trim()) throw new Error("اختر الفرع وأدخل عنواناً للسجل.");
  const data = Object.fromEntries(["title", "description", ...spec.fields.map(f=>f.key)]
    .filter(key => key in draft).map(key=>[key,draft[key]]));
  const result = id
    ? await supabase.from(spec.table).update(data).eq("id",id).eq("branch_id",branchId).select("id")
    : await supabase.from(spec.table).insert({...data, branch_id:branchId}).select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم تسمح صلاحيات قاعدة البيانات بحفظ السجل.");
}
export async function removeUnifiedRow(spec: UnifiedSpec, branchId: string, id: string) {
  if (!spec.allowDelete) throw new Error("الحذف غير متاح لهذه الوحدة؛ استخدم دورة الإلغاء الإدارية.");
  const result = await supabase.from(spec.table).delete().eq("id",id).eq("branch_id",branchId).select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم تسمح صلاحيات قاعدة البيانات بحذف السجل.");
}
export async function loadUnifiedBranches(): Promise<{id:string;name:string}[]> {
  const result = await supabase.from("branches").select("id,name").order("name");
  if (result.error) throw new Error(result.error.message);
  return result.data ?? [];
}
