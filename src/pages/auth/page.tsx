import { useState, type FormEvent } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import saiLogo from "@/portal/assets/saiLogo";
import { signIn, signUpAccount } from "@/portal/lib/auth";

type Lang = "ar" | "en";
type Mode = "signin" | "signup";
type FieldKey = "fullName" | "email" | "password" | "confirm";

type Copy = {
  dir: "rtl" | "ltr";
  brand: string;
  brandSub: string;
  heroTitle: string;
  heroText: string;
  heroPoints: string[];
  back: string;
  eyebrow: string;
  signInTitle: string;
  signInText: string;
  signUpTitle: string;
  signUpText: string;
  tabSignIn: string;
  tabSignUp: string;
  fullName: string;
  fullNameHint: string;
  email: string;
  language: string;
  languageHint: string;
  password: string;
  passwordHint: string;
  confirm: string;
  submitSignIn: string;
  submitSignUp: string;
  submitting: string;
  noAccount: string;
  haveAccount: string;
  required: string;
  badName: string;
  badEmail: string;
  badPassword: string;
  badConfirm: string;
  genericError: string;
  confirmTitle: string;
  confirmText: string;
  confirmBack: string;
  show: string;
  hide: string;
  footer: string;
  secure: string;
  arabic: string;
  english: string;
};

