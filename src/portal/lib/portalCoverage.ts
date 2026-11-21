/**
 * Master coverage registry — the 40 categories required by the V2.0 master
 * execution prompt, reconciled against the live hierarchical registry.
 *
 * This is an audit catalogue, not a navigation source. Each requirement records
 * which main module owns it, the operational zone, the reviewed submenus, the
 * permission that gates it, the record scope the backend enforces, and its real
 * implementation / test / deployment status. Several original categories are
 * consolidated into one reviewed module, so the count of modules is not the
 * measure of coverage — every requirement must be accounted for here.
 */
import type { PortalZoneId } from "./portalRegistry";

export type CoverageStatus =
  | "completed"
  | "implemented_unverified"
  | "partial"
  | "pending"
  | "blocked";

export type CoverageGroup = "academic" | "operations" | "specialised";

export type CoverageRequirement = {
  /** Original requirement number from the master prompt (01–40). */
  id: string;
  group: CoverageGroup;
  nameAr: string;
  nameEn: string;
  nameZh: string;
  zone: PortalZoneId;
  /** Owning main module id from portalRegistry. */
  parentModuleId: string;
  /** Reviewed submenu ids from portalRegistry that implement this requirement. */
  submenus: readonly string[];
  /** Primary functional route (page module id), or null when blocked. */
  route: string | null;
  /** Module action that gates the requirement. */
  permission: string;
  /** Record scope enforced by the backend for this requirement. */
  scope: string;
  /** Supabase data source (tables / functions / storage). */
  dataSource: string;
  status: CoverageStatus;
  testStatus: "passing" | "partial" | "not_started";
  deployStatus: "live" | "staged" | "not_deployed";
  /** Consolidation or dependency note (empty when none). */
  note?: string;
};

export const coverageGroups: readonly { id: CoverageGroup; labelAr: string; labelEn: string; labelZh: string }[] = [
  { id: "academic", labelAr: "الإدارة الأكاديمية والإدارية", labelEn: "Academic & administrative management", labelZh: "学术与行政管理" },
  { id: "operations", labelAr: "العمليات المؤسسية", labelEn: "Institutional operations", labelZh: "机构运营" },
  { id: "specialised", labelAr: "وحدات كلية ساي المتخصصة", labelEn: "Yemen SAI specialised modules", labelZh: "SAI 学院特色模块" },
];

const req = (row: CoverageRequirement): CoverageRequirement => row;

/**
 * All 40 master categories. Status reflects verified implementation only — a
 * page existing is never treated as complete on its own.
 */
