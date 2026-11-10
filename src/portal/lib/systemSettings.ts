import { supabase } from "./supabase";

// Only non-secret, allowlisted configuration. Role changes continue to use
// the privileged manage-roles Edge Function; financial operations use their own RPCs.
export type SettingField = { key: string; label: string; type?: "boolean" | "email" | "number" | "text" | "select"; options?: readonly string[]; hint?: string };
export type SettingSection = { category: string; title: string; fields: readonly SettingField[]; superOnly?: boolean; note?: string };
export const settingsSections: readonly SettingSection[] = [
  { category:"general",title:"الإعداد العام",fields:[{key:"college_name",label:"اسم الكلية"},{key:"website_url",label:"الموقع"},{key:"contact_email",label:"بريد الاتصال",type:"email"},{key:"contact_phone",label:"الهاتف"},{key:"address",label:"العنوان"}] },
  { category:"sessions",title:"إعداد الجلسة",fields:[{key:"default_session_id",label:"معرّف الجلسة الافتراضية"},{key:"registration_open",label:"فتح التسجيل",type:"boolean"}],note:"الجلسات الأكاديمية تُنشأ وتُدار من قسم الفروع والجلسات؛ هذا التفضيل لا ينشئ جلسة." },
  { category:"notifications",title:"الإشعارات",fields:[{key:"push_enabled",label:"إظهار إشعارات الدفع",type:"boolean"},{key:"digest_enabled",label:"ملخص الإشعارات",type:"boolean"},{key:"quiet_hours",label:"ساعات الهدوء"}] },
  { category:"sms",title:"الرسائل القصيرة",fields:[{key:"enabled",label:"تفضيل التفعيل",type:"boolean"},{key:"provider_name",label:"مزود الخدمة"},{key:"sender_name",label:"اسم المرسل"}],note:"الإرسال الفعلي يحتاج Edge Function ومزود SMS معتمد وأسرار محفوظة في الخادم." },
  { category:"whatsapp",title:"واتساب",fields:[{key:"enabled",label:"تفضيل التفعيل",type:"boolean"},{key:"business_number",label:"رقم النشاط التجاري"},{key:"template_namespace",label:"مساحة القوالب"}],note:"لا يتم إرسال رسائل تلقائياً بمجرد حفظ هذه القيم؛ يلزم تكامل WhatsApp Business مع الخادم." },
  { category:"email",title:"البريد الإلكتروني",fields:[{key:"enabled",label:"تفضيل التفعيل",type:"boolean"},{key:"sender_address",label:"بريد المرسل",type:"email"},{key:"sender_name",label:"اسم المرسل"}],note:"لا تضع SMTP password أو مفاتيح API هنا. احفظ الأسرار في Edge Function Secrets." },
  { category:"payments",title:"طرق الدفع",fields:[{key:"default_currency",label:"العملة الافتراضية"},{key:"invoice_prefix",label:"بادئة الفاتورة"},{key:"enabled_methods",label:"وسائل الدفع المعروضة"}],note:"تفضيلات العرض فقط؛ تحصيل الأموال لا يتم إلا عبر إجراءات المالية الآمنة الحالية." },
  { category:"printing",title:"الطباعة",fields:[{key:"paper_size",label:"حجم الورق",type:"select",options:["A4","Letter"]},{key:"header_text",label:"ترويسة الطباعة"},{key:"footer_text",label:"تذييل الطباعة"}] },
  { category:"cms",title:"إعداد CMS",fields:[{key:"site_title",label:"عنوان الموقع"},{key:"default_locale",label:"لغة الموقع",type:"select",options:["ar","en","zh"]},{key:"public_notice",label:"إعلان الموقع"}],note:"الأخبار والبرامج والمحتوى الحالي تستخدم جداول cms_* القائمة؛ وصفحات Front CMS تُدار في قسم منفصل." },
  { category:"backups",title:"سياسة النسخ الاحتياطي",superOnly:true,fields:[{key:"retention_days",label:"عدد أيام الاحتفاظ (سياسة)",type:"number"},{key:"alert_email",label:"تنبيه النسخ",type:"email"}],note:"هذا إعداد سياسة فقط، وليس أمر نسخ احتياطي. استخدم النسخ الاحتياطي المُدار والمختبر في Supabase." },
  { category:"languages",title:"اللغات",fields:[{key:"default_locale",label:"اللغة",type:"select",options:["ar","en","zh"]},{key:"enabled_locales",label:"اللغات المتاحة (ar,en,zh)"},{key:"timezone",label:"المنطقة الزمنية",type:"select",options:["Asia/Aden","UTC"]}] },
  { category:"currencies",title:"العملات",fields:[{key:"base_currency",label:"العملة الأساسية"},{key:"enabled_currencies",label:"العملات المعتمدة"}],note:"لا تُغيّر أرقام المدفوعات التاريخية أو سعر الصرف بمجرد تعديل هذا الحقل." },
  { category:"extensions",title:"الإضافات والوحدات",superOnly:true,fields:[{key:"enabled_module_ids",label:"معرفات الوحدات المفعلة"},{key:"enabled_plugin_ids",label:"معرفات الإضافات"}],note:"قائمة اختيار إدارية فقط؛ لا تُحمّل كوداً تنفيذياً من هذه الحقول." },
  { category:"custom_fields",title:"الحقول المخصصة",fields:[{key:"student_form_schema",label:"وصف حقول الطالب"},{key:"admissions_form_schema",label:"وصف حقول القبول"}],note:"لا يتم تنفيذ المخططات المخزنة ككود. يلزم تكامل نموذج واجهة آمن قبل عرض حقول إضافية." },
  { category:"verification",title:"التحقق",superOnly:true,fields:[{key:"certificate_verification_enabled",label:"تفضيل التحقق من الشهادات",type:"boolean"},{key:"guardian_check_required",label:"تفضيل التحقق من ولي الأمر",type:"boolean"}],note:"تفضيلات فقط؛ لا تقوم مقام مسار التحقق الرسمي أو التوقيع الرقمي." },
  { category:"updates",title:"التحديثات والصيانة",superOnly:true,fields:[{key:"release_channel",label:"قناة التحديث",type:"select",options:["stable","beta"]},{key:"maintenance_notice",label:"رسالة صيانة"}],note:"لا يبدأ نشر الكود من هذه الشاشة. نشر الموقع والتطبيق يحتاج CI/CD وصلاحيات محددة." },
];
export type SettingRow = { category:string; setting_key:string; value_text:string; updated_at:string; updated_by:string|null };

