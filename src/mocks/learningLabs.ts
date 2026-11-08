export const listeningLessons = [
  {
    id: "l1",
    title: "في مطعم صيني",
    subtitle: "طلب الطعام والسؤال عن السعر",
    level: "HSK 2",
    minutes: 6,
    summary: "حوار قصير بين نادل وزبون في مطعم، مع مفردات الطلب والدفع.",
    transcript: [
      { speaker: "النادل", hanzi: "欢迎光临！您几位？", pinyin: "Huānyíng guānglín! Nín jǐ wèi?", arabic: "أهلاً بك! كم شخصاً معك؟" },
      { speaker: "الزبون", hanzi: "两个人。请给我菜单。", pinyin: "Liǎng ge rén. Qǐng gěi wǒ càidān.", arabic: "شخصان. أعطني قائمة الطعام من فضلك." },
      { speaker: "النادل", hanzi: "好的。您想吃什么？", pinyin: "Hǎo de. Nín xiǎng chī shénme?", arabic: "حسناً. ماذا تريد أن تأكل؟" },
      { speaker: "الزبون", hanzi: "我要一碗牛肉面，还有一杯茶。", pinyin: "Wǒ yào yì wǎn niúròu miàn, hái yǒu yì bēi chá.", arabic: "أريد وعاءً من نودلز اللحم البقري وكوب شاي." },
      { speaker: "النادل", hanzi: "一共四十五块。", pinyin: "Yígòng sìshíwǔ kuài.", arabic: "المجموع خمسة وأربعون يواناً." },
    ],
    questions: [
      { id: "l1q1", prompt: "كم شخصاً كان مع الزبون؟", options: ["شخص واحد", "شخصان", "ثلاثة أشخاص", "أربعة أشخاص"], answer: 1, hint: "استمع إلى عبارة «两个人» في السطر الثاني." },
      { id: "l1q2", prompt: "كم كان المجموع المطلوب دفعه؟", options: ["35 يواناً", "40 يواناً", "45 يواناً", "54 يواناً"], answer: 2, hint: "الرقم «四十五» يعني خمسة وأربعين." },
    ],
  },
  {
    id: "l2",
    title: "موعد مع المعلم",
    subtitle: "السؤال عن الوقت وتحديد موعد",
    level: "HSK 3",
    minutes: 7,
    summary: "طالبة تطلب مقابلة معلمها لتوضيح درس صعب، وتتفق معه على موعد.",
    transcript: [
      { speaker: "الطالبة", hanzi: "老师，您现在有空吗？", pinyin: "Lǎoshī, nín xiànzài yǒu kòng ma?", arabic: "أستاذ، هل أنت متفرغ الآن؟" },
      { speaker: "المعلم", hanzi: "我现在有点忙。下午三点怎么样？", pinyin: "Wǒ xiànzài yǒudiǎn máng. Xiàwǔ sān diǎn zěnmeyàng?", arabic: "أنا مشغول قليلاً الآن. ما رأيك في الثالثة بعد الظهر؟" },
      { speaker: "الطالبة", hanzi: "可以。我想问语法的问题。", pinyin: "Kěyǐ. Wǒ xiǎng wèn yǔfǎ de wèntí.", arabic: "لا بأس. أريد أن أسأل عن مسألة في القواعد." },
      { speaker: "المعلم", hanzi: "好，请带上课本到办公室来。", pinyin: "Hǎo, qǐng dài shàng kèběn dào bàngōngshì lái.", arabic: "حسناً، أحضري الكتاب إلى المكتب." },
    ],
    questions: [
      { id: "l2q1", prompt: "على أي ساعة اتفق الطرفان؟", options: ["الثامنة صباحاً", "الثالثة بعد الظهر", "الخامسة مساءً", "العاشرة صباحاً"], answer: 1, hint: "«下午三点» تعني الثالثة بعد الظهر." },
      { id: "l2q2", prompt: "ماذا طلب المعلم من الطالبة أن تحضر؟", options: ["الواجب", "الكتاب", "جهاز الحاسوب", "الاختبار"], answer: 1, hint: "«课本» تعني الكتاب الدراسي." },
    ],
  },
  {
    id: "l3",
    title: "الطقس والملابس",
    subtitle: "وصف الطقس واختيار الملابس المناسبة",
    level: "HSK 2",
    minutes: 5,
    summary: "صديقان يتحدثان عن برد بكين واختيار المعطف المناسب.",
    transcript: [
      { speaker: "لي", hanzi: "今天北京很冷。", pinyin: "Jīntiān Běijīng hěn lěng.", arabic: "الجو بارد جداً في بكين اليوم." },
      { speaker: "وانغ", hanzi: "是的，外面还下雪了。", pinyin: "Shì de, wàimiàn hái xià xuě le.", arabic: "نعم، والثلج ينزل في الخارج أيضاً." },
      { speaker: "لي", hanzi: "你穿这件大衣吧。", pinyin: "Nǐ chuān zhè jiàn dàyī ba.", arabic: "ارتدِ هذا المعطف." },
      { speaker: "وانغ", hanzi: "好的，谢谢。你也要多穿一点。", pinyin: "Hǎo de, xièxie. Nǐ yě yào duō chuān yìdiǎn.", arabic: "حسناً، شكراً. وأنت أيضاً يجب أن تلبس أكثر." },
    ],
    questions: [
      { id: "l3q1", prompt: "كيف حال الطقس في بكين؟", options: ["حار ومشمس", "بارد ومثلج", "ممطر وخفيف", "غائم ودافئ"], answer: 1, hint: "«下雪» تعني ينزل الثلج." },
      { id: "l3q2", prompt: "ماذا اقترح لي على صديقه؟", options: ["أن يشرب الشاي", "أن يرتدي المعطف", "أن يفتح النافذة", "أن يبقى في المنزل"], answer: 1, hint: "«大衣» تعني المعطف." },
    ],
  },
];

