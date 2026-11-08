import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router-dom';
import useLang from '@/hooks/useLang';
import Navbar from '@/components/feature/Navbar';
import Footer from '@/components/feature/Footer';
import { supabase } from '@/portal/lib/supabase';

type ApplicationStatus = {
  application_no: string;
  applicant_name: string;
  program: string | null;
  level: string | null;
  status: string;
  branch_name: string | null;
  session_name: string | null;
  submitted_at: string;
  status_updated_at: string;
};

const steps = ['new', 'contacted', 'assessment', 'accepted', 'enrolled'] as const;

type StatusHistoryRow = { action: string; new_status: string; occurred_at: string };

const stepCopy: Record<string, { ar: string; en: string }> = {
  new: { ar: 'تم استلام الطلب', en: 'Enquiry received' },
  contacted: { ar: 'التواصل مع المتقدم', en: 'Contacted' },
  assessment: { ar: 'التقييم والمقابلة', en: 'Assessment' },
  accepted: { ar: 'صدور القبول', en: 'Accepted' },
  enrolled: { ar: 'إتمام التسجيل', en: 'Enrolled' },
};

const statusCopy: Record<string, { ar: string; en: string }> = {
  new: { ar: 'قيد المراجعة الأولية', en: 'Under initial review' },
  contacted: { ar: 'تم التواصل معك', en: 'We contacted you' },
  assessment: { ar: 'في مرحلة التقييم', en: 'In assessment' },
  accepted: { ar: 'تم قبولك', en: 'Accepted' },
  enrolled: { ar: 'مسجل رسميًا', en: 'Enrolled' },
  rejected: { ar: 'الطلب غير مقبول', en: 'Not accepted' },
  withdrawn: { ar: 'تم سحب الطلب', en: 'Withdrawn' },
};

