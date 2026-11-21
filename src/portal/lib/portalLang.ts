/**
 * Portal UI language model.
 *
 * SAI College runs one portal for nine role-based user portals. Every label that
 * belongs to the portal chrome (navigation, sections, dashboard hub, control
 * centre) is translated here so the same screen can run in Arabic, English and
 * Chinese without duplicating layout code.
 *
 * Translation order is always [Arabic, English, Chinese].
 */
export type PortalLanguage = "ar" | "en" | "zh";

export type PortalDirection = "rtl" | "ltr";

export const portalLanguages: readonly {
  id: PortalLanguage;
  label: string;
  short: string;
  dir: PortalDirection;
}[] = [
  { id: "ar", label: "العربية", short: "AR", dir: "rtl" },
  { id: "en", label: "English", short: "EN", dir: "ltr" },
  { id: "zh", label: "中文", short: "ZH", dir: "ltr" },
] as const;

type Entry = readonly [string, string, string];

export function languageIndex(language: PortalLanguage): 0 | 1 | 2 {
  if (language === "en") return 1;
  if (language === "zh") return 2;
  return 0;
}

export function directionFor(language: PortalLanguage): PortalDirection {
  return language === "ar" ? "rtl" : "ltr";
}

export function isPortalLanguage(value: string): value is PortalLanguage {
  return value === "ar" || value === "en" || value === "zh";
}

/** Reviewed module labels. Keys match the module ids in `navigation.ts`. */
export const navLabels: Record<string, Entry> = {
  home: ["الرئيسية", "Home", "首页"],
  profile: ["ملفي الشخصي", "My profile", "我的档案"],
  notifications: ["مركز الإشعارات", "Notifications", "通知中心"],
  admissions: ["القبول والتسجيل", "Admissions", "招生与注册"],
  scanner: ["ماسح إيصالات القبول", "Receipt scanner", "收据扫描"],
  students: ["سجلات الطلاب", "Student records", "学生档案"],
  classes: ["الصفوف", "Classes", "班级"],
  academics: ["الشؤون الأكاديمية", "Academic affairs", "教务管理"],
  timetable: ["الجداول والتقويم", "Timetable & calendar", "课表与日历"],
  qr: ["الحضور بالرمز QR", "QR attendance", "二维码考勤"],
  attendance: ["الحضور والمتابعة", "Attendance", "考勤追踪"],
  courses: ["المقررات والدروس", "Courses & lessons", "课程与课节"],
  listening: ["الاستماع", "Listening", "听力训练"],
  speaking: ["التحدث والنطق", "Speaking", "口语表达"],
  tones: ["النغمات الصينية", "Chinese tones", "汉语声调"],
  vocabulary: ["المفردات", "Vocabulary", "词汇"],
  handwriting: ["الكتابة اليدوية", "Handwriting", "书写练习"],
  reading: ["القراءة", "Reading", "阅读"],
  review: ["المراجعة المتباعدة", "Spaced review", "间隔复习"],
  homework: ["الواجبات", "Homework", "作业"],
  quizzes: ["الاختبارات القصيرة", "Quizzes", "随堂测验"],
  exams: ["الامتحانات", "Examinations", "考试"],
  progress: ["التقدم التعليمي", "Learning progress", "学习进度"],
  authoring: ["تأليف الدروس", "Lesson authoring", "课节编写"],
  media: ["مكتبة الوسائط", "Media library", "媒体库"],
  approvals: ["المراجعة والنشر", "Review & publish", "审核与发布"],
  staff: ["شؤون الموظفين", "Staff affairs", "人事管理"],
  reception: ["الاستقبال", "Reception", "前台接待"],
  library: ["المكتبة", "Library", "图书馆"],
  finance: ["الرسوم والمالية", "Fees & finance", "费用财务"],
  communications: ["التواصل والإعلانات", "Communications", "通讯公告"],
  branches: ["الفروع", "Branches", "校区"],
  sessions: ["الجلسات الأكاديمية", "Academic sessions", "学期"],
  reports: ["التقارير والطباعة", "Reports & printing", "报表打印"],
  cms: ["الموقع التعريفي CMS", "Website CMS", "网站内容管理"],
  roles: ["إدارة الأدوار والصلاحيات", "Roles & permissions", "角色与权限"],
  downloads: ["مركز التحميل", "Download centre", "下载中心"],
  inventory: ["المخزون", "Inventory", "库存管理"],
  transport: ["النقل", "Transport", "校车服务"],
  portfolio: ["ملف الإنجاز", "Student portfolio", "学生成长档案"],
  housing: ["السكن الطلابي", "Student housing", "学生宿舍"],
  certificates: ["الشهادات", "Certificates", "证书"],
  frontCms: ["صفحات Front CMS", "Front CMS pages", "门户页面"],
  alumni: ["الخريجون", "Alumni", "校友"],
  settings: ["إعدادات النظام", "System settings", "系统设置"],
  systemCatalog: ["جرد النظام والوحدات", "System inventory", "系统清单"],
  backups: ["النسخ الاحتياطي والاستعادة", "Backup & restore", "备份与恢复"],
  permissionsCenter: ["مصفوفة الصلاحيات المتقدمة", "Advanced permissions matrix", "高级权限矩阵"],
  sidebarManager: ["إدارة القائمة الجانبية", "Sidebar management", "侧边栏管理"],
  coverageAudit: ["تدقيق التغطية", "Coverage audit", "覆盖审计"],
};