export const coverageRequirements: readonly CoverageRequirement[] = [
  // ------------------------------------------------ academic & administrative
  req({ id: "01", group: "academic", nameAr: "لوحة التحكم", nameEn: "Dashboard", nameZh: "控制台", zone: "daily", parentModuleId: "dashboard", submenus: ["overview"], route: "home", permission: "view", scope: "own_records", dataSource: "profiles, user_roles, dashboard RPCs", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "02", group: "academic", nameAr: "الاستقبال والواجهة", nameEn: "Front Office", nameZh: "前台接待", zone: "daily", parentModuleId: "front-office", submenus: ["enquiries", "reception", "scanner"], route: "admissions", permission: "create", scope: "branch", dataSource: "admissions_enquiries, admission events, reception workspace", status: "completed", testStatus: "passing", deployStatus: "live", note: "Visitor, call, appointment, correspondence and complaint registers are wired on the reception module with duplicate detection and admission conversion." }),
  req({ id: "03", group: "academic", nameAr: "معلومات الطلاب", nameEn: "Student Information", nameZh: "学生信息", zone: "daily", parentModuleId: "student-information", submenus: ["records", "classes", "portfolio"], route: "students", permission: "view", scope: "branch", dataSource: "students, classes, branch_memberships", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "04", group: "academic", nameAr: "تحصيل الرسوم", nameEn: "Fees Collection", nameZh: "学费收缴", zone: "daily", parentModuleId: "fees", submenus: ["collection"], route: "finance", permission: "financial_approval", scope: "branch", dataSource: "fee_payments, fee_refunds, finance_audit_log", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "05", group: "academic", nameAr: "المقررات الإلكترونية", nameEn: "Online Courses", nameZh: "在线课程", zone: "academics", parentModuleId: "courses", submenus: ["catalogue"], route: "courses", permission: "view", scope: "class", dataSource: "learning_courses, learning_lessons", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "06", group: "academic", nameAr: "سجلات السلوك", nameEn: "Behaviour Records", nameZh: "行为记录", zone: "daily", parentModuleId: "student-information", submenus: ["portfolio"], route: "portfolio", permission: "edit", scope: "assigned_student", dataSource: "sai_student_portfolios", status: "partial", testStatus: "partial", deployStatus: "staged", note: "Portfolio exists; a dedicated behaviour incident log with approval is still pending." }),
  req({ id: "07", group: "academic", nameAr: "إدارة الفروع المتعددة", nameEn: "Multi-Branch Management", nameZh: "多校区管理", zone: "daily", parentModuleId: "organisation", submenus: ["branches", "sessions"], route: "branches", permission: "manage", scope: "institution", dataSource: "branches, academic_sessions, branch_memberships", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "08", group: "academic", nameAr: "دروس مباشرة Google Meet", nameEn: "Google Meet Live Classes", nameZh: "Google Meet 直播课", zone: "academics", parentModuleId: "courses", submenus: ["catalogue"], route: null, permission: "manage", scope: "class", dataSource: "learning_lessons.live_url", status: "blocked", testStatus: "not_started", deployStatus: "not_deployed", note: "Requires a verified Google Workspace / Meet integration; live links are stored on lessons but no meeting provisioning exists." }),
  req({ id: "09", group: "academic", nameAr: "دروس مباشرة Zoom", nameEn: "Zoom Live Classes", nameZh: "Zoom 直播课", zone: "academics", parentModuleId: "courses", submenus: ["catalogue"], route: null, permission: "manage", scope: "class", dataSource: "learning_lessons.live_url", status: "blocked", testStatus: "not_started", deployStatus: "not_deployed", note: "Requires a Zoom Server-to-Server OAuth app; no credentials are configured." }),
  req({ id: "10", group: "academic", nameAr: "الإيرادات", nameEn: "Income", nameZh: "收入", zone: "daily", parentModuleId: "fees", submenus: ["collection"], route: "finance", permission: "financial_approval", scope: "branch", dataSource: "fee_payments, finance_audit_log", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "11", group: "academic", nameAr: "المصروفات", nameEn: "Expenses", nameZh: "支出", zone: "daily", parentModuleId: "fees", submenus: ["collection"], route: "finance", permission: "financial_approval", scope: "branch", dataSource: "fee_refunds, finance_audit_log", status: "partial", testStatus: "partial", deployStatus: "staged", note: "Refunds are covered; a full expense/voucher ledger with approval workflow is still pending." }),
  req({ id: "12", group: "academic", nameAr: "الحضور بالرمز QR", nameEn: "QR Code Attendance", nameZh: "二维码考勤", zone: "daily", parentModuleId: "attendance", submenus: ["qr"], route: "qr", permission: "create", scope: "class", dataSource: "attendance_sessions, attendance_records", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "13", group: "academic", nameAr: "اختبارات HSK و YCT", nameEn: "HSK & YCT Examinations", nameZh: "HSK 与 YCT 考试", zone: "academics", parentModuleId: "examinations", submenus: ["exams"], route: "exams", permission: "view", scope: "class", dataSource: "exams, exam_results", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "14", group: "academic", nameAr: "الامتحانات", nameEn: "Examinations", nameZh: "考试管理", zone: "academics", parentModuleId: "examinations", submenus: ["exams"], route: "exams", permission: "manage", scope: "class", dataSource: "exams, exam_results", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "15", group: "academic", nameAr: "الحضور والانصراف", nameEn: "Attendance", nameZh: "考勤", zone: "daily", parentModuleId: "attendance", submenus: ["tracking"], route: "attendance", permission: "create", scope: "class", dataSource: "attendance_sessions, attendance_records", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "16", group: "academic", nameAr: "الاختبارات الإلكترونية", nameEn: "Online Examinations", nameZh: "在线考试", zone: "academics", parentModuleId: "homework", submenus: ["quizzes"], route: "quizzes", permission: "manage", scope: "class", dataSource: "learning_assessments, learning_assessment_attempts, learning_assessment_answers", status: "completed", testStatus: "passing", deployStatus: "live", note: "Question bank, attempt limits, protected delivery screen, automatic grading and attempt history are wired on the quizzes module." }),
  req({ id: "17", group: "academic", nameAr: "الشؤون الأكاديمية", nameEn: "Academics", nameZh: "教务管理", zone: "academics", parentModuleId: "academic-affairs", submenus: ["affairs"], route: "academics", permission: "manage", scope: "institution", dataSource: "classes, academic_sessions", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "18", group: "academic", nameAr: "التقويم السنوي", nameEn: "Annual Calendar", nameZh: "年度日历", zone: "academics", parentModuleId: "academic-affairs", submenus: ["timetable"], route: "timetable", permission: "view", scope: "institution", dataSource: "academic_sessions, timetable data", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "19", group: "academic", nameAr: "خطة الدرس", nameEn: "Lesson Plan", nameZh: "课时计划", zone: "academics", parentModuleId: "content-studio", submenus: ["authoring"], route: "authoring", permission: "create", scope: "course", dataSource: "learning_lessons, learning_lesson_*", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "20", group: "academic", nameAr: "الموارد البشرية", nameEn: "Human Resources", nameZh: "人力资源", zone: "administration", parentModuleId: "hr", submenus: ["staff"], route: "staff", permission: "manage", scope: "branch", dataSource: "sai_hr_employees, sai_hr_payroll_entries, sai_hr_leave_requests", status: "completed", testStatus: "passing", deployStatus: "live" }),

  // ------------------------------------------------------- institutional ops
  req({ id: "21", group: "operations", nameAr: "التواصل", nameEn: "Communication", nameZh: "通讯", zone: "daily", parentModuleId: "communications", submenus: ["announcements"], route: "communications", permission: "publish", scope: "institution", dataSource: "announcements, announcement_deliveries, announcement_reads", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "22", group: "operations", nameAr: "مركز التحميل", nameEn: "Download Center", nameZh: "下载中心", zone: "academics", parentModuleId: "downloads", submenus: ["downloads"], route: "downloads", permission: "download", scope: "institution", dataSource: "sai_download_resources, storage", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "23", group: "operations", nameAr: "الواجبات", nameEn: "Homework", nameZh: "作业", zone: "academics", parentModuleId: "homework", submenus: ["homework"], route: "homework", permission: "assign", scope: "class", dataSource: "learning_homework, learning_homework_submissions", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "24", group: "operations", nameAr: "المكتبة", nameEn: "Library", nameZh: "图书馆", zone: "academics", parentModuleId: "library", submenus: ["library"], route: "library", permission: "manage", scope: "institution", dataSource: "library_items, library_loans", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "25", group: "operations", nameAr: "المخزون", nameEn: "Inventory", nameZh: "库存", zone: "administration", parentModuleId: "inventory", submenus: ["inventory"], route: "inventory", permission: "manage", scope: "branch", dataSource: "sai_inventory_items", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "26", group: "operations", nameAr: "السيرة الذاتية للطالب", nameEn: "Student CV", nameZh: "学生简历", zone: "daily", parentModuleId: "student-information", submenus: ["portfolio"], route: "portfolio", permission: "print", scope: "assigned_student", dataSource: "sai_student_portfolios, students", status: "partial", testStatus: "partial", deployStatus: "staged", note: "Portfolio and print sheets exist; a formal CV document template with verification is pending." }),
  req({ id: "27", group: "operations", nameAr: "النقل", nameEn: "Transport", nameZh: "校车", zone: "administration", parentModuleId: "services", submenus: ["transport"], route: "transport", permission: "manage", scope: "branch", dataSource: "sai_transport_routes", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "28", group: "operations", nameAr: "السكن الطلابي", nameEn: "Dormitory", nameZh: "学生宿舍", zone: "administration", parentModuleId: "services", submenus: ["housing"], route: "housing", permission: "manage", scope: "branch", dataSource: "sai_housing_rooms", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "29", group: "operations", nameAr: "الشهادات وبطاقات الهوية", nameEn: "Certificates & ID Cards", nameZh: "证书与身份证", zone: "administration", parentModuleId: "services", submenus: ["certificates"], route: "certificates", permission: "print", scope: "assigned_student", dataSource: "sai_certificates", status: "partial", testStatus: "partial", deployStatus: "staged", note: "Certificate records and print sheets exist; digital signature and public verification service are pending." }),
  req({ id: "30", group: "operations", nameAr: "الموقع التعريفي CMS", nameEn: "Front CMS", nameZh: "门户内容管理", zone: "administration", parentModuleId: "website-cms", submenus: ["cms", "frontCms"], route: "cms", permission: "publish", scope: "institution", dataSource: "cms_news, cms_programs, cms_site_content, sai_cms_pages", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "31", group: "operations", nameAr: "الخريجون", nameEn: "Alumni", nameZh: "校友", zone: "administration", parentModuleId: "services", submenus: ["alumni"], route: "alumni", permission: "view", scope: "institution", dataSource: "sai_alumni", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "32", group: "operations", nameAr: "التقارير", nameEn: "Reports", nameZh: "报表", zone: "administration", parentModuleId: "reports", submenus: ["reports"], route: "reports", permission: "export", scope: "branch", dataSource: "report RPCs, audit_logs", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "33", group: "operations", nameAr: "إعدادات النظام", nameEn: "System Settings", nameZh: "系统设置", zone: "administration", parentModuleId: "system", submenus: ["settings", "catalog", "backups"], route: "settings", permission: "manage", scope: "institution", dataSource: "sai_system_settings, sai_system_settings_audit", status: "completed", testStatus: "passing", deployStatus: "live" }),

  // ------------------------------------------------ SAI specialised modules
  req({ id: "34", group: "specialised", nameAr: "تعلّم اللغة الصينية", nameEn: "Chinese Language Learning", nameZh: "汉语学习", zone: "academics", parentModuleId: "languages", submenus: ["vocabulary"], route: "vocabulary", permission: "view", scope: "class", dataSource: "learning_vocabulary, learning_vocab_progress", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "35", group: "specialised", nameAr: "المنح الدراسية", nameEn: "Scholarships", nameZh: "奖学金", zone: "daily", parentModuleId: "fees", submenus: ["collection"], route: "finance", permission: "approve", scope: "branch", dataSource: "fee_waivers", status: "partial", testStatus: "partial", deployStatus: "staged", note: "Fee waivers exist; a scholarship programme catalogue with application and award workflow is pending." }),
  req({ id: "36", group: "specialised", nameAr: "الخدمات الطلابية", nameEn: "Student Services", nameZh: "学生服务", zone: "administration", parentModuleId: "services", submenus: ["transport", "housing", "certificates", "alumni"], route: "transport", permission: "view", scope: "assigned_student", dataSource: "sai_transport_routes, sai_housing_rooms, sai_certificates, sai_alumni", status: "completed", testStatus: "passing", deployStatus: "live" }),
  req({ id: "37", group: "specialised", nameAr: "التوظيف", nameEn: "Recruitment", nameZh: "招聘", zone: "administration", parentModuleId: "hr", submenus: ["staff"], route: null, permission: "manage", scope: "institution", dataSource: "sai_hr_employees", status: "pending", testStatus: "not_started", deployStatus: "not_deployed", note: "A vacancy and applicant pipeline with review stages is not yet built; the HR directory is the current foundation." }),
  req({ id: "38", group: "specialised", nameAr: "إدارة أولياء الأمور", nameEn: "Parent & Guardian Management", nameZh: "家长与监护人管理", zone: "daily", parentModuleId: "student-information", submenus: ["records"], route: "students", permission: "view", scope: "guardian_relationship", dataSource: "parent_student_links, students", status: "partial", testStatus: "partial", deployStatus: "staged", note: "Guardian links exist and are enforced in RLS; a dedicated guardian directory with verified-relationship workflow is pending." }),
  req({ id: "39", group: "specialised", nameAr: "الإدارة المالية المتقدمة", nameEn: "Advanced Financial Management", nameZh: "高级财务管理", zone: "daily", parentModuleId: "fees", submenus: ["collection"], route: "finance", permission: "financial_approval", scope: "branch", dataSource: "fee_groups, fee_assignments, fee_payments, fee_refunds, fee_waivers, finance_audit_log", status: "partial", testStatus: "partial", deployStatus: "staged", note: "Core ledger, approvals and audit are live; multi-currency budgets and expense vouchers remain staged." }),
  req({ id: "40", group: "specialised", nameAr: "مركز الطباعة", nameEn: "Printing Center", nameZh: "打印中心", zone: "administration", parentModuleId: "reports", submenus: ["reports"], route: "reports", permission: "print", scope: "branch", dataSource: "report print sheets, letterhead, archive headers", status: "partial", testStatus: "partial", deployStatus: "staged", note: "Letterhead, receipts and report sheets print; a central print queue with job history is pending." }),
];

