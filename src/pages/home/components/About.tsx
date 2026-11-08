import useLang from '@/hooks/useLang';
import { aboutText } from '@/mocks/home';
import { useSiteContent } from '@/hooks/useCmsContent';

export default function About() {
  const { tx, lang } = useLang();
  const { get } = useSiteContent();

  const kicker = get('about.kicker', aboutText.kicker);
  const title = get('about.title', aboutText.title);
  const p1 = get('about.p1', aboutText.p1);
  const p2 = get('about.p2', aboutText.p2);

  const points = aboutText.points.map((point, index) => {
    const position = index + 1;
    const label = get(`about.point.${position}`, { ar: point.ar, en: point.en });
    const icon = get(`about.point.${position}.icon`, { ar: point.icon, en: point.icon });
    return { icon: (lang === 'ar' ? icon.ar : icon.en) || point.icon, label };
  });

  return (
    <section id="about" className="reveal px-4 md:px-10 py-16 md:py-24 bg-background-50">
      <div className="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-2 gap-10 lg:gap-16 items-center">
        <div className="w-full h-[320px] md:h-[440px] rounded-lg overflow-hidden">
          <img
            src="https://readdy.ai/api/search-image?query=Yemeni%20students%20studying%20Chinese%20characters%20in%20a%20bright%20modern%20classroom%20with%20a%20Chinese%20teacher%2C%20warm%20cream%20walls%2C%20soft%20natural%20daylight%2C%20editorial%20photography%20with%20red%20and%20gold%20details&width=900&height=880&seq=sai-about-1&orientation=squarish"
            alt="Students learning Chinese at SAI College"
            title="SAI College Chinese language classroom"
            className="w-full h-full object-cover object-top"
          />
        </div>
        <div>
          <span className="text-xs font-label uppercase tracking-wider text-secondary-600">{tx(kicker)}</span>
          <h2 className="mt-3 font-heading text-2xl md:text-4xl text-foreground-950 leading-tight">{tx(title)}</h2>
          <p className="mt-5 text-sm md:text-base text-foreground-700 leading-relaxed">{tx(p1)}</p>
          <p className="mt-3 text-sm md:text-base text-foreground-700 leading-relaxed">{tx(p2)}</p>
          <div className="mt-8 grid grid-cols-1 sm:grid-cols-2 gap-3">
            {points.map((point, index) => (
              <div key={index} className="flex items-center gap-3 rounded-lg bg-background-100 p-3">
                <span className="w-10 h-10 rounded-md bg-secondary-100 text-secondary-800 flex items-center justify-center"><i className={`${point.icon} text-lg`}></i></span>
                <span className="text-sm text-foreground-900">{tx(point.label)}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}