export default function ApplicationStatusPage() {
  const { isAr } = useLang();
  const [searchParams] = useSearchParams();
  const [reference, setReference] = useState('');
  const [status, setStatus] = useState<'idle' | 'loading' | 'found' | 'missing' | 'error'>('idle');
  const [result, setResult] = useState<ApplicationStatus | null>(null);
  const [errorMessage, setErrorMessage] = useState('');
  const [history, setHistory] = useState<StatusHistoryRow[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyError, setHistoryError] = useState('');
  const autoLookupDone = useRef(false);

  async function lookup(raw: string) {
    const value = raw.trim();
    if (value.length < 6) {
      setStatus('error');
      setErrorMessage(isAr ? 'أدخل الرقم المرجعي كاملًا كما ورد في رسالة التأكيد (يبدأ بـ SAI-APP-).' : 'Enter the full reference number from your confirmation email (it starts with SAI-APP-).');
      setResult(null);
      return;
    }
    setStatus('loading');
    setErrorMessage('');
    setResult(null);
    try {
      const { data, error } = await supabase.rpc('sai_public_admission_status', { p_reference: value });
      if (error) {
        setStatus('error');
        setErrorMessage(isAr ? 'تعذر البحث عن الطلب الآن. حاول مرة أخرى بعد قليل.' : 'We could not look up your application right now. Please try again shortly.');
        return;
      }
      const rows = Array.isArray(data) ? data : [];
      const row = rows[0] as ApplicationStatus | undefined;
      if (!row) {
        setStatus('missing');
        return;
      }
      setResult(row);
      setStatus('found');
    } catch {
      setStatus('error');
      setErrorMessage(isAr ? 'خطأ في الشبكة. تحقق من الاتصال وحاول مجددًا.' : 'Network error. Check your connection and try again.');
    }
  }

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    await lookup(reference);
  };

  useEffect(() => {
    if (autoLookupDone.current) return;
    autoLookupDone.current = true;
    const preset = (searchParams.get('ref') ?? '').trim();
    if (preset.length < 6) return;
    setReference(preset);
    void lookup(preset);
  }, [searchParams]);

  useEffect(() => {
    if (!result) {
      setHistory([]);
      setHistoryError('');
      setHistoryLoading(false);
      return;
    }
    let active = true;
    setHistory([]);
    setHistoryError('');
    setHistoryLoading(true);
    supabase
      .rpc('sai_public_admission_history', { p_reference: result.application_no })
      .then(({ data, error }) => {
        if (!active) return;
        if (error) {
          setHistory([]);
          setHistoryError(isAr ? 'تعذر تحميل سجل التحديثات حاليًا.' : 'We could not load the update history right now.');
          return;
        }
        const rows = Array.isArray(data) ? data : [];
        setHistory(
          rows
            .filter((row): row is StatusHistoryRow =>
              typeof row === 'object' && row !== null && 'new_status' in row && 'occurred_at' in row)
            .map((row) => ({
              action: typeof row.action === 'string' ? row.action : 'status_change',
              new_status: String((row as StatusHistoryRow).new_status),
              occurred_at: String((row as StatusHistoryRow).occurred_at),
            })),
        );
      })
      .catch(() => {
        if (active) {
          setHistory([]);
          setHistoryError(isAr ? 'تعذر تحميل سجل التحديثات حاليًا.' : 'We could not load the update history right now.');
        }
      })
      .finally(() => {
        if (active) setHistoryLoading(false);
      });
    return () => {
      active = false;
    };
  }, [result, isAr]);

  const currentIndex = result ? steps.indexOf(result.status as (typeof steps)[number]) : -1;
  const closed = result ? ['rejected', 'withdrawn'].includes(result.status) : false;
  const submittedDate = result
    ? new Date(result.submitted_at).toLocaleDateString(isAr ? 'ar-EG' : 'en-GB', { year: 'numeric', month: 'long', day: 'numeric' })
    : '';
  const updatedDate = result
    ? new Date(result.status_updated_at).toLocaleDateString(isAr ? 'ar-EG' : 'en-GB', { year: 'numeric', month: 'long', day: 'numeric' })
    : '';

  const badgeTone = closed
    ? 'bg-primary-100 text-primary-800 border-primary-200'
    : result?.status === 'enrolled' || result?.status === 'accepted'
      ? 'bg-secondary-100 text-secondary-900 border-secondary-200'
      : 'bg-accent-100 text-accent-900 border-accent-200';

  return (
    <div className="min-h-screen bg-background-50">
      <Navbar />
      <main>
        <section className="relative overflow-hidden px-4 md:px-10 pt-28 md:pt-36 pb-12 md:pb-16 bg-primary-900 text-background-50">
          <div className="absolute -top-28 -left-20 w-72 h-72 rounded-full bg-accent-500/15" aria-hidden="true"></div>
          <div className="absolute -bottom-24 right-4 w-56 h-56 rounded-full bg-secondary-500/10" aria-hidden="true"></div>
          <div className="relative max-w-4xl mx-auto">
            <span className="text-xs font-label uppercase tracking-wider text-accent-300">
              {isAr ? 'مكتب القبول' : 'Admissions office'}
            </span>
            <h1 className="mt-3 font-heading text-2xl md:text-4xl text-background-50">
              {isAr ? 'تابع حالة طلب القبول' : 'Track your application'}
            </h1>
            <p className="mt-3 text-sm md:text-base text-background-100/85 max-w-2xl leading-relaxed">
              {isAr
                ? 'أدخل الرقم المرجعي الذي وصلك عند تقديم الطلب (مثال: SAI-APP-1042) لعرض آخر تحديث على طلبك.'
                : 'Enter the reference number you received when you applied (for example SAI-APP-1042) to see the latest update.'}
            </p>
          </div>
        </section>

        <section className="px-4 md:px-10 py-12 md:py-16">
          <div className="max-w-4xl mx-auto grid grid-cols-1 lg:grid-cols-5 gap-6 lg:gap-8">
            <div className="lg:col-span-3 rounded-lg border border-background-200 bg-background-50 p-5 md:p-7">
              <form onSubmit={onSubmit} className="grid grid-cols-1 gap-4">
                <div className="min-w-0">
                  <label htmlFor="adm-reference" className="text-xs text-foreground-700">
                    {isAr ? 'الرقم المرجعي للطلب' : 'Application reference'}
                  </label>
                  <input
                    id="adm-reference"
                    name="reference"
                    value={reference}
                    onChange={(e) => setReference(e.target.value)}
                    placeholder="SAI-APP-1042"
                    dir="ltr"
                    autoComplete="off"
                    className="mt-1 w-full box-border rounded-md border border-background-300 bg-background-50 px-3 py-2.5 text-sm text-foreground-900 font-mono tracking-wide focus:outline-none focus:ring-2 focus:ring-primary-400"
                  />
                </div>
                <button
                  type="submit"
                  disabled={status === 'loading'}
                  className="w-full whitespace-nowrap cursor-pointer rounded-md bg-primary-500 hover:bg-primary-600 text-background-50 py-3 text-sm font-label disabled:opacity-60"
                >
                  {status === 'loading' ? (isAr ? 'جارٍ البحث...' : 'Looking up...') : (isAr ? 'عرض حالة الطلب' : 'View status')}
                </button>
              </form>

              {status === 'missing' && (
                <div className="mt-5 rounded-md border border-accent-300 bg-accent-100 px-4 py-3">
                  <p className="text-sm text-accent-950">
                    {isAr
                      ? 'لم نعثر على طلب بهذا الرقم. تأكد من كتابة الرقم كما ورد في رسالة التأكيد، أو تواصل مع مكتب القبول.'
                      : 'No application matches this number. Check the reference from your confirmation email, or contact the admissions office.'}
                  </p>
                </div>
              )}
              {status === 'error' && (
                <div className="mt-5 rounded-md border border-primary-200 bg-primary-100 px-4 py-3">
                  <p className="text-sm text-primary-800">{errorMessage}</p>
                </div>
              )}

              {status === 'found' && result && (
                <div className="mt-6 border-t border-background-200 pt-6">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="text-xs text-foreground-600">{isAr ? 'رقم الطلب' : 'Reference'}</p>
                      <p className="font-heading text-base md:text-lg text-foreground-950 break-all" dir="ltr">{result.application_no}</p>
                    </div>
                    <span className={`inline-flex items-center rounded-full border px-3 py-1 text-xs whitespace-nowrap ${badgeTone}`}>
                      {statusCopy[result.status]?.[isAr ? 'ar' : 'en'] ?? result.status}
                    </span>
                  </div>

                  <dl className="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
                    <div className="min-w-0"><dt className="text-xs text-foreground-600">{isAr ? 'اسم المتقدم' : 'Applicant'}</dt><dd className="text-foreground-900">{result.applicant_name}</dd></div>
                    <div className="min-w-0"><dt className="text-xs text-foreground-600">{isAr ? 'البرنامج' : 'Programme'}</dt><dd className="text-foreground-900">{result.program || '—'}</dd></div>
                    <div className="min-w-0"><dt className="text-xs text-foreground-600">{isAr ? 'الفرع' : 'Branch'}</dt><dd className="text-foreground-900">{result.branch_name || '—'}</dd></div>
                    <div className="min-w-0"><dt className="text-xs text-foreground-600">{isAr ? 'الجلسة' : 'Session'}</dt><dd className="text-foreground-900">{result.session_name || '—'}</dd></div>
                    <div className="min-w-0"><dt className="text-xs text-foreground-600">{isAr ? 'تاريخ التقديم' : 'Submitted'}</dt><dd className="text-foreground-900">{submittedDate}</dd></div>
                    <div className="min-w-0"><dt className="text-xs text-foreground-600">{isAr ? 'آخر تحديث' : 'Last update'}</dt><dd className="text-foreground-900">{updatedDate}</dd></div>
                  </dl>

                  {closed ? (
                    <p className="mt-6 rounded-md bg-background-100 border border-background-200 px-4 py-3 text-xs text-foreground-700">
                      {isAr
                        ? 'هذا الطلب مغلق حاليًا. تواصل مع مكتب القبول للاستفسار عن الخطوات التالية.'
                        : 'This application is currently closed. Please contact the admissions office for next steps.'}
                    </p>
                  ) : (
                    <ol className="mt-7 space-y-0">
                      {steps.map((step, index) => {
                        const done = currentIndex >= 0 && index <= currentIndex;
                        const active = index === currentIndex;
                        return (
                          <li key={step} className="flex gap-3 items-start">
                            <div className="flex flex-col items-center">
                              <span className={`w-7 h-7 shrink-0 rounded-full flex items-center justify-center text-xs border ${done ? 'bg-primary-500 text-background-50 border-primary-500' : 'bg-background-50 text-foreground-500 border-background-300'}`}>
                                {done ? <i className="ri-check-line"></i> : index + 1}
                              </span>
                              {index < steps.length - 1 && <span className={`w-px h-9 ${index < currentIndex ? 'bg-primary-400' : 'bg-background-300'}`}></span>}
                            </div>
                            <div className="pb-3 min-w-0">
                              <p className={`text-sm ${active ? 'font-semibold text-foreground-950' : done ? 'text-foreground-900' : 'text-foreground-500'}`}>
                                {stepCopy[step][isAr ? 'ar' : 'en']}
                              </p>
                              {active && (
                                <p className="text-xs text-foreground-600 mt-0.5">
                                  {isAr ? 'هذه هي المرحلة الحالية لطلبك.' : 'Your application is at this stage.'}
                                </p>
                              )}
                            </div>
                          </li>
                        );
                      })}
                    </ol>
                  )}

                  <div className="mt-8 border-t border-background-200 pt-5">
                    <h3 className="font-heading text-sm md:text-base text-foreground-950">
                      {isAr ? 'سجل تغييرات الحالة' : 'Status history'}
                    </h3>
                    <p className="mt-1 text-xs text-foreground-600">
                      {isAr
                        ? 'كل تغيير على طلبك يُسجّل بالتاريخ هنا، من الاستلام حتى التسجيل.'
                        : 'Every change to your application is recorded here with its date, from receipt to enrolment.'}
                    </p>

                    {historyLoading && (
                      <p className="mt-3 text-xs text-foreground-600">{isAr ? 'جارٍ تحميل السجل...' : 'Loading history...'}</p>
                    )}
                    {!historyLoading && historyError && (
                      <p className="mt-3 rounded-md border border-accent-200 bg-accent-100 px-3 py-2 text-xs text-accent-950">{historyError}</p>
                    )}
                    {!historyLoading && !historyError && !history.length && (
                      <p className="mt-3 text-xs text-foreground-600">
                        {isAr ? 'لا توجد تحديثات مسجّلة بعد؛ طلبك قيد المراجعة.' : 'No updates recorded yet; your application is being reviewed.'}
                      </p>
                    )}

                    {!historyLoading && !!history.length && (
                      <ol className="mt-4">
                        {history.map((row, index) => (
                          <li key={`${row.occurred_at}-${index}`} className="flex gap-3">
                            <div className="flex flex-col items-center">
                              <span className="mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full bg-primary-500"></span>
                              {index < history.length - 1 && <span className="my-1 w-px flex-1 bg-background-300"></span>}
                            </div>
                            <div className="min-w-0 pb-4">
                              <p className="text-sm text-foreground-900">
                                {statusCopy[row.new_status]?.[isAr ? 'ar' : 'en'] ?? row.new_status}
                              </p>
                              <p className="mt-0.5 text-xs text-foreground-600">
                                {new Date(row.occurred_at).toLocaleString(isAr ? 'ar-EG' : 'en-GB', {
                                  year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit',
                                })}
                              </p>
                            </div>
                          </li>
                        ))}
                      </ol>
                    )}
                  </div>
                </div>
              )}
            </div>

            <aside className="lg:col-span-2 space-y-4">
              <div className="rounded-lg border border-background-200 bg-background-100 p-5">
                <h2 className="font-heading text-sm md:text-base text-foreground-950">{isAr ? 'كيف يعمل هذا؟' : 'How it works'}</h2>
                <ul className="mt-3 space-y-2 text-xs md:text-sm text-foreground-700">
                  <li className="flex gap-2"><i className="ri-mail-check-line text-primary-600"></i>{isAr ? 'يُرسل رقم الطلب إلى بريدك بعد التقديم مباشرة.' : 'Your reference is emailed to you right after you apply.'}</li>
                  <li className="flex gap-2"><i className="ri-search-line text-primary-600"></i>{isAr ? 'استخدم نفس الرقم في أي وقت لعرض الحالة.' : 'Use the same number at any time to see your status.'}</li>
                  <li className="flex gap-2"><i className="ri-user-heart-line text-primary-600"></i>{isAr ? 'يُحدّث فريق القبول الحالة بعد كل تواصل أو تقييم.' : 'Our team updates the status after each contact or assessment.'}</li>
                </ul>
              </div>
              <div className="rounded-lg border border-background-200 bg-background-50 p-5">
                <h2 className="font-heading text-sm md:text-base text-foreground-950">{isAr ? 'فقدت رقمك؟' : 'Lost your number?'}</h2>
                <p className="mt-2 text-xs md:text-sm text-foreground-700">
                  {isAr
                    ? 'تواصل مع مكتب القبول مع ذكر اسمك ورقم هاتفك، وسنعيد إرسال الرقم المرجعي إليك.'
                    : 'Contact the admissions office with your name and phone number and we will resend your reference.'}
                </p>
                <a href="mailto:admissions@saicollege.edu.ye" className="mt-3 inline-flex items-center gap-1 text-xs md:text-sm text-primary-700 underline whitespace-nowrap cursor-pointer">
                  admissions@saicollege.edu.ye
                  <i className="ri-mail-line"></i>
                </a>
              </div>
            </aside>
          </div>
        </section>
      </main>
      <Footer />
    </div>
  );
}