export const toneReferences = [
  { id: "tr1", tone: 1, name: "النغمة الأولى", mark: "ā", hanzi: "妈", pinyin: "mā", arabic: "أم", contour: [92, 92, 92, 92, 92, 92], hint: "نغمة عالية ومسطحة، كأنك تغني درجة واحدة طويلة." },
  { id: "tr2", tone: 2, name: "النغمة الثانية", mark: "á", hanzi: "麻", pinyin: "má", arabic: "قنب", contour: [34, 48, 62, 74, 86, 94], hint: "نغمة صاعدة من الوسط إلى الأعلى، كأنك تسأل." },
  { id: "tr3", tone: 3, name: "النغمة الثالثة", mark: "ǎ", hanzi: "马", pinyin: "mǎ", arabic: "حصان", contour: [58, 42, 28, 24, 36, 58], hint: "نغمة هابطة ثم صاعدة، كأنك تتردد." },
  { id: "tr4", tone: 4, name: "النغمة الرابعة", mark: "à", hanzi: "骂", pinyin: "mà", arabic: "يوبّخ", contour: [96, 82, 66, 48, 30, 16], hint: "نغمة هابطة بقوة من الأعلى إلى الأسفل، كأنك تعطي أمراً." },
];

export const tonePractice = [
  { id: "tp1", word: "买", meaning: "يشتري", pinyin: "mǎi", tone: 3, options: ["māi", "mái", "mǎi", "mài"] },
  { id: "tp2", word: "问", meaning: "يسأل", pinyin: "wèn", tone: 4, options: ["wēn", "wén", "wěn", "wèn"] },
  { id: "tp3", word: "茶", meaning: "شاي", pinyin: "chá", tone: 2, options: ["chā", "chá", "chǎ", "chà"] },
  { id: "tp4", word: "书", meaning: "كتاب", pinyin: "shū", tone: 1, options: ["shū", "shú", "shǔ", "shù"] },
  { id: "tp5", word: "你好", meaning: "مرحباً", pinyin: "nǐ hǎo", tone: 3, options: ["nī hāo", "ní háo", "nǐ hǎo", "nì hào"] },
  { id: "tp6", word: "再见", meaning: "إلى اللقاء", pinyin: "zàijiàn", tone: 4, options: ["zāijiān", "záijián", "zǎijiǎn", "zàijiàn"] },
];

