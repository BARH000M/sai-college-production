export const academicBranchOptions = [
  { id: "main", name: "Main Campus - Sana'a" },
  { id: "hadda", name: "فرع حدة" },
  { id: "taiz", name: "فرع تعز" },
];

export const academicClassOptions = [
  { id: "c1", name: "المستوى الثالث - أ", program: "اللغة الصينية التطبيقية", teacher: "أ. لي مينغ", students: 24 },
  { id: "c2", name: "المستوى الثاني - ب", program: "اللغة الصينية التطبيقية", teacher: "أ. سارة الحداد", students: 21 },
  { id: "c3", name: "المستوى الأول - ج", program: "اللغة الصينية للمبتدئين", teacher: "أ. محمد الصبري", students: 18 },
];

export const weekDays = [
  { id: "sun", label: "الأحد", short: "الأحد" },
  { id: "mon", label: "الاثنين", short: "الاثنين" },
  { id: "tue", label: "الثلاثاء", short: "الثلاثاء" },
  { id: "wed", label: "الأربعاء", short: "الأربعاء" },
  { id: "thu", label: "الخميس", short: "الخميس" },
  { id: "sat", label: "السبت", short: "السبت" },
];

export const periodSlots = [
  { id: 1, label: "الحصة الأولى", time: "08:00 - 08:45" },
  { id: 2, label: "الحصة الثانية", time: "08:55 - 09:40" },
  { id: 3, label: "الحصة الثالثة", time: "10:00 - 10:45" },
  { id: 4, label: "الحصة الرابعة", time: "10:55 - 11:40" },
  { id: 5, label: "الحصة الخامسة", time: "12:15 - 13:00" },
  { id: 6, label: "الحصة السادسة", time: "13:10 - 13:55" },
];

