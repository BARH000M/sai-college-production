import { Link, useLocation } from "react-router-dom";
import Navbar from "@/components/feature/Navbar";
import Footer from "@/components/feature/Footer";

/**
 * Catch-all route. It offers a way back into the marketing site and the portal
 * instead of leaving the visitor on a dead end.
 */
export default function NotFound() {
  const location = useLocation();

  return (
    <div className="min-h-screen bg-background-50 flex flex-col">
      <Navbar />
      <main className="flex-1 flex items-center justify-center px-4 md:px-10 pt-32 pb-16 md:pt-40 md:pb-24">
        <div className="w-full max-w-2xl rounded-lg border border-background-200 bg-background-50 p-6 md:p-10 text-center">
          <span className="inline-flex items-center gap-2 rounded-full bg-accent-100 px-3 py-1 text-xs font-label text-accent-900">
            <i className="ri-compass-3-line"></i>
            404
          </span>
          <h1 className="mt-5 font-heading text-2xl md:text-4xl text-foreground-950">
            لم نجد هذه الصفحة
          </h1>
          <p className="mt-3 text-sm md:text-base text-foreground-600 leading-relaxed">
            قد يكون الرابط قديماً أو مكتوباً بشكل غير صحيح. يمكنك العودة إلى الصفحة الرئيسية أو
            الانتقال مباشرة إلى بوابة الكلية.
          </p>
          <p className="mt-4 text-xs text-foreground-500 break-all" dir="ltr">{location.pathname}</p>
          <div className="mt-7 flex flex-col sm:flex-row justify-center gap-3">
            <Link to="/" className="whitespace-nowrap cursor-pointer rounded-md bg-primary-500 hover:bg-primary-600 px-5 py-2.5 text-sm text-background-50">
              الصفحة الرئيسية
            </Link>
            <Link to="/portal/login" className="whitespace-nowrap cursor-pointer rounded-md border border-background-300 px-5 py-2.5 text-sm text-foreground-800 hover:bg-background-100">
              بوابة الكلية
            </Link>
            <Link to="/application-status" className="whitespace-nowrap cursor-pointer rounded-md border border-background-300 px-5 py-2.5 text-sm text-foreground-800 hover:bg-background-100">
              حالة طلب القبول
            </Link>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  );
}