/** Reviewed main-menu module labels. Keys match `portalRegistry.ts` module ids. */
export const moduleLabels: Record<string, Entry> = {
  dashboard: ["لوحة التحكم", "Dashboard", "控制台"],
  "front-office": ["الاستقبال والقبول", "Reception & admissions", "前台与招生"],
  "student-information": ["شؤون الطلاب", "Student information", "学生信息"],
  fees: ["تحصيل الرسوم", "Fees collection", "学费管理"],
  attendance: ["الحضور والانصراف", "Attendance", "考勤"],
  communications: ["التواصل والإعلانات", "Communications", "通讯公告"],
  organisation: ["الفروع والجلسات", "Branches & sessions", "校区与学期"],
  courses: ["المقررات الإلكترونية", "Online courses", "在线课程"],
  languages: ["اللغة الصينية", "Chinese language", "汉语学习"],
  "language-labs": ["مختبرات المهارات", "Skills labs", "技能实验室"],
  homework: ["الواجبات والتقييم", "Homework & assessment", "作业与评估"],
  examinations: ["الاختبارات والامتحانات", "Examinations", "考试管理"],
  progress: ["التقدم التعليمي", "Learning progress", "学习进度"],
  "content-studio": ["استوديو المحتوى", "Content studio", "内容工作室"],
  "academic-affairs": ["الشؤون الأكاديمية", "Academic affairs", "教务管理"],
  library: ["المكتبة", "Library", "图书馆"],
  downloads: ["مركز التحميل", "Download centre", "下载中心"],
  hr: ["الموارد البشرية", "Human resources", "人力资源"],
  reports: ["التقارير", "Reports", "报表"],
  "website-cms": ["الموقع التعريفي", "Website CMS", "网站内容管理"],
  services: ["الخدمات الطلابية", "Student services", "学生服务"],
  inventory: ["المخزون", "Inventory", "库存管理"],
  "access-control": ["الأدوار والصلاحيات", "Roles & permissions", "角色与权限"],
  system: ["النظام والنسخ الاحتياطي", "System & backups", "系统与备份"],
};

/** Reviewed sidebar submenu labels. Keys match `portalRegistry.ts` submenu ids. */
export const sectionLabels: Record<string, Entry> = {
  overview: ["نظرة عامة", "Overview", "概览"],
  account: ["الملف الشخصي", "My account", "我的账户"],
  inbox: ["مركز الإشعارات", "Notification centre", "通知中心"],
  enquiries: ["استفسارات القبول", "Admission enquiries", "招生咨询"],
  reception: ["سجل الزوار", "Reception & visitors", "前台与访客"],
  scanner: ["ماسح الإيصالات", "Receipt scanner", "收据扫描"],
  records: ["سجلات الطلاب", "Student records", "学生档案"],
  classes: ["الصفوف والشعب", "Classes & sections", "班级与分班"],
  portfolio: ["ملف الإنجاز", "Student portfolio", "成长档案"],
  collection: ["تحصيل الرسوم", "Fee collection", "学费收缴"],
  tracking: ["الحضور والمتابعة", "Attendance tracking", "考勤追踪"],
  qr: ["الحضور بالرمز QR", "QR attendance", "二维码考勤"],
  announcements: ["الإعلانات والرسائل", "Announcements", "公告消息"],
  branches: ["دليل الفروع", "Branch directory", "校区目录"],
  sessions: ["الجلسات الأكاديمية", "Academic sessions", "学期"],
  catalogue: ["المقررات والدروس", "Courses & lessons", "课程与课节"],
  vocabulary: ["المفردات", "Vocabulary", "词汇"],
  listening: ["الاستماع", "Listening", "听力"],
  speaking: ["التحدث والنطق", "Speaking", "口语"],
  tones: ["النغمات الصينية", "Chinese tones", "声调"],
  handwriting: ["الكتابة اليدوية", "Handwriting", "书写"],
  reading: ["القراءة", "Reading", "阅读"],
  review: ["المراجعة المتباعدة", "Spaced review", "间隔复习"],
  homework: ["الواجبات", "Homework", "作业"],
  quizzes: ["الاختبارات القصيرة", "Quizzes", "随堂测验"],
  exams: ["الامتحانات", "Examinations", "考试"],
  progress: ["التقدم التعليمي", "Learning progress", "学习进度"],
  authoring: ["تأليف الدروس", "Lesson authoring", "课节编写"],
  media: ["مكتبة الوسائط", "Media library", "媒体库"],
  approvals: ["المراجعة والنشر", "Review & publish", "审核与发布"],
  affairs: ["الشؤون الأكاديمية", "Academic affairs", "教务"],
  timetable: ["الجداول والتقويم", "Timetable & calendar", "课表日历"],
  library: ["المكتبة", "Library", "图书馆"],
  downloads: ["مركز التحميل", "Download centre", "下载中心"],
  staff: ["شؤون الموظفين", "Staff affairs", "人事管理"],
  reports: ["التقارير والطباعة", "Reports & printing", "报表打印"],
  cms: ["الموقع التعريفي CMS", "Website CMS", "网站内容管理"],
  frontCms: ["صفحات Front CMS", "Front CMS pages", "门户页面"],
  transport: ["النقل", "Transport", "校车"],
  housing: ["السكن الطلابي", "Student housing", "宿舍"],
  certificates: ["الشهادات", "Certificates", "证书"],
  alumni: ["الخريجون", "Alumni", "校友"],
  inventory: ["المخزون", "Inventory", "库存"],
  roles: ["إدارة الأدوار", "Role management", "角色管理"],
  settings: ["إعدادات النظام", "System settings", "系统设置"],
  catalog: ["جرد النظام", "System inventory", "系统清单"],
  backups: ["النسخ الاحتياطي", "Backup & restore", "备份恢复"],
  permissions: ["مصفوفة الصلاحيات", "Permissions matrix", "权限矩阵"],
  sidebar: ["إدارة القائمة الجانبية", "Sidebar management", "侧边栏管理"],
  coverage: ["تدقيق التغطية", "Coverage audit", "覆盖审计"],
};

/** Reviewed sidebar zone labels. Keys match `sidebarSections.ts`. */
export const zoneLabels: Record<string, Entry> = {
  daily: ["العمل اليومي", "Daily operations", "日常事务"],
  academics: ["التعليم والتعلم", "Teaching & learning", "教学与学习"],
  administration: ["الإدارة والنظام", "Administration", "行政与系统"],
};