export const weeklyLessons = [
  { id: "w1", classId: "c1", day: "sun", period: 1, subject: "اللغة الصينية الشاملة", teacher: "أ. لي مينغ", room: "A-201", kind: "core" },
  { id: "w2", classId: "c1", day: "sun", period: 2, subject: "القراءة والكتابة", teacher: "أ. لي مينغ", room: "A-201", kind: "core" },
  { id: "w3", classId: "c1", day: "sun", period: 3, subject: "النغمات والنطق", teacher: "أ. تشاو يان", room: "مختبر اللغة", kind: "lab" },
  { id: "w4", classId: "c1", day: "sun", period: 5, subject: "الرياضيات", teacher: "أ. محمد الصبري", room: "B-101", kind: "general" },
  { id: "w5", classId: "c1", day: "mon", period: 1, subject: "المحادثة والاستماع", teacher: "أ. تشاو يان", room: "مختبر اللغة", kind: "lab" },
  { id: "w6", classId: "c1", day: "mon", period: 2, subject: "اللغة الصينية الشاملة", teacher: "أ. لي مينغ", room: "A-201", kind: "core" },
  { id: "w7", classId: "c1", day: "mon", period: 4, subject: "اللغة الإنجليزية", teacher: "أ. هدى المقطري", room: "A-202", kind: "general" },
  { id: "w8", classId: "c1", day: "mon", period: 6, subject: "التربية الإسلامية", teacher: "أ. سارة الحداد", room: "A-201", kind: "general" },
  { id: "w9", classId: "c1", day: "tue", period: 1, subject: "اللغة الصينية الشاملة", teacher: "أ. لي مينغ", room: "A-201", kind: "core" },
  { id: "w10", classId: "c1", day: "tue", period: 3, subject: "القراءة والكتابة", teacher: "أ. لي مينغ", room: "A-201", kind: "core" },
  { id: "w11", classId: "c1", day: "tue", period: 4, subject: "الثقافة الصينية", teacher: "أ. تشاو يان", room: "القاعة الذكية", kind: "culture" },
  { id: "w12", classId: "c1", day: "wed", period: 2, subject: "المحادثة والاستماع", teacher: "أ. تشاو يان", room: "مختبر اللغة", kind: "lab" },
  { id: "w13", classId: "c1", day: "wed", period: 3, subject: "اللغة الصينية الشاملة", teacher: "أ. لي مينغ", room: "A-201", kind: "core" },
  { id: "w14", classId: "c1", day: "wed", period: 5, subject: "الرياضيات", teacher: "أ. محمد الصبري", room: "B-101", kind: "general" },
  { id: "w15", classId: "c1", day: "thu", period: 1, subject: "القراءة والكتابة", teacher: "أ. لي مينغ", room: "A-201", kind: "core" },
  { id: "w16", classId: "c1", day: "thu", period: 2, subject: "المحادثة والاستماع", teacher: "أ. تشاو يان", room: "مختبر اللغة", kind: "lab" },
  { id: "w17", classId: "c1", day: "thu", period: 4, subject: "اللغة الإنجليزية", teacher: "أ. هدى المقطري", room: "A-202", kind: "general" },
  { id: "w18", classId: "c1", day: "sat", period: 2, subject: "مراجعة أسبوعية", teacher: "أ. لي مينغ", room: "A-201", kind: "review" },
  { id: "w19", classId: "c2", day: "sun", period: 2, subject: "اللغة الصينية الشاملة", teacher: "أ. سارة الحداد", room: "A-105", kind: "core" },
  { id: "w20", classId: "c2", day: "sun", period: 3, subject: "المحادثة والاستماع", teacher: "أ. تشاو يان", room: "مختبر اللغة", kind: "lab" },
  { id: "w21", classId: "c2", day: "mon", period: 1, subject: "القراءة والكتابة", teacher: "أ. سارة الحداد", room: "A-105", kind: "core" },
  { id: "w22", classId: "c2", day: "tue", period: 5, subject: "النغمات والنطق", teacher: "أ. تشاو يان", room: "مختبر اللغة", kind: "lab" },
  { id: "w23", classId: "c2", day: "wed", period: 1, subject: "اللغة الصينية الشاملة", teacher: "أ. سارة الحداد", room: "A-105", kind: "core" },
  { id: "w24", classId: "c2", day: "thu", period: 3, subject: "الثقافة الصينية", teacher: "أ. لي مينغ", room: "القاعة الذكية", kind: "culture" },
  { id: "w25", classId: "c3", day: "sun", period: 4, subject: "اللغة الصينية للمبتدئين", teacher: "أ. محمد الصبري", room: "A-103", kind: "core" },
  { id: "w26", classId: "c3", day: "mon", period: 3, subject: "النغمات والنطق", teacher: "أ. تشاو يان", room: "مختبر اللغة", kind: "lab" },
  { id: "w27", classId: "c3", day: "tue", period: 2, subject: "القراءة والكتابة", teacher: "أ. محمد الصبري", room: "A-103", kind: "core" },
  { id: "w28", classId: "c3", day: "wed", period: 6, subject: "المحادثة والاستماع", teacher: "أ. لي مينغ", room: "مختبر اللغة", kind: "lab" },
];

export const calendarEvents = [
  { id: "e1", date: "2026-11-08", title: "انطلاق الأسبوع الثقافي الصيني", type: "event", time: "09:00", place: "الساحة الرئيسية", note: "معرض للخط الصيني وأطباق تقليدية وعروض موسيقية يقدمها طلاب المستوى الثالث." },
  { id: "e2", date: "2026-11-11", title: "اختبار منتصف الفصل - HSK 3", type: "exam", time: "09:00", place: "القاعة الذكية", note: "يشمل الاستماع والقراءة والكتابة، مدة الاختبار 90 دقيقة." },
  { id: "e3", date: "2026-11-12", title: "تسليم واجب المحادثة الصوتية", type: "deadline", time: "13:00", place: "بوابة التعلّم", note: "تسجيل صوتي مدته دقيقتان عن روتينك اليومي بالصينية." },
  { id: "e4", date: "2026-11-14", title: "اجتماع مجلس الأكاديمية", type: "meeting", time: "10:30", place: "قاعة الاجتماعات", note: "مراجعة نتائج منتصف الفصل وخطط الدعم للطلاب المتعثرين." },
  { id: "e5", date: "2026-11-18", title: "إجازة وطنية", type: "holiday", time: "طوال اليوم", place: "—", note: "تعطّل الدراسة في جميع الفروع وتُستأنف في اليوم التالي." },
  { id: "e6", date: "2026-11-22", title: "ورشة النطق والنغمات", type: "event", time: "11:00", place: "مختبر اللغة", note: "ورشة تطبيقية لتصحيح النغمات الأربع بإشراف أ. تشاو يان." },
  { id: "e7", date: "2026-11-25", title: "اختبار الشفهي - المستوى الثاني", type: "exam", time: "08:30", place: "مختبر اللغة", note: "مقابلة قصيرة لكل طالب أمام لجنة من معلمين اثنين." },
  { id: "e8", date: "2026-11-29", title: "آخر موعد لرفع درجات الشهر", type: "deadline", time: "16:00", place: "النظام الإداري", note: "على المعلمين اعتماد درجات المشاركة والواجبات قبل هذا الموعد." },
];

