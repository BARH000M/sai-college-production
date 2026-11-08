import { getDb } from "../api/queries/connection";
import { news, programs } from "./schema";

const programRows = [
  {
    slug: "chinese-hsk-comprehensive",
    title: "برامج اللغة الصينية (HSK 1–6)",
    category: "اللغة الصينية",
    subtitle: "مسار متدرج من المستوى المبتدئ حتى الاحتراف",
    description: "دورات شاملة لتعليم اللغة الصينية لجميع المستويات، تبدأ من النطق والبنية الأساسية للجملة وتصل إلى القراءة والكتابة المتقدمة والمحادثة الأكاديمية. يُختبر المتدرب في نهاية كل مستوى للانتقال إلى المستوى الذي يليه.",
    level: "HSK 1 — HSK 6",
    duration: "١٢ أسبوعاً لكل مستوى",
    schedule: "٣ حصص أسبوعياً",
    imageUrl: "/images/hsk.webp",
    sortOrder: 1,
  },
  {
    slug: "hsk-exam-preparation",
    title: "مسار التحضير لاختبار HSK",
    category: "اختبارات معتمدة",
    subtitle: "تدريب مركّز على شكل الاختبار الرسمي وتوقيته",
    description: "مسار مخصص للطلاب الذين أنهوا المستوى ويستعدون للاختبار الرسمي. يعتمد على نماذج سابقة، وإدارة الوقت داخل قاعة الاختبار، وتحليل الأخطاء المتكررة قبل التقديم.",
    level: "HSK 1 — HSK 4",
    duration: "٨ أسابيع",
    schedule: "حصتان أسبوعياً + اختبار محاكاة",
    imageUrl: "/images/exam.webp",
    sortOrder: 2,
  },
  {
    slug: "chinese-adult-diploma",
    title: "دبلوم اللغة الصينية للبالغين",
    category: "دبلوم",
    subtitle: "مسار أكاديمي ممتد بشهادة إتمام",
    description: "يجمع الدبلوم اللغة والثقافة ومهارات الترجمة المبدئية في مسار واحد ممتد. مناسب لمن يريد بناء قدرة لغوية راسخة للدراسة أو العمل.",
    level: "من الصفر حتى HSK 3",
    duration: "عام دراسي كامل",
    schedule: "٣ حصص أسبوعياً",
    imageUrl: "/images/diploma.webp",
    sortOrder: 3,
  },
  {
    slug: "yct-children",
    title: "برنامج YCT للأطفال",
    category: "الأطفال",
    subtitle: "الصينية للأطفال بأسلوب تفاعلي وآمن",
    description: "مسار مصمم للأطفال يقوم على اللعب والحركة والأنشطة البصرية بدل الحفظ المباشر. يبني الطفل مفرداته عبر القصص والأغاني والرسم.",
    level: "YCT 1 — YCT 4",
    duration: "١٠ أسابيع لكل مستوى",
    schedule: "حصتان أسبوعياً",
    imageUrl: "/images/children.webp",
    sortOrder: 4,
  },
  {
    slug: "business-chinese",
    title: "الصينية للأعمال",
    category: "لغة متخصصة",
    subtitle: "لغة التجارة والتفاوض والمراسلات",
    description: "برنامج موجّه لمن يتعامل مع شركات أو موردين صينيين. يغطي مفردات العقود والتفاوض والمراسلات التجارية، مع تدريب على صياغة بريد عمل واضح ومهذب بالصينية.",
    level: "HSK 2 وما فوق",
    duration: "١٠ أسابيع",
    schedule: "حصتان أسبوعياً",
    imageUrl: "/images/business.webp",
    sortOrder: 5,
  },
  {
    slug: "study-in-china",
    title: "الابتعاث والمنح الدراسية",
    category: "خدمات أكاديمية",
    subtitle: "إرشاد للدراسة في الجامعات الصينية",
    description: "خدمة إرشادية ترافق الطالب في اختيار الجامعة والتخصص وتجهيز ملف التقديم وترجمة المستندات. لا تضمن الخدمة قبولاً أو منحة، والقرار النهائي يعود للجامعة المستقبلة.",
    level: "إرشاد فردي",
    duration: "حسب المسار",
    schedule: "جلسات بالموعد",
    imageUrl: "/images/scholarships.webp",
    sortOrder: 6,
  },
];

const publishedAt = new Date("2026-10-24T08:00:00Z");
const newsRows = [
  {
    slug: "registration-2026-2027",
    title: "بدء التسجيل للعام الدراسي 2026-2027",
    summary: "يفتح مكتب القبول والتسجيل باب استقبال الطلبات للعام الدراسي الجديد.",
    content: "يبدأ التسجيل للعام الدراسي الجديد اعتبارًا من الأحد القادم في مبنى القبول والتسجيل من الساعة الثامنة صباحًا حتى الثانية ظهرًا. المستندات المطلوبة: شهادة الميلاد، صورة الهوية، آخر كشف درجات.",
    publishedAt,
  },
  {
    slug: "midterm-schedule",
    title: "جدول اختبارات منتصف الفصل",
    summary: "راجع مواعيد الاختبارات والقاعات قبل بداية فترة التقييم.",
    content: "تم نشر جدول اختبارات منتصف الفصل الدراسي على لوحات الإعلانات وفي بوابة الطالب. يرجى مراجعة الجدول والتأكد من القاعات.",
    publishedAt,
  },
  {
    slug: "library-instructions",
    title: "تعليمات المكتبة",
    summary: "تذكير للطلاب بمواعيد إعادة الكتب المستعارة.",
    content: "يُرجى من جميع الطلاب إعادة الكتب المستعارة قبل نهاية الشهر لتجنب غرامات التأخير.",
    publishedAt,
  },
];

async function seed() {
  const db = getDb();
  console.log("Seeding college content...");
  for (const row of programRows) {
    await db.insert(programs).values(row).onDuplicateKeyUpdate({ set: row });
  }
  for (const row of newsRows) {
    await db.insert(news).values(row).onDuplicateKeyUpdate({ set: row });
  }
  console.log("Done.");
  process.exit(0);
}

seed().catch((error) => {
  console.error(error);
  process.exit(1);
});