const copy: Record<Lang, Copy> = {
  ar: {
    dir: "rtl",
    brand: "كلية ساي التعليمية اليمنية الصينية",
    brandSub: "SAI Yemeni–Chinese College · Sana'a",
    heroTitle: "بوابة واحدة لكل حياتك الأكاديمية",
    heroText:
      "سجّل دخولك لمتابعة الصفوف والحضور والنتائج، أو أنشئ حسابك الجديد لتبدأ رحلتك مع كلية ساي.",
    heroPoints: [
      "حسابك يُربط تلقائياً بملفك الأكاديمي بعد اعتماد الإدارة",
      "واجهة كاملة بالعربية والإنجليزية",
      "بياناتك محمية بصلاحيات دقيقة لكل دور",
    ],
    back: "العودة إلى الموقع",
    eyebrow: "بوابة الكلية",
    signInTitle: "تسجيل الدخول",
    signInText: "أدخل بريدك الإلكتروني وكلمة المرور للوصول إلى حسابك.",
    signUpTitle: "إنشاء حساب جديد",
    signUpText: "أنشئ حسابك بالاسم والبريد واللغة المفضلة، ثم تنتظر اعتماد دورك من الإدارة.",
    tabSignIn: "دخول",
    tabSignUp: "حساب جديد",
    fullName: "الاسم الكامل",
    fullNameHint: "كما تحب أن يظهر في ملفك الشخصي.",
    email: "البريد الإلكتروني",
    language: "اللغة المفضلة",
    languageHint: "تُحفظ مع ملفك وتُستخدم في التنبيهات لاحقاً.",
    password: "كلمة المرور",
    passwordHint: "8 أحرف على الأقل.",
    confirm: "تأكيد كلمة المرور",
    submitSignIn: "دخول إلى البوابة",
    submitSignUp: "إنشاء الحساب",
    submitting: "جارٍ المعالجة...",
    noAccount: "ليس لديك حساب؟",
    haveAccount: "لديك حساب بالفعل؟",
    required: "هذا الحقل مطلوب.",
    badName: "اكتب الاسم الكامل (حرفان على الأقل).",
    badEmail: "اكتب بريداً إلكترونياً صحيحاً.",
    badPassword: "كلمة المرور يجب أن تكون 8 أحرف أو أكثر.",
    badConfirm: "كلمتا المرور غير متطابقتين.",
    genericError: "تعذر إكمال الطلب. حاول مرة أخرى.",
    confirmTitle: "تحقق من بريدك الإلكتروني",
    confirmText:
      "أرسلنا رابط تأكيد إلى بريدك. بعد التأكيد سجّل الدخول، وسيظهر حسابك في قائمة انتظار الدور حتى تعتمده الإدارة.",
    confirmBack: "العودة لتسجيل الدخول",
    show: "إظهار كلمة المرور",
    hide: "إخفاء كلمة المرور",
    footer: "كلية ساي التعليمية اليمنية الصينية · صنعاء",
    secure: "اتصال آمن عبر بوابة الكلية",
    arabic: "العربية",
    english: "English",
  },
  en: {
    dir: "ltr",
    brand: "SAI Yemeni–Chinese College",
    brandSub: "كلية ساي التعليمية اليمنية الصينية",
    heroTitle: "One doorway to your whole academic life",
    heroText:
      "Sign in to follow your classes, attendance and results, or create a new account to begin your journey at SAI College.",
    heroPoints: [
      "Your account is linked to your academic record once staff approve it",
      "Full interface in English and Arabic",
      "Your data is protected by role-based access rules",
    ],
    back: "Back to website",
    eyebrow: "College portal",
    signInTitle: "Sign in",
    signInText: "Enter your email address and password to reach your account.",
    signUpTitle: "Create an account",
    signUpText: "Register your name, email and preferred language, then wait for your role to be granted.",
    tabSignIn: "Sign in",
    tabSignUp: "Sign up",
    fullName: "Full name",
    fullNameHint: "This is how your name appears on your profile.",
    email: "Email address",
    language: "Preferred language",
    languageHint: "Saved with your profile and used for notifications.",
    password: "Password",
    passwordHint: "At least 8 characters.",
    confirm: "Confirm password",
    submitSignIn: "Sign in to portal",
    submitSignUp: "Create my account",
    submitting: "Working...",
    noAccount: "No account yet?",
    haveAccount: "Already have an account?",
    required: "This field is required.",
    badName: "Enter your full name (at least 2 characters).",
    badEmail: "Enter a valid email address.",
    badPassword: "Password must be at least 8 characters.",
    badConfirm: "The two passwords do not match.",
    genericError: "We could not complete the request. Please try again.",
    confirmTitle: "Check your email",
    confirmText:
      "We sent a confirmation link to your inbox. After confirming, sign in — your account will wait for a role until staff approve it.",
    confirmBack: "Back to sign in",
    show: "Show password",
    hide: "Hide password",
    footer: "SAI Yemeni–Chinese College · Sana'a",
    secure: "Secure connection to the college portal",
    arabic: "العربية",
    english: "English",
  },
};

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function friendlyAuthError(message: string, lang: Lang): string {
  const text = message.toLowerCase();
  const ar = lang === "ar";
  if (text.includes("invalid login credentials")) {
    return ar ? "البريد الإلكتروني أو كلمة المرور غير صحيحة." : "The email address or password is incorrect.";
  }
  if (text.includes("email not confirmed")) {
    return ar ? "لم يتم تأكيد بريدك الإلكتروني بعد. افتح رابط التأكيد في بريدك أولاً." : "Your email is not confirmed yet. Open the confirmation link in your inbox first.";
  }
  if (text.includes("already registered") || text.includes("already been registered") || text.includes("user already exists")) {
    return ar ? "هذا البريد مسجّل بالفعل. سجّل الدخول بدلاً من إنشاء حساب جديد." : "This email is already registered. Sign in instead of creating a new account.";
  }
  if (text.includes("password") && (text.includes("6") || text.includes("8") || text.includes("weak"))) {
    return ar ? "كلمة المرور قصيرة أو ضعيفة. استخدم 8 أحرف على الأقل." : "That password is too short or too weak. Use at least 8 characters.";
  }
  if (text.includes("rate limit") || text.includes("too many")) {
    return ar ? "محاولات كثيرة خلال وقت قصير. انتظر دقيقة ثم حاول مرة أخرى." : "Too many attempts in a short time. Wait a minute and try again.";
  }
  if (text.includes("fetch") || text.includes("network") || text.includes("failed to fetch")) {
    return ar ? "تعذر الاتصال بالخادم. تحقق من الإنترنت ثم حاول مرة أخرى." : "We could not reach the server. Check your connection and try again.";
  }
  return message;
}

function PasswordField({
  id, label, hint, value, onChange, error, copy: t, autoComplete,
}: {
  id: string; label: string; hint: string; value: string; onChange: (value: string) => void;
  error?: string; copy: Copy; autoComplete: string;
}) {
  const [visible, setVisible] = useState(false);
  return (
    <div>
      <label htmlFor={id} className="block text-xs font-semibold text-foreground-800">{label}</label>
      <div className="relative mt-1">
        <input
          id={id}
          type={visible ? "text" : "password"}
          value={value}
          autoComplete={autoComplete}
          onChange={(event) => onChange(event.target.value)}
          aria-invalid={!!error}
          aria-describedby={error ? `${id}-error` : `${id}-hint`}
          className={`w-full rounded-md border bg-background-50 px-3 py-2.5 pe-11 text-sm text-foreground-950 outline-none transition focus:ring-2 focus:ring-primary-300 ${error ? "border-primary-500" : "border-background-300"}`}
        />
        <button
          type="button"
          onClick={() => setVisible((current) => !current)}
          aria-label={visible ? t.hide : t.show}
          className="absolute inset-y-0 end-0 flex w-10 items-center justify-center text-foreground-600 hover:text-primary-700"
        >
          <i className={visible ? "ri-eye-off-line" : "ri-eye-line"} aria-hidden="true"></i>
        </button>
      </div>
      {error
        ? <p id={`${id}-error`} className="mt-1 text-xs text-primary-700">{error}</p>
        : <p id={`${id}-hint`} className="mt-1 text-xs text-foreground-600">{hint}</p>}
    </div>
  );
}