export const speakingDrills = [
  {
    id: "sp1",
    hanzi: "我叫阿米娜，我是也门人。",
    pinyin: "Wǒ jiào Āmǐnà, wǒ shì Yěmén rén.",
    arabic: "اسمي أمينة، وأنا من اليمن.",
    focus: "النغمة الثالثة في «我»",
    tips: ["انزل ببطء في «wǒ» ثم اصعد قليلاً قبل الانتقال.", "لا تنطق «يا» بدل «وو»، اجعل الشفتين مستديرتين قليلاً."],
  },
  {
    id: "sp2",
    hanzi: "请问，图书馆在哪里？",
    pinyin: "Qǐngwèn, túshūguǎn zài nǎlǐ?",
    arabic: "لو سمحت، أين المكتبة؟",
    focus: "نغمة السؤال الصاعدة",
    tips: ["«qǐng» نغمة هابطة صاعدة، لا ترفع الصوت في نهايتها.", "«nǎlǐ» نغمتان ثالثتان متتاليتان: الأولى تتحول إلى نغمة ثانية."],
  },
  {
    id: "sp3",
    hanzi: "我喜欢学习中文，因为很有意思。",
    pinyin: "Wǒ xǐhuān xuéxí Zhōngwén, yīnwèi hěn yǒu yìsi.",
    arabic: "أحب تعلم اللغة الصينية لأنها ممتعة جداً.",
    focus: "الإيقاع وإدغام الكلمات",
    tips: ["اقرأ «xǐhuān» بسرعة مع الحفاظ على وضوح النغمات.", "«yǒu yìsi» تُلفظ ككتلة واحدة، لا تقطعها كلمة كلمة."],
  },
  {
    id: "sp4",
    hanzi: "谢谢你的帮助，明天见！",
    pinyin: "Xièxie nǐ de bāngzhù, míngtiān jiàn!",
    arabic: "شكراً على مساعدتك، أراك غداً!",
    focus: "النغمة الرابعة المزدوجة",
    tips: ["«xièxie» النغمة الثانية للكلمة الثانية أخف وأقصر.", "أنهِ الجملة «jiàn» بهبوط واضح دون مدّ."],
  },
];

export const handwritingChars = [
  { id: "hw1", char: "你", pinyin: "nǐ", arabic: "أنت", strokes: 7, radical: "亻", hint: "ابدأ بالجزء الأيسر «亻» ثم الجزء الأيمن «尔» من الأعلى إلى الأسفل." },
  { id: "hw2", char: "好", pinyin: "hǎo", arabic: "جيد", strokes: 6, radical: "女", hint: "المرأة «女» على اليسار أصغر من المعتاد لتفسح مكان «子»." },
  { id: "hw3", char: "学", pinyin: "xué", arabic: "يتعلم", strokes: 8, radical: "子", hint: "الجزء العلوي ثلاث نقاط وأغطية، ثم «子» في الأسفل بخط أفقي طويل." },
  { id: "hw4", char: "爱", pinyin: "ài", arabic: "حب", strokes: 10, radical: "爫", hint: "الجزء العلوي «爫» ثم الغطاء، وأخيراً «友» في الأسفل." },
  { id: "hw5", char: "书", pinyin: "shū", arabic: "كتاب", strokes: 4, radical: "乙", hint: "أربع ضربات فقط: خط أفقي، خط منحنٍ، ثم نقطتان رأسيتان." },
  { id: "hw6", char: "国", pinyin: "guó", arabic: "دولة", strokes: 8, radical: "囗", hint: "ارسم الإطار الخارجي أولاً، ثم «玉» في الداخل قبل إغلاق الخط السفلي." },
];