/** Portal chrome strings. */
export const uiStrings: Record<string, Entry> = {
  appName: ["كلية ساي", "SAI College", "SAI 学院"],
  appTagline: ["الموقع التعريفي", "Public website", "学院官网"],
  portal: ["بوابة", "Portal", "门户"],
  mainMenu: ["القائمة الرئيسية", "Main menu", "主菜单"],
  quickLinks: ["روابط سريعة", "Quick links", "快捷入口"],
  searchPlaceholder: ["ابحث في أقسام البوابة", "Search portal sections", "搜索门户栏目"],
  searchNoResults: ["لا توجد أقسام مطابقة.", "No matching sections.", "没有匹配的栏目。"],
  searchHint: ["اكتب حرفين على الأقل للبحث.", "Type at least two characters.", "请输入至少两个字符。"],
  close: ["إغلاق", "Close", "关闭"],
  openMenu: ["فتح القائمة", "Open menu", "打开菜单"],
  closeMenu: ["إغلاق القائمة", "Close menu", "关闭菜单"],
  expand: ["توسيع القائمة", "Expand menu", "展开菜单"],
  collapse: ["طي القائمة", "Collapse menu", "收起菜单"],
  notifications: ["مركز الإشعارات", "Notification centre", "通知中心"],
  unreadNotifications: ["إشعارات غير مقروءة", "unread notifications", "条未读通知"],
  signOut: ["تسجيل الخروج", "Sign out", "退出登录"],
  signingOut: ["جارٍ تسجيل الخروج...", "Signing out...", "正在退出..."],
  language: ["اللغة", "Language", "语言"],
  portalLanguage: ["لغة البوابة", "Portal language", "门户语言"],
  navLabel: ["التنقل الرئيسي", "Main navigation", "主导航"],
  brandSubtitle: ["بوابة موحدة", "Unified portal", "统一门户"],
  directory: ["دليل الوحدات", "Module directory", "模块总览"],
  directoryTitle: ["دليل الوحدات", "Module directory", "模块总览"],
  directoryIntro: [
    "كل وحدة متاحة لدورك في مكان واحد، مصنفة بحسب القسم. لا تظهر إلا الوحدات المفعّلة والمسموح بها.",
    "Every module available to your role in one place, grouped by section. Only enabled and permitted modules appear.",
    "按栏目汇总当前角色可用的全部模块。仅显示已启用且已授权的模块。",
  ],
  controlCenter: ["مركز التحكم العام", "Control centre", "总控制中心"],
  controlCenterTitle: ["مركز التحكم العام", "Super Admin Control Centre", "超级管理员控制中心"],
  controlCenterIntro: [
    "نظرة موحدة على الوحدات والأدوار والصلاحيات وحالة النظام لكل من الموقع وتطبيق الجوال.",
    "A single view of modules, roles, permissions and system health across web and mobile.",
    "统一查看网站与移动端的模块、角色、权限与系统状态。",
  ],
  modulesAvailable: ["وحدات مفعّلة", "Enabled modules", "已启用模块"],
  rolesCount: ["أدوار معتمدة", "Approved roles", "已批准角色"],
  pendingCount: ["وحدات قيد التجهيز", "Modules pending", "待上线模块"],
  alwaysOnCount: ["وحدات أساسية", "Always on", "常驻模块"],
  roleCoverage: ["تغطية الأدوار", "Role coverage", "角色覆盖"],
  moduleAccess: ["مصفوفة الوصول", "Access matrix", "权限矩阵"],
  pendingModules: ["وحدات بانتظار الأساس", "Modules awaiting foundation", "等待基础设施的模块"],
  quickActions: ["إجراءات سريعة", "Quick actions", "快捷操作"],
  manageRoles: ["إدارة الأدوار", "Manage roles", "管理角色"],
  manageToggles: ["تفعيل الوحدات", "Module toggles", "模块开关"],
  systemSettings: ["إعدادات النظام", "System settings", "系统设置"],
  systemInventory: ["جرد النظام", "System inventory", "系统清单"],
  backups: ["النسخ الاحتياطي", "Backups", "备份"],
  auditLog: ["سجل التدقيق", "Audit log", "审计日志"],
  viewAll: ["عرض الكل", "View all", "查看全部"],
  module: ["وحدة", "module", "个模块"],
  modules: ["وحدات", "modules", "个模块"],
  role: ["دور", "role", "个角色"],
  roles: ["أدوار", "roles", "个角色"],
  noAccess: ["لا توجد وحدات متاحة لهذا الدور.", "No modules are available for this role.", "该角色暂无可用的模块。"],
  restricted: ["الوصول غير متاح", "Access unavailable", "无访问权限"],
  restrictedBody: [
    "مركز التحكم العام متاح للمسؤول العام ومدير الأكاديمية فقط.",
    "The control centre is available to the super administrator and academy administrator only.",
    "总控制中心仅限超级管理员与学院管理员访问。",
  ],
  backHome: ["العودة للرئيسية", "Back to dashboard", "返回控制台"],
  globalToggleNote: [
    "التعطيل العام يسبق كل تخصيصات الأدوار، فلا يمكن لأي دور إعادة تفعيل وحدة معطّلة عامةً.",
    "A global disable always wins over per-role overrides, so no role can re-enable a globally disabled module.",
    "全局停用优先于任何角色覆盖，任何角色都无法重新启用已全局停用的模块。",
  ],
  multiRoleNote: [
    "الحساب متعدد الأدوار يرى اتحاد وحدات أدواره؛ وتُخفى الوحدة فقط عندما تمنعها كل أدواره.",
    "A multi-role account sees the union of its roles; a module is hidden only when every role denies it.",
    "多角色账户可见其角色的并集；仅当所有角色都拒绝时才隐藏模块。",
  ],
  globalRuleTitle: ["قاعدة التعطيل العام", "Global disable rule", "全局停用规则"],
  multiRoleTitle: ["قاعدة الحساب متعدد الأدوار", "Multi-role rule", "多角色规则"],
  alwaysOnNote: ["وحدات محمية لا يمكن تعطيلها", "Protected modules that cannot be disabled", "受保护的常驻模块"],
  rolePortal: ["بوابة", "portal", "门户"],
  signedInAs: ["الحساب", "Signed in as", "当前账户"],
  website: ["الموقع التعريفي", "Public website", "学院官网"],
  skipToContent: ["انتقل إلى المحتوى", "Skip to content", "跳到内容"],
  mainModule: ["الوحدة الرئيسية", "Main module", "主模块"],
  submenu: ["القائمة الفرعية", "Submenu", "子菜单"],
  pendingBadge: ["قيد التجهيز", "Pending", "待上线"],
  moduleCount: ["وحدات", "modules", "个模块"],
  sectionsCount: ["أقسام", "sections", "个栏目"],
  activePortal: ["البوابة النشطة", "Active portal", "当前门户"],
  permissionsTitle: ["مصفوفة الأدوار والصلاحيات", "Roles & permissions matrix", "角色与权限矩阵"],
  permissionsIntro: [
    "حرّر صلاحيات كل دور على مستوى كل وحدة: الإجراءات المسموحة ونطاق السجلات، مع معاينة فعالة قبل الحفظ.",
    "Edit every role's permissions per module — allowed actions and record scope — with an effective preview before saving.",
    "按模块编辑每个角色的权限（允许的操作与记录范围），保存前可预览有效权限。",
  ],
  sidebarTitle: ["إدارة القائمة الجانبية", "Sidebar management centre", "侧边栏管理中心"],
  sidebarIntro: [
    "تحكم مركزي بترتيب الوحدات وإظهارها وتسمياتها وأيقوناتها والروابط السريعة، مع معاينة لكل بوابة ولغة.",
    "Central control of module order, visibility, labels, icons and quick links, with a preview for every portal and language.",
    "集中管理模块排序、显示、标签、图标与快捷入口，并可预览每个门户与语言。",
  ],
  coverageTitle: ["تدقيق تغطية الوحدات الأربعين", "Forty-module coverage audit", "四十模块覆盖审计"],
  coverageIntro: [
    "مطابقة كل متطلب من متطلبات النسخة الرئيسية V2.0 مع الوحدة المنفّذة وحالتها الفعلية للاختبار والنشر.",
    "Reconciles every V2.0 master requirement against the implementing module and its actual test and deployment status.",
    "将 V2.0 主清单的每项要求与实现模块及其测试、部署实际状态逐项对照。",
  ],
  save: ["حفظ التغييرات", "Save changes", "保存更改"],
  saving: ["جارٍ الحفظ...", "Saving...", "保存中..."],
  reset: ["إرجاع للافتراضي", "Reset", "重置"],
  unsaved: ["تغييرات غير محفوظة", "Unsaved changes", "未保存更改"],
  savedAt: ["تم الحفظ", "Saved", "已保存"],
  changeSummary: ["ملخص التغييرات", "Change summary", "更改摘要"],
  auditHistory: ["سجل التدقيق", "Audit history", "审计历史"],
  actions: ["الإجراءات", "Actions", "操作"],
  scope: ["نطاق السجلات", "Record scope", "记录范围"],
  effectivePreview: ["المعاينة الفعالة", "Effective preview", "有效预览"],
  selectRole: ["اختر الدور", "Select role", "选择角色"],
  searchModules: ["ابحث في الوحدات", "Search modules", "搜索模块"],
  expandAll: ["توسيع الكل", "Expand all", "全部展开"],
  collapseAll: ["طي الكل", "Collapse all", "全部收起"],
  sensitiveConfirm: ["تأكيد التغييرات الحساسة", "Confirm sensitive changes", "确认敏感更改"],
  confirm: ["تأكيد", "Confirm", "确认"],
  cancel: ["إلغاء", "Cancel", "取消"],
  status: ["الحالة", "Status", "状态"],
  requirement: ["المتطلب", "Requirement", "要求"],
  dataSource: ["مصدر البيانات", "Data source", "数据源"],
  testStatus: ["الاختبار", "Tests", "测试"],
  deployStatus: ["النشر", "Deployment", "部署"],
  group: ["المجموعة", "Group", "分组"],
  hideModule: ["إخفاء من القائمة", "Hide from menu", "从菜单隐藏"],
  showModule: ["إظهار في القائمة", "Show in menu", "在菜单显示"],
  moveUp: ["تحريك لأعلى", "Move up", "上移"],
  moveDown: ["تحريك لأسفل", "Move down", "下移"],
  quickLink: ["رابط سريع", "Quick link", "快捷入口"],
  labelsAr: ["التسمية العربية", "Arabic label", "阿拉伯语标签"],
  labelsEn: ["التسمية الإنجليزية", "English label", "英语标签"],
  labelsZh: ["التسمية الصينية", "Chinese label", "中文标签"],
  icon: ["الأيقونة", "Icon", "图标"],
  preview: ["معاينة", "Preview", "预览"],

  /* ---- Portal shell / auth states ---- */
  checkingAccount: ["جارٍ التحقق من الحساب", "Checking your account", "正在验证账户"],
  checkingAccountBody: [
    "يرجى الانتظار أثناء تحميل الجلسة والبيانات.",
    "Please wait while your session and permissions load.",
    "正在加载会话与权限，请稍候。",
  ],
  accountLoadFailed: ["تعذر تحميل بيانات الحساب", "Could not load your account", "无法加载账户信息"],
  profileUnavailable: ["الملف الشخصي غير متاح", "Profile unavailable", "档案不可用"],
  profileUnavailableBody: [
    "لم يتم العثور على ملفك الشخصي أو لا تسمح سياسات الوصول بعرضه. تواصل مع مسؤول النظام.",
    "Your profile was not found or access policies do not allow it to be shown. Contact your system administrator.",
    "未找到您的档案，或访问策略不允许显示。请联系系统管理员。",
  ],
  accessUnavailableTitle: ["الوصول غير متاح", "Access unavailable", "无访问权限"],
  accessUnavailableBody: [
    "لوحة الإدارة غير متاحة لأدوار حسابك.",
    "The administration dashboard is not available for your account roles.",
    "您的账户角色无法访问管理控制台。",
  ],
  pageNotFoundTitle: ["الصفحة غير موجودة", "Page not found", "页面不存在"],
  pageNotFoundBody: ["العنوان المطلوب غير متاح.", "The requested address is not available.", "请求的地址不可用。"],
  loadingPortalSettings: ["جارٍ تحميل إعدادات اللوحة", "Loading portal settings", "正在加载门户设置"],
  loadingPortalSettingsBody: [
    "يتم تجهيز حالة تفعيل الوحدات قبل عرض اللوحة.",
    "Module availability is being prepared before the portal opens.",
    "正在准备模块启用状态，随后打开门户。",
  ],
  signOutFailed: ["تعذر تسجيل الخروج", "Could not sign out", "无法退出登录"],
  noRoleYetTitle: ["لا يوجد دور بعد", "No role assigned yet", "尚未分配角色"],
  noRoleYetBody: [
    "سيظهر محتوى لوحتك بعد اعتماد دورك من الإدارة.",
    "Your dashboard content appears once administration approves your role.",
    "管理员批准您的角色后，控制台内容将显示。",
  ],
  accountNotIdentified: ["تعذر تحديد الحساب", "Could not identify the account", "无法识别账户"],
  accountNotIdentifiedBody: [
    "أعد تسجيل الدخول للوصول إلى لوحتك.",
    "Sign in again to reach your dashboard.",
    "请重新登录以访问您的控制台。",
  ],

  /* ---- Staff dashboard ---- */
  adminEyebrow: ["الإدارة والأكاديمية", "Administration & academics", "行政与教务"],
  dashboardIntro: [
    "نظرة سريعة على الطلاب والصفوف وطلبات القبول الجديدة.",
    "A quick view of students, classes and new admission enquiries.",
    "快速查看学生、班级与最新招生咨询。",
  ],
  reportsAndReminders: ["التقارير والتذكيرات", "Reports & reminders", "报表与提醒"],
  refresh: ["تحديث", "Refresh", "刷新"],
  loadingAcademics: ["جارٍ تحميل بيانات الأكاديمية...", "Loading academic data...", "正在加载教务数据..."],
  dashboardLoadFailed: ["تعذر تحميل بيانات اللوحة", "Could not load dashboard data", "无法加载控制台数据"],
  retry: ["إعادة المحاولة", "Retry", "重试"],
  kpiActiveStudents: ["الطلاب النشطون", "Active students", "在读学生"],
  kpiActiveStudentsNote: ["السجلات النشطة المتاحة لحسابك", "Active records available to your account", "您账户可用的在读记录"],
  kpiRunningClasses: ["الصفوف النشطة", "Active classes", "开课班级"],
  kpiRunningClassesNote: ["شعب مفتوحة في الجلسات المسموحة", "Sections open in permitted sessions", "允许学期内已开班的分班"],
  kpiNewEnquiries: ["طلبات قبول جديدة", "New admission enquiries", "新招生咨询"],
  kpiNewEnquiriesNote: ["بانتظار أول تواصل", "Awaiting first contact", "等待首次联系"],
  kpiBranches: ["الفروع", "Branches", "校区"],
  kpiSessionsNote: ["{count} جلسة أكاديمية", "{count} academic sessions", "{count} 个学期"],
  latestEnquiries: ["أحدث طلبات القبول", "Latest admission enquiries", "最新招生咨询"],
  openAdmissionsWorkspace: ["فتح مساحة القبول", "Open admissions workspace", "打开招生工作区"],
  noEnquiries: ["لا توجد طلبات قبول متاحة لحسابك بعد.", "No admission enquiries are available to your account yet.", "您的账户暂无招生咨询记录。"],
  programUnspecified: ["برنامج غير محدد", "Programme not specified", "未指定课程"],
  branchesAndSessions: ["الفروع والجلسات", "Branches & sessions", "校区与学期"],
  manageBranches: ["إدارة الفروع", "Manage branches", "管理校区"],
  branchesLabel: ["الفروع", "Branches", "校区"],
  noBranches: ["لا توجد فروع متاحة.", "No branches are available.", "暂无可用校区。"],
  academicSessionsLabel: ["الجلسات الأكاديمية", "Academic sessions", "学期"],
  noSessions: ["لا توجد جلسات متاحة.", "No sessions are available.", "暂无可用学期。"],
  sectionsOccupancy: ["شعب الصفوف والإشغال", "Sections & occupancy", "分班与容量"],
  manageClasses: ["إدارة الصفوف", "Manage classes", "管理班级"],
  sectionsOccupancyNote: [
    "عدد المسجلين لكل شعبة من الطلاب النشطين، مقارنة بالسعة المعتمدة.",
    "Enrolled active students per section compared with the approved capacity.",
    "每个分班的在读学生人数与核定容量对比。",
  ],
  noSections: ["لا توجد شعب متاحة لحسابك بعد.", "No sections are available to your account yet.", "您的账户暂无可用分班。"],
  thSection: ["الشعبة", "Section", "分班"],
  thProgram: ["البرنامج", "Programme", "课程"],
  thBranch: ["الفرع", "Branch", "校区"],
  thOccupancy: ["الإشغال", "Occupancy", "容量"],
  thAttendance: ["الحضور", "Attendance", "考勤"],
  attendanceRegister: ["سجل الحضور", "Attendance register", "考勤登记"],
  inactive: ["غير نشطة", "inactive", "未启用"],

  /* ---- Super admin overview ---- */
  superAdminEyebrow: ["إشراف الإدارة العامة", "General administration oversight", "综合管理监督"],
  superAdminTitle: ["مؤشرات النظام من الخدمات المعتمدة", "System indicators from approved services", "来自已批准服务的系统指标"],
  systemInventoryLink: ["جرد الوحدات", "Module inventory", "模块清单"],
  refreshIndicators: ["تحديث المؤشرات", "Refresh indicators", "刷新指标"],
  superAdminNote: [
    "الأعداد تُقرأ من ملخص Edge Function المخصص للمسؤول العام. لا تمثل حالات الإكمال التاريخية إتقاناً موثقاً، ومسارات الوسائط المسجلة لا تثبت وجود الملف في التخزين.",
    "Counts are read from the super administrator summary service. Historical completion states are not verified mastery, and stored media paths do not prove the file exists in storage.",
    "数据来自超级管理员汇总服务。历史完成状态不代表已核实掌握程度，记录的媒体路径也不证明文件已存在于存储中。",
  ],
  loadingIndicators: ["جارٍ تحميل مؤشرات النظام...", "Loading system indicators...", "正在加载系统指标..."],
  indicatorsLoadFailed: ["تعذر تحميل مؤشرات النظام", "Could not load system indicators", "无法加载系统指标"],
  groupAccountsIdentity: ["الحسابات والهوية", "Accounts & identity", "账户与身份"],
  groupStudentsAcademics: ["الطلاب والأكاديميا", "Students & academics", "学生与教务"],
  groupLearningAssessment: ["التعلّم والتقييم", "Learning & assessment", "学习与评估"],
  groupContentReadiness: ["جاهزية المحتوى والتنبيهات التشغيلية", "Content readiness & operational alerts", "内容就绪与运行提醒"],
  operationalAlerts: ["تنبيهات تحتاج متابعة", "Alerts needing follow-up", "待跟进提醒"],
  reviewAction: ["مراجعة", "Review", "查看"],
  noAlerts: ["لا توجد تنبيهات في المؤشرات المعروضة.", "No alerts in the displayed indicators.", "所显示指标中暂无提醒。"],
  assetPathNote: [
    "توجد {count} إحالات لمسارات ملفات؛ لم يتحقق هذا الملخص من وجود الملفات فعلياً في Storage.",
    "There are {count} stored media path references; this summary did not verify the files exist in storage.",
    "共有 {count} 条媒体路径引用；本汇总未核实文件是否真实存在于存储中。",
  ],
  unreadForAccount: ["الإشعارات غير المقروءة لهذا الحساب", "Unread notifications for this account", "本账户未读通知"],
  openNotifications: ["فتح الإشعارات", "Open notifications", "打开通知"],
  loadingNotifications: ["جارٍ تحميل الإشعارات...", "Loading notifications...", "正在加载通知..."],
  notificationsLoadFailed: ["تعذر تحميل الإشعارات", "Could not load notifications", "无法加载通知"],
  unreadSuffix: ["غير مقروءة", "unread", "条未读"],
  notificationsScopeNote: [
    "هذا العدد خاص بحساب المسؤول العام الحالي، وليس إجمالي إشعارات جميع المستخدمين.",
    "This count belongs to the current super administrator account, not all users combined.",
    "此计数仅属当前超级管理员账户，而非全部用户。",
  ],
  mediaLimitsTitle: ["حدود مؤشرات الوسائط والتقييم", "Media & assessment indicator limits", "媒体与评估指标限制"],
  reviewCourses: ["مراجعة المقررات", "Review courses", "查看课程"],
  mediaLimitBody1: [
    "المهام المصححة هي تسليمات واجبات موجودة؛ لا يوجد بنك امتحانات أو إحصاء موثوق لمحاولات اختبارات في العقد الحالي.",
    "Graded tasks are existing homework submissions; there is no exam bank or reliable attempt statistics in the current contract.",
    "已批改任务来自现有作业提交；当前契约中没有题库或可靠的考试尝试统计。",
  ],
  mediaLimitBody2: [
    "مسارات الملفات مؤشرات مرجعية فقط. يلزم فحص وجود كائنات التخزين المصرح بها قبل وصف الوسائط بأنها جاهزة.",
    "File paths are reference indicators only. Authorised storage objects must be verified before media can be described as ready.",
    "文件路径仅为参考指标。在将媒体描述为就绪前，必须核实已授权的存储对象。",
  ],
  manageAccountsRoles: ["إدارة الحسابات والأدوار", "Manage accounts & roles", "管理账户与角色"],
  reports: ["التقارير", "Reports", "报表"],
  metricTotalUsers: ["إجمالي حسابات الدخول", "Total sign-in accounts", "登录账户总数"],
  metricEmailConfirmed: ["حسابات مؤكدة البريد", "Email-confirmed accounts", "邮箱已确认账户"],
  metricPendingEmail: ["بانتظار تأكيد البريد", "Awaiting email confirmation", "等待邮箱确认"],
  metricBanned: ["حسابات موقوفة مؤقتاً", "Suspended accounts", "已停用账户"],
  metricNoRoles: ["حسابات بلا أدوار", "Accounts without roles", "未分配角色账户"],
  metricProfiles: ["ملفات المستخدمين", "User profiles", "用户档案"],
  metricRoleAssignments: ["إسنادات الأدوار", "Role assignments", "角色分配"],
  metricTeachers: ["حسابات بدور معلم", "Teacher accounts", "教师账户"],
  metricStudents: ["إجمالي الطلاب", "Total students", "学生总数"],
  metricActiveStudents: ["الطلاب النشطون", "Active students", "在读学生"],
  metricStudentsWithoutAccounts: ["طلاب بلا حساب مرتبط", "Students without a linked account", "未关联账户的学生"],
  metricActiveClasses: ["الصفوف النشطة", "Active classes", "开课班级"],
  metricClassesWithoutTeachers: ["صفوف بلا معلم مسند", "Classes without a teacher", "未分配教师的班级"],
  metricCourses: ["إجمالي المقررات", "Total courses", "课程总数"],
  metricActiveCourses: ["المقررات النشطة", "Active courses", "在用课程"],
  metricLessons: ["إجمالي الدروس", "Total lessons", "课节总数"],
  metricPublishedLessons: ["الدروس المنشورة", "Published lessons", "已发布课节"],
  metricLessonProgress: ["حالات تعلم قيد الدراسة", "Learning states in progress", "进行中的学习状态"],
  metricLegacyProgress: ["حالات إكمال تاريخية غير متحققة", "Unverified historical completions", "未核实的历史完成"],
  metricHomeworkPending: ["تسليمات بانتظار التصحيح", "Submissions awaiting grading", "待批改提交"],
  metricHomeworkGraded: ["تسليمات صُححت", "Graded submissions", "已批改提交"],
  metricPendingAdmissions: ["طلبات قبول جديدة", "New admission enquiries", "新招生咨询"],
  metricLessonAssets: ["دروس لها مسارات وسائط مسجلة", "Lessons with stored media paths", "含媒体路径的课节"],
  metricLessonsMissingContent: ["دروس بلا محتوى مسجل", "Lessons without recorded content", "无内容记录的课节"],
  metricActiveEnrollments: ["طلاب نشطون مسندون إلى صف", "Active students assigned to a class", "已分班的在读学生"],
  alertPendingAdmissions: ["طلبات قبول جديدة تنتظر التواصل", "New admission enquiries awaiting contact", "新招生咨询等待联系"],
  alertHomeworkPending: ["تسليمات واجبات تنتظر التصحيح", "Homework submissions awaiting grading", "待批改的作业提交"],
  alertClassesWithoutTeachers: ["صفوف نشطة بلا معلم مسند", "Active classes without a teacher", "未分配教师的开课班级"],
  alertStudentsWithoutAccounts: ["سجلات طلاب نشطة بلا حساب مرتبط", "Active student records without a linked account", "未关联账户的在读学生记录"],
  alertUsersWithoutRoles: ["حسابات دخول بلا دور", "Sign-in accounts without a role", "未分配角色的登录账户"],
  alertPendingEmail: ["حسابات بانتظار تأكيد البريد", "Accounts awaiting email confirmation", "等待邮箱确认的账户"],
  alertLessonsMissingContent: ["دروس بلا محتوى مسجل", "Lessons without recorded content", "无内容记录的课节"],

  /* ---- Operations dashboard ---- */
  opsEyebrow: ["الإدارة العامة", "General administration", "综合管理"],
  opsIntro: ["نظرة على بيانات الأكاديمية في النطاق المحدد.", "An overview of academic data in the selected scope.", "查看指定范围内的教务数据。"],
  refreshData: ["تحديث البيانات", "Refresh data", "刷新数据"],
  branchLabel: ["الفرع", "Branch", "校区"],
  noBranchesOption: ["لا توجد فروع متاحة", "No branches available", "暂无可用校区"],
  sessionLabel: ["الجلسة الأكاديمية", "Academic session", "学期"],
  noSessionsOption: ["لا توجد جلسات متاحة", "No sessions available", "暂无可用学期"],
  activeSuffix: ["نشطة", "active", "进行中"],
  loadingBranches: ["جارٍ تحميل الفروع والجلسات...", "Loading branches and sessions...", "正在加载校区与学期..."],
  branchesLoadFailed: ["تعذر تحميل الفروع أو الجلسات", "Could not load branches or sessions", "无法加载校区或学期"],
  noScopeNotice: [
    "لا توجد فروع أو جلسات متاحة لحسابك. قد تمنع سياسات الوصول عرض السجلات؛ تحقق مع مسؤول النظام.",
    "No branches or sessions are available to your account. Access policies may block record visibility; check with your system administrator.",
    "您的账户没有可用校区或学期。访问策略可能限制记录显示，请联系系统管理员。",
  ],
  kpiActiveBranches: ["الفروع النشطة", "Active branches", "启用校区"],
  kpiActiveBranchesNote: ["الفروع المتاحة لحسابك", "Branches available to your account", "您账户可用的校区"],
  kpiActiveStudentsShort: ["الطلاب النشطون", "Active students", "在读学生"],
  kpiActiveStudentsShortNote: ["المسجلون في صفوف الفرع والجلسة", "Enrolled in the branch and session classes", "已在校区与学期班级注册"],
  kpiClasses: ["الصفوف", "Classes", "班级"],
  kpiClassesNote: ["جميع صفوف الفرع والجلسة المحددين", "All classes in the selected branch and session", "所选校区与学期的全部班级"],
  kpiAwaitingContact: ["بانتظار أول تواصل", "Awaiting first contact", "等待首次联系"],
  kpiAwaitingContactNote: [
    "طلبات «جديد» أقدم من ثلاثة أيام في الفرع المحدد",
    "New enquiries older than three days in the selected branch",
    "所选校区中超过三天未处理的“新”咨询",
  ],
  viewOverdue: ["عرض الطلبات المتأخرة", "View overdue enquiries", "查看逾期咨询"],
  kpiActiveSession: ["الجلسة النشطة", "Active session", "当前学期"],
  kpiActiveSessionNote: ["الجلسة المختارة", "The selected session", "所选学期"],
  noActiveSession: ["لا توجد جلسة نشطة محددة", "No active session selected", "未选择进行中的学期"],
  loadingDashboard: ["جارٍ تحميل بيانات اللوحة...", "Loading dashboard data...", "正在加载控制台数据..."],
  retryDashboard: ["إعادة محاولة تحميل اللوحة", "Retry loading the dashboard", "重新加载控制台"],
  figuresNote: [
    "تعرض الأرقام السجلات التي تسمح بها سياسات الوصول فقط. لا تعني النتيجة الفارغة بالضرورة عدم وجود بيانات.",
    "Figures show only the records access policies allow. An empty result does not necessarily mean no data exists.",
    "数字仅显示访问策略允许的记录。空结果不一定代表没有数据。",
  ],
  pendingSections: ["أقسام قيد التجهيز", "Sections in preparation", "准备中的栏目"],
  pendingSectionsNote: [
    "هذه الأقسام لا تظهر في القائمة حتى يكتمل أساسها في قاعدة البيانات، حتى لا يظهر أي زر لا يعمل.",
    "These sections stay out of the menu until their database foundation is complete, so no button is ever shown that does not work.",
    "这些栏目在数据库基础完成前不会出现在菜单中，避免出现无法使用的按钮。",
  ],
  allModulesComplete: [
    "كل الوحدات المخطط لها مفعّلة ومُتحقق منها بعد إنجاز النسخة V4.0.",
    "All planned modules are enabled and verified as of the V4.0 release.",
    "V4.0 发布后，全部计划模块均已启用并核实。",
  ],
  admissionsGlance: ["نظرة على القبول", "Admissions at a glance", "招生概览"],
  awaitingFirstContact: ["طلب بانتظار أول تواصل", "enquiries awaiting first contact", "条咨询等待首次联系"],
  awaitingFirstContactNote: [
    "ما زالت في حالة «جديد» منذ أكثر من ثلاثة أيام دون تسجيل أي تواصل.",
    "Still in “new” status for more than three days with no contact recorded.",
    "仍为“新”状态超过三天且未记录任何联系。",
  ],
  calculatingOverdue: ["جارٍ حساب الطلبات المتأخرة...", "Calculating overdue enquiries...", "正在计算逾期咨询..."],
  overdueCalcFailed: ["تعذر حساب الطلبات المتأخرة", "Could not calculate overdue enquiries", "无法计算逾期咨询"],
  openFilteredList: ["فتح القائمة المصفّاة", "Open filtered list", "打开筛选列表"],
  admissionsWorkspace: ["مساحة القبول", "Admissions workspace", "招生工作区"],
  reminderTitle: ["تذكيرات الطلبات المتأخرة", "Overdue enquiry reminders", "逾期咨询提醒"],
  reminderNote: [
    "تشغّل نفس المهمة التي تعمل تلقائيًا كل صباح: رسالة للمتقدم وملخص لفريق القبول. لا يتلقى أي طلب تذكيرًا أكثر من مرة.",
    "Runs the same job that executes every morning: a message to the applicant and a summary for the admissions team. No enquiry is reminded more than once.",
    "运行每日早晨的同一任务：向申请人发送消息，并向招生团队发送汇总。每条咨询只提醒一次。",
  ],
  runReminders: ["تشغيل التذكيرات الآن", "Run reminders now", "立即运行提醒"],
  runningReminders: ["جارٍ تشغيل التذكيرات...", "Running reminders...", "正在运行提醒..."],
  upcomingLessons: ["الحصص القادمة", "Upcoming lessons", "近期课节"],
  upcomingLessonsBody: [
    "يتوفر الآن جدول الحصص الأسبوعي وتقويم الاختبارات والفعاليات لكل شعبة.",
    "The weekly timetable and the exam and event calendar are now available for every section.",
    "每个分班的周课表与考试、活动日历均已可用。",
  ],
  viewTimetable: ["عرض الجدول والتقويم", "View timetable & calendar", "查看课表与日历"],
  qrAttendance: ["الحضور بالرمز QR", "QR attendance", "二维码考勤"],
  recentAudit: ["آخر أحداث التدقيق غير المتحقق منها", "Latest unverified audit events", "最新未核实审计事件"],
  auditNote: [
    "سجل عام غير مصنف حسب الفرع أو الجلسة؛ قد يتضمن معلومات مزورة ولا يثبت وقوع الأحداث المعروضة.",
    "A global log not scoped by branch or session; it may contain falsified entries and does not prove the events shown occurred.",
    "未按校区或学期划分的全局日志；可能包含伪造条目，且不能证明所显示事件已发生。",
  ],
  loadingAudit: ["جارٍ تحميل سجل التدقيق...", "Loading audit log...", "正在加载审计日志..."],
  auditLoadFailed: ["تعذر تحميل سجل التدقيق", "Could not load the audit log", "无法加载审计日志"],
  selectScope: ["اختر فرعاً وجلسة لعرض اللوحة.", "Select a branch and session to view the dashboard.", "请选择校区与学期以查看控制台。"],
  noAuditEvents: ["لا توجد أحداث متاحة لهذا الحساب.", "No events are available to this account.", "该账户暂无可用事件。"]
};

