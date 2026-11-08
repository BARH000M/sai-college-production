import useLang from '@/hooks/useLang';
import { heroText, stats } from '@/mocks/home';

export default function Hero() {
  const { tx, lang } = useLang();
  return (
    <section id="top" className="relative w-full min-h-[600px] md:h-[760px] flex items-center">
      <img
        src="https://readdy.ai/api/search-image?query=Stylized%20artistic%20illustration%20blending%20old%20Sanaa%20tower%20houses%20with%20Chinese%20pagoda%20rooftops%20at%20dusk%2C%20deep%20crimson%20and%20warm%20gold%20tones%2C%20dark%20moody%20sky%20for%20text%20contrast%2C%20painterly%20texture%2C%20harmonious%20wide%20composition&width=1920&height=1080&seq=sai-hero-1&orientation=landscape"
        alt="SAI College Yemeni Chinese education"
        title="SAI College Yemeni Chinese College"
        className="absolute inset-0 w-full h-full object-cover object-top"
      />
      <div className="absolute inset-0 bg-gradient-to-b from-black/50 via-black/40 to-black/60"></div>
      <div className="relative w-full px-4 md:px-10 pt-28 pb-12 flex flex-col items-center text-center">
        <span className="fade-up inline-flex items-center gap-2 text-xs md:text-sm px-3 py-1 rounded-full bg-accent-500 text-foreground-950 font-label">
          <i className="ri-calendar-check-line"></i>{tx(heroText.badge)}
        </span>
        <h1 className="fade-up mt-5 max-w-3xl font-heading font-semibold text-3xl md:text-5xl leading-tight text-background-50" style={{ animationDelay: '0.1s' }}>
          {tx(heroText.title)}
        </h1>
        <p className="fade-up mt-5 max-w-2xl text-sm md:text-base text-background-100/90 leading-relaxed" style={{ animationDelay: '0.2s' }}>
          {tx(heroText.sub)}
        </p>
        <div className="fade-up mt-8 flex flex-col sm:flex-row gap-3" style={{ animationDelay: '0.3s' }}>
          <a href="#admissions" className="whitespace-nowrap cursor-pointer px-6 py-3 rounded-md bg-primary-500 hover:bg-primary-600 text-background-50 text-sm font-label">{tx(heroText.cta1)}</a>
          <a href="#programs" className="whitespace-nowrap cursor-pointer px-6 py-3 rounded-md border border-background-50/50 text-background-50 hover:bg-background-50/10 text-sm font-label">{tx(heroText.cta2)}</a>
        </div>
        <div className="mt-14 w-full max-w-4xl grid grid-cols-2 md:grid-cols-4 gap-3">
          {stats.map((s) => (
            <div key={s.en} className="rounded-lg bg-background-50/10 border border-background-50/20 backdrop-blur-sm p-4">
              <div className="font-heading text-2xl md:text-3xl text-accent-300">{s.value}</div>
              <div className="text-xs md:text-sm text-background-100/90 mt-1">{s[lang]}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}