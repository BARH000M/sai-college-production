import { useEffect, useState } from "react";
import { loadNews, loadPrograms, loadSiteContent } from "@/portal/lib/cms";
import { newsItems as fallbackNews, programs as fallbackPrograms } from "@/mocks/home";

export type LangPair = { ar: string; en: string };

export type ProgramView = {
  icon: string;
  years: LangPair;
  en: string;
  ar: string;
  den: string;
  dar: string;
};

export type NewsView = {
  date: LangPair;
  tag: LangPair;
  en: string;
  ar: string;
  den: string;
  dar: string;
  img: string;
};

const fallbackNewsImage = "https://readdy.ai/api/search-image?query=Chinese%20culture%20event%20with%20red%20lanterns%20and%20students%20on%20a%20warm%20cream%20campus%2C%20soft%20natural%20light%2C%20minimal%20editorial%20illustration%20in%20red%20and%20gold%20tones&width=800&height=520&seq=sai-news-fallback&orientation=landscape";

const fallbackNewsRows: NewsView[] = fallbackNews.map((item) => ({
  date: item.date,
  tag: item.tag,
  en: item.en,
  ar: item.ar,
  den: "",
  dar: "",
  img: item.img,
}));

function datePair(value: string): LangPair {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return { ar: value, en: value };
  return {
    ar: date.toLocaleDateString("ar-EG", { day: "numeric", month: "long", year: "numeric" }),
    en: date.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }),
  };
}

/**
 * Public programs list. Published CMS programs win; the static content is only a
 * fallback so the marketing page keeps rendering if the CMS is unreachable.
 */
export function useCmsPrograms(): ProgramView[] {
  const [rows, setRows] = useState<ProgramView[]>(fallbackPrograms);
  useEffect(() => {
    let active = true;
    void loadPrograms(false)
      .then((programs) => {
        if (!active || !programs.length) return;
        setRows(programs.map((program) => ({
          icon: program.icon,
          years: { ar: program.duration_ar, en: program.duration_en },
          en: program.title_en,
          ar: program.title_ar,
          den: program.summary_en,
          dar: program.summary_ar,
        })));
      })
      .catch(() => { /* keep the fallback content */ });
    return () => { active = false; };
  }, []);
  return rows;
}

export function useCmsNews(): NewsView[] {
  const [rows, setRows] = useState<NewsView[]>(fallbackNewsRows);
  useEffect(() => {
    let active = true;
    void loadNews(false)
      .then((news) => {
        if (!active || !news.length) return;
        setRows(news.map((item) => ({
          date: datePair(item.published_at),
          tag: { ar: item.tag_ar, en: item.tag_en },
          en: item.title_en,
          ar: item.title_ar,
          den: item.summary_en,
          dar: item.summary_ar,
          img: item.image_url?.trim() ? item.image_url : fallbackNewsImage,
        })));
      })
      .catch(() => { /* keep the fallback content */ });
    return () => { active = false; };
  }, []);
  return rows;
}

/** Editable marketing copy keyed by `cms_site_content.key`. */
export function useSiteContent() {
  const [map, setMap] = useState<Record<string, LangPair>>({});
  useEffect(() => {
    let active = true;
    void loadSiteContent()
      .then((rows) => {
        if (!active) return;
        const next: Record<string, LangPair> = {};
        rows.forEach((row) => { next[row.key] = { ar: row.value_ar, en: row.value_en }; });
        setMap(next);
      })
      .catch(() => { /* keep the static fallback copy */ });
    return () => { active = false; };
  }, []);

  function get(key: string, fallback: LangPair): LangPair {
    const row = map[key];
    if (!row) return fallback;
    return { ar: row.ar || fallback.ar, en: row.en || fallback.en };
  }

  return { get };
}