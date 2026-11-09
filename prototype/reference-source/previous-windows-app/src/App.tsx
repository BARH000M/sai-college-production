import { useEffect, useMemo, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import {
  ArrowLeft,
  ArrowRight,
  Award,
  Bell,
  BookOpen,
  CalendarDays,
  Check,
  ChevronLeft,
  Clock3,
  ExternalLink,
  FileCheck2,
  FileText,
  GraduationCap,
  Home as HomeIcon,
  Inbox,
  LoaderCircle,
  LogIn,
  LogOut,
  Menu,
  MessageSquareText,
  Newspaper,
  Search,
  Send,
  ShieldCheck,
  Sparkles,
  UserRound,
  X,
} from "lucide-react";
import {
  Link,
  Navigate,
  Route,
  Routes,
  useLocation,
  useNavigate,
  useParams,
  useSearchParams,
} from "react-router";
import { Toaster, toast } from "sonner";
import { trpc } from "@/providers/trpc";
import { useAuth } from "@/hooks/useAuth";
import Login from "./pages/Login";
import NotFound from "./pages/NotFound";

function usePrograms() {
  return trpc.college.programs.useQuery(undefined, { staleTime: 60_000 });
}
function useNews() {
  return trpc.college.news.useQuery(undefined, { staleTime: 60_000 });
}
type Program = NonNullable<ReturnType<typeof usePrograms>["data"]>[number];
type NewsItem = NonNullable<ReturnType<typeof useNews>["data"]>[number];

const navItems = [
  { path: "/", label: "الرئيسية", icon: HomeIcon },
  { path: "/programs", label: "البرامج", icon: BookOpen },
  { path: "/news", label: "الأخبار", icon: Newspaper },
  { path: "/requests", label: "طلباتي", icon: FileText },
  { path: "/profile", label: "حسابي", icon: UserRound },
];

function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <Link to="/" className={`brand ${compact ? "brand--compact" : ""}`} aria-label="كلية ساي - الرئيسية">
      <span className="brand__mark" aria-hidden="true">SAI<span>✦</span></span>
      <span className="brand__text">
        <strong>كلية ساي التعليمية</strong>
        <small>اليمنية الصينية · 2026–2027</small>
      </span>
    </Link>
  );
}

function AppShell({ children }: { children: ReactNode }) {
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: "instant" });
    setMenuOpen(false);
  }, [location.pathname]);

  const isActive = (path: string) =>
    path === "/" ? location.pathname === "/" : location.pathname.startsWith(path);

  return (
    <div className="app-shell" dir="rtl">
      <aside className="desktop-rail">
        <Brand />
        <nav className="rail-nav" aria-label="التنقل الرئيسي">
          {navItems.map(({ path, label, icon: Icon }) => (
            <Link key={path} to={path} className={isActive(path) ? "active" : ""}>
              <Icon size={20} strokeWidth={1.8} />
              <span>{label}</span>
              {isActive(path) && <span className="nav-dot" />}
            </Link>
          ))}
        </nav>
        <div className="rail-help">
          <span className="eyebrow">مكتب القبول</span>
          <strong>هل تحتاج إلى مساعدة؟</strong>
          <p>أرسل استفسارك وسيتواصل معك فريق الاستقبال.</p>
          <Link to="/apply" className="text-link">ابدأ الاستفسار <ArrowLeft size={16} /></Link>
        </div>
        <a className="website-link" href="https://www.sai-academic.com/" target="_blank" rel="noreferrer">
          زيارة الموقع التعريفي <ExternalLink size={15} />
        </a>
      </aside>

      <header className="mobile-header">
        <Brand compact />
        <button className="icon-button" onClick={() => setMenuOpen(true)} aria-label="فتح القائمة">
          <Menu size={22} />
        </button>
      </header>

      {menuOpen && (
        <div className="menu-overlay" role="presentation" onClick={() => setMenuOpen(false)}>
          <section className="menu-panel" role="dialog" aria-modal="true" aria-label="القائمة" onClick={(e) => e.stopPropagation()}>
            <div className="menu-panel__top"><Brand compact /><button className="icon-button" onClick={() => setMenuOpen(false)} aria-label="إغلاق القائمة"><X /></button></div>
            <Link to="/apply" className="button button--primary"><Send size={18} /> استفسار القبول</Link>
            <Link to="/verify" className="menu-row"><ShieldCheck /> التحقق من الوثائق <ChevronLeft /></Link>
            <a href="https://www.sai-academic.com/" target="_blank" rel="noreferrer" className="menu-row"><ExternalLink /> الموقع التعريفي <ChevronLeft /></a>
            <p className="menu-note">تعليم لغوي وأكاديمي يجمع بين المنهج اليمني واللغة الصينية.</p>
          </section>
        </div>
      )}

      <main className="app-main" id="main-content">{children}</main>

      <nav className="bottom-nav" aria-label="التنقل الرئيسي للجوال">
        {navItems.map(({ path, label, icon: Icon }) => (
          <Link key={path} to={path} className={isActive(path) ? "active" : ""} aria-current={isActive(path) ? "page" : undefined}>
            <Icon size={21} strokeWidth={isActive(path) ? 2.4 : 1.7} />
            <span>{label}</span>
          </Link>
        ))}
      </nav>
      <Toaster position="top-center" dir="rtl" richColors />
    </div>
  );
}

