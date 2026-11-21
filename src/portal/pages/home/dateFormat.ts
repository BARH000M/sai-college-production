import type { PortalLanguage } from "../../lib/portalLang";

/** Maps the portal language to the locale used for dates and numbers. */
const locales: Record<PortalLanguage, string> = {
  ar: "ar",
  en: "en-GB",
  zh: "zh-CN",
};

export function formatDate(value: string | null, language: PortalLanguage = "ar"): string {
  if (!value) return "—";
  return new Date(value).toLocaleDateString(locales[language], { year: "numeric", month: "short", day: "numeric" });
}

export function formatDateTime(value: string | null, language: PortalLanguage = "ar"): string {
  if (!value) return "—";
  return new Date(value).toLocaleString(locales[language], {
    year: "numeric", month: "short", day: "numeric", hour: "2-digit", minute: "2-digit",
  });
}