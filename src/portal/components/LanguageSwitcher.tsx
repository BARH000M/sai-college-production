import { portalLanguages } from "../lib/portalLang";
import { usePortalLang } from "../lib/portalLangContext";

/**
 * Segmented language control for the portal. Arabic is the default; English and
 * Chinese translate the portal chrome and navigation while page bodies keep their
 * authored content.
 */
export function LanguageSwitcher({ compact = false }: { compact?: boolean }) {
  const { lang, setLang, t } = usePortalLang();

  return (
    <div className={`lang-switch ${compact ? "lang-switch-compact" : ""}`} role="group" aria-label={t("portalLanguage")}>
      {portalLanguages.map((language) => {
        const active = language.id === lang;
        return (
          <button
            key={language.id}
            type="button"
            className={`lang-switch-option ${active ? "is-active" : ""}`}
            aria-pressed={active}
            title={language.label}
            onClick={() => setLang(language.id)}
          >
            {language.short}
          </button>
        );
      })}
    </div>
  );
}