function PageHeading({ eyebrow, title, description, action }: { eyebrow: string; title: string; description?: string; action?: ReactNode }) {
  return (
    <div className="page-heading">
      <div><span className="eyebrow">{eyebrow}</span><h1>{title}</h1>{description && <p>{description}</p>}</div>
      {action}
    </div>
  );
}

function BackButton({ to, label = "رجوع" }: { to: string; label?: string }) {
  return <Link to={to} className="back-button"><ArrowRight size={18} /> {label}</Link>;
}

function LoadingState({ label = "جارٍ تحميل المحتوى" }: { label?: string }) {
  return <div className="state-panel" role="status"><LoaderCircle className="spin" /><strong>{label}</strong><p>سيظهر المحتوى هنا خلال لحظات.</p></div>;
}

function ErrorState({ retry }: { retry: () => void }) {
  return <div className="state-panel state-panel--error"><Inbox /><strong>تعذّر تحميل المحتوى</strong><p>تحقق من اتصالك ثم حاول مرة أخرى.</p><button className="button button--outline" onClick={retry}>إعادة المحاولة</button></div>;
}

function EmptyState({ title, description, action }: { title: string; description: string; action?: ReactNode }) {
  return <div className="state-panel"><Inbox /><strong>{title}</strong><p>{description}</p>{action}</div>;
}

function ProgramRow({ program }: { program: Program }) {
  return (
    <Link to={`/programs/${program.slug}`} className="program-row">
      <img src={program.imageUrl} alt="" />
      <div className="program-row__content">
        <span className="tag">{program.category}</span>
        <h3>{program.title}</h3>
        <p>{program.subtitle}</p>
        <div className="program-meta"><span><Award size={15} />{program.level}</span><span><Clock3 size={15} />{program.duration}</span></div>
      </div>
      <ChevronLeft className="row-chevron" size={20} />
    </Link>
  );
}

function NewsRow({ item, featured = false }: { item: NewsItem; featured?: boolean }) {
  return (
    <Link to={`/news/${item.slug}`} className={`news-row ${featured ? "news-row--featured" : ""}`}>
      <div className="news-date"><CalendarDays size={17} /><time>{new Intl.DateTimeFormat("ar-YE", { day: "numeric", month: "long", year: "numeric" }).format(item.publishedAt)}</time></div>
      <h3>{item.title}</h3>
      <p>{item.summary}</p>
      <span className="text-link">اقرأ الإعلان <ArrowLeft size={15} /></span>
    </Link>
  );
}

