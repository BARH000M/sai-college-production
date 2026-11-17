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
  const characters = Array.from(fullName);
  const hasControl = characters.some((character) => character.charCodeAt(0) < 32 || character.charCodeAt(0) === 127);
  if (characters.length < 2 || characters.length > 120 || hasControl) {
    throw new Error("الاسم الكامل يجب أن يكون بين حرفين و١٢٠ حرفاً دون محارف تحكم.");
  }
  const phone = values.phone.trim();
  const digits = phone.replace(/[^0-9]/g, "").length;
  if (phone && (!/^[+0-9][0-9 ()-]{5,31}$/.test(phone) || digits < 6 || digits > 20)) {
    throw new Error("رقم الهاتف غير صالح. استخدم أرقاماً مع رمز الدولة عند الحاجة.");
  }
  if (values.locale !== "ar" && values.locale !== "en") throw new Error("لغة التواصل غير مدعومة.");
  if (!userId) throw new Error("انتهت الجلسة. يرجى تسجيل الدخول.");
  const result = await supabase
    .from("profiles")
    .update({
      full_name: fullName,
      phone: phone || null,
      preferred_locale: values.locale,
    })
    .eq("id", userId)
    .select("id");
  if (result.error) throw new Error(result.error.message);
  if (!result.data?.length) throw new Error("لم يُحدّث الملف الشخصي؛ قد لا تملك الصلاحية.");
}
