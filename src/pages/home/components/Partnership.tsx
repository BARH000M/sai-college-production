import useLang from '@/hooks/useLang';
import { partnership } from '@/mocks/home';

export default function Partnership() {
  const { tx, lang } = useLang();
  return (
    <section id="partnership" className="reveal px-4 md:px-10 py-16 md:py-24 bg-secondary-50">
      <div className="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-5 gap-10">
        <div className="lg:col-span-2">
          <span className="text-xs font-label uppercase tracking-wider text-secondary-700">{tx(partnership.kicker)}</span>
          <h2 className="mt-3 font-heading text-2xl md:text-4xl text-foreground-950">{tx(partnership.title)}</h2>
          <p className="mt-4 text-sm md:text-base text-foreground-700 leading-relaxed">{tx(partnership.sub)}</p>
          <div className="mt-6 flex flex-wrap gap-2">
            {partnership.partners.map((c) => (
              <span key={c} className="text-xs px-3 py-1.5 rounded-full bg-background-50 border border-secondary-200 text-secondary-900 whitespace-nowrap">{c}</span>
            ))}
          </div>
        </div>
        <ol className="lg:col-span-3 grid grid-cols-1 sm:grid-cols-2 gap-4">
          {partnership.steps.map((s, i) => (
            <li key={s.en} className="rounded-lg bg-background-50 p-5 md:p-6 border border-background-200">
              <span className={`w-10 h-10 rounded-full flex items-center justify-center font-heading text-sm ${i === 3 ? 'bg-accent-500 text-foreground-950' : 'bg-secondary-500 text-background-50'}`}>{i + 1}</span>
              <p className="mt-4 text-sm md:text-base text-foreground-900">{s[lang]}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}