function HomePage() {
  const programs = usePrograms();
  const news = useNews();
  return (
    <div className="page home-page">
      <section className="home-hero">
        <img src="/images/campus.webp" alt="بيئة تعليمية في كلية ساي" />
        <div className="home-hero__shade" />
        <div className="home-hero__content">
          <span className="hero-badge"><Sparkles size={14} /> التسجيل للعام 2026–2027</span>
          <h1>تعلّم الصينية.<br /><em>وافتح مسارك للعالم.</em></h1>
          <p>برامج لغوية وأكاديمية تجمع بين المنهج اليمني واللغة الصينية، من أول حرف حتى الاحتراف.</p>
          <div className="hero-actions">
            <Link to="/apply" className="button button--gold">استفسار القبول <ArrowLeft size={18} /></Link>
            <Link to="/programs" className="button button--glass">استكشف البرامج</Link>
          </div>
        </div>
        <div className="hero-stat"><strong>{programs.data?.length ?? "—"}</strong><span>مسارات أكاديمية</span></div>
      </section>

      <section className="quick-actions" aria-label="إجراءات سريعة">
        <Link to="/apply"><span><MessageSquareText /></span><div><strong>استفسار القبول</strong><small>أرسل بياناتك للمكتب</small></div><ChevronLeft /></Link>
        <Link to="/verify"><span><FileCheck2 /></span><div><strong>التحقق من وثيقة</strong><small>تحقق برمز الإصدار</small></div><ChevronLeft /></Link>
        <Link to="/requests"><span><Inbox /></span><div><strong>متابعة طلباتي</strong><small>الحالة والرقم المرجعي</small></div><ChevronLeft /></Link>
      </section>

      <section className="content-section">
        <div className="section-heading"><div><span className="eyebrow">ابدأ مسارك</span><h2>برامج مختارة</h2></div><Link to="/programs" className="text-link">كل البرامج <ArrowLeft size={16} /></Link></div>
        {programs.isLoading ? <LoadingState /> : programs.error ? <ErrorState retry={programs.refetch} /> : (
          <div className="program-list">{programs.data?.slice(0, 3).map((p) => <ProgramRow key={p.id} program={p} />)}</div>
        )}
      </section>

      <section className="content-section news-preview">
        <div className="section-heading"><div><span className="eyebrow">من الكلية</span><h2>آخر الأخبار</h2></div><Link to="/news" className="text-link">كل الأخبار <ArrowLeft size={16} /></Link></div>
        {news.isLoading ? <LoadingState /> : news.error ? <ErrorState retry={news.refetch} /> : (
          <div className="news-grid">{news.data?.slice(0, 2).map((n) => <NewsRow key={n.id} item={n} />)}</div>
        )}
      </section>

      <section className="contact-strip">
        <div><span className="eyebrow">نحن هنا للإجابة</span><h2>غير متأكد من المسار المناسب؟</h2><p>أخبرنا بمستواك وهدفك، وسيساعدك مكتب القبول في اختيار البرنامج.</p></div>
        <Link to="/apply" className="button button--primary">تحدث مع القبول <ArrowLeft size={17} /></Link>
      </section>
    </div>
  );
}

function ProgramDetail({ program }: { program: Program }) {
  return (
    <div className="detail-page">
      <BackButton to="/programs" label="كل البرامج" />
      <div className="detail-hero"><img src={program.imageUrl} alt={program.title} /><span className="tag">{program.category}</span></div>
      <div className="detail-body">
        <h1>{program.title}</h1><p className="detail-subtitle">{program.subtitle}</p>
        <div className="detail-facts">
          <div><Award /><span>المستوى</span><strong>{program.level}</strong></div>
          <div><Clock3 /><span>المدة</span><strong>{program.duration}</strong></div>
          <div><CalendarDays /><span>الجدول</span><strong>{program.schedule}</strong></div>
        </div>
        <section><h2>عن هذا المسار</h2><p>{program.description}</p></section>
        <section className="outcome-box"><GraduationCap /><div><h2>ماذا بعد التسجيل؟</h2><p>يراجع مكتب القبول بياناتك ويتواصل معك لتحديد المستوى والخطوات التالية. إرسال الاستفسار لا يعني قبولاً نهائياً.</p></div></section>
        <Link to={`/apply?program=${program.slug}`} className="button button--gold button--wide">سجّل اهتمامك بهذا البرنامج <ArrowLeft size={18} /></Link>
      </div>
    </div>
  );
}