export const coverageStatusMeta: Record<CoverageStatus, { ar: string; en: string; zh: string; tone: string }> = {
  completed: { ar: "مكتمل ومُتحقق", en: "Completed & verified", zh: "已完成并验证", tone: "ok" },
  implemented_unverified: { ar: "منفّذ بانتظار التحقق", en: "Implemented, unverified", zh: "已实现待验证", tone: "info" },
  partial: { ar: "مكتمل جزئياً", en: "Partially complete", zh: "部分完成", tone: "warn" },
  pending: { ar: "قيد الانتظار", en: "Pending", zh: "待处理", tone: "neutral" },
  blocked: { ar: "متعطّل باعتماد خارجي", en: "Blocked (external dependency)", zh: "受外部依赖阻塞", tone: "danger" },
};

export type CoverageSummary = {
  total: number;
  completed: number;
  partial: number;
  pending: number;
  blocked: number;
  unverified: number;
  percent: number;
  byGroup: { id: CoverageGroup; total: number; completed: number }[];
};

export function coverageSummary(rows: readonly CoverageRequirement[] = coverageRequirements): CoverageSummary {
  const count = (status: CoverageStatus) => rows.filter((row) => row.status === status).length;
  const completed = count("completed");
  return {
    total: rows.length,
    completed,
    partial: count("partial"),
    pending: count("pending"),
    blocked: count("blocked"),
    unverified: count("implemented_unverified"),
    percent: rows.length ? Math.round((completed / rows.length) * 100) : 0,
    byGroup: coverageGroups.map((group) => {
      const groupRows = rows.filter((row) => row.group === group.id);
      return { id: group.id, total: groupRows.length, completed: groupRows.filter((row) => row.status === "completed").length };
    }),
  };
}

/** Rows whose owning module is consolidated into a main module, for the audit view. */
export function consolidatedModules(rows: readonly CoverageRequirement[] = coverageRequirements): { moduleId: string; requirements: readonly string[] }[] {
  const map = new Map<string, string[]>();
  for (const row of rows) {
    map.set(row.parentModuleId, [...(map.get(row.parentModuleId) ?? []), row.id]);
  }
  return [...map.entries()].map(([moduleId, requirements]) => ({ moduleId, requirements }));
}

/** A requirement is "exposed" when it renders a live route today. */
export function isRequirementExposed(row: CoverageRequirement): boolean {
  return row.route !== null && (row.status === "completed" || row.status === "partial" || row.status === "implemented_unverified");
}