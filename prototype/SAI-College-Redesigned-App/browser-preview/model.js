const MODEL = {
  "roles": {
    "super_admin": [
      "الإدارة العامة",
      "جميع الفروع والإعدادات والموافقات"
    ],
    "admin": [
      "مدير الأكاديمية",
      "إدارة العمليات الأكاديمية والتشغيلية"
    ],
    "teacher": [
      "المعلم",
      "فصوله المسندة والتدريس والتقييم"
    ],
    "accountant": [
      "المحاسب",
      "الرسوم والتحصيل والدخل والمصروفات"
    ],
    "receptionist": [
      "الاستقبال",
      "استفسارات القبول والزوار والتسجيل الأولي"
    ],
    "librarian": [
      "أمين المكتبة",
      "الفهرس والإعارة والإرجاع"
    ],
    "student": [
      "الطالب",
      "تعلمه وسجله الشخصي فقط"
    ],
    "parent": [
      "ولي الأمر",
      "الأبناء المرتبطون به فقط"
    ],
    "content_editor": [
      "محرر المحتوى",
      "تأليف المحتوى والوسائط والمراجعات"
    ]
  },
  "modules": [
    {
      "id": "home",
      "label": "الرئيسية",
      "pillar": "المؤسسة",
      "icon": "⌂",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "accountant",
        "receptionist",
        "librarian",
        "student",
        "parent",
        "content_editor"
      ],
      "tabs": [
        "نظرة عامة"
      ]
    },
    {
      "id": "admissions",
      "label": "القبول والتسجيل",
      "pillar": "الإدارة",
      "icon": "◎",
      "roles": [
        "super_admin",
        "admin",
        "receptionist"
      ],
      "tabs": [
        "استفسارات القبول",
        "الطلبات",
        "التسجيل"
      ]
    },
    {
      "id": "students",
      "label": "سجلات الطلاب",
      "pillar": "الإدارة",
      "icon": "♙",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "receptionist",
        "parent",
        "student"
      ],
      "tabs": [
        "ملفات الطلاب",
        "أولياء الأمور",
        "استيراد تجريبي"
      ]
    },
    {
      "id": "academics",
      "label": "الشؤون الأكاديمية",
      "pillar": "الإدارة",
      "icon": "▦",
      "roles": [
        "super_admin",
        "admin",
        "teacher"
      ],
      "tabs": [
        "البرامج والمستويات",
        "الصفوف والشعب",
        "الخطة الدراسية"
      ]
    },
    {
      "id": "timetable",
      "label": "الجداول والتقويم",
      "pillar": "الإدارة",
      "icon": "▤",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "parent",
        "receptionist"
      ],
      "tabs": [
        "جدول الحصص",
        "الاختبارات المجدولة",
        "التقويم السنوي"
      ]
    },
    {
      "id": "attendance",
      "label": "الحضور والغياب",
      "pillar": "الإدارة",
      "icon": "✓",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "accountant",
        "receptionist",
        "student",
        "parent"
      ],
      "tabs": [
        "حضور الطلاب",
        "حضور الموظفين",
        "التقارير"
      ]
    },
    {
      "id": "qr",
      "label": "الحضور بالرمز QR",
      "pillar": "الإدارة",
      "icon": "▣",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "receptionist",
        "student"
      ],
      "tabs": [
        "بطاقة الحضور",
        "محاكاة التحقق"
      ]
    },
    {
      "id": "courses",
      "label": "المقررات والدروس",
      "pillar": "التعلم",
      "icon": "书",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "parent",
        "content_editor"
      ],
      "tabs": [
        "كتالوج المقررات",
        "الدروس",
        "الموارد والتنزيلات",
        "الحصص المباشرة"
      ]
    },
    {
      "id": "listening",
      "label": "الاستماع",
      "pillar": "التعلم",
      "icon": "◖",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "content_editor"
      ],
      "tabs": [
        "مختبر الاستماع"
      ]
    },
    {
      "id": "speaking",
      "label": "التحدث والنطق",
      "pillar": "التعلم",
      "icon": "◉",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "content_editor"
      ],
      "tabs": [
        "التدريب الشفهي"
      ]
    },
    {
      "id": "tones",
      "label": "النغمات الصينية",
      "pillar": "التعلم",
      "icon": "∿",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "content_editor"
      ],
      "tabs": [
        "تمييز النغمات"
      ]
    },
    {
      "id": "vocabulary",
      "label": "المفردات",
      "pillar": "التعلم",
      "icon": "字",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "content_editor"
      ],
      "tabs": [
        "البطاقات",
        "المحفوظات"
      ]
    },
    {
      "id": "handwriting",
      "label": "الكتابة اليدوية",
      "pillar": "التعلم",
      "icon": "✎",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "content_editor"
      ],
      "tabs": [
        "لوحة الكتابة"
      ]
    },
    {
      "id": "reading",
      "label": "القراءة",
      "pillar": "التعلم",
      "icon": "文",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "content_editor"
      ],
      "tabs": [
        "نصوص وفهم"
      ]
    },
    {
      "id": "review",
      "label": "المراجعة المتباعدة",
      "pillar": "التعلم",
      "icon": "↻",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student"
      ],
      "tabs": [
        "مستحق اليوم",
        "سجل المراجعات"
      ]
    },
    {
      "id": "homework",
      "label": "الواجبات",
      "pillar": "التعلم",
      "icon": "☷",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "parent"
      ],
      "tabs": [
        "واجبات قائمة",
        "التسليم والتقييم"
      ]
    },
    {
      "id": "quizzes",
      "label": "الاختبارات القصيرة",
      "pillar": "التعلم",
      "icon": "?",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "content_editor"
      ],
      "tabs": [
        "تدريب قصير",
        "النتيجة"
      ]
    },
    {
      "id": "exams",
      "label": "الامتحانات",
      "pillar": "التعلم",
      "icon": "▧",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "parent",
        "content_editor"
      ],
      "tabs": [
        "الجدول والنتائج",
        "بنك الأسئلة",
        "التقييم"
      ]
    },
    {
      "id": "certificates",
      "label": "الشهادات والبطاقات",
      "pillar": "التعلم",
      "icon": "◇",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "parent",
        "receptionist"
      ],
      "tabs": [
        "شهادات الإنجاز",
        "بطاقات الطلاب",
        "السيرة الدراسية"
      ]
    },
    {
      "id": "progress",
      "label": "التقدم التعليمي",
      "pillar": "التعلم",
      "icon": "▥",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "student",
        "parent"
      ],
      "tabs": [
        "الأبعاد التعليمية",
        "تقارير الطالب"
      ]
    },
    {
      "id": "authoring",
      "label": "تأليف الدروس",
      "pillar": "المحتوى",
      "icon": "✐",
      "roles": [
        "super_admin",
        "admin",
        "content_editor",
        "teacher"
      ],
      "tabs": [
        "تحرير الدرس",
        "المحتوى متعدد اللغات",
        "الإصدارات"
      ]
    },
    {
      "id": "media",
      "label": "مكتبة الوسائط",
      "pillar": "المحتوى",
      "icon": "▨",
      "roles": [
        "super_admin",
        "admin",
        "content_editor",
        "teacher"
      ],
      "tabs": [
        "صور",
        "صوت",
        "فيديو",
        "ملفات"
      ]
    },
    {
      "id": "approvals",
      "label": "المراجعة والنشر",
      "pillar": "المحتوى",
      "icon": "✓",
      "roles": [
        "super_admin",
        "admin",
        "content_editor",
        "teacher"
      ],
      "tabs": [
        "قائمة المراجعة",
        "منشور",
        "السجل"
      ]
    },
    {
      "id": "finance",
      "label": "الرسوم والمالية",
      "pillar": "العمليات",
      "icon": "ر",
      "roles": [
        "super_admin",
        "admin",
        "accountant",
        "parent",
        "student"
      ],
      "tabs": [
        "الفواتير",
        "المجموعات والخصومات",
        "الإيصالات",
        "الدخل والمصروفات"
      ]
    },
    {
      "id": "staff",
      "label": "شؤون الموظفين",
      "pillar": "العمليات",
      "icon": "♙",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "accountant",
        "receptionist",
        "librarian",
        "content_editor"
      ],
      "tabs": [
        "دليل الموظفين",
        "الإجازات",
        "الحضور"
      ]
    },
    {
      "id": "reception",
      "label": "الاستقبال",
      "pillar": "العمليات",
      "icon": "▱",
      "roles": [
        "super_admin",
        "admin",
        "receptionist"
      ],
      "tabs": [
        "الزوار",
        "المكالمات",
        "مواعيد ومراسلات"
      ]
    },
    {
      "id": "library",
      "label": "المكتبة",
      "pillar": "العمليات",
      "icon": "▥",
      "roles": [
        "super_admin",
        "admin",
        "librarian",
        "teacher",
        "parent",
        "student"
      ],
      "tabs": [
        "الفهرس",
        "الإعارة والإرجاع",
        "الحجوزات"
      ]
    },
    {
      "id": "communications",
      "label": "التواصل والإعلانات",
      "pillar": "العمليات",
      "icon": "✉",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "accountant",
        "receptionist",
        "librarian",
        "student",
        "parent",
        "content_editor"
      ],
      "tabs": [
        "الإعلانات",
        "الرسائل",
        "قوالب التواصل"
      ]
    },
    {
      "id": "branches",
      "label": "الفروع والجلسات",
      "pillar": "المؤسسة",
      "icon": "⌘",
      "roles": [
        "super_admin",
        "admin"
      ],
      "tabs": [
        "الفروع",
        "الجلسات الأكاديمية",
        "الفعاليات"
      ]
    },
    {
      "id": "reports",
      "label": "التقارير والطباعة",
      "pillar": "المؤسسة",
      "icon": "▤",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "accountant",
        "receptionist",
        "librarian",
        "parent",
        "student",
        "content_editor"
      ],
      "tabs": [
        "تقارير نطاقي",
        "السلوك والمتابعة",
        "الطباعة"
      ]
    },
    {
      "id": "cms",
      "label": "الموقع التعريفي CMS",
      "pillar": "المحتوى",
      "icon": "▢",
      "roles": [
        "super_admin",
        "admin",
        "content_editor"
      ],
      "tabs": [
        "الصفحات",
        "القوائم",
        "البنرات والمعرض"
      ]
    },
    {
      "id": "settings",
      "label": "النظام والصلاحيات",
      "pillar": "المؤسسة",
      "icon": "⚙",
      "roles": [
        "super_admin",
        "admin",
        "teacher",
        "accountant",
        "receptionist",
        "librarian",
        "student",
        "parent",
        "content_editor"
      ],
      "tabs": [
        "حسابي",
        "دليل الصلاحيات",
        "سجل التدقيق",
        "التكاملات",
        "نطاق النسخة"
      ]
    }
  ],
  "accounts": [
    {
      "id": "general",
      "name": "المدير العام",
      "roles": [
        "super_admin"
      ]
    },
    {
      "id": "manager",
      "name": "مدير الأكاديمية",
      "roles": [
        "admin"
      ]
    },
    {
      "id": "teacher",
      "name": "أحمد الحطاري",
      "roles": [
        "teacher"
      ]
    },
    {
      "id": "finance",
      "name": "سلمى المحاسبة",
      "roles": [
        "accountant"
      ]
    },
    {
      "id": "reception",
      "name": "نورا الاستقبال",
      "roles": [
        "receptionist"
      ]
    },
    {
      "id": "library",
      "name": "خالد أمين المكتبة",
      "roles": [
        "librarian"
      ]
    },
    {
      "id": "student",
      "name": "أحمد محمد عبدالله",
      "roles": [
        "student"
      ]
    },
    {
      "id": "parent",
      "name": "محمد عبدالله سالم",
      "roles": [
        "parent"
      ]
    },
    {
      "id": "editor",
      "name": "مومو محررة المحتوى",
      "roles": [
        "content_editor"
      ]
    },
    {
      "id": "dual",
      "name": "أحمد مدير ومعلم",
      "roles": [
        "admin",
        "teacher"
      ]
    }
  ],
  "students": [
    {
      "id": "STU00125",
      "name": "أحمد محمد عبدالله",
      "classId": "c1",
      "branch": "main",
      "parent": "parent",
      "grade": 88,
      "attendance": 95
    },
    {
      "id": "STU00126",
      "name": "ليان محمد عبدالله",
      "classId": "c2",
      "branch": "main",
      "parent": "parent",
      "grade": 92,
      "attendance": 97
    },
    {
      "id": "STU00127",
      "name": "خالد سالم علي",
      "classId": "c3",
      "branch": "east",
      "parent": null,
      "grade": 81,
      "attendance": 90
    }
  ],
  "classes": [
    {
      "id": "c1",
      "name": "HSK 1 • أ",
      "branch": "main",
      "capacity": 20,
      "enrolled": 12,
      "teacher": "teacher",
      "session": "2026-27"
    },
    {
      "id": "c2",
      "name": "YCT 1 • أطفال",
      "branch": "main",
      "capacity": 25,
      "enrolled": 25,
      "teacher": "teacher",
      "session": "2026-27"
    },
    {
      "id": "c3",
      "name": "HSK 2 • ب",
      "branch": "east",
      "capacity": 20,
      "enrolled": 17,
      "teacher": "other",
      "session": "2026-27"
    },
    {
      "id": "c4",
      "name": "HSK 1 • أرشيف",
      "branch": "main",
      "capacity": 20,
      "enrolled": 16,
      "teacher": "teacher",
      "session": "2025-26"
    }
  ],
  "words": [
    {
      "hanzi": "你好",
      "pinyin": "nǐ hǎo",
      "arabic": "مرحباً"
    },
    {
      "hanzi": "谢谢",
      "pinyin": "xièxie",
      "arabic": "شكراً"
    },
    {
      "hanzi": "老师",
      "pinyin": "lǎoshī",
      "arabic": "معلّم"
    },
    {
      "hanzi": "学生",
      "pinyin": "xuésheng",
      "arabic": "طالب"
    },
    {
      "hanzi": "中国",
      "pinyin": "Zhōngguó",
      "arabic": "الصين"
    }
  ],
  "later": [
    "السكن الداخلي",
    "النقل",
    "المخزون المادي",
    "الرواتب",
    "الخريجون",
    "المجموعات المدرسية School Houses",
    "صيغ امتحانات CBSE"
  ]
};