function ProgramsPage() {
  const { slug } = useParams();
  const programs = usePrograms();
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("الكل");
  const categories = useMemo(() => ["الكل", ...Array.from(new Set(programs.data?.map((p) => p.category) ?? []))], [programs.data]);

  if (programs.isLoading) return <div className="page"><LoadingState /></div>;
  if (programs.error) return <div className="page"><ErrorState retry={programs.refetch} /></div>;
  if (slug) {
    const program = programs.data?.find((p) => p.slug === slug);
    return <div className="page">{program ? <ProgramDetail program={program} /> : <EmptyState title="البرنامج غير موجود" description="ربما تغيّر الرابط أو لم يعد البرنامج منشوراً." action={<BackButton to="/programs" />} />}</div>;
  }

  const filtered = programs.data?.filter((p) => (category === "الكل" || p.category === category) && `${p.title} ${p.subtitle}`.includes(query.trim())) ?? [];
  return (
    <div className="page">
      <PageHeading eyebrow="المسارات الأكاديمية" title="البرامج والمقررات" description="اختر المسار واطّلع على مستواه ومدته قبل تقديم استفسار الالتحاق." />
      <label className="search-field"><Search size={20} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="ابحث عن برنامج أو مسار..." aria-label="البحث في البرامج" />{query && <button onClick={() => setQuery("")} aria-label="مسح البحث"><X size={18} /></button>}</label>
      <div className="filter-scroll" aria-label="تصفية البرامج">{categories.map((c) => <button key={c} className={category === c ? "active" : ""} onClick={() => setCategory(c)}>{c}</button>)}</div>
      <div className="results-count"><strong>{filtered.length}</strong> {filtered.length === 1 ? "برنامج" : "برامج"}</div>
      {filtered.length ? <div className="program-list program-list--grid">{filtered.map((p) => <ProgramRow key={p.id} program={p} />)}</div> : <EmptyState title="لا توجد نتائج مطابقة" description="جرّب كلمة بحث أخرى أو اعرض كل المسارات." action={<button className="button button--outline" onClick={() => { setQuery(""); setCategory("الكل"); }}>مسح عوامل التصفية</button>} />}
    </div>
  );
}

function NewsDetail({ item }: { item: NewsItem }) {
  return (
    <article className="article-page">
      <BackButton to="/news" label="كل الأخبار" />
      <div className="article-marker"><Bell /></div>
      <span className="eyebrow">إعلان عام</span>
      <h1>{item.title}</h1>
      <div className="article-date"><CalendarDays size={17} />{new Intl.DateTimeFormat("ar-YE", { weekday: "long", day: "numeric", month: "long", year: "numeric" }).format(item.publishedAt)}</div>
      <p className="article-lead">{item.summary}</p>
      <p>{item.content}</p>
      <div className="article-note"><ShieldCheck /><span>هذا الإعلان صادر عن كلية ساي التعليمية اليمنية الصينية وموجّه لعموم الجمهور.</span></div>
      <Link to="/apply" className="button button--primary">للاستفسار عن القبول <ArrowLeft size={17} /></Link>
    </article>
  );
}

function NewsPage() {
  const { slug } = useParams();
  const news = useNews();
  if (news.isLoading) return <div className="page"><LoadingState /></div>;
  if (news.error) return <div className="page"><ErrorState retry={news.refetch} /></div>;
  if (slug) {
    const item = news.data?.find((n) => n.slug === slug);
    return <div className="page page--narrow">{item ? <NewsDetail item={item} /> : <EmptyState title="الإعلان غير موجود" description="تحقق من الرابط أو عد إلى قائمة الأخبار." action={<BackButton to="/news" />} />}</div>;
  }
  return (
    <div className="page">
      <PageHeading eyebrow="الأخبار والإعلانات" title="آخر أخبار الكلية" description="إعلانات عامة ومواعيد مهمة للطلاب وأولياء الأمور." />
      {news.data?.length ? <div className="news-list">{news.data.map((n, i) => <NewsRow key={n.id} item={n} featured={i === 0} />)}</div> : <EmptyState title="لا توجد أخبار منشورة" description="ستظهر إعلانات الكلية الجديدة هنا." />}
    </div>
  );
}

