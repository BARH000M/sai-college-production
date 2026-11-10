import { supabase } from "./supabase";

export type ProfileRecord = {
  fullName: string;
  email: string | null;
  phone: string | null;
  locale: "ar" | "en";
};

export async function loadMyProfile(userId: string): Promise<ProfileRecord | null> {
  const result = await supabase
    .from("profiles")
    .select("full_name,email,phone,preferred_locale")
    .eq("id", userId)
    .maybeSingle<{ full_name: string; email: string | null; phone: string | null; preferred_locale: string }>();
  if (result.error) throw new Error(result.error.message);
  if (!result.data) return null;
  return {
    fullName: result.data.full_name,
    email: result.data.email,
    phone: result.data.phone,
    locale: result.data.preferred_locale === "en" ? "en" : "ar",
  };
}

export async function saveMyProfile(
  userId: string,
  values: { fullName: string; phone: string; locale: "ar" | "en" },
): Promise<void> {
  const fullName = values.fullName.trim();
  if (fullName.length < 2) throw new Error("الاسم الكامل مطلوب (حرفان على الأقل).");
  const phone = values.phone.trim();
  if (phone && !/^[+\d][\d\s()-]{5,}$/.test(phone)) {
    throw new Error("رقم الهاتف غير صالح. استخدم أرقاماً مع رمز الدولة عند الحاجة.");
  }
  const result = await supabase
    .from("profiles")
    .update({
      full_name: fullName,
      phone: phone || null,
      preferred_locale: values.locale,
      updated_at: new Date().toISOString(),
    })
    .eq("id", userId)
    .select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحدّث الملف الشخصي؛ قد لا تملك الصلاحية.");
}