/** Admission enquiry status labels. Keys match `admissionStatuses` in `admissions.ts`. */
export const statusLabels: Record<string, Entry> = {
  new: ["جديد", "New", "新"] ,
  contacted: ["تم التواصل", "Contacted", "已联系"],
  assessment: ["اختبار القبول", "Assessment", "入学测评"],
  accepted: ["مقبول", "Accepted", "已录取"],
  enrolled: ["مسجل", "Enrolled", "已注册"],
  rejected: ["مرفوض", "Rejected", "未录取"],
  withdrawn: ["منسحب", "Withdrawn", "已撤回"],
};

function pick(entry: Entry | undefined, language: PortalLanguage, fallback: string): string {
  if (!entry) return fallback;
  return entry[languageIndex(language)] || fallback;
}

export function translateUi(language: PortalLanguage, key: string): string {
  return pick(uiStrings[key], language, key);
}

export function translateNav(language: PortalLanguage, id: string, fallback: string): string {
  return pick(navLabels[id], language, fallback);
}

export function translateModule(language: PortalLanguage, id: string, fallback: string): string {
  return pick(moduleLabels[id], language, fallback);
}

export function translateSection(language: PortalLanguage, id: string, fallback: string): string {
  return pick(sectionLabels[id], language, fallback);
}

export function translateZone(language: PortalLanguage, id: string, fallback: string): string {
  return pick(zoneLabels[id], language, fallback);
}

export function translateStatus(language: PortalLanguage, id: string, fallback: string): string {
  return pick(statusLabels[id], language, fallback);
}