export const readingPassages = [
  {
    id: "rd1",
    title: "يومي في الكلية",
    level: "HSK 2",
    minutes: 4,
    intro: "طالب يصف يومه الدراسي من الصباح حتى المساء.",
    paragraphs: [
      { hanzi: "我每天早上七点起床，然后吃早饭。", pinyin: "Wǒ měitiān zǎoshang qī diǎn qǐchuáng, ránhòu chī zǎofàn.", arabic: "أستيقظ كل يوم في السابعة صباحاً، ثم أتناول الفطور." },
      { hanzi: "八点我去大学上课。我们的汉语老师很好，她常常帮助我们。", pinyin: "Bā diǎn wǒ qù dàxué shàngkè. Wǒmen de Hànyǔ lǎoshī hěn hǎo, tā chángcháng bāngzhù wǒmen.", arabic: "في الثامنة أذهب إلى الجامعة للدراسة. معلمة اللغة الصينية لدينا رائعة، وهي تساعدنا دائماً." },
      { hanzi: "下午我和朋友一起去图书馆看书。晚上九点回家，十一点睡觉。", pinyin: "Xiàwǔ wǒ hé péngyou yìqǐ qù túshūguǎn kàn shū. Wǎnshang jiǔ diǎn huí jiā, shíyī diǎn shuìjiào.", arabic: "بعد الظهر أذهب مع صديقي إلى المكتبة للقراءة. أعود إلى البيت في التاسعة مساءً وأنام في الحادية عشرة." },
    ],
    vocabulary: [
      { hanzi: "起床", pinyin: "qǐchuáng", arabic: "يستيقظ" },
      { hanzi: "常常", pinyin: "chángcháng", arabic: "غالباً" },
      { hanzi: "帮助", pinyin: "bāngzhù", arabic: "يساعد" },
      { hanzi: "图书馆", pinyin: "túshūguǎn", arabic: "المكتبة" },
    ],
    questions: [
      { id: "rd1q1", prompt: "في أي ساعة يستيقظ الكاتب؟", options: ["السادسة", "السابعة", "الثامنة", "التاسعة"], answer: 1, hint: "«七点» تعني السابعة." },
      { id: "rd1q2", prompt: "إلى أين يذهب بعد الظهر؟", options: ["إلى المطعم", "إلى المكتبة", "إلى الملعب", "إلى السوق"], answer: 1, hint: "«图书馆» تعني المكتبة." },
    ],
  },
  {
    id: "rd2",
    title: "رسالة إلى صديق",
    level: "HSK 3",
    minutes: 5,
    intro: "رسالة قصيرة تدعو صديقاً لزيارة مدينة صنعاء القديمة.",
    paragraphs: [
      { hanzi: "亲爱的阿里：你好！", pinyin: "Qīn'ài de Ālǐ: nǐ hǎo!", arabic: "عزيزي علي: مرحباً!" },
      { hanzi: "下个周末我想去萨那老城。听说那里的老房子非常漂亮，还有很多好吃的。", pinyin: "Xià ge zhōumò wǒ xiǎng qù Sānà lǎochéng. Tīngshuō nàlǐ de lǎo fángzi fēicháng piàoliang, hái yǒu hěn duō hǎochī de.", arabic: "في نهاية الأسبوع القادمة أريد الذهاب إلى صنعاء القديمة. سمعت أن بيوتها القديمة جميلة جداً، وفيها طعام لذيذ كثير." },
      { hanzi: "你有时间吗？我们早上九点在学校门口见，好吗？", pinyin: "Nǐ yǒu shíjiān ma? Wǒmen zǎoshang jiǔ diǎn zài xuéxiào ménkǒu jiàn, hǎo ma?", arabic: "هل لديك وقت؟ لنلتقِ أمام بوابة المدرسة في التاسعة صباحاً، ما رأيك؟" },
      { hanzi: "请给我回信。你的朋友，萨米。", pinyin: "Qǐng gěi wǒ huí xìn. Nǐ de péngyou, Sāmǐ.", arabic: "أرسل لي رداً من فضلك. صديقك، سامي." },
    ],
    vocabulary: [
      { hanzi: "周末", pinyin: "zhōumò", arabic: "نهاية الأسبوع" },
      { hanzi: "老城", pinyin: "lǎochéng", arabic: "المدينة القديمة" },
      { hanzi: "门口", pinyin: "ménkǒu", arabic: "البوابة" },
      { hanzi: "回信", pinyin: "huí xìn", arabic: "يرد بالرسالة" },
    ],
    questions: [
      { id: "rd2q1", prompt: "إلى أين يريد سامي الذهاب؟", options: ["إلى الشاطئ", "إلى صنعاء القديمة", "إلى المطار", "إلى الجبل"], answer: 1, hint: "«萨那老城» تعني صنعاء القديمة." },
      { id: "rd2q2", prompt: "أين حدد موعد اللقاء؟", options: ["أمام المكتبة", "أمام بوابة المدرسة", "في المقهى", "في المطار"], answer: 1, hint: "«学校门口» تعني بوابة المدرسة." },
    ],
  },
];

