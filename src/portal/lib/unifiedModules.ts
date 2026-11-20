import { supabase } from "./supabase";

// The eight administrative tables follow the proposed 029 migration; the HR
// employee directory has its own Phase 5A migration. Keep existing modules unchanged.
export type UnifiedId = "staff" | "downloads" | "inventory" | "transport" | "portfolio" | "housing" | "certificates" | "frontCms" | "alumni";
export type Field = { key: string; label: string; kind?: "number" | "date" | "boolean" | "text"; required?: boolean; defaultValue?: string };
export type UnifiedSpec = {
  id: UnifiedId; title: string; table: string; roles: readonly string[];
  writeRoles: readonly string[]; fields: readonly Field[]; allowDelete?: boolean;
};
const campus = ["super_admin", "admin"] as const;
const operations = ["super_admin", "admin", "receptionist"] as const;
const editors = ["super_admin", "admin", "content_editor"] as const;
export const unifiedModules: Record<UnifiedId, UnifiedSpec> = {
  staff: { id:"staff", title:"شؤون الموظفين", table:"sai_hr_employees", roles:campus, writeRoles:campus, fields:[
    {key:"employee_code",label:"الرقم الوظيفي",required:true},
    {key:"department",label:"القسم",required:true},
    {key:"designation",label:"المسمى الوظيفي",required:true},
    {key:"contact_phone",label:"هاتف العمل"},
    {key:"contact_email",label:"بريد العمل"},
    {key:"hired_on",label:"تاريخ التعيين",kind:"date"},
    {key:"employment_status",label:"الحالة",defaultValue:"active"},
  ] },
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
  if (spec.fields.some(field => field.required && !String(draft[field.key] ?? "").trim())) {
    throw new Error("أكمل جميع الحقول المطلوبة.");
  }
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