function ApplyPage() {
  const [searchParams] = useSearchParams();
  const programs = usePrograms();
  const { isAuthenticated, isLoading } = useAuth();
  const navigate = useNavigate();
  const utils = trpc.useUtils();
  const [studentName, setStudentName] = useState("");
  const [phone, setPhone] = useState("");
  const [programSlug, setProgramSlug] = useState(searchParams.get("program") ?? "");
  const [message, setMessage] = useState("");
  const [submittedReference, setSubmittedReference] = useState("");
  const [formError, setFormError] = useState("");
  const createRequest = trpc.college.createRequest.useMutation({
    onSuccess: (created) => {
      setSubmittedReference(created.reference);
      utils.college.myRequests.invalidate();
      toast.success("تم تسجيل الاستفسار بنجاح");
    },
    onError: () => setFormError("تعذّر إرسال الاستفسار. حاول مرة أخرى بعد قليل."),
  });

  function submit(e: FormEvent) {
    e.preventDefault();
    setFormError("");
    if (createRequest.isPending) return;
    if (!isAuthenticated) { navigate("/login"); return; }
    if (studentName.trim().length < 3 || studentName.trim().length > 255 || phone.trim().length < 7 || phone.trim().length > 40 || !programs.data?.some((p) => p.slug === programSlug)) {
      setFormError("أكمل الاسم ورقم الهاتف واختر البرنامج قبل الإرسال."); return;
    }
    createRequest.mutate({ studentName, phone, programSlug, message: message || undefined });
  }

  if (submittedReference) {
    return <div className="page page--narrow"><div className="success-screen"><div className="success-icon"><Check /></div><span className="eyebrow">تم الاستلام</span><h1>وصل استفسارك إلى مكتب القبول</h1><p>احتفظ بالرقم المرجعي التالي. يمكنك متابعة الحالة من صفحة طلباتي.</p><div className="reference-box"><span>الرقم المرجعي</span><strong dir="ltr">{submittedReference}</strong></div><Link to="/requests" className="button button--primary button--wide">عرض طلباتي <ArrowLeft size={18} /></Link><Link to="/" className="text-link">العودة إلى الرئيسية</Link></div></div>;
  }

  return (
    <div className="page page--narrow">
      <BackButton to={searchParams.get("program") ? `/programs/${searchParams.get("program")}` : "/"} />
      <PageHeading eyebrow="القبول والتسجيل" title="استفسار القبول" description="اترك بياناتك وسيتواصل معك مكتب الاستقبال. الاستفسار لا ينشئ تسجيلاً تلقائياً." />
      {!isLoading && !isAuthenticated && <div className="auth-notice"><LogIn /><div><strong>سجّل الدخول لحفظ طلبك</strong><p>تحتاج إلى حساب لإرسال الاستفسار ومتابعته على أجهزتك.</p></div><Link to="/login" className="text-link">دخول</Link></div>}
      <form className="app-form" onSubmit={submit} noValidate>
        <section><div className="form-section-title"><UserRound /><div><h2>بيانات الطالب</h2><p>اكتب الاسم كما يظهر في الوثائق الرسمية.</p></div></div>
          <label>الاسم الكامل <span>*</span><input value={studentName} onChange={(e) => setStudentName(e.target.value)} placeholder="مثال: محمد أحمد علي" autoComplete="name" maxLength={255} required /></label>
          <label>رقم الهاتف <span>*</span><input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="77XXXXXXX" inputMode="tel" dir="ltr" autoComplete="tel" maxLength={40} required /></label>
        </section>
        <section><div className="form-section-title"><BookOpen /><div><h2>البرنامج المهتم به</h2><p>اختر أقرب مسار، ويمكن للمكتب مساعدتك لاحقاً.</p></div></div>
          {programs.error && <div className="form-error" role="alert">تعذّر تحميل البرامج. <button type="button" className="text-link" onClick={() => programs.refetch()}>إعادة المحاولة</button></div>}
          <label>البرنامج <span>*</span><select value={programSlug} onChange={(e) => setProgramSlug(e.target.value)} required><option value="" disabled>اختر البرنامج</option>{programs.data?.map((p) => <option key={p.slug} value={p.slug}>{p.title}</option>)}</select></label>
          <label>رسالتك <small>(اختياري)</small><textarea value={message} onChange={(e) => setMessage(e.target.value.slice(0, 500))} placeholder="اذكر مستواك الحالي أو أي سؤال لديك..." rows={4} /><span className="char-count">{message.length}/500</span></label>
        </section>
        {formError && <div className="form-error" role="alert">{formError}</div>}
        <div className="form-assurance"><ShieldCheck /><p>لا ترسل وثائق أو بيانات مالية عبر هذا النموذج. تخضع الطلبات للمراجعة من مكتب القبول.</p></div>
        <button className="button button--gold button--wide" disabled={createRequest.isPending || isLoading || programs.isLoading || !!programs.error}>{createRequest.isPending ? <LoaderCircle className="spin" /> : <Send size={18} />}{isAuthenticated ? "إرسال الاستفسار" : "تسجيل الدخول والمتابعة"}</button>
      </form>
    </div>
  );
}