export const reviewCards = [
  { id: "rv1", hanzi: "学生", pinyin: "xuéshēng", arabic: "طالب", example: "他是我们班的学生。", exampleAr: "هو طالب في صفنا.", tag: "المدرسة", bucket: "جديد", dueIn: "اليوم" },
  { id: "rv2", hanzi: "老师", pinyin: "lǎoshī", arabic: "معلم", example: "老师今天很忙。", exampleAr: "المعلم مشغول اليوم.", tag: "المدرسة", bucket: "جديد", dueIn: "اليوم" },
  { id: "rv3", hanzi: "图书馆", pinyin: "túshūguǎn", arabic: "مكتبة", example: "我在图书馆看书。", exampleAr: "أقرأ في المكتبة.", tag: "الأماكن", bucket: "مراجعة", dueIn: "اليوم" },
  { id: "rv4", hanzi: "喜欢", pinyin: "xǐhuān", arabic: "يحب", example: "我喜欢中国茶。", exampleAr: "أحب الشاي الصيني.", tag: "أفعال", bucket: "متأخر", dueIn: "متأخرة يومين" },
  { id: "rv5", hanzi: "早上", pinyin: "zǎoshang", arabic: "صباحاً", example: "我早上七点起床。", exampleAr: "أستيقظ في السابعة صباحاً.", tag: "الوقت", bucket: "مراجعة", dueIn: "اليوم" },
  { id: "rv6", hanzi: "谢谢", pinyin: "xièxie", arabic: "شكراً", example: "谢谢你的帮助。", exampleAr: "شكراً على مساعدتك.", tag: "التواصل", bucket: "مراجعة", dueIn: "اليوم" },
  { id: "rv7", hanzi: "便宜", pinyin: "piányi", arabic: "رخيص", example: "这件衣服很便宜。", exampleAr: "هذا الثوب رخيص جداً.", tag: "التسوق", bucket: "جديد", dueIn: "اليوم" },
  { id: "rv8", hanzi: "帮助", pinyin: "bāngzhù", arabic: "يساعد", example: "请帮助我。", exampleAr: "ساعدني من فضلك.", tag: "أفعال", bucket: "متأخر", dueIn: "متأخرة يوماً" },
  { id: "rv9", hanzi: "明天", pinyin: "míngtiān", arabic: "غداً", example: "明天见！", exampleAr: "أراك غداً!", tag: "الوقت", bucket: "مراجعة", dueIn: "اليوم" },
  { id: "rv10", hanzi: "认识", pinyin: "rènshi", arabic: "يتعرّف / يعرف", example: "很高兴认识你。", exampleAr: "سعيد بمعرفتك.", tag: "التواصل", bucket: "جديد", dueIn: "اليوم" },
];

export const labSummaryStats = [
  { id: "ls1", label: "دروس مكتملة هذا الأسبوع", value: "9" },
  { id: "ls2", label: "دقائق استماع", value: "86" },
  { id: "ls3", label: "بطاقات مستحقة", value: "10" },
  { id: "ls4", label: "دقة النطق", value: "84%" },
];