import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import useLang from '@/hooks/useLang';
import { supabase } from '@/portal/lib/supabase';
import { admissionSteps, programs } from '@/mocks/home';

const errorCopy: Record<string, { ar: string; en: string }> = {
  INVALID_NAME: { ar: 'يرجى إدخال الاسم الكامل بشكل صحيح.', en: 'Please enter a valid full name.' },
  INVALID_PHONE: { ar: 'يرجى إدخال رقم هاتف صحيح.', en: 'Please enter a valid phone number.' },
  INVALID_EMAIL: { ar: 'يرجى إدخال بريد إلكتروني صحيح.', en: 'Please enter a valid email address.' },
  MESSAGE_TOO_LONG: { ar: 'الرسالة أطول من 500 حرف.', en: 'Message exceeds 500 characters.' },
  NO_ACTIVE_TERM: { ar: 'القبول غير مفتوح حالياً. تواصل مع مكتب القبول.', en: 'Admissions are not open right now. Please contact the admissions office.' },
  NO_ADMISSIONS_OWNER: { ar: 'تعذر تسجيل الطلب حالياً. تواصل مع مكتب القبول.', en: 'We could not register the enquiry. Please contact the admissions office.' },
};

export default function Admissions() {
  const { isAr } = useLang();
  const [status, setStatus] = useState<'idle' | 'sending' | 'ok' | 'error'>('idle');
  const [formError, setFormError] = useState('');
  const [reference, setReference] = useState('');
  const [emailNote, setEmailNote] = useState<'idle' | 'pending' | 'sent' | 'unconfigured' | 'failed'>('idle');
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
    setReference('');
    setEmailNote('idle');
    try {
      const { data, error } = await supabase.rpc('sai_public_admission_submit', {
        p_full_name: String(fd.get('full_name') || '').trim(),
        p_phone: String(fd.get('phone') || '').trim(),
        p_email: String(fd.get('email') || '').trim(),
        p_program: String(fd.get('program') || '').trim(),
        p_message: String(fd.get('message') || '').trim(),
      });
      if (error) {
        const key = Object.keys(errorCopy).find((code) => (error.message || '').includes(code));
        setFormError(key ? errorCopy[key][isAr ? 'ar' : 'en'] : (isAr ? 'تعذر إرسال الطلب. حاول مرة أخرى.' : 'We could not send your enquiry. Please try again.'));
        setStatus('error');
        return;
      }
      const ref = Array.isArray(data) ? data[0] : data;
      if (typeof ref === 'string' && ref.trim()) {
        const trimmedRef = ref.trim();
        setReference(trimmedRef);
        setStatus('ok');
        form.reset();
        setMsgLen(0);
        setEmailNote('pending');
        const base = __BASE_PATH__.replace(/\/$/, '');
        void supabase.functions.invoke('admission-notify', {
          body: { reference: trimmedRef, statusUrl: `${window.location.origin}${base}/application-status` },
        }).then(({ data, error: notifyError }) => {
          if (notifyError) { setEmailNote('failed'); return; }
          const result = data as { sent?: boolean; reason?: string } | null;
          if (result?.sent) setEmailNote('sent');
          else if (result?.reason === 'EMAIL_NOT_CONFIGURED') setEmailNote('unconfigured');
          else setEmailNote('failed');
        }).catch(() => setEmailNote('failed'));
      } else {
        setFormError(isAr ? 'تعذر إنشاء رقم مرجعي. حاول مرة أخرى.' : 'We could not create a reference number. Please try again.');
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
        <form id="sai-admissions-inquiry" onSubmit={onSubmit} className="relative rounded-lg bg-background-50 border border-background-200 p-5 md:p-8 grid grid-cols-1 sm:grid-cols-2 gap-4">
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
            {status === 'ok' && (reference ? (
              <div className="mt-3 rounded-md border border-secondary-300 bg-secondary-100 px-4 py-3">
                <p className="text-xs text-secondary-900">{isAr ? 'تم استلام طلبك وتسجيله في نظام القبول. رقم الطلب المرجعي:' : 'Your enquiry is registered in our admissions system. Reference number:'}</p>
                <p className="mt-1 font-heading text-lg text-foreground-950" dir="ltr">{reference}</p>
                <p className="mt-1 text-xs text-foreground-700">{isAr ? 'احتفظ بهذا الرقم لمتابعة طلبك مع مكتب القبول.' : 'Keep this number to follow up with the admissions office.'}</p>
                <p className="mt-2 text-xs text-foreground-700">
                  {emailNote === 'pending' && (isAr ? 'جارٍ إرسال رسالة التأكيد إلى بريدك الإلكتروني...' : 'Sending your confirmation email...')}
                  {emailNote === 'sent' && (isAr ? 'أرسلنا رقم الطلب إلى بريدك الإلكتروني، وأبلغنا فريق القبول بالطلب الجديد.' : 'We emailed your reference number and alerted the admissions team.')}
                  {emailNote === 'failed' && (isAr ? 'تم تسجيل طلبك، لكن تعذر إرسال رسالة التأكيد الآن. احتفظ بالرقم أعلاه.' : 'Your enquiry is registered, but the confirmation email could not be sent. Keep the number above.')}
                  {emailNote === 'unconfigured' && (isAr ? 'احتفظ بالرقم أعلاه؛ سيتواصل معك فريق القبول.' : 'Keep the number above; our admissions team will contact you.')}
                </p>
                <Link to="/application-status" className="mt-3 inline-flex items-center gap-1 text-xs text-primary-700 underline cursor-pointer whitespace-nowrap">
                  {isAr ? 'متابعة حالة الطلب' : 'Track application status'}
                  <i className="ri-arrow-left-line"></i>
                </Link>
              </div>
            ) : (
              <p className="mt-3 text-sm text-secondary-700">{isAr ? 'شكرًا! سيتواصل معك فريق القبول قريبًا.' : 'Thank you! Our admissions team will contact you soon.'}</p>
            ))}
            {status === 'error' && <p className="mt-3 text-sm text-primary-700">{formError}</p>}
          </div>
        </form>
      </div>
    </section>
  );
}