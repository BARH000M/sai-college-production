typedef Word = ({String hanzi, String pinyin, String arabic});

class Lesson {
  const Lesson(
    this.id,
    this.title,
    this.example,
    this.pinyin,
    this.meaning,
    this.words,
    this.tip,
  );
  final String id, title, example, pinyin, meaning, tip;
  final List<Word> words;
}

class Course {
  const Course(this.code, this.title, this.subtitle, this.lessons);
  final String code, title, subtitle;
  final List<Lesson> lessons;
}

const courses = <Course>[
  Course('P0', 'المستوى التمهيدي', 'الأصوات والنغمات والتحية الأولى', [
    Lesson(
      'P0-01',
      'النغمات الأربع',
      '妈妈，你好！',
      'Māma, nǐ hǎo!',
      'أمي، مرحباً!',
      [
        (hanzi: '妈', pinyin: 'mā', arabic: 'أم'),
        (hanzi: '麻', pinyin: 'má', arabic: 'قنّب'),
        (hanzi: '马', pinyin: 'mǎ', arabic: 'حصان'),
        (hanzi: '骂', pinyin: 'mà', arabic: 'يُوبّخ'),
      ],
      'النغمة الأولى ثابتة، والثانية صاعدة، والثالثة منخفضة، والرابعة هابطة. غيّر النغمة من دون تغيير المقطع.',
    ),
    Lesson(
      'P0-02',
      'التحية والوداع',
      '你好！明天见。',
      'Nǐ hǎo! Míngtiān jiàn.',
      'مرحباً! أراك غداً.',
      [
        (hanzi: '你好', pinyin: 'nǐ hǎo', arabic: 'مرحباً'),
        (hanzi: '再见', pinyin: 'zàijiàn', arabic: 'إلى اللقاء'),
        (hanzi: '明天', pinyin: 'míngtiān', arabic: 'غداً'),
      ],
      'استخدم 您好 للتحية بأدب في موقف رسمي. جرّب تحية المعلّم ثم ودّعه.',
    ),
    Lesson(
      'P0-03',
      'الأرقام من واحد إلى ثلاثة',
      '一、二、三。',
      'Yī, èr, sān.',
      'واحد، اثنان، ثلاثة.',
      [
        (hanzi: '一', pinyin: 'yī', arabic: 'واحد'),
        (hanzi: '二', pinyin: 'èr', arabic: 'اثنان'),
        (hanzi: '三', pinyin: 'sān', arabic: 'ثلاثة'),
      ],
      'ابدأ برسم الخطوط الأفقية من اليسار إلى اليمين، ومن أعلى الرمز إلى أسفله.',
    ),
    Lesson(
      'P0-04',
      'الشكر والاعتذار',
      '谢谢！不用谢。',
      'Xièxie! Bú yòng xiè.',
      'شكراً! لا شكر على واجب.',
      [
        (hanzi: '谢谢', pinyin: 'xièxie', arabic: 'شكراً'),
        (hanzi: '对不起', pinyin: 'duìbuqǐ', arabic: 'آسف'),
        (hanzi: '没关系', pinyin: 'méi guānxi', arabic: 'لا بأس'),
      ],
      'ردّ على 对不起 بـ 没关系. المقطع الثاني من 谢谢 خفيف وقصير.',
    ),
    Lesson(
      'P0-05',
      'في القاعة',
      '请听，然后读。',
      'Qǐng tīng, ránhòu dú.',
      'استمع من فضلك، ثم اقرأ.',
      [
        (hanzi: '听', pinyin: 'tīng', arabic: 'يستمع'),
        (hanzi: '读', pinyin: 'dú', arabic: 'يقرأ'),
        (hanzi: '写', pinyin: 'xiě', arabic: 'يكتب'),
      ],
      'تأتي 请 قبل الفعل لطلب مهذّب. استمع للمثال ثم أعطِ زميلك تعليمة.',
    ),
  ]),
  Course('A0', 'المستوى الأساسي', 'التعارف والمفردات والجمل الأساسية', [
    Lesson(
      'A0-01',
      'ما اسمك؟',
      '我叫小明，你呢？',
      'Wǒ jiào Xiǎomíng, nǐ ne?',
      'اسمي شياو مينغ، وأنت؟',
      [
        (hanzi: '名字', pinyin: 'míngzi', arabic: 'اسم'),
        (hanzi: '我', pinyin: 'wǒ', arabic: 'أنا'),
        (hanzi: '你', pinyin: 'nǐ', arabic: 'أنت'),
      ],
      'قل 我叫 ثم اسمك. أضف 你呢 للسؤال عن الطرف الآخر.',
    ),
    Lesson(
      'A0-02',
      'أفراد الأسرة',
      '这是我妈妈。',
      'Zhè shì wǒ māma.',
      'هذه أمي.',
      [
        (hanzi: '妈妈', pinyin: 'māma', arabic: 'أمي'),
        (hanzi: '爸爸', pinyin: 'bàba', arabic: 'أبي'),
        (hanzi: '姐姐', pinyin: 'jiějie', arabic: 'أخت كبرى'),
      ],
      'يمكن حذف 的 عند الحديث عن الأقارب المقربين، مثل 我妈妈.',
    ),
    Lesson(
      'A0-03',
      'من أين أنت؟',
      '我是也门人。',
      'Wǒ shì Yěmén rén.',
      'أنا يمني.',
      [
        (hanzi: '也门', pinyin: 'Yěmén', arabic: 'اليمن'),
        (hanzi: '中国', pinyin: 'Zhōngguó', arabic: 'الصين'),
        (hanzi: '学生', pinyin: 'xuésheng', arabic: 'طالب'),
      ],
      'يمكن أن يأتي 人 بعد اسم البلد للتعريف بالجنسية، مثل 中国人.',
    ),
    Lesson(
      'A0-04',
      'الأشياء في الصف',
      '桌子上有一本书。',
      'Zhuōzi shàng yǒu yì běn shū.',
      'على الطاولة كتاب.',
      [
        (hanzi: '书', pinyin: 'shū', arabic: 'كتاب'),
        (hanzi: '桌子', pinyin: 'zhuōzi', arabic: 'طاولة'),
        (hanzi: '笔', pinyin: 'bǐ', arabic: 'قلم'),
      ],
      'التركيب 有 يدل على وجود شيء. 本 أداة عدّ للكتب.',
    ),
    Lesson(
      'A0-05',
      'الوقت والأيام',
      '今天星期六。',
      'Jīntiān xīngqīliù.',
      'اليوم السبت.',
      [
        (hanzi: '今天', pinyin: 'jīntiān', arabic: 'اليوم'),
        (hanzi: '昨天', pinyin: 'zuótiān', arabic: 'أمس'),
        (hanzi: '星期六', pinyin: 'xīngqīliù', arabic: 'السبت'),
      ],
      'من الاثنين إلى السبت، اجمع 星期 ورقم اليوم. الأحد هو 星期天 أو 星期日.',
    ),
  ]),
  Course('SAI1', 'المستوى SAI1', 'محادثات يومية في المطعم والسوق والكلية', [
    Lesson(
      'SAI1-01',
      'طلب مشروب',
      '我想喝一杯茶。',
      'Wǒ xiǎng hē yì bēi chá.',
      'أريد أن أشرب كوباً من الشاي.',
      [
        (hanzi: '茶', pinyin: 'chá', arabic: 'شاي'),
        (hanzi: '水', pinyin: 'shuǐ', arabic: 'ماء'),
        (hanzi: '咖啡', pinyin: 'kāfēi', arabic: 'قهوة'),
      ],
      'تأتي 想 قبل الفعل للتعبير عن الرغبة. استخدم 一杯 عند طلب كوب.',
    ),
    Lesson(
      'SAI1-02',
      'في السوق',
      '这个多少钱？',
      'Zhège duōshao qián?',
      'كم سعر هذا؟',
      [
        (hanzi: '钱', pinyin: 'qián', arabic: 'مال'),
        (hanzi: '贵', pinyin: 'guì', arabic: 'غالٍ'),
        (hanzi: '便宜', pinyin: 'piányi', arabic: 'رخيص'),
      ],
      'استخدم 多少钱 للسؤال عن السعر، وأشر إلى الشيء بـ 这个.',
    ),
    Lesson(
      'SAI1-03',
      'أين المكتبة؟',
      '请问，图书馆在哪儿？',
      'Qǐngwèn, túshūguǎn zài nǎr?',
      'عذراً، أين المكتبة؟',
      [
        (hanzi: '图书馆', pinyin: 'túshūguǎn', arabic: 'مكتبة'),
        (hanzi: '左边', pinyin: 'zuǒbian', arabic: 'جهة اليسار'),
        (hanzi: '右边', pinyin: 'yòubian', arabic: 'جهة اليمين'),
      ],
      '在 + مكان يصف الموقع. ابدأ بسؤال مهذب باستعمال 请问.',
    ),
    Lesson(
      'SAI1-04',
      'الذهاب إلى الكلية',
      '我坐公共汽车去学校。',
      'Wǒ zuò gōnggòng qìchē qù xuéxiào.',
      'أذهب إلى المدرسة بالحافلة.',
      [
        (hanzi: '公共汽车', pinyin: 'gōnggòng qìchē', arabic: 'حافلة'),
        (hanzi: '学校', pinyin: 'xuéxiào', arabic: 'مدرسة'),
        (hanzi: '走路', pinyin: 'zǒulù', arabic: 'يمشي'),
      ],
      'ضع وسيلة المواصلات قبل 去 والوجهة. جرّب ذكر وسيلتك المعتادة.',
    ),
    Lesson(
      'SAI1-05',
      'الهوايات',
      '我喜欢看书，也喜欢听音乐。',
      'Wǒ xǐhuan kàn shū, yě xǐhuan tīng yīnyuè.',
      'أحب القراءة وأحب أيضاً الاستماع إلى الموسيقى.',
      [
        (hanzi: '喜欢', pinyin: 'xǐhuan', arabic: 'يحب'),
        (hanzi: '音乐', pinyin: 'yīnyuè', arabic: 'موسيقى'),
        (hanzi: '运动', pinyin: 'yùndòng', arabic: 'رياضة'),
      ],
      'تأتي 也 قبل الفعل. قدّم نفسك ثم اذكر هوايتين تحبهما.',
    ),
  ]),
  Course('SAI2', 'المستوى SAI2', 'قواعد واستخدامات عملية للمحادثة', [
    Lesson(
      'SAI2-01',
      'تقديم الأسرة',
      '我家有四口人。',
      'Wǒ jiā yǒu sì kǒu rén.',
      'في أسرتي أربعة أشخاص.',
      [
        (hanzi: '家人', pinyin: 'jiārén', arabic: 'أفراد الأسرة'),
        (hanzi: '介绍', pinyin: 'jièshào', arabic: 'يعرّف أو يقدّم'),
        (hanzi: '口', pinyin: 'kǒu', arabic: 'أداة عدّ لأفراد الأسرة'),
      ],
      'استخدم 口 لعدّ أفراد الأسرة. اجعل المثال عن أسرتك بتغيير العدد.',
    ),
    Lesson(
      'SAI2-02',
      'المقارنة بين شيئين',
      '这本书比那本书便宜。',
      'Zhè běn shū bǐ nà běn shū piányi.',
      'هذا الكتاب أرخص من ذلك الكتاب.',
      [
        (hanzi: '比', pinyin: 'bǐ', arabic: 'أداة المقارنة'),
        (hanzi: '大', pinyin: 'dà', arabic: 'كبير'),
        (hanzi: '快', pinyin: 'kuài', arabic: 'سريع'),
      ],
      'النمط هو أ + 比 + ب + الصفة. استخدمه للمقارنة بين مدينتين أو سعرين.',
    ),
    Lesson(
      'SAI2-03',
      'السبب والنتيجة',
      '因为下雨，所以我坐车。',
      'Yīnwèi xiàyǔ, suǒyǐ wǒ zuò chē.',
      'لأنها تمطر، لذلك أذهب بالسيارة.',
      [
        (hanzi: '因为', pinyin: 'yīnwèi', arabic: 'لأنّ'),
        (hanzi: '所以', pinyin: 'suǒyǐ', arabic: 'لذلك'),
        (hanzi: '下雨', pinyin: 'xiàyǔ', arabic: 'تمطر'),
      ],
      'ابدأ السبب بـ 因为 ثم استخدم 所以 لذكر النتيجة.',
    ),
    Lesson(
      'SAI2-04',
      'ما الذي فعلته أمس؟',
      '我昨天买了一本书。',
      'Wǒ zuótiān mǎi le yì běn shū.',
      'اشتريت أمس كتاباً.',
      [
        (hanzi: '买', pinyin: 'mǎi', arabic: 'يشتري'),
        (hanzi: '卖', pinyin: 'mài', arabic: 'يبيع'),
        (hanzi: '了', pinyin: 'le', arabic: 'أداة تدل هنا على اكتمال الفعل'),
      ],
      'قد تأتي 了 بعد الفعل لبيان اكتماله. انتبه إلى فرق النغمة بين 买 و卖.',
    ),
    Lesson(
      'SAI2-05',
      'خطط عطلة الأسبوع',
      '周末我打算去看朋友。',
      'Zhōumò wǒ dǎsuàn qù kàn péngyou.',
      'أنوي زيارة صديق في عطلة الأسبوع.',
      [
        (hanzi: '打算', pinyin: 'dǎsuàn', arabic: 'ينوي'),
        (hanzi: '周末', pinyin: 'zhōumò', arabic: 'عطلة الأسبوع'),
        (hanzi: '朋友', pinyin: 'péngyou', arabic: 'صديق'),
      ],
      'استخدم 打算 قبل الفعل للحديث عن نية أو خطة. اسأل زميلك عن خطته ثم أجب.',
    ),
  ]),
];