export async function loadSettings(category: string): Promise<SettingRow[]> {
  if (!settingsSections.some(section=>section.category===category)) throw new Error("تصنيف إعدادات غير معروف.");
  const { data, error } = await supabase.from("sai_system_settings").select("category,setting_key,value_text,updated_at,updated_by")
    .eq("category",category).order("setting_key");
  if (error) throw new Error(error.message);
  return (data ?? []) as SettingRow[];
}
export async function saveSetting(section: SettingSection, field: SettingField, value: string): Promise<void> {
  if (!settingsSections.includes(section) || !section.fields.includes(field)) throw new Error("هذا الإعداد غير مسموح.");
  const next = value.trim();
  if (next.length > 2000) throw new Error("القيمة طويلة جداً.");
  if (field.type==="boolean" && !["true","false"].includes(next)) throw new Error("قيمة غير صحيحة.");
  if (field.type==="select" && field.options && !field.options.includes(next)) throw new Error("خيار غير مدعوم.");
  if (field.type==="number" && next && (!/^\d+$/.test(next) || Number(next)>3650)) throw new Error("رقم غير صالح.");
  if (field.type==="email" && next && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(next)) throw new Error("البريد غير صحيح.");
  const { data, error } = await supabase.from("sai_system_settings")
    .upsert({category:section.category, setting_key:field.key, value_text:next},{onConflict:"category,setting_key"})
    .select("setting_key");
  if (error) throw new Error(error.message);
  if (!data?.length) throw new Error("لم يسمح الخادم بحفظ الإعداد.");
}
