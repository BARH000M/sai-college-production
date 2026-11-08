import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';

export type Lang = 'en' | 'ar';
export type Bi = { en: string; ar: string };

export default function useLang() {
  const { i18n } = useTranslation();
  const lang: Lang = i18n.language === 'ar' ? 'ar' : 'en';

  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  }, [lang]);

  const toggle = () => i18n.changeLanguage(lang === 'ar' ? 'en' : 'ar');
  const tx = (b: Bi) => b[lang];
  return { lang, toggle, tx, isAr: lang === 'ar' };
}