export default function AuthPage() {
  const [params] = useSearchParams();
  const [lang, setLang] = useState<Lang>("ar");
  const [mode, setMode] = useState<Mode>(() => (params.get("mode") === "signup" ? "signup" : "signin"));
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [locale, setLocale] = useState<Lang>("ar");
  const [errors, setErrors] = useState<Partial<Record<FieldKey, string>>>({});
  const [formError, setFormError] = useState("");
  const [busy, setBusy] = useState(false);
  const [confirmationSent, setConfirmationSent] = useState(false);
  const navigate = useNavigate();
  const t = copy[lang];

  function nextPath(): string {
    const requested = params.get("next") ?? "";
    return requested.startsWith("/") && !requested.startsWith("//") ? requested : "/portal/dashboard";
  }

  function switchMode(next: Mode) {
    setMode(next);
    setErrors({});
    setFormError("");
    setConfirmationSent(false);
    setPassword("");
    setConfirm("");
  }

  function validate(): boolean {
    const next: Partial<Record<FieldKey, string>> = {};
    if (mode === "signup" && fullName.trim().length < 2) next.fullName = t.badName;
    if (!email.trim()) next.email = t.required;
    else if (!emailPattern.test(email.trim())) next.email = t.badEmail;
    if (!password) next.password = t.required;
    else if (password.length < 8) next.password = t.badPassword;
    if (mode === "signup") {
      if (!confirm) next.confirm = t.required;
      else if (confirm !== password) next.confirm = t.badConfirm;
    }
    setErrors(next);
    return !Object.keys(next).length;
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setFormError("");
    if (!validate()) return;
    setBusy(true);
    try {
      if (mode === "signup") {
        const result = await signUpAccount({ fullName, email, password, locale });
        if (result.state.authError) {
          setFormError(friendlyAuthError(result.state.authError, lang));
          return;
        }
        if (result.confirmationRequired) {
          setConfirmationSent(true);
          return;
        }
        navigate(nextPath(), { replace: true });
        return;
      }
      const state = await signIn(email.trim(), password);
      if (state.status === "signed-in") {
        navigate(nextPath(), { replace: true });
        return;
      }
      setFormError(friendlyAuthError(state.authError ?? t.genericError, lang));
    } catch {
      setFormError(t.genericError);
    } finally {
      setBusy(false);
    }
  }

  const fieldClass = (invalid: boolean) =>
    `mt-1 w-full rounded-md border bg-background-50 px-3 py-2.5 text-sm text-foreground-950 outline-none transition focus:ring-2 focus:ring-primary-300 ${invalid ? "border-primary-500" : "border-background-300"}`;

  return (
    <div dir={t.dir} lang={lang} className="min-h-screen bg-background-50 text-foreground-950">
      <div className="grid min-h-screen lg:grid-cols-2">
        <aside className="relative hidden overflow-hidden bg-foreground-950 lg:block">
          <img
            src="https://readdy.ai/api/search-image?query=Elegant%20abstract%20academic%20architecture%20with%20deep%20maroon%20arches%20warm%20cream%20stone%20and%20soft%20gold%20light%20rays%2C%20minimal%20editorial%20illustration%2C%20calm%20scholarly%20atmosphere%2C%20no%20people%2C%20no%20text&width=1200&height=1600&seq=sai-auth-2026&orientation=portrait"
            alt=""
            className="absolute inset-0 h-full w-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-foreground-950/90 via-foreground-950/60 to-foreground-950/30"></div>
          <div className="relative z-10 flex h-full w-full flex-col justify-between p-12 text-background-50">
            <Link to="/" className="flex items-center gap-3">
              <span className="flex h-14 w-14 items-center justify-center rounded-lg bg-background-50 p-1.5">
                <img src={saiLogo} alt="SAI College" className="h-full w-full object-contain" />
              </span>
              <span>
                <strong className="block font-heading text-base">{t.brand}</strong>
                <small className="block text-xs text-background-200">{t.brandSub}</small>
              </span>
            </Link>
            <div className="max-w-md">
              <h2 className="font-heading text-3xl leading-snug">{t.heroTitle}</h2>
              <p className="mt-4 text-sm leading-relaxed text-background-200">{t.heroText}</p>
              <ul className="mt-8 space-y-3">
                {t.heroPoints.map((point) => (
                  <li key={point} className="flex items-start gap-3 text-sm text-background-100">
                    <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-accent-500 text-foreground-950">
                      <i className="ri-check-line text-xs" aria-hidden="true"></i>
                    </span>
                    {point}
                  </li>
                ))}
              </ul>
            </div>
            <p className="text-xs text-background-300">{t.footer}</p>
          </div>
        </aside>

        <main className="flex flex-col">
          <div className="flex items-center justify-between gap-3 px-5 pt-5 md:px-10">
            <Link to="/" className="inline-flex items-center gap-2 text-sm text-foreground-700 hover:text-primary-700">
              <i className="ri-arrow-left-line rtl:rotate-180" aria-hidden="true"></i>
              {t.back}
            </Link>
            <div className="flex items-center gap-1 rounded-full border border-background-300 bg-background-100 p-1">
              <button
                type="button"
                onClick={() => setLang("ar")}
                className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs ${lang === "ar" ? "bg-primary-500 text-background-50" : "text-foreground-700"}`}
              >
                العربية
              </button>
              <button
                type="button"
                onClick={() => setLang("en")}
                className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs ${lang === "en" ? "bg-primary-500 text-background-50" : "text-foreground-700"}`}
              >
                English
              </button>
            </div>
          </div>

          <div className="flex flex-1 items-center justify-center px-5 py-10 md:px-10">
            <div className="w-full max-w-md">
              <div className="mb-6 flex items-center gap-3 lg:hidden">
                <span className="flex h-12 w-12 items-center justify-center rounded-lg border border-background-200 bg-background-50 p-1.5">
                  <img src={saiLogo} alt="SAI College" className="h-full w-full object-contain" />
                </span>
                <span>
                  <strong className="block font-heading text-sm">{t.brand}</strong>
                  <small className="block text-xs text-foreground-600">{t.brandSub}</small>
                </span>
              </div>

              <div className="rounded-lg border border-background-200 bg-background-50 p-6 md:p-8">
                {confirmationSent ? (
                  <div className="text-center">
                    <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-secondary-100 text-secondary-900">
                      <i className="ri-mail-check-line text-2xl" aria-hidden="true"></i>
                    </span>
                    <h1 className="mt-4 font-heading text-xl">{t.confirmTitle}</h1>
                    <p className="mt-3 text-sm leading-relaxed text-foreground-700">{t.confirmText}</p>
                    <button
                      type="button"
                      onClick={() => switchMode("signin")}
                      className="mt-6 w-full whitespace-nowrap rounded-md bg-primary-500 px-4 py-3 text-sm font-label text-background-50 hover:bg-primary-600"
                    >
                      {t.confirmBack}
                    </button>
                  </div>
                ) : (
                  <>
                    <p className="text-xs font-label uppercase tracking-wider text-primary-700">{t.eyebrow}</p>
                    <h1 className="mt-2 font-heading text-2xl">{mode === "signin" ? t.signInTitle : t.signUpTitle}</h1>
                    <p className="mt-2 text-sm leading-relaxed text-foreground-600">
                      {mode === "signin" ? t.signInText : t.signUpText}
                    </p>

                    <div className="mt-6 flex rounded-full border border-background-300 bg-background-100 p-1" role="tablist">
                      <button
                        type="button"
                        role="tab"
                        aria-selected={mode === "signin"}
                        onClick={() => switchMode("signin")}
                        className={`flex-1 whitespace-nowrap rounded-full px-4 py-2 text-sm ${mode === "signin" ? "bg-primary-500 text-background-50" : "text-foreground-700"}`}
                      >
                        {t.tabSignIn}
                      </button>
                      <button
                        type="button"
                        role="tab"
                        aria-selected={mode === "signup"}
                        onClick={() => switchMode("signup")}
                        className={`flex-1 whitespace-nowrap rounded-full px-4 py-2 text-sm ${mode === "signup" ? "bg-primary-500 text-background-50" : "text-foreground-700"}`}
                      >
                        {t.tabSignUp}
                      </button>
                    </div>

                    <form onSubmit={submit} noValidate className="mt-6 space-y-4">
                      {mode === "signup" && (
                        <div>
                          <label htmlFor="auth-name" className="block text-xs font-semibold text-foreground-800">{t.fullName}</label>
                          <input
                            id="auth-name"
                            value={fullName}
                            autoComplete="name"
                            onChange={(event) => { setFullName(event.target.value); setErrors((current) => ({ ...current, fullName: undefined })); }}
                            aria-invalid={!!errors.fullName}
                            aria-describedby={errors.fullName ? "auth-name-error" : "auth-name-hint"}
                            className={fieldClass(!!errors.fullName)}
                          />
                          {errors.fullName
                            ? <p id="auth-name-error" className="mt-1 text-xs text-primary-700">{errors.fullName}</p>
                            : <p id="auth-name-hint" className="mt-1 text-xs text-foreground-600">{t.fullNameHint}</p>}
                        </div>
                      )}

                      <div>
                        <label htmlFor="auth-email" className="block text-xs font-semibold text-foreground-800">{t.email}</label>
                        <input
                          id="auth-email"
                          type="email"
                          dir="ltr"
                          value={email}
                          autoComplete="email"
                          onChange={(event) => { setEmail(event.target.value); setErrors((current) => ({ ...current, email: undefined })); }}
                          aria-invalid={!!errors.email}
                          aria-describedby={errors.email ? "auth-email-error" : undefined}
                          className={fieldClass(!!errors.email)}
                        />
                        {errors.email && <p id="auth-email-error" className="mt-1 text-xs text-primary-700">{errors.email}</p>}
                      </div>

                      {mode === "signup" && (
                        <div>
                          <label htmlFor="auth-locale" className="block text-xs font-semibold text-foreground-800">{t.language}</label>
                          <select
                            id="auth-locale"
                            value={locale}
                            onChange={(event) => setLocale(event.target.value === "en" ? "en" : "ar")}
                            className="mt-1 w-full cursor-pointer rounded-md border border-background-300 bg-background-50 px-3 py-2.5 text-sm text-foreground-950 outline-none focus:ring-2 focus:ring-primary-300"
                          >
                            <option value="ar">{t.arabic}</option>
                            <option value="en">{t.english}</option>
                          </select>
                          <p className="mt-1 text-xs text-foreground-600">{t.languageHint}</p>
                        </div>
                      )}

                      <PasswordField
                        id="auth-password"
                        label={t.password}
                        hint={t.passwordHint}
                        value={password}
                        onChange={(value) => { setPassword(value); setErrors((current) => ({ ...current, password: undefined })); }}
                        error={errors.password}
                        copy={t}
                        autoComplete={mode === "signin" ? "current-password" : "new-password"}
                      />

                      {mode === "signup" && (
                        <PasswordField
                          id="auth-confirm"
                          label={t.confirm}
                          hint={t.passwordHint}
                          value={confirm}
                          onChange={(value) => { setConfirm(value); setErrors((current) => ({ ...current, confirm: undefined })); }}
                          error={errors.confirm}
                          copy={t}
                          autoComplete="new-password"
                        />
                      )}

                      {formError && (
                        <p className="rounded-md border border-primary-200 bg-primary-50 px-3 py-2.5 text-xs leading-relaxed text-primary-800" role="alert">
                          {formError}
                        </p>
                      )}

                      <button
                        type="submit"
                        disabled={busy}
                        className="w-full whitespace-nowrap rounded-md bg-primary-500 px-4 py-3 text-sm font-label text-background-50 transition hover:bg-primary-600 disabled:opacity-60"
                      >
                        {busy ? t.submitting : mode === "signin" ? t.submitSignIn : t.submitSignUp}
                      </button>

                      <p className="text-center text-xs text-foreground-600">
                        {mode === "signin" ? t.noAccount : t.haveAccount}{" "}
                        <button
                          type="button"
                          onClick={() => switchMode(mode === "signin" ? "signup" : "signin")}
                          className="whitespace-nowrap font-semibold text-primary-700 underline"
                        >
                          {mode === "signin" ? t.tabSignUp : t.tabSignIn}
                        </button>
                      </p>
                    </form>
                  </>
                )}
              </div>

              <p className="mt-5 flex items-center justify-center gap-2 text-xs text-foreground-600">
                <i className="ri-shield-check-line" aria-hidden="true"></i>
                {t.secure}
              </p>
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}