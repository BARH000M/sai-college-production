import {
  createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode,
} from "react";
import {
  directionFor, isPortalLanguage, translateModule, translateNav, translateSection, translateStatus, translateUi, translateZone,
  type PortalDirection, type PortalLanguage,
} from "./portalLang";

const STORAGE_KEY = "sai-portal-lang";

type PortalLangContextValue = {
  /** Active portal language. */
  lang: PortalLanguage;
  /** Writing direction for the active language. */
  dir: PortalDirection;
  /** Switches language and persists the choice for the next visit. */
  setLang: (language: PortalLanguage) => void;
  /** Translates a portal chrome string, falling back to the Arabic source. */
  t: (key: string, fallback?: string) => string;
  /** Translates a page label by navigation module id. */
  tNav: (id: string, fallback: string) => string;
  /** Translates a main-menu module label by registry module id. */
  tModule: (id: string, fallback: string) => string;
  /** Translates a sidebar section label by section id. */
  tSection: (id: string, fallback: string) => string;
  /** Translates a sidebar zone label by zone id. */
  tZone: (id: string, fallback: string) => string;
  /** Translates an admission enquiry status by status id. */
  tStatus: (id: string, fallback: string) => string;
};

const PortalLangContext = createContext<PortalLangContextValue | null>(null);

function readStoredLanguage(): PortalLanguage {
  if (typeof window === "undefined") return "ar";
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY) ?? "";
    if (isPortalLanguage(stored)) return stored;
  } catch {
    // Private mode or blocked storage: keep the Arabic default.
  }
  return "ar";
}

/**
 * Keeps `document.documentElement.lang` and `dir` in sync with the portal
 * language so screen readers, form controls and the print layout follow the
 * chosen language instead of the public website default.
 */
export function PortalLanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<PortalLanguage>(readStoredLanguage);
  const dir = directionFor(lang);

  useEffect(() => {
    const root = document.documentElement;
    const previous = { lang: root.lang, dir: root.dir };
    root.lang = lang;
    root.dir = dir;
    return () => {
      root.lang = previous.lang;
      root.dir = previous.dir;
    };
  }, [lang, dir]);

  const setLang = useCallback((language: PortalLanguage) => {
    setLangState(language);
    try {
      window.localStorage.setItem(STORAGE_KEY, language);
    } catch {
      // Persisting the preference is best effort; the session still switches.
    }
  }, []);

  const value = useMemo<PortalLangContextValue>(() => ({
    lang,
    dir,
    setLang,
    t: (key, fallback) => translateUi(lang, key) || fallback || key,
    tNav: (id, fallback) => translateNav(lang, id, fallback),
    tModule: (id, fallback) => translateModule(lang, id, fallback),
    tSection: (id, fallback) => translateSection(lang, id, fallback),
    tZone: (id, fallback) => translateZone(lang, id, fallback),
    tStatus: (id, fallback) => translateStatus(lang, id, fallback),
  }), [lang, dir, setLang]);

  return <PortalLangContext.Provider value={value}>{children}</PortalLangContext.Provider>;
}

export function usePortalLang(): PortalLangContextValue {
  const context = useContext(PortalLangContext);
  if (!context) throw new Error("usePortalLang must be used inside PortalLanguageProvider");
  return context;
}