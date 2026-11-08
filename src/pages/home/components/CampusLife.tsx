import useLang from '@/hooks/useLang';
import { campusLife } from '@/mocks/home';
import { useSiteContent } from '@/hooks/useCmsContent';

export default function CampusLife() {
  const { tx, lang } = useLang();
  const { get } = useSiteContent();

  const kicker = get('campus.kicker', campusLife.kicker);
  const title = get('campus.title', campusLife.title);
  const sub = get('campus.subtitle', campusLife.sub);

  const items = campusLife.items.map((item, index) => {
    const position = index + 1;
    const image = get(`campus.item.${position}.image`, { ar: item.img, en: item.img });
    const caption = get(`campus.item.${position}.caption`, { ar: item.ar, en: item.en });
    const resolved = (lang === 'ar' ? image.ar : image.en) || item.img;
    return { image: resolved, caption };
  });

  return (
    <section id="campus" className="reveal px-4 md:px-10 py-16 md:py-24 bg-background-100">
      <div className="max-w-6xl mx-auto">
        <div className="max-w-2xl">
          <span className="text-xs font-label uppercase tracking-wider text-accent-700">{tx(kicker)}</span>
          <h2 className="mt-3 font-heading text-2xl md:text-4xl text-foreground-950 leading-tight">{tx(title)}</h2>
          <p className="mt-4 text-sm md:text-base text-foreground-700 leading-relaxed">{tx(sub)}</p>
        </div>

        <div className="mt-10 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-5">
          {items.map((item, index) => (
            <figure key={index} className="group relative w-full h-[200px] md:h-[220px] rounded-lg overflow-hidden bg-background-200 cursor-pointer">
              <img
                src={item.image}
                alt={tx(item.caption)}
                title={`${tx(item.caption)} · كلية ساي`}
                className="w-full h-full object-cover object-top transition-transform duration-500 group-hover:scale-105"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-foreground-950/70 via-foreground-950/10 to-transparent"></div>
              <figcaption className="absolute inset-x-0 bottom-0 p-4 text-sm text-background-50 font-label">
                {tx(item.caption)}
              </figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}