// Reference labels and audit classifications; this catalog does not grant access.
export type InventoryEntryStatus = "implemented" | "partial" | "pending";
export type InventoryReferenceEntry = {
  ar: string;
  en: string;
  status: InventoryEntryStatus;
  moduleId: string | null;
  profile: string;
  note: string;
};
export type InventoryReferenceCategory = { ar: string; entries: readonly InventoryReferenceEntry[] };

export const inventoryReference: readonly InventoryReferenceCategory[] = [
  {
    "ar": "مكتب الاستقبال",
    "entries": [
      {
        "ar": "استعلام عن القبول",
        "en": "Admission Inquiry",
        "status": "partial",
        "moduleId": "admissions",
        "profile": "ADM",
        "note": "partial."
      },
      {
        "ar": "كتاب الزوار",
        "en": "Visitor Book",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no visitor log."
      },
      {
        "ar": "سجل المكالمات الهاتفية",
        "en": "Phone Call Log",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no call log."
      },
      {
        "ar": "الإرسال البريدي",
        "en": "Postal Dispatch",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no dispatch log."
      },
      {
        "ar": "استلام بريدي",
        "en": "Postal Receive",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no received-mail log."
      },
      {
        "ar": "يشتكي",
        "en": "Complaints",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no complaints workflow."
      },
      {
        "ar": "قائمة الغرض",
        "en": "Purpose List",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no purpose catalog."
      }
    ]
  },
  {
    "ar": "معلومات الطلاب",
    "entries": [
      {
        "ar": "تفاصيل الطالب",
        "en": "Student Details",
        "status": "partial",
        "moduleId": "students",
        "profile": "STU",
        "note": "partial directory, not complete legacy student record."
      },
      {
        "ar": "قبول الطالب",
        "en": "Student Admission",
        "status": "partial",
        "moduleId": "admissions",
        "profile": "ADM",
        "note": "partial, no verified admissions-to-enrollment conversion."
      },
      {
        "ar": "القبول عبر الإنترنت",
        "en": "Online Admission",
        "status": "partial",
        "moduleId": "admissions",
        "profile": "PUB",
        "note": "partial RPC contract, public UI/live endpoint unverified."
      },
      {
        "ar": "الطلاب المعاقون",
        "en": "Students with Disabilities",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no disability-specific fields/workflow."
      },
      {
        "ar": "طالب متعدد الصفوف",
        "en": "Multi-Class Student",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, current student model has one class assignment."
      },
      {
        "ar": "حذف مجمع",
        "en": "Bulk Delete",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "not supported; destructive bulk deletion is not implemented."
      },
      {
        "ar": "فئات الطلاب",
        "en": "Student Categories",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no category service."
      },
      {
        "ar": "بيت الطالب",
        "en": "Student House",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, housing schema not verified in checked-in sources."
      },
      {
        "ar": "تعطيل السبب",
        "en": "Disable Reason",
        "status": "partial",
        "moduleId": "students",
        "profile": "STU",
        "note": "partial, no deactivation reason/audit UI."
      },
      {
        "ar": "استيراد الطلاب",
        "en": "Student Import",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no import/validation workflow."
      },
      {
        "ar": "سجل الطلاب التاريخي",
        "en": "Student History",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no historical archive."
      },
      {
        "ar": "تقرير أولياء الأمور",
        "en": "Parent Report",
        "status": "partial",
        "moduleId": "reports",
        "profile": "PROFILE",
        "note": "partial verified links, no dedicated report."
      },
      {
        "ar": "بيانات دخول الطلاب",
        "en": "Student Login Credentials",
        "status": "partial",
        "moduleId": "roles",
        "profile": "ROLE",
        "note": "partial account/role administration; no credential disclosure/reset UI."
      },
      {
        "ar": "السيرة الذاتية",
        "en": "Student CV",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, portfolio schema not verified in checked-in sources."
      },
      {
        "ar": "نقل للفرع",
        "en": "Branch Transfer",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no safe branch-transfer transaction."
      }
    ]
  },
  {
    "ar": "تحصيل الرسوم",
    "entries": [
      {
        "ar": "تحصيل الرسوم",
        "en": "Collect Fees",
        "status": "partial",
        "moduleId": "finance",
        "profile": "FIN",
        "note": "partial, payment RPC source exists, live backend unverified."
      },
      {
        "ar": "دفع/بحث رسوم",
        "en": "Fees Payment/Search",
        "status": "partial",
        "moduleId": "finance",
        "profile": "FIN",
        "note": "partial payment/assignment APIs, live backend unverified."
      },
      {
        "ar": "الرسوم المستحقة",
        "en": "Due Fees",
        "status": "partial",
        "moduleId": "finance",
        "profile": "FIN",
        "note": "partial assignment/balance contract, no live verification."
      },
      {
        "ar": "سيد الرسوم",
        "en": "Fees Master",
        "status": "partial",
        "moduleId": "finance",
        "profile": "FIN",
        "note": "partial fee-group configuration only."
      },
      {
        "ar": "مجموعة الرسوم",
        "en": "Fees Group",
        "status": "partial",
        "moduleId": "finance",
        "profile": "FIN",
        "note": "partial, supported by migration 019."
      },
      {
        "ar": "نوع الرسوم",
        "en": "Fees Type",
        "status": "pending",
        "moduleId": null,
        "profile": "FIN",
        "note": "pending, no separate fee-type catalog."
      },
      {
        "ar": "خصم الرسوم",
        "en": "Fees Discount",
        "status": "partial",
        "moduleId": "finance",
        "profile": "FIN",
        "note": "partial discount amount in assignment contract; live verification pending."
      },
      {
        "ar": "رسوم ترحيل",
        "en": "Carry Forward Fees",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no fee-transfer workflow."
      },
      {
        "ar": "البنوك",
        "en": "Banks",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no bank-account directory."
      }
    ]
  },
  {
    "ar": "الدخل",
    "entries": [
      {
        "ar": "وصف الدخل",
        "en": "Income Head",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no non-fee income catalog."
      },
      {
        "ar": "إضافة دخل",
        "en": "Add Income",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no non-fee income transaction."
      }
    ]
  },
  {
    "ar": "المصروفات",
    "entries": [
      {
        "ar": "أوصاف المصروف",
        "en": "Expense Head",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no expense category workflow."
      },
      {
        "ar": "إضافة مصروف",
        "en": "Add Expense",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no expense transaction workflow."
      }
    ]
  },
  {
    "ar": "الحضور",
    "entries": [
      {
        "ar": "حضور الطلاب",
        "en": "Student Attendance",
        "status": "implemented",
        "moduleId": "attendance",
        "profile": "ATT",
        "note": "working, staff register and scoped personal view."
      },
      {
        "ar": "حضور QR",
        "en": "QR Attendance",
        "status": "implemented",
        "moduleId": "qr",
        "profile": "ATT",
        "note": "working, QR route with backend class scope."
      },
      {
        "ar": "الحضور حسب التاريخ",
        "en": "Attendance by Date",
        "status": "implemented",
        "moduleId": "attendance",
        "profile": "REP",
        "note": "working, date-range/class-scoped attendance report."
      }
    ]
  },
  {
    "ar": "الامتحانات",
    "entries": [
      {
        "ar": "قائمة الامتحانات",
        "en": "Exam List",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, exam module hidden and exam schema not verified in checked-in sources."
      },
      {
        "ar": "جدول الامتحان",
        "en": "Exam Schedule",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, mock dates are not a persisted schedule."
      },
      {
        "ar": "سجل الدرجات",
        "en": "Marks Register",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no exam-attempt/marks backend."
      },
      {
        "ar": "تقديرات الدرجات",
        "en": "Marks Grade",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no grading-scale service."
      }
    ]
  },
  {
    "ar": "امتحانات CBSE",
    "entries": [
      {
        "ar": "الامتحانات",
        "en": "Examinations",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, CBSE exam schema not verified in checked-in sources."
      },
      {
        "ar": "مجموعة الامتحانات",
        "en": "Exam Group",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no exam-group management."
      },
      {
        "ar": "جدول الامتحان",
        "en": "Exam Schedule",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no persisted CBSE schedule."
      },
      {
        "ar": "نتيجة الامتحان",
        "en": "Exam Result",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no results backend."
      },
      {
        "ar": "بطاقة قبول التصميم",
        "en": "Admit Card Design",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no admit-card designer."
      },
      {
        "ar": "طباعة بطاقة الدخول",
        "en": "Print Admit Card",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no verified admit-card data."
      },
      {
        "ar": "تصميم ماركشيت",
        "en": "Marksheet Design",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no marksheet template."
      },
      {
        "ar": "طباعة ماركشيت",
        "en": "Print Marksheet",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no marksheet data/output."
      },
      {
        "ar": "علامات الصف",
        "en": "Class Marks",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no class mark entry."
      },
      {
        "ar": "قسم العلامات",
        "en": "Marks Division",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no marks-division configuration."
      }
    ]
  },
  {
    "ar": "امتحان CBSE",
    "entries": [
      {
        "ar": "امتحان",
        "en": "Exam",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no CBSE exam workflow."
      },
      {
        "ar": "جدول الامتحان",
        "en": "Exam Schedule",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no persisted schedule."
      },
      {
        "ar": "طباعة ماركشيت",
        "en": "Print Marksheet",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no marksheet generation."
      },
      {
        "ar": "قالب",
        "en": "Template",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no exam-template service."
      },
      {
        "ar": "تعيين المراقبة",
        "en": "Invigilation Assignment",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no invigilation assignment."
      },
      {
        "ar": "بطاقة القبول",
        "en": "Admit Card",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no admit-card service."
      },
      {
        "ar": "التقارير",
        "en": "Reports",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no CBSE reports."
      },
      {
        "ar": "جلسة",
        "en": "Session",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no exam-session workflow."
      }
    ]
  },
  {
    "ar": "الأكاديمية",
    "entries": [
      {
        "ar": "الفصول والأقسام",
        "en": "Classes and Sections",
        "status": "partial",
        "moduleId": "classes",
        "profile": "STU",
        "note": "partial, scoped class management but no full section lifecycle."
      },
      {
        "ar": "المواد",
        "en": "Subjects",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no subject catalog/table."
      },
      {
        "ar": "تعيين المواد والمعلمين",
        "en": "Subject and Teacher Assignment",
        "status": "partial",
        "moduleId": "academics",
        "profile": "STU",
        "note": "partial class-teacher reference only; no subject assignment."
      },
      {
        "ar": "الجدول الأسبوعي",
        "en": "Class Timetable",
        "status": "pending",
        "moduleId": null,
        "profile": "ACA",
        "note": "pending, React is static mock data and mobile live view is unavailable."
      },
      {
        "ar": "ترقية الطلاب",
        "en": "Student Promotion",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no promotion transaction."
      },
      {
        "ar": "خطة الدرس",
        "en": "Lesson Plan",
        "status": "partial",
        "moduleId": null,
        "profile": "LEARN",
        "note": "partial lessons exist, no approved lesson-plan workflow."
      }
    ]
  },
  {
    "ar": "الواجب المنزلي",
    "entries": [
      {
        "ar": "وصف الواجب",
        "en": "Homework Description",
        "status": "implemented",
        "moduleId": "homework",
        "profile": "HW",
        "note": "working published homework, student submission, and grading."
      }
    ]
  },
  {
    "ar": "مركز التحميل",
    "entries": [
      {
        "ar": "المواد القابلة للتنزيل",
        "en": "Downloadable Content",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, resource table/storage policy not verified in checked-in sources."
      },
      {
        "ar": "يوتيوب تعليمي",
        "en": "Educational YouTube",
        "status": "partial",
        "moduleId": "downloads",
        "profile": "LEARN",
        "note": "partial lesson URLs only, no YouTube library/catalog."
      }
    ]
  },
  {
    "ar": "المكتبة",
    "entries": [
      {
        "ar": "قائمة الكتب",
        "en": "Book List",
        "status": "implemented",
        "moduleId": "library",
        "profile": "LIB",
        "note": "working branch-scoped catalog."
      },
      {
        "ar": "إضافة كتاب",
        "en": "Add Book",
        "status": "implemented",
        "moduleId": "library",
        "profile": "LIB",
        "note": "working librarian/admin-authorized writes."
      },
      {
        "ar": "الإصدار والعودة",
        "en": "Issue and Return",
        "status": "implemented",
        "moduleId": "library",
        "profile": "LIB",
        "note": "working server RPC circulation transactions."
      }
    ]
  },
  {
    "ar": "النقل",
    "entries": [
      {
        "ar": "المركبات",
        "en": "Vehicles",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, transport schema not verified in checked-in sources."
      },
      {
        "ar": "الخطوط",
        "en": "Routes",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, transport schema not verified in checked-in sources."
      },
      {
        "ar": "نقاط الالتقاط",
        "en": "Pickup Points",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, transport schema not verified in checked-in sources."
      }
    ]
  },
  {
    "ar": "السكن",
    "entries": [
      {
        "ar": "الغرف",
        "en": "Rooms",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, housing schema not verified in checked-in sources."
      }
    ]
  },
  {
    "ar": "المخزون",
    "entries": [
      {
        "ar": "الأصناف",
        "en": "Items",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, inventory schema not verified in checked-in sources."
      },
      {
        "ar": "حركة المخزون",
        "en": "Item Stock",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, no movement ledger/transaction."
      }
    ]
  },
  {
    "ar": "الموارد البشرية",
    "entries": [
      {
        "ar": "دليل الموظفين",
        "en": "Staff Directory",
        "status": "partial",
        "moduleId": "staff",
        "profile": "ROLE",
        "note": "partial account/role service only, no HR directory module."
      },
      {
        "ar": "الحضور والغياب",
        "en": "Staff Attendance",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no staff attendance data."
      },
      {
        "ar": "الرواتب",
        "en": "Payroll",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no payroll data/permissions."
      },
      {
        "ar": "الإجازات",
        "en": "Leave",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no leave workflow."
      },
      {
        "ar": "تقييم المعلمين",
        "en": "Teacher Evaluation",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no evaluation records/rubric."
      }
    ]
  },
  {
    "ar": "التواصل",
    "entries": [
      {
        "ar": "لوحة الإعلانات",
        "en": "Notice Board",
        "status": "implemented",
        "moduleId": "communications",
        "profile": "COM",
        "note": "working with branch/audience RLS."
      },
      {
        "ar": "إرسال رسالة",
        "en": "Send Message",
        "status": "partial",
        "moduleId": "communications",
        "profile": "COM",
        "note": "partial announcement/email only, not private messaging."
      },
      {
        "ar": "سجل الرسائل",
        "en": "Message History",
        "status": "partial",
        "moduleId": "communications",
        "profile": "COM",
        "note": "partial announcement/delivery history only."
      }
    ]
  },
  {
    "ar": "الدورات الإلكترونية",
    "entries": [
      {
        "ar": "الدورات",
        "en": "Courses",
        "status": "implemented",
        "moduleId": "courses",
        "profile": "LEARN",
        "note": "working class/teacher-scoped courses and lessons."
      },
      {
        "ar": "بنك الأسئلة",
        "en": "Question Bank",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no question bank."
      },
      {
        "ar": "الدفع دون اتصال",
        "en": "Offline Payment",
        "status": "pending",
        "moduleId": null,
        "profile": "FIN",
        "note": "pending, no offline-payment review/approval workflow."
      },
      {
        "ar": "تقرير الدورات",
        "en": "Course Report",
        "status": "partial",
        "moduleId": "reports",
        "profile": "REP",
        "note": "partial learning/homework aggregates, no dedicated course report."
      },
      {
        "ar": "امتحانات أونلاين",
        "en": "Online Examinations",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no exam-attempt backend."
      }
    ]
  },
  {
    "ar": "الحصص المباشرة",
    "entries": [
      {
        "ar": "Zoom / Google Meet",
        "en": "Live Classes",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no meeting integration or attendance."
      },
      {
        "ar": "تقرير الحصص",
        "en": "Live Class Report",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no live-class session data."
      }
    ]
  },
  {
    "ar": "السلوك",
    "entries": [
      {
        "ar": "تعيين حادث",
        "en": "Assign Incident",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no behavior-incident workflow."
      },
      {
        "ar": "سجل الحوادث",
        "en": "Incident Record",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no behavior records."
      }
    ]
  },
  {
    "ar": "الشهادات والبطاقات",
    "entries": [
      {
        "ar": "إصدار شهادة",
        "en": "Generate Certificate",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, proposed table only; no verified issuance/signature workflow."
      },
      {
        "ar": "شهادة نقل",
        "en": "Transfer Certificate",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, no transfer-certificate workflow."
      },
      {
        "ar": "بطاقة هوية",
        "en": "ID Card",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no ID-card generation."
      }
    ]
  },
  {
    "ar": "الجبهة الأمامية",
    "entries": [
      {
        "ar": "الموقع التعريفي",
        "en": "Front Website",
        "status": "pending",
        "moduleId": null,
        "profile": "CMS",
        "note": "blocked, CMS migration reconstruction is not replay-verified."
      }
    ]
  },
  {
    "ar": "الخريجون",
    "entries": [
      {
        "ar": "إدارة الخريجين",
        "en": "Manage Alumni",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, alumni schema not verified in checked-in sources."
      },
      {
        "ar": "أحداث الخريجين",
        "en": "Alumni Events",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no alumni-events backend."
      }
    ]
  },
  {
    "ar": "مركز الاستمرارية",
    "entries": [
      {
        "ar": "مركز الاستمرارية",
        "en": "Continuity Center",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no continuity module/backend."
      }
    ]
  },
  {
    "ar": "التقويم",
    "entries": [
      {
        "ar": "التقويم والمهام",
        "en": "Calendar and Tasks",
        "status": "partial",
        "moduleId": "timetable",
        "profile": "ACA",
        "note": "partial static calendar demonstration, no persisted event/task CRUD."
      }
    ]
  },
  {
    "ar": "التقارير",
    "entries": [
      {
        "ar": "تقرير الطلاب",
        "en": "Student Report",
        "status": "implemented",
        "moduleId": "reports",
        "profile": "REP",
        "note": "working enrollment/student report, RLS-scoped."
      },
      {
        "ar": "تقرير الرسوم",
        "en": "Fees Report",
        "status": "pending",
        "moduleId": null,
        "profile": "FIN",
        "note": "pending, no verified finance report UI/data in Reports."
      },
      {
        "ar": "الرسوم المتوازنة",
        "en": "Balance Fees",
        "status": "pending",
        "moduleId": null,
        "profile": "FIN",
        "note": "pending, no verified balance report."
      },
      {
        "ar": "حركات مالية",
        "en": "Financial Transactions",
        "status": "partial",
        "moduleId": "finance",
        "profile": "FIN",
        "note": "partial payment-ledger source exists, dedicated report/live data unverified."
      },
      {
        "ar": "تقرير الحضور",
        "en": "Attendance Report",
        "status": "implemented",
        "moduleId": "reports",
        "profile": "REP",
        "note": "working date-range attendance report."
      },
      {
        "ar": "درجات الامتحانات",
        "en": "Exam Marks Report",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no exam-marks backend."
      }
    ]
  },
  {
    "ar": "الرسائل الداخلية",
    "entries": [
      {
        "ar": "الرسائل",
        "en": "Messages",
        "status": "partial",
        "moduleId": "communications",
        "profile": "COM",
        "note": "partial announcements are not private/internal message threads."
      }
    ]
  },
  {
    "ar": "الطالب",
    "entries": [
      {
        "ar": "ملفي الدراسي",
        "en": "My Profile",
        "status": "partial",
        "moduleId": "profile",
        "profile": "PROFILE",
        "note": "partial real learner history/dashboard, not complete academic record/certificate view."
      },
      {
        "ar": "سيرتي الذاتية",
        "en": "My CV",
        "status": "pending",
        "moduleId": null,
        "profile": "UNI",
        "note": "pending, portfolio schema not verified in checked-in sources."
      }
    ]
  },
  {
    "ar": "ولي الأمر",
    "entries": [
      {
        "ar": "أبنائي",
        "en": "My Children",
        "status": "partial",
        "moduleId": "home",
        "profile": "PROFILE",
        "note": "working partial verified-child links; no live parent test account."
      },
      {
        "ar": "رسوم الأبناء",
        "en": "Child Fees",
        "status": "partial",
        "moduleId": "finance",
        "profile": "FIN",
        "note": "partial role-gated source, live RLS unverified."
      },
      {
        "ar": "واجب الأبناء",
        "en": "Child Homework",
        "status": "partial",
        "moduleId": "homework",
        "profile": "HW",
        "note": "partial, depends on verified-child RLS; live parent test pending."
      }
    ]
  },
  {
    "ar": "النسخ الاحتياطي",
    "entries": [
      {
        "ar": "النسخ والاستعادة",
        "en": "Backup and Restore",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no backup/restore UI; settings only describe policy."
      }
    ]
  },
  {
    "ar": "إعدادات النظام",
    "entries": [
      {
        "ar": "الإعداد العام",
        "en": "General Setting",
        "status": "pending",
        "moduleId": null,
        "profile": "SET",
        "note": "blocked, the settings table contract is not verified in checked-in migrations or against the live database."
      },
      {
        "ar": "شعار وخلفية الدخول",
        "en": "Logo/Favicon/Login Background",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no asset-setting workflow."
      },
      {
        "ar": "تطبيق الهاتف المحمول",
        "en": "Mobile App",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no mobile-app configuration service."
      },
      {
        "ar": "لوحة الطالب / الوصي",
        "en": "Student/Guardian Panel",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial generic preferences only, no dashboard configuration behavior."
      },
      {
        "ar": "مصاريف",
        "en": "Fees Settings",
        "status": "partial",
        "moduleId": null,
        "profile": "FIN",
        "note": "partial source contract only, no live validation."
      },
      {
        "ar": "إنشاء معرف تلقائي",
        "en": "ID Auto Generation",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no configurable ID policy."
      },
      {
        "ar": "نوع الحضور",
        "en": "Attendance Type",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, attendance statuses are fixed."
      },
      {
        "ar": "إعداد الجلسة",
        "en": "Session Setting",
        "status": "partial",
        "moduleId": "sessions",
        "profile": "SET",
        "note": "partial preference only; sessions are managed separately."
      },
      {
        "ar": "إعداد الإخطار",
        "en": "Notification Setting",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial preference only; no push-delivery configuration."
      },
      {
        "ar": "مراسلة واتساب",
        "en": "WhatsApp Messaging",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial preference only; no WhatsApp integration."
      },
      {
        "ar": "إعداد الرسائل القصيرة",
        "en": "SMS Setting",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial preference only; no SMS integration."
      },
      {
        "ar": "إعداد البريد الإلكتروني",
        "en": "Email Setting",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial preference only; sending requires deployed provider/Edge Function."
      },
      {
        "ar": "طرق الدفع",
        "en": "Payment Methods",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial display preferences; server validates actual payment methods."
      },
      {
        "ar": "طباعة رأس التذييل",
        "en": "Header/Footer Printing",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial fields exist; print-template integration unverified."
      },
      {
        "ar": "الطباعة الحرارية",
        "en": "Thermal Printing",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no thermal-print configuration."
      },
      {
        "ar": "إعداد CMS الأمامي",
        "en": "Front CMS Setting",
        "status": "pending",
        "moduleId": null,
        "profile": "CMS",
        "note": "blocked, reconstructed schema/policies prepared but not replay-verified; original deployed contract still missing."
      },
      {
        "ar": "تصاريح الأدوار",
        "en": "Role Permissions",
        "status": "partial",
        "moduleId": "roles",
        "profile": "ROLE",
        "note": "working partial protected role assignment, no arbitrary permission matrix."
      },
      {
        "ar": "استرجاع البيانات",
        "en": "Data Recovery",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no browser-accessible restore operation."
      },
      {
        "ar": "اللغات",
        "en": "Languages",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial locale preferences, no translation editor."
      },
      {
        "ar": "عملة",
        "en": "Currency",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial preference only; finance schema constrains transaction currency."
      },
      {
        "ar": "إضافات",
        "en": "Plugins",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial metadata only; no dynamic plugin execution/loading."
      },
      {
        "ar": "المستخدمون",
        "en": "Users",
        "status": "partial",
        "moduleId": "roles",
        "profile": "ROLE",
        "note": "partial protected account/role service; no credential exposure."
      },
      {
        "ar": "الوحدات",
        "en": "Modules",
        "status": "partial",
        "moduleId": "systemCatalog",
        "profile": "SET",
        "note": "partial preference only; enabled modules are code-controlled."
      },
      {
        "ar": "الحقول المخصصة",
        "en": "Custom Fields",
        "status": "partial",
        "moduleId": null,
        "profile": "SET",
        "note": "partial schema descriptions stored, not rendered as dynamic forms."
      },
      {
        "ar": "إعداد كلمة التحقق",
        "en": "CAPTCHA Setting",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no captcha provider/integration."
      },
      {
        "ar": "حقول النظام",
        "en": "System Fields",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no field registry/mutation workflow."
      },
      {
        "ar": "تحديث الملف التعريفي للطالب",
        "en": "Student Profile Update",
        "status": "partial",
        "moduleId": null,
        "profile": "PROFILE",
        "note": "working partial own-profile fields only."
      },
      {
        "ar": "القبول عبر الإنترنت",
        "en": "Online Admission Setting",
        "status": "partial",
        "moduleId": null,
        "profile": "PUB",
        "note": "partial RPC contract; public route/live behavior unverified."
      },
      {
        "ar": "أنواع الملفات",
        "en": "File Types",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no centralized upload/type policy UI."
      },
      {
        "ar": "قائمة الشريط الجانبي",
        "en": "Sidebar Menu",
        "status": "partial",
        "moduleId": null,
        "profile": "NAV",
        "note": "partial static role/module map, not editable in settings."
      },
      {
        "ar": "تحديث النظام",
        "en": "System Update",
        "status": "pending",
        "moduleId": null,
        "profile": "NONE",
        "note": "pending, no self-update/deployment operation."
      }
    ]
  }
];