export const academicKpis = [
  { id: "k1", label: "خطط دراسية معتمدة", value: "12", detail: "ثلاثة برامج · أربعة مستويات", tone: "primary" },
  { id: "k2", label: "اختبارات مجدولة", value: "7", detail: "خلال نوفمبر 2026", tone: "secondary" },
  { id: "k3", label: "شعب نشطة", value: "18", detail: "إجمالي 396 طالباً", tone: "accent" },
  { id: "k4", label: "طلبات أكاديمية معلّقة", value: "5", detail: "تحويل شعبة وتأجيل", tone: "plain" },
];

export const academicPlans = [
  { id: "p1", title: "خطة HSK 1 المكثف", program: "اللغة الصينية للمبتدئين", level: "HSK 1", hours: 120, weeks: 12, owner: "أ. محمد الصبري", status: "معتمدة", updated: "2026-09-21" },
  { id: "p2", title: "خطة HSK 2 - المسار العام", program: "اللغة الصينية التطبيقية", level: "HSK 2", hours: 160, weeks: 16, owner: "أ. سارة الحداد", status: "معتمدة", updated: "2026-10-02" },
  { id: "p3", title: "خطة HSK 3 - المحادثة المكثفة", program: "اللغة الصينية التطبيقية", level: "HSK 3", hours: 180, weeks: 16, owner: "أ. لي مينغ", status: "قيد المراجعة", updated: "2026-10-28" },
  { id: "p4", title: "خطة الثقافة الصينية المساندة", program: "اللغة الصينية التطبيقية", level: "كل المستويات", hours: 40, weeks: 8, owner: "أ. تشاو يان", status: "معتمدة", updated: "2026-08-15" },
  { id: "p5", title: "خطة الدعم العلاجي للنطق", program: "برنامج الدعم الأكاديمي", level: "HSK 1 - HSK 2", hours: 24, weeks: 6, owner: "أ. تشاو يان", status: "مسودة", updated: "2026-11-04" },
];

export const academicExams = [
  { id: "x1", title: "اختبار منتصف الفصل - HSK 3", className: "المستوى الثالث - أ", date: "2026-11-11", time: "09:00", room: "القاعة الذكية", invigilator: "أ. سارة الحداد", status: "مجدول" },
  { id: "x2", title: "اختبار الاستماع القصير", className: "المستوى الثاني - ب", date: "2026-11-12", time: "10:00", room: "مختبر اللغة", invigilator: "أ. تشاو يان", status: "مجدول" },
  { id: "x3", title: "اختبار الشفهي", className: "المستوى الثاني - ب", date: "2026-11-25", time: "08:30", room: "مختبر اللغة", invigilator: "أ. لي مينغ", status: "بانتظار الاعتماد" },
  { id: "x4", title: "اختبار المفردات الأسبوعي", className: "المستوى الأول - ج", date: "2026-11-09", time: "08:00", room: "A-103", invigilator: "أ. محمد الصبري", status: "اكتمل" },
  { id: "x5", title: "الاختبار النهائي - HSK 1", className: "المستوى الأول - ج", date: "2026-12-14", time: "09:00", room: "القاعة الكبرى", invigilator: "أ. سارة الحداد", status: "بانتظار الاعتماد" },
  { id: "x6", title: "اختبار القراءة والكتابة", className: "المستوى الثالث - أ", date: "2026-11-19", time: "11:00", room: "A-201", invigilator: "أ. لي مينغ", status: "مجدول" },
];

