import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import useLang from '@/hooks/useLang';
import { navLinks } from '@/mocks/home';
import saiLogo from '@/portal/assets/saiLogo';

export default function Navbar() {
  const { lang, toggle, isAr } = useLang();
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 40);
    window.addEventListener('scroll', onScroll);
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const light = scrolled || open;

  return (
    <header className={`fixed top-0 inset-x-0 z-50 transition-colors duration-300 ${light ? 'bg-background-50 border-b border-background-200' : 'bg-transparent'}`}>
      <nav className="flex items-center justify-between px-4 md:px-10 h-16 md:h-20">
        <a href="#top" className="flex items-center gap-2 cursor-pointer">
          <span className="w-11 h-11 rounded-md bg-background-50 flex items-center justify-center p-1">
            <img src={saiLogo} alt="شعار كلية ساي التعليمية اليمنية الصينية" className="w-full h-full object-contain" />
          </span>
          <span className={`font-heading font-semibold text-base ${light ? 'text-foreground-950' : 'text-background-50'}`}>
            {isAr ? 'كلية ساي' : 'SAI College'}
          </span>
        </a>
        <ul className="hidden lg:flex items-center gap-7">
          {navLinks.map((l) => (
            <li key={l.id}>
              <a href={`#${l.id}`} className={`text-sm whitespace-nowrap cursor-pointer transition-colors hover:text-accent-500 ${light ? 'text-foreground-700' : 'text-background-50/90'}`}>
                {l[lang]}
              </a>
            </li>
          ))}
        </ul>
        <div className="flex items-center gap-2">
          <button type="button" onClick={toggle} className={`whitespace-nowrap cursor-pointer text-sm px-3 py-1.5 rounded-full border ${light ? 'border-background-300 text-foreground-800' : 'border-background-50/40 text-background-50'}`}>
            {isAr ? 'English' : 'العربية'}
          </button>
          <Link to="/portal/login" className={`hidden md:inline-flex whitespace-nowrap cursor-pointer text-sm px-3 py-2 rounded-md border ${light ? 'border-background-300 text-foreground-800 hover:bg-background-100' : 'border-background-50/50 text-background-50 hover:bg-background-50/10'}`}>
            {isAr ? 'بوابة الكلية' : 'College portal'}
          </Link>
          <a href="#admissions" className="hidden md:inline-flex whitespace-nowrap cursor-pointer text-sm px-4 py-2 rounded-md bg-primary-500 hover:bg-primary-600 text-background-50">
            {isAr ? 'قدّم الآن' : 'Apply now'}
          </a>
          <button type="button" aria-label="menu" onClick={() => setOpen(!open)} className={`lg:hidden w-9 h-9 flex items-center justify-center cursor-pointer ${light ? 'text-foreground-900' : 'text-background-50'}`}>
            <i className={`${open ? 'ri-close-line' : 'ri-menu-line'} text-xl`}></i>
          </button>
        </div>
      </nav>
      {open && (
        <ul className="lg:hidden flex flex-col px-4 pb-4 gap-1 bg-background-50">
          {navLinks.map((l) => (
            <li key={l.id}>
              <a href={`#${l.id}`} onClick={() => setOpen(false)} className="block py-2 text-sm text-foreground-800 cursor-pointer">{l[lang]}</a>
            </li>
          ))}
          <li>
            <Link to="/portal/login" onClick={() => setOpen(false)} className="block py-2 text-sm text-primary-700 cursor-pointer">{isAr ? 'بوابة الكلية' : 'College portal'}</Link>
          </li>
        </ul>
      )}
    </header>
  );
}