import { useState, type FormEvent } from 'react';
import useLang from '@/hooks/useLang';
import { admissionSteps, programs } from '@/mocks/home';

const FORM_URL = 'https://readdy.ai/api/form/dbo74dv53qvvv5m6cf30';

export default function Admissions() {
  const { isAr } = useLang();
  const [status, setStatus] = useState<'idle' | 'sending' | 'ok' | 'error'>('idle');
  const [formError, setFormError] = useState('');
  const [msgLen, setMsgLen] = useState(0);

  const onSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const form = e.currentTarget;
    const fd = new FormData(form);
    const trap = String(fd.get('contact_alt') || '').trim();
    if (trap) { setStatus('ok'); return; }
    fd.delete('contact_alt');
    if (String(fd.get('message') || '').length > 500) {
      setFormError(isAr ? 'الرسالة أطول من 500 حرف.' : 'Message exceeds 500 characters.');
      setStatus('error');
      return;
    }
    setStatus('sending');
    setFormError('');
    try {
      const body = new URLSearchParams();
      fd.forEach((v, k) => body.append(k, String(v)));
      const response = await fetch(FORM_URL, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body.toString() });
      const responseText = await response.text();
      let parsed: { code?: string; message?: string; meta?: { message?: string; detail?: string } } | null = null;
      try { parsed = JSON.parse(responseText); } catch { parsed = null; }
      const serverMsg = parsed?.meta?.message || parsed?.message || parsed?.meta?.detail || responseText;
      if (response.ok && parsed?.code === 'OK' && !/spam/i.test(serverMsg || '')) {
        setStatus('ok');
        form.reset();
        setMsgLen(0);
      } else {
        setFormError(serverMsg || (isAr ? 'تعذر الإرسال.' : 'Submission failed.'));
        setStatus('error');
      }
    } catch {
      setFormError(isAr ? 'خطأ في الشبكة، حاول مرة أخرى.' : 'Network error, please try again.');
      setStatus('error');
    }
  };

  const field = 'w-full box-border rounded-md border border-background-300 bg-background-50 px-3 py-2.5 text-sm text-foreground-900 focus:outline-none focus:ring-2 focus:ring-primary-400';

  return (
    <section id="admissions" className="reveal px-4 md:px-10 py-16 md:py-24 bg-primary-50">
      <div className="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-2 gap-10">
        <div>
          <span className="text-xs font-label uppercase tracking-wider text-primary-700">{isAr ? 'القبول والتسجيل' : 'Admissions'}</span>
          <h2 className="mt-3 font-heading text-2xl md:text-4xl text-foreground-950">{isAr ? 'أربع خطوات لبدء رحلتك' : 'Four steps to start your journey'}</h2>
          <ul className="mt-8 space-y-4">
            {admissionSteps.map((s) => (
              <li key={s.en} className="flex gap-4 items-start">
                <span className="w-11 h-11 shrink-0 rounded-md bg-primary-500 text-background-50 flex items-center justify-center"><i className={`${s.icon} text-lg`}></i></span>
                <div>
                  <h3 className="font-heading text-sm md:text-base text-foreground-950">{isAr ? s.ar : s.en}</h3>
                  <p className="text-xs md:text-sm text-foreground-600 mt-0.5">{isAr ? s.dar : s.den}</p>
                </div>
              </li>
            ))}
          </ul>
        </div>
        <form id="sai-admissions-inquiry" data-readdy-form onSubmit={onSubmit} className="relative rounded-lg bg-background-50 border border-background-200 p-5 md:p-8 grid grid-cols-1 sm:grid-cols-2 gap-4">
          <input type="text" name="contact_alt" className="form-extra-field" tabIndex={-1} autoComplete="off" aria-hidden="true" readOnly />
          <div className="min-w-0"><label className="text-xs text-foreground-700">{isAr ? 'الاسم الكامل' : 'Full name'}</label><input required name="full_name" className={`${field} mt-1`} /></div>
          <div className="min-w-0"><label className="text-xs text-foreground-700">{isAr ? 'رقم الهاتف' : 'Phone'}</label><input required name="phone" type="tel" className={`${field} mt-1`} /></div>
          <div className="min-w-0 sm:col-span-2"><label className="text-xs text-foreground-700">{isAr ? 'البريد الإلكتروني' : 'Email'}</label><input required name="email" type="email" className={`${field} mt-1`} /></div>
          <div className="min-w-0 sm:col-span-2">
            <label className="text-xs text-foreground-700">{isAr ? 'البرنامج المطلوب' : 'Program of interest'}</label>
            <select name="program" className={`${field} mt-1 cursor-pointer`}>
              {programs.map((p) => <option key={p.en} value={p.en}>{isAr ? p.ar : p.en}</option>)}
            </select>
          </div>
          <div className="min-w-0 sm:col-span-2">
            <label className="text-xs text-foreground-700">{isAr ? 'رسالتك' : 'Message'}</label>
            <textarea name="message" rows={4} maxLength={500} onChange={(e) => setMsgLen(e.target.value.length)} className={`${field} mt-1 resize-none`}></textarea>
            <div className="text-xs text-foreground-500 mt-1">{msgLen}/500</div>
          </div>
          <div className="sm:col-span-2">
            <button type="submit" disabled={status === 'sending'} className="w-full whitespace-nowrap cursor-pointer rounded-md bg-primary-500 hover:bg-primary-600 text-background-50 py-3 text-sm font-label disabled:opacity-60">
              {status === 'sending' ? (isAr ? 'جارٍ الإرسال...' : 'Sending...') : (isAr ? 'إرسال الاستفسار' : 'Send inquiry')}
            </button>
            {status === 'ok' && <p className="mt-3 text-sm text-secondary-700">{isAr ? 'شكرًا! سيتواصل معك فريق القبول قريبًا.' : 'Thank you! Our admissions team will contact you soon.'}</p>}
            {status === 'error' && <p className="mt-3 text-sm text-primary-700">{formError}</p>}
          </div>
        </form>
      </div>
    </section>
  );
}