export const academicSections = [
  { id: "s1", name: "المستوى الثالث - أ", program: "اللغة الصينية التطبيقية", teacher: "أ. لي مينغ", room: "A-201", students: 24, capacity: 28, status: "مستقرة" },
  { id: "s2", name: "المستوى الثاني - ب", program: "اللغة الصينية التطبيقية", teacher: "أ. سارة الحداد", room: "A-105", students: 21, capacity: 26, status: "مستقرة" },
  { id: "s3", name: "المستوى الأول - ج", program: "اللغة الصينية للمبتدئين", teacher: "أ. محمد الصبري", room: "A-103", students: 18, capacity: 25, status: "تحتاج دعماً" },
  { id: "s4", name: "المستوى الثالث - ب", program: "اللغة الصينية التطبيقية", teacher: "أ. تشاو يان", room: "A-202", students: 26, capacity: 26, status: "مكتملة" },
  { id: "s5", name: "المستوى الثاني - أ", program: "اللغة الصينية للمبتدئين", teacher: "أ. هدى المقطري", room: "B-102", students: 16, capacity: 24, status: "مستقرة" },
];

export const academicRequests = [
  { id: "q1", student: "أمينة محمد الوصابي", admissionNo: "SAI-2026-118", type: "تحويل شعبة", detail: "من المستوى الثالث - أ إلى المستوى الثالث - ب", submitted: "2026-11-04", status: "قيد المراجعة" },
  { id: "q2", student: "عبدالله صالح المقطري", admissionNo: "SAI-2026-092", type: "تأجيل جلسة", detail: "تأجيل اختبار منتصف الفصل ثلاثة أيام", submitted: "2026-11-05", status: "بحاجة لمستند" },
  { id: "q3", student: "ريم أحمد الشميري", admissionNo: "SAI-2026-131", type: "إعادة تصحيح", detail: "مراجعة درجة سؤال القراءة في اختبار المفردات", submitted: "2026-11-06", status: "قيد المراجعة" },
  { id: "q4", student: "محمد خالد الجابري", admissionNo: "SAI-2026-077", type: "تجاوز شرط", detail: "تجاوز متطلب HSK 2 بناءً على شهادة خارجية", submitted: "2026-11-02", status: "مقبول" },
  { id: "q5", student: "ليان عبدالرحمن الحداد", admissionNo: "SAI-2026-144", type: "تعويض حصة", detail: "تعويض حصتين من مادة المحادثة", submitted: "2026-11-07", status: "قيد المراجعة" },
];

export const qrRoster = [
  { id: "st1", name: "أمينة محمد الوصابي", admissionNo: "SAI-2026-118", level: "HSK 3", present: true, at: "08:04" },
  { id: "st2", name: "عبدالله صالح المقطري", admissionNo: "SAI-2026-092", level: "HSK 3", present: true, at: "08:06" },
  { id: "st3", name: "ريم أحمد الشميري", admissionNo: "SAI-2026-131", level: "HSK 3", present: true, at: "08:07" },
  { id: "st4", name: "محمد خالد الجابري", admissionNo: "SAI-2026-077", level: "HSK 3", present: false, at: "" },
  { id: "st5", name: "ليان عبدالرحمن الحداد", admissionNo: "SAI-2026-144", level: "HSK 3", present: true, at: "08:11" },
  { id: "st6", name: "يوسف علي الصبري", admissionNo: "SAI-2026-051", level: "HSK 3", present: false, at: "" },
  { id: "st7", name: "سلمان فهد العمري", admissionNo: "SAI-2026-063", level: "HSK 3", present: true, at: "08:13" },
  { id: "st8", name: "نور عبدالإله القاسمي", admissionNo: "SAI-2026-120", level: "HSK 3", present: true, at: "08:15" },
  { id: "st9", name: "أروى يحيى الحكيمي", admissionNo: "SAI-2026-108", level: "HSK 3", present: false, at: "" },
  { id: "st10", name: "طارق منير الشرعبي", admissionNo: "SAI-2026-099", level: "HSK 3", present: true, at: "08:18" },
  { id: "st11", name: "هدى محمد الروضي", admissionNo: "SAI-2026-136", level: "HSK 3", present: false, at: "" },
  { id: "st12", name: "أحمد سامي الزبيري", admissionNo: "SAI-2026-084", level: "HSK 3", present: true, at: "08:21" },
];