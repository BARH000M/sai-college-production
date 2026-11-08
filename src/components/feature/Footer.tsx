import { Link } from 'react-router-dom';
import useLang from '@/hooks/useLang';
import { contactInfo, navLinks } from '@/mocks/home';
import saiLogo from '@/portal/assets/saiLogo';

export default function Footer() {
  const { tx, lang, isAr } = useLang();
  return (
    <footer className="px-4 md:px-10 pt-14 pb-6 bg-accent-100 text-foreground-900">
      <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-10">
        <div>
          <img src={saiLogo} alt="شعار كلية ساي" className="w-14 h-14 object-contain rounded-md" />
          <div className="mt-3 font-heading text-lg">{isAr ? 'كلية ساي التعليمية اليمنية الصينية' : 'SAI Yemeni–Chinese College'}</div>
          <p className="mt-3 text-sm text-foreground-700 leading-relaxed">{isAr ? 'نعدّ جيلًا يمنيًا يتقن التقنية واللغة الصينية.' : 'Preparing a Yemeni generation fluent in technology and Mandarin.'}</p>
        </div>
        <div>
          <ul className="grid grid-cols-2 gap-2 text-sm">
            {navLinks.map((l) => <li key={l.id}><a href={`#${l.id}`} className="hover:text-primary-600 cursor-pointer whitespace-nowrap">{l[lang]}</a></li>)}
            <li><Link to="/portal/login" className="hover:text-primary-600 cursor-pointer whitespace-nowrap text-primary-700">{isAr ? 'بوابة الكلية' : 'College portal'}</Link></li>
            <li><Link to="/application-status" className="hover:text-primary-600 cursor-pointer whitespace-nowrap">{isAr ? 'حالة طلب القبول' : 'Application status'}</Link></li>
          </ul>
        </div>
        <ul className="space-y-2 text-sm text-foreground-800">
          <li className="flex items-center gap-2"><i className="ri-map-pin-line"></i>{tx(contactInfo.address)}</li>
          <li className="flex items-center gap-2"><i className="ri-phone-line"></i><span dir="ltr">{contactInfo.phone}</span></li>
          <li className="flex items-center gap-2"><i className="ri-mail-line"></i>{contactInfo.email}</li>
        </ul>
      </div>
      <div className="max-w-6xl mx-auto mt-10 pt-5 border-t border-accent-300 flex flex-col sm:flex-row justify-between gap-2 text-xs text-foreground-600">
        <span>© 2026 SAI College</span>
        <span>{isAr ? 'صنعاء، الجمهورية اليمنية' : 'Sana\'a, Republic of Yemen'}</span>
      </div>
    </footer>
  );
}