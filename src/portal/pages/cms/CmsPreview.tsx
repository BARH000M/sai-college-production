import { useEffect, useMemo, useState } from "react";
import saiLogo from "@/portal/assets/saiLogo";
import { loadNews, loadPrograms, loadSiteContent, type CmsNews, type CmsProgram, type SiteContentRow } from "@/portal/lib/cms";
import { aboutText, campusLife, heroText, newsItems, programs as staticPrograms, stats } from "@/mocks/home";
import { usePreviewDraft } from "./previewDraft";

type Device = "desktop" | "mobile";

const heroImage = "https://readdy.ai/api/search-image?query=Warm%20cream%20abstract%20architectural%20backdrop%20with%20subtle%20Chinese%20lattice%20patterns%20and%20soft%20golden%20light%2C%20minimal%20editorial%20style%20for%20an%20education%20website%20hero&width=1600&height=900&seq=sai-cms-preview-hero&orientation=landscape";

export function CmsPreview({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { draft } = usePreviewDraft();
  const [device, setDevice] = useState<Device>("desktop");
  const [rows, setRows] = useState<SiteContentRow[]>([]);
  const [publishedPrograms, setPublishedPrograms] = useState<CmsProgram[]>([]);
  const [publishedNews, setPublishedNews] = useState<CmsNews[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    let active = true;
    setLoading(true);
    setError(null);
    void Promise.all([loadSiteContent(), loadPrograms(false), loadNews(false)])
      .then(([content, programRows, newsRows]) => {
        if (!active) return;
        setRows(content);
        setPublishedPrograms(programRows);
        setPublishedNews(newsRows);
      })
      .catch((failure: unknown) => {
        if (active) setError(failure instanceof Error ? failure.message : String(failure));
      })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => { if (event.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  const content = useMemo(() => {
    const map: Record<string, { value_ar: string; value_en: string }> = {};
    rows.forEach((row) => { map[row.key] = { value_ar: row.value_ar, value_en: row.value_en }; });
    if (draft.content) {
      Object.entries(draft.content).forEach(([key, value]) => {
        const base = map[key];
        map[key] = {
          value_ar: value.value_ar || base?.value_ar || "",
          value_en: value.value_en || base?.value_en || "",
        };
      });
    }
    return map;
  }, [rows, draft.content]);

  const t = (key: string, fallback: string) => content[key]?.value_ar || fallback;

  const previewPrograms = useMemo(() => {
    const base = draft.programs ?? publishedPrograms;
    return base.filter((row) => row.is_published);
  }, [draft.programs, publishedPrograms]);

  const previewNews = useMemo(() => {
    const base = draft.news ?? publishedNews;
    return base.filter((row) => row.is_published);
  }, [draft.news, publishedNews]);

  if (!open) return null;

  const campusItems = campusLife.items.map((item, index) => {
    const position = index + 1;
    return {
      image: t(`campus.item.${position}.image`, item.img),
      caption: t(`campus.item.${position}.caption`, item.ar),
    };
  });

  const aboutPoints = aboutText.points.map((point, index) => {
    const position = index + 1;
    return {
      icon: t(`about.point.${position}.icon`, point.icon),
      label: t(`about.point.${position}`, point.ar),
    };
  });

  const statItems = [
    { value: t("stats.students.value", stats[0].value), label: t("stats.students.label", stats[0].ar) },
    { value: t("stats.faculty.value", stats[1].value), label: t("stats.faculty.label", stats[1].ar) },
    { value: t("stats.programs.value", stats[2].value), label: t("stats.programs.label", stats[2].ar) },
    { value: t("stats.partners.value", stats[3].value), label: t("stats.partners.label", stats[3].ar) },
  ];

  const programCards: { id: string; icon: string; title: string; summary: string; duration: string }[] =
    previewPrograms.length
      ? previewPrograms.map((program) => ({
        id: program.id,
        icon: program.icon,
        title: program.title_ar,
        summary: program.summary_ar,
        duration: program.duration_ar,
      }))
      : staticPrograms.map((item, index) => ({
        id: `static-${index}`,
        icon: item.icon,
        title: item.ar,
        summary: item.dar,
        duration: item.years.ar,
      }));

  const newsCards: { id: string; title: string; summary: string; tag: string; image: string | null }[] =
    previewNews.length
      ? previewNews.map((item) => ({
        id: item.id,
        title: item.title_ar,
        summary: item.summary_ar,
        tag: item.tag_ar,
        image: item.image_url,
      }))
      : newsItems.map((item, index) => ({
        id: `static-${index}`,
        title: item.ar,
        summary: item.en,
        tag: item.tag.ar,
        image: item.img,
      }));

  return <div className="fixed inset-0 z-[120] bg-background-100 flex flex-col" dir="rtl" role="dialog" aria-modal="true" aria-label="معاينة مباشرة للصفحة العامة">
    <header className="flex flex-wrap items-center justify-between gap-3 px-4 md:px-6 py-3 bg-background-50 border-b border-background-200">
      <div className="flex items-center gap-3">
        <span className="inline-flex items-center gap-2 text-sm font-semibold text-foreground-900">
          <i className="ri-eye-line text-primary-600" aria-hidden="true"></i>
          معاينة مباشرة قبل النشر
        </span>
        <span className="hidden sm:inline text-xs px-2 py-1 rounded-full bg-accent-100 text-accent-900">
          التغييرات غير المحفوظة تظهر هنا فقط
        </span>
      </div>
      <div className="flex items-center gap-2">
        <div className="flex items-center gap-1 rounded-md border border-background-300 p-1">
          <button type="button" onClick={() => setDevice("desktop")} className={`cursor-pointer text-xs px-3 py-1.5 rounded ${device === "desktop" ? "bg-primary-500 text-background-50" : "text-foreground-700"}`}>
            <i className="ri-computer-line" aria-hidden="true"></i> حاسوب
          </button>
          <button type="button" onClick={() => setDevice("mobile")} className={`cursor-pointer text-xs px-3 py-1.5 rounded ${device === "mobile" ? "bg-primary-500 text-background-50" : "text-foreground-700"}`}>
            <i className="ri-smartphone-line" aria-hidden="true"></i> جوال
          </button>
        </div>
        <button type="button" onClick={onClose} className="button secondary whitespace-nowrap">إغلاق المعاينة</button>
      </div>
    </header>

    <div className="flex-1 overflow-y-auto px-3 md:px-6 py-5">
      {loading && <p className="text-sm text-foreground-700" role="status">جارٍ تجهيز المعاينة...</p>}
      {error && <p className="text-sm text-foreground-900 bg-accent-100 rounded-md p-3" role="alert">تعذر تحميل بيانات المعاينة: {error}</p>}

      {!loading && !error && <div className={device === "mobile" ? "w-[390px] max-w-full mx-auto bg-background-50 rounded-lg overflow-hidden border border-background-300" : "w-full max-w-6xl mx-auto bg-background-50 rounded-lg overflow-hidden border border-background-200"}>
        {/* Hero */}
        <section className="relative w-full h-[300px] md:h-[420px] overflow-hidden">
          <img src={heroImage} alt="معاينة واجهة الموقع" title="معاينة الواجهة العامة" className="absolute inset-0 w-full h-full object-cover object-top" />
          <div className="absolute inset-0 bg-gradient-to-b from-foreground-950/60 via-foreground-950/45 to-foreground-950/70"></div>
          <div className="relative h-full flex flex-col justify-center px-6 md:px-12 max-w-3xl">
            <span className="self-start text-xs px-3 py-1 rounded-full bg-accent-500 text-foreground-950">{t("hero.badge", heroText.badge.ar)}</span>
            <h1 className="mt-4 font-heading text-xl md:text-4xl text-background-50 leading-tight">{t("hero.title", heroText.title.ar)}</h1>
            <p className="mt-3 text-xs md:text-base text-background-50/90 leading-relaxed line-clamp-3">{t("hero.subtitle", heroText.sub.ar)}</p>
            <div className="mt-5 flex flex-wrap gap-2">
              <span className="text-xs md:text-sm px-4 py-2 rounded-md bg-primary-500 text-background-50 whitespace-nowrap">{t("hero.cta1", heroText.cta1.ar)}</span>
              <span className="text-xs md:text-sm px-4 py-2 rounded-md border border-background-50/60 text-background-50 whitespace-nowrap">{t("hero.cta2", heroText.cta2.ar)}</span>
            </div>
          </div>
        </section>

        {/* Stats */}
        <section className="grid grid-cols-2 md:grid-cols-4 gap-3 px-4 md:px-10 py-6 bg-background-50">
          {statItems.map((item, index) => <div key={index} className="rounded-lg bg-background-100 p-3 md:p-4 text-center">
            <strong className="block font-heading text-lg md:text-2xl text-primary-700">{item.value}</strong>
            <span className="text-[11px] md:text-sm text-foreground-700">{item.label}</span>
          </div>)}
        </section>

        {/* About */}
        <section className="grid grid-cols-1 lg:grid-cols-2 gap-6 md:gap-10 items-center px-4 md:px-10 py-8 md:py-12">
          <div className="w-full h-[220px] md:h-[300px] rounded-lg overflow-hidden">
            <img src={campusItems[0].image} alt="معاينة صورة عن الكلية" title="عن الكلية" className="w-full h-full object-cover object-top" />
          </div>
          <div>
            <span className="text-xs uppercase tracking-wider text-secondary-600">{t("about.kicker", aboutText.kicker.ar)}</span>
            <h2 className="mt-2 font-heading text-lg md:text-2xl text-foreground-950 leading-tight">{t("about.title", aboutText.title.ar)}</h2>
            <p className="mt-3 text-xs md:text-sm text-foreground-700 leading-relaxed">{t("about.p1", aboutText.p1.ar)}</p>
            <p className="mt-2 text-xs md:text-sm text-foreground-700 leading-relaxed">{t("about.p2", aboutText.p2.ar)}</p>
            <div className="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-2">
              {aboutPoints.map((point, index) => <div key={index} className="flex items-center gap-2 rounded-lg bg-background-100 p-2.5">
                <span className="w-8 h-8 rounded-md bg-secondary-100 text-secondary-800 flex items-center justify-center"><i className={`${point.icon} text-sm`} aria-hidden="true"></i></span>
                <span className="text-xs md:text-sm text-foreground-900">{point.label}</span>
              </div>)}
            </div>
          </div>
        </section>

        {/* Programs */}
        <section className="px-4 md:px-10 py-8 md:py-12 bg-background-100">
          <h2 className="font-heading text-lg md:text-2xl text-foreground-950">البرامج الأكاديمية</h2>
          <div className="mt-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4">
            {programCards.map((program) => <article key={program.id} className="rounded-lg bg-background-50 border border-background-200 p-4">
              <span className="w-9 h-9 rounded-md bg-primary-100 text-primary-700 flex items-center justify-center"><i className={`${program.icon} text-lg`} aria-hidden="true"></i></span>
              <h3 className="mt-3 font-heading text-sm md:text-base text-foreground-950">{program.title}</h3>
              <p className="mt-1 text-[11px] md:text-sm text-foreground-700 leading-relaxed">{program.summary}</p>
              <span className="mt-3 inline-block text-[11px] px-2 py-1 rounded-full bg-secondary-100 text-secondary-900">{program.duration}</span>
            </article>)}
          </div>
        </section>

        {/* Campus life */}
        <section className="px-4 md:px-10 py-8 md:py-12">
          <span className="text-xs uppercase tracking-wider text-accent-700">{t("campus.kicker", campusLife.kicker.ar)}</span>
          <h2 className="mt-2 font-heading text-lg md:text-2xl text-foreground-950">{t("campus.title", campusLife.title.ar)}</h2>
          <p className="mt-2 text-xs md:text-sm text-foreground-700">{t("campus.subtitle", campusLife.sub.ar)}</p>
          <div className="mt-4 grid grid-cols-2 lg:grid-cols-3 gap-2 md:gap-3">
            {campusItems.map((item, index) => <figure key={index} className="relative w-full h-[110px] md:h-[150px] rounded-lg overflow-hidden bg-background-200">
              <img src={item.image} alt={item.caption} title={item.caption} className="w-full h-full object-cover object-top" />
              <div className="absolute inset-0 bg-gradient-to-t from-foreground-950/70 to-transparent"></div>
              <figcaption className="absolute inset-x-0 bottom-0 p-2 text-[10px] md:text-xs text-background-50">{item.caption}</figcaption>
            </figure>)}
          </div>
        </section>

        {/* News */}
        <section className="px-4 md:px-10 py-8 md:py-12 bg-background-100">
          <h2 className="font-heading text-lg md:text-2xl text-foreground-950">آخر الأخبار</h2>
          <div className="mt-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4">
            {newsCards.map((item) => <article key={item.id} className="rounded-lg bg-background-50 border border-background-200 overflow-hidden">
              <div className="w-full h-[120px] md:h-[150px] overflow-hidden">
                {item.image
                  ? <img src={item.image} alt={item.title} title={item.title} className="w-full h-full object-cover object-top" />
                  : <div className="w-full h-full bg-background-200 flex items-center justify-center text-foreground-600"><i className="ri-image-line text-2xl" aria-hidden="true"></i></div>}
              </div>
              <div className="p-3 md:p-4">
                <span className="text-[10px] md:text-xs px-2 py-1 rounded-full bg-accent-100 text-accent-900">{item.tag}</span>
                <h3 className="mt-2 font-heading text-sm md:text-base text-foreground-950">{item.title}</h3>
                <p className="mt-1 text-[11px] md:text-xs text-foreground-700 line-clamp-2">{item.summary}</p>
              </div>
            </article>)}
          </div>
        </section>

        <footer className="flex items-center justify-between gap-3 px-4 md:px-10 py-5 bg-secondary-50">
          <div className="flex items-center gap-2">
            <img src={saiLogo} alt="شعار كلية ساي" className="w-8 h-8 object-contain" />
            <span className="text-xs md:text-sm text-foreground-800">كلية ساي التعليمية اليمنية الصينية</span>
          </div>
          <span className="text-[11px] md:text-xs text-foreground-600">معاينة داخلية — ليست الصفحة المنشورة</span>
        </footer>
      </div>}
    </div>
  </div>;
}