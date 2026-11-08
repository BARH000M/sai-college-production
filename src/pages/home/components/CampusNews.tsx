import useLang from '@/hooks/useLang';
import { useCmsNews } from '@/hooks/useCmsContent';

export default function CampusNews() {
  const { tx, isAr } = useLang();
  const newsItems = useCmsNews();

  return (
    <>
      <section id="campus-gallery" className="reveal px-4 md:px-10 py-16 md:py-24 bg-background-50">
        <div className="max-w-6xl mx-auto">
          <h2 className="font-heading text-2xl md:text-4xl text-foreground-950 text-center">{isAr ? 'الحياة في الحرم الجامعي' : 'Life on campus'}</h2>
          <p className="mt-3 text-sm text-foreground-600 text-center max-w-xl mx-auto">{isAr ? 'مختبرات حديثة، نوادٍ ثقافية، ومكتبة ثنائية اللغة.' : 'Modern labs, cultural clubs and a bilingual library.'}</p>
          <div className="mt-10 grid grid-cols-2 md:grid-cols-4 gap-3 md:gap-4">
            <div className="col-span-2 row-span-2 h-[260px] md:h-[440px] rounded-lg overflow-hidden">
              <img src="https://readdy.ai/api/search-image?query=Modern%20college%20courtyard%20in%20Sanaa%20with%20students%20walking%2C%20traditional%20Yemeni%20stained%20glass%20windows%20and%20red%20Chinese%20lanterns%2C%20warm%20cream%20tones%2C%20soft%20golden%20daylight%2C%20editorial%20photography&width=900&height=880&seq=sai-gallery-01&orientation=squarish" alt="SAI College courtyard" title="SAI College campus" className="w-full h-full object-cover object-top" />
            </div>
            <div className="h-[125px] md:h-[212px] rounded-lg overflow-hidden">
              <img src="https://readdy.ai/api/search-image?query=Students%20working%20in%20an%20electrical%20engineering%20lab%20with%20circuit%20boards%20and%20solar%20panel%20models%2C%20clean%20cream%20background%2C%20soft%20light%2C%20editorial%20photography%20with%20warm%20tones&width=600&height=440&seq=sai-gallery-02&orientation=landscape" alt="Engineering lab" title="SAI College engineering lab" className="w-full h-full object-cover object-top" />
            </div>
            <div className="h-[125px] md:h-[212px] rounded-lg overflow-hidden">
              <img src="https://readdy.ai/api/search-image?query=Bilingual%20library%20with%20Arabic%20and%20Chinese%20books%20on%20wooden%20shelves%2C%20reading%20tables%2C%20warm%20cream%20background%2C%20soft%20natural%20light%2C%20calm%20editorial%20photography&width=600&height=440&seq=sai-gallery-03&orientation=landscape" alt="Library" title="SAI College bilingual library" className="w-full h-full object-cover object-top" />
            </div>
            <div className="col-span-2 h-[125px] md:h-[212px] rounded-lg overflow-hidden">
              <img src="https://readdy.ai/api/search-image?query=Students%20celebrating%20a%20cultural%20festival%20with%20red%20lanterns%20and%20Yemeni%20decorations%20in%20a%20college%20hall%2C%20warm%20cream%20and%20gold%20tones%2C%20soft%20festive%20light%2C%20editorial%20photography&width=1200&height=440&seq=sai-gallery-04&orientation=landscape" alt="Cultural festival" title="SAI College cultural festival" className="w-full h-full object-cover object-top" />
            </div>
          </div>
        </div>
      </section>
      <section id="news" className="reveal px-4 md:px-10 py-16 md:py-24 bg-background-100">
        <div className="max-w-6xl mx-auto">
          <h2 className="font-heading text-2xl md:text-4xl text-foreground-950">{isAr ? 'آخر الأخبار' : 'Latest news'}</h2>
          <div className="mt-8 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            {newsItems.map((n) => (
              <article key={`${n.ar}-${n.en}`} className="rounded-lg bg-background-50 overflow-hidden border border-background-200">
                <div className="w-full h-48"><img src={n.img} alt={n.en} title={n.en} className="w-full h-full object-cover object-top" /></div>
                <div className="p-4 md:p-5">
                  <div className="flex flex-wrap items-center gap-2 text-xs">
                    <span className="px-2 py-0.5 rounded-full bg-accent-100 text-accent-900">{tx(n.tag)}</span>
                    <span className="text-foreground-500">{tx(n.date)}</span>
                  </div>
                  <h3 className="mt-3 font-heading text-sm md:text-base text-foreground-950 leading-snug">{isAr ? n.ar : n.en}</h3>
                  {(isAr ? n.dar : n.den) && <p className="mt-2 text-xs md:text-sm text-foreground-600 leading-relaxed line-clamp-2">{isAr ? n.dar : n.den}</p>}
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}