function RequestsPage() {
  const { isAuthenticated, isLoading } = useAuth();
  const requests = trpc.college.myRequests.useQuery(undefined, { enabled: isAuthenticated, retry: false });
  const programs = usePrograms();
  const statusLabels = { received: "تم الاستلام", reviewing: "قيد المراجعة", contacted: "تم التواصل" };

  if (isLoading) return <div className="page"><LoadingState label="جارٍ التحقق من حسابك" /></div>;
  if (!isAuthenticated) return <div className="page"><PageHeading eyebrow="سجل القبول" title="طلباتي" /><EmptyState title="سجّل الدخول لعرض طلباتك" description="تُحفظ أرقامك المرجعية وحالة كل استفسار في مكان واحد." action={<Link to="/login" className="button button--primary"><LogIn size={18} /> تسجيل الدخول</Link>} /></div>;
  return (
    <div className="page">
      <PageHeading eyebrow="سجل القبول" title="طلباتي" description="تابع الاستفسارات التي أرسلتها إلى مكتب القبول." action={<Link to="/apply" className="button button--primary"><Send size={17} /> استفسار جديد</Link>} />
      {requests.isLoading ? <LoadingState /> : requests.error ? <ErrorState retry={requests.refetch} /> : requests.data?.length ? <div className="request-list">{requests.data.map((request) => {
        const program = programs.data?.find((p) => p.slug === request.programSlug);
        return <article className="request-card" key={request.id}><div className="request-card__top"><span className={`status status--${request.status}`}>{statusLabels[request.status]}</span><span dir="ltr">{request.reference}</span></div><h2>{program?.title ?? "استفسار قبول"}</h2><p><UserRound size={16} /> {request.studentName}</p><p><CalendarDays size={16} /> {new Intl.DateTimeFormat("ar-YE", { dateStyle: "medium" }).format(request.createdAt)}</p><div className="request-timeline"><span className="done"><Check /> تم الإرسال</span><i /><span className={request.status !== "received" ? "done" : ""}>المراجعة</span><i /><span className={request.status === "contacted" ? "done" : ""}>التواصل</span></div></article>;
      })}</div> : <EmptyState title="لا توجد طلبات بعد" description="ابدأ باختيار برنامج وإرسال استفسارك الأول إلى مكتب القبول." action={<Link to="/programs" className="button button--primary">استكشف البرامج</Link>} />}
    </div>
  );
}

function VerifyPage() {
  const [code, setCode] = useState("");
  const [submittedCode, setSubmittedCode] = useState("");
  const verification = trpc.college.verifyDocument.useQuery({ code: submittedCode }, { enabled: submittedCode.length >= 6, retry: false });
  function submit(e: FormEvent) { e.preventDefault(); const clean = code.trim().toUpperCase(); if (clean.length >= 6 && clean.length <= 40) setSubmittedCode(clean); }
  return (
    <div className="page page--narrow">
      <BackButton to="/" />
      <PageHeading eyebrow="خدمة التحقق" title="التحقق من الوثائق" description="أدخل الرمز المطبوع على الوثيقة للتحقق من حالتها وبيانات إصدارها." />
      <div className="verify-illustration"><ShieldCheck /><span><FileCheck2 /></span></div>
      <form className="verify-form" onSubmit={submit}>
        <label>رمز التحقق<input dir="ltr" value={code} onChange={(e) => { setCode(e.target.value.toUpperCase()); setSubmittedCode(""); }} placeholder="SAI-DOC-XXXXXX" minLength={6} maxLength={40} required /></label>
        <button className="button button--primary button--wide" disabled={code.trim().length < 6 || verification.isFetching}>{verification.isFetching ? <LoaderCircle className="spin" /> : <Search size={18} />} تحقق الآن</button>
      </form>
      {verification.isFetching && <LoadingState label="جارٍ البحث في سجل الوثائق" />}
      {!verification.isFetching && submittedCode && verification.data && <div className={`verification-result ${verification.data.status === "valid" ? "verification-result--valid" : "verification-result--inactive"}`}><ShieldCheck /><span className="eyebrow">{verification.data.status === "valid" ? "وثيقة صالحة" : "وثيقة غير سارية"}</span><h2>{verification.data.title}</h2><p>{verification.data.holderName}</p><div><span>الحالة</span><strong>{verification.data.status === "valid" ? "صالحة" : verification.data.status === "expired" ? "منتهية" : "ملغاة"}</strong></div><div><span>تاريخ الإصدار</span><strong>{new Intl.DateTimeFormat("ar-YE", { dateStyle: "long" }).format(verification.data.issuedAt)}</strong></div></div>}
      {!verification.isFetching && submittedCode && verification.data === null && <EmptyState title="لم نعثر على وثيقة بهذا الرمز" description="راجع الرمز المطبوع وتأكد من كتابته كاملاً، ثم حاول مجدداً." />}
      {verification.error && <ErrorState retry={verification.refetch} />}
      <div className="privacy-note"><ShieldCheck /><p>لا تعرض هذه الخدمة وثائق الطلاب أو بياناتهم الخاصة للعموم. تظهر نتيجة فقط عند إدخال رمز تحقق صحيح.</p></div>
    </div>
  );
}

