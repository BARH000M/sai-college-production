import useLang from '@/hooks/useLang';
import { useCmsPrograms } from '@/hooks/useCmsContent';

export default function Programs() {
  const { tx, isAr } = useLang();
  const programs = useCmsPrograms();

  return (
    <section id="programs" className="reveal px-4 md:px-10 py-16 md:py-24 bg-background-100">
      <div className="max-w-6xl mx-auto">
        <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-10">
          <div>
            <span className="text-xs font-label uppercase tracking-wider text-primary-600">{isAr ? 'البرامج الأكاديمية' : 'Academic programs'}</span>
            <h2 className="mt-3 font-heading text-2xl md:text-4xl text-foreground-950">{isAr ? 'مهارات عملية لسوق عمل متغير' : 'Practical skills for a changing job market'}</h2>
          </div>
          <p className="text-sm text-foreground-600 max-w-md">{isAr ? 'جميع البرامج تشمل اللغة الصينية وتدريبًا ميدانيًا لدى شركات شريكة.' : 'Every program includes Mandarin and field training with partner companies.'}</p>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-5">
          {programs.map((p) => (
            <article key={`${p.ar}-${p.en}`} className="group rounded-lg bg-background-50 border border-background-200 p-5 md:p-6 hover:border-primary-300 transition-colors">
              <div className="flex items-center justify-between">
                <span className="w-12 h-12 rounded-md bg-primary-100 text-primary-700 flex items-center justify-center group-hover:bg-primary-500 group-hover:text-background-50 transition-colors"><i className={`${p.icon} text-xl`}></i></span>
                <span className="text-xs px-2.5 py-1 rounded-full bg-secondary-100 text-secondary-900">{tx(p.years)}</span>
              </div>
              <h3 className="mt-5 font-heading text-base md:text-lg text-foreground-950">{isAr ? p.ar : p.en}</h3>
              <p className="mt-2 text-xs md:text-sm text-foreground-600 leading-relaxed">{isAr ? p.dar : p.den}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}