function ProfilePage() {
  const { user, isAuthenticated, isLoading, logout } = useAuth();
  if (isLoading) return <div className="page"><LoadingState label="جارٍ تحميل الحساب" /></div>;
  return (
    <div className="page page--narrow">
      <PageHeading eyebrow="الحساب والإعدادات" title={isAuthenticated ? `مرحباً، ${user?.name ?? "بك"}` : "حسابي"} description="إدارة الحساب والوصول إلى خدمات الكلية." />
      {isAuthenticated ? <>
        <section className="profile-card"><div className="profile-avatar">{user?.avatar ? <img src={user.avatar} alt="" /> : <UserRound />}</div><div><h2>{user?.name ?? "مستخدم كلية ساي"}</h2><p>{user?.email ?? "حساب مرتبط بالمنصة"}</p></div><span className="status status--received">حساب نشط</span></section>
        <div className="settings-list"><Link to="/requests"><FileText /><span><strong>طلبات القبول</strong><small>عرض الاستفسارات وحالاتها</small></span><ChevronLeft /></Link><Link to="/verify"><ShieldCheck /><span><strong>التحقق من الوثائق</strong><small>التحقق برمز الوثيقة</small></span><ChevronLeft /></Link><a href="https://www.sai-academic.com/" target="_blank" rel="noreferrer"><ExternalLink /><span><strong>الموقع التعريفي</strong><small>زيارة موقع الكلية</small></span><ChevronLeft /></a></div>
        <button className="button button--outline button--wide logout-button" onClick={logout}><LogOut size={18} /> تسجيل الخروج</button>
      </> : <div className="signed-out"><div className="signed-out__icon"><UserRound /></div><h2>حساب واحد لكل خدماتك</h2><p>سجّل الدخول لإرسال استفسارات القبول وحفظها ومتابعة حالتها من أي جهاز.</p><Link to="/login" className="button button--gold button--wide"><LogIn size={18} /> تسجيل الدخول</Link><Link to="/" className="text-link">متابعة التصفح كزائر</Link></div>}
      <div className="app-info"><span>كلية ساي التعليمية اليمنية الصينية</span><small>نسخة التطبيق التجريبية · 2026–2027</small></div>
    </div>
  );
}

export default function App() {
  return (
    <AppShell>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/programs" element={<ProgramsPage />} />
        <Route path="/programs/:slug" element={<ProgramsPage />} />
        <Route path="/news" element={<NewsPage />} />
        <Route path="/news/:slug" element={<NewsPage />} />
        <Route path="/apply" element={<ApplyPage />} />
        <Route path="/requests" element={<RequestsPage />} />
        <Route path="/verify" element={<VerifyPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route path="/login" element={<Login />} />
        <Route path="/404" element={<NotFound />} />
        <Route path="*" element={<Navigate to="/404" replace />} />
      </Routes>
    </AppShell>
  );
}
