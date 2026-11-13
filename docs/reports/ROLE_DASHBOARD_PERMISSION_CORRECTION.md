# Role dashboard and permission correction

## Status

**Dashboard implementation is present and the requested web/mobile checks pass.
The Supabase Preview migration correction remains unverified pending authoritative
schema and migration-history comparison.** Migration 020 is still an untrusted
reconstruction, not the original deployed DDL. No Supabase schema was applied
and no production data was changed.

## Changes made

The web navigation and direct module-route role map now:

- Denies Teacher access to general admissions and the unrestricted student
  directory. Teacher class and student workflows remain in the assigned-class
  Teacher Portal.
- Denies Student and Parent access to the administrative student and class
  directories.
- Denies Student and Parent access to the generic attendance register. That
  screen loads class sessions and class attendance history; it is not a
  verified personal-attendance view.
- Removes Receptionist access to finance, including payment posting. Front
  office admissions remain available.
- Preserves additive access for legitimate multi-role accounts.

Flutter applies equivalent restrictions to its generic class and attendance
screens. Teachers retain the assigned-class entry point. The web Student and
verified-Parent dashboards now show only personal/verified-child attendance;
Flutter still has no corresponding personal attendance panel. Hiding the
unscoped register remains safer than exposing class-wide records.

These are client-side navigation and route guards. They do **not** prove or
replace Supabase RLS, RPC, or Edge Function authorization.

## Dashboard and module implementation

- The Super Administrator dashboard requests aggregate counts through the
  `manage-roles` Edge Function. It verifies the caller's session and
  `super_admin` role before running the summary action; the response contains
  counts only, not account PII. Auth accounts are paged through Auth Admin,
  while database metrics use exact counts. Failed counts produce an error
  state rather than a zero-valued dashboard.
- The dashboard covers accounts, roles, students, teachers, classes, branches,
  academic sessions, courses, lessons, active students assigned to classes,
  lesson progress, homework submissions, new admissions, content references,
  and notifications for the signed-in Super Administrator. Positive
  operational counts link to the corresponding existing module.
- A recorded `content_path` is counted only as a media reference; the Edge
  summary does not verify that an object exists in Storage. Assessment counts
  are homework submission activity only. There is no verified exam-attempt
  contract in the current repository.
- Student and verified-parent dashboards now show the most recent personal
  attendance records. Student identity is resolved by the authenticated
  `user_id`; parent records are derived from links with non-null `verified_at`.
  The attendance query filters by that student ID, then fetches only the
  referenced sessions. Existing RLS remains authoritative. The generic,
  class-wide attendance register remains hidden from Student and Parent roles.
- The Student dashboard includes real class courses, lessons, published
  homework, graded submissions, recent progress activity, and a resume link
  for a recorded in-progress lesson. Legacy completion states are still
  described as unverified, not mastery. No exam scores, achievements, or
  certificates are fabricated.
- Teacher dashboard code and approved Teacher screens were not changed during
  these stages. Six incomplete skill pages (listening, speaking, tones,
  handwriting, reading, and spaced review) are no longer presented as working
  modules; they are marked pending with their backend/content limitations.
- A Super Administrator-only system catalog lists all enabled routes and
  pending modules without linking pending items to placeholder pages. It
  summarizes all 32 reference categories and displays the 147 supplied submenu
  entries with their audit classifications and links to related enabled
  modules. The report retains the line-by-line audit of those labels.

## Before/after permission corrections

| Role | Before | After |
|---|---|---|
| Super Admin | Existing broad module access | Dashboard summary and system catalog added; submenu audit is documented below; live backend governance remains unverified |
| Admin | Existing institutional navigation | Unchanged; privileged permission-definition enforcement remains unverified |
| Teacher | Could open general admissions, student directory, and web class directory | Those generic routes are denied; assigned-class teaching and attendance entry points remain |
| Accountant | Finance access | Unchanged |
| Receptionist | Admissions, student directory, and finance/payment posting | Admissions and front-office access retained; finance and payment posting denied |
| Librarian | Library-scoped navigation | Unchanged |
| Student | Could open student/class directories and the generic attendance register | Those unscoped routes are denied; learning routes remain |
| Parent | Could open student/class directories and the generic attendance register | Those unscoped routes are denied; web personal attendance uses verified guardian links |
| Content Editor | Content-focused navigation | Unchanged |

Multi-role accounts continue to receive the union of their assigned role
navigation. The role selector in Flutter preview is demonstration-only and is
not an authorization mechanism.

## Role menu inventory

The web menu is generated from `navigation.ts` and filtered by role and module
availability. The corrections above change the affected roles' visible links
and their direct module-route authorization. A full before/after route,
backend-operation, data-scope, and read/write inventory for all nine roles has
not yet been completed.

The original role-reference menu counts remain reference figures only:
Super Admin 142, Admin 141, Accountant 14, Teacher 33, Receptionist 9,
Librarian 3, Student 11, Parent 8; Content Editor was not specified. They are
not implemented or verified menu totals.

## Required 32-category inventory

All reference categories and expected entry counts are recorded here for
tracking. The supplied source at
[`docs/requirements/SYSTEM_MENU_INVENTORY_32_CATEGORIES.md`](../requirements/SYSTEM_MENU_INVENTORY_32_CATEGORIES.md)
contains all 147 original Arabic labels and is currently untracked in the
worktree. The Super Administrator catalog now includes each reference entry;
the per-entry audit below records actual routes, role gates, data operations,
and gaps without implying that related modules implement every legacy action.

| # | Category | Reference entries | Current inventory assessment |
|---:|---|---:|---|
| 1 | Front Office | 7 | Audited below |
| 2 | Student Information | 15 | Audited below |
| 3 | Fees Collection | 9 | Audited below |
| 4 | Income | 2 | Audited below |
| 5 | Expenses | 2 | Audited below |
| 6 | Attendance | 3 | Audited below |
| 7 | Examinations | 4 | Audited below |
| 8 | CBSE Examinations | 10 | Audited below |
| 9 | CBSE Exam | 8 | Audited below |
| 10 | Academics | 6 | Audited below |
| 11 | Homework | 1 | Audited below |
| 12 | Download Center | 2 | Audited below |
| 13 | Library | 3 | Audited below |
| 14 | Transport | 3 | Audited below |
| 15 | Hostel | 1 | Audited below |
| 16 | Inventory | 2 | Audited below |
| 17 | Human Resources | 5 | Audited below |
| 18 | Communicate | 3 | Audited below |
| 19 | Online Courses | 5 | Audited below |
| 20 | Live Classes | 2 | Audited below |
| 21 | Behaviour Records | 2 | Audited below |
| 22 | Certificates and Cards | 3 | Audited below |
| 23 | Front CMS | 1 | Audited below |
| 24 | Alumni | 2 | Audited below |
| 25 | Continuity Center | 1 | Audited below |
| 26 | Calendar | 1 | Audited below |
| 27 | Reports | 6 | Audited below |
| 28 | Internal Messaging | 1 | Audited below |
| 29 | Student Personal Services | 2 | Audited below |
| 30 | Parent Personal Services | 3 | Audited below |
| 31 | Backup and Restore | 1 | Audited below |
| 32 | System Settings | 31 | Audited below |
| **Total** | **32 categories** | **147** | **Per-entry status and audit profiles below** |

The separate earlier role reference of 142 Super Admin menu entries is
preserved; it is not forced to equal the 147-entry functional inventory.

## Existing implementation reused

- Web role definitions, available-module filtering, sidebars, mobile tabs, and
  direct module routing in `src/portal/lib/navigation.ts` and
  `src/portal/lib/sidebarSections.ts`.
- Existing Teacher Portal and assigned-class workflows.
- Existing finance permissions and payment workflow; the Receptionist
  capability was removed from the client permission helper as well as the
  navigation.
- Flutter's shared `Access` policy and Teacher Portal routing.

## Backend dependencies and limitations

- Client-side role checks are UX controls only. RLS and privileged operations
  must enforce each role and row scope independently.
- The personal-attendance UI relies on the existing migration 006 RLS policy
  for student-own and verified-parent access. No authenticated role accounts
  were available to perform live positive/negative policy tests.
- Parent finance and homework visibility continue to rely on their existing
  RLS policies; this change adds no broader access.
- The new Edge Function summary action must be deployed before the new
  Super Administrator dashboard can load in production. Hostinger VPS and
  Supabase are identified as targets, but the approved deployment mechanism
  and server deployment configuration are not confirmed. Deno and Supabase
  CLIs are not installed here.
- PR #4's Supabase Preview check failed in its migration-014 CMS block with
  `relation "public.cms_programs" does not exist` at
  `ALTER POLICY cms_programs_write`. The reported Preview project is
  `mgibjusuglafbnlrkbep`; the production metadata supplied by the user is from
  `aeryusbrulqdxjdynwfh`. Treat them as distinct environments until verified.
- The current uncommitted migration-014 edit wraps its CMS statements in a
  prerequisite check: it defers when all CMS tables are absent, applies the
  existing write-policy role change and programs/news read policies when all
  three tables plus the helper exist, defers when only the helper is absent,
  and errors on a partial table set. It still assumes specific policy names and
  a helper signature. An already-applied migration 014 will not rerun this edit.
- The untracked migration 020 creates eleven private role/branch/class/student
  and learning helper functions, then bootstraps three CMS tables with inferred
  columns/defaults, three inferred indexes, grants, RLS, and fallback policies.
  It does not reproduce the confirmed `cms_site_content.updated_by` column and
  its `auth.users(id) ON DELETE SET NULL` foreign key. Its DDL, helper bodies,
  grants, indexes, and policy expressions have not been compared with full
  production metadata; `CREATE TABLE IF NOT EXISTS` does not reconcile a
  pre-existing but structurally different table.
- Migrations 022 and 025 depend on private helper functions. Migration 020
  currently defines copies ahead of those migrations, but production helper
  signatures, attributes, ACLs, and definitions have not been retrieved.
  Therefore the proposed early helper bootstrap is not yet verified as an
  exact or safe reproduction.
- The repository has no Supabase Preview workflow; the failing Preview check
  is an external GitHub integration. Its recorded result remains failed; it was
  not rerun against the current uncommitted changes. The new chain was not
  applied to any database. An isolated Postgres replay is still required.
- Storage object existence, exam-attempt statistics, achievements, and
  certificate issuance/verification are not supported by a verified backend
  contract in this repository.
- Authenticated Student, Parent, Teacher, and Super Administrator test
  accounts were not available for live RLS checks.

## Deployment readiness review

- The repository's `web-ci.yml` runs dependency installation, type-check,
  production build, and compatibility tests. `mobile-ci.yml` runs Flutter
  analysis and tests. Neither workflow deploys.
- No deployment script, Docker/Compose file, or Nginx configuration was found.
  The local web build command is `npm run build` and its output is `out/`, but
  the VPS installation directory and web-server configuration are unverified.
- The user identified Hostinger VPS and Supabase as the production targets, but
  the approved deploy process remains unconfirmed. Deno and Supabase CLIs are
  unavailable in this environment. No deployment was attempted and no
  existing Edge Function was modified.
- The Preview source changes in migrations 014 and 020 remain uncommitted.
  They do not bypass the check and have not been applied to any database.

## Per-entry audit of the supplied 147-item inventory

The audit preserves the Arabic source labels exactly. Each profile code resolves
to the React route/component, authorized web roles, Flutter counterpart,
database operation, scope, read/write behavior, status, and blockers. “Partial”
means a related workflow exists but does not implement the complete legacy
operation. “Pending” means there is no verified live workflow. Client role
gates are navigation controls only; backend RLS and server authorization remain
authoritative.

### Audit profiles

| Code | Route and roles | Flutter | Backend operation, scope, read/write | Status and blockers |
|---|---|---|---|---|
| ADM | `/portal/modules/admissions`; `super_admin`, `admin`, `receptionist` | `PageId.admissions` exists, but live mode has no Supabase-backed admissions screen; preview is demonstration data | `admissions_enquiries`, `sai_admissions_staff`, `sai_admissions_sessions`; branch/session scoped; staff read/create/update, no delete; migration 004 | Working enquiry workflow; no visitor, mail, or call management |
| PUB | Public landing-page form (`src/pages/home/components/Admissions.tsx`) and `/application-status`; no authenticated role required for applicant submission | No live applicant form | Migration 004 defines public submit/status/history RPCs; submission is server-side, status/history are reference-based reads | Partial. UI/RPC contracts exist; live endpoint and anonymous authorization behavior were not exercised |
| STU | `/portal/modules/students`; `super_admin`, `admin`, `receptionist` | No equivalent live student-administration screen | `students`, `classes`, `branches`, `academic_sessions`; branch/session filters and RLS; read for all listed roles, create/update only Super Admin/Admin, no bulk delete | Partial directory; no import, multi-class, transfer, category, disability, or historical-record workflows |
| PROFILE | `/portal/profile` and role dashboard; all roles | `PageId.profile` | `profiles`, `user_roles`, student/verified-parent links; self/verified-child scope; own profile read/update | Working personal profile and scoped dashboards; no CV/portfolio issuance |
| ATT | `/portal/modules/attendance`, `/portal/modules/qr`; `super_admin`, `admin`, `teacher`, `receptionist` | Live attendance/Teacher Portal | `attendance_sessions`, `attendance_records`; class/branch scope for staff, exact student and verified-parent scope for personal view; authorized read/write | Working scoped attendance; backend rejects unauthorized class writes and future dates |
| REP | `/portal/modules/reports`; `super_admin`, `admin`, `teacher`, `accountant`, `receptionist`, `librarian`, `content_editor` | `PageId.reports` | Reads `students`, `classes`, `branches`, `academic_sessions`, attendance, learning courses/homework/submissions; RLS-scoped; read-only | Enrollment, attendance, homework, admissions/distribution reports exist; fee and exam-mark reports do not |
| ACA | `/portal/modules/classes` (Super Admin/Admin), `/portal/modules/academics` (Super Admin/Admin/Teacher), `/portal/modules/timetable` (Super Admin/Admin/Teacher/Student/Parent/Receptionist) | `PageId.classes` teacher portal; `PageId.schedule` shows unavailable in live mode | `classes`, `branches`, `academic_sessions` support scoped class management; React `AcademicAffairs`/`Timetable` instead read static `src/mocks/academics`; no persisted timetable/subject/plan/exam-schedule CRUD | Partial. Class management is real; academic-affairs and timetable pages are demonstrations |
| LEARN | `/portal/modules/courses`, `/portal/modules/progress`, `/portal/modules/vocabulary`; route gates in `navigation.ts` | Live course catalog/vocabulary | `learning_courses`, `learning_lessons`, `learning_lesson_progress`, `learning_vocabulary`, `learning_vocab_progress`; class/teacher/student scope; staff content writes, student-scoped progress | Working where RLS permits; no exam/question bank, mastery claim, or independent assessment workflow |
| HW | `/portal/modules/homework`; `super_admin`, `admin`, `teacher`, `student`, `parent` | `PageId.assignments` / live homework | `learning_homework`, `learning_homework_submissions`; student and assigned-class scope; publish, submit, and grade/update | Working homework flow; not an exam/certificate system |
| LIB | `/portal/modules/library`; `super_admin`, `admin`, `librarian`, `teacher`, `parent`, `student` | `PageId.library` | `library_items`, `library_loans`, `sai_library_issue`, `sai_library_return`; branch-scoped circulation and self/verified-child loan reads; staff catalog/circulation writes | Working book list/add/issue/return; server transactions and RLS enforce permissions |
| COM | `/portal/modules/communications`, `/portal/modules/notifications`; all roles view, `super_admin`, `admin`, `content_editor` manage | `PageId.notifications` | `announcements`, `announcement_reads`, delivery log and `announcement-email`; audience/branch-scoped reads, management writes | Working announcement/email workflow; not private chat, postal log, or phone log |
| FIN | `/portal/modules/finance`; `super_admin`, `admin`, `accountant`, `student`, `parent` (Receptionist excluded) | `PageId.finance` / live finance screen | `019_public_finance.sql` defines fee groups/assignments/payments/waivers/refunds and protected RPCs; branch/self/verified-child reads and role-checked mutations | Code/schema contract exists; live migration status and authenticated financial RLS not verified. Other income/expense/bank workflows are unsupported |
| CMS | `/portal/modules/cms`; `super_admin`, `admin`, `content_editor` | `PageId.frontCms` uses CMS tables; live role-specific behavior unverified | `cms_programs`, `cms_news`, `cms_site_content` are production tables with RLS enabled; authenticated write policies authorize `super_admin`, `admin`, `content_editor` through `private.sai_security_has_role`; clients call these tables through `cms.ts` | Table existence, RLS and write-role set are user-verified production facts; exact columns/defaults/constraints/indexes/grants/policy expressions/helper signature still need metadata comparison. Do not treat migration 020's reconstructed DDL as authoritative |
| SET | `/portal/modules/settings`; `super_admin`, `admin`; selected fields Super Admin-only | `PageId.settings` | UI reads/upserts the production `sai_system_settings` table | Table existence is user-verified; settings schema, grants, RLS and live authorization remain unverified. SMS/WhatsApp/email/backup/update settings are preferences, not integrations or restore/deploy operations |
| ROLE | `/portal/modules/roles`; Super Admin only | `PageId.users` is Super Admin-only; live role-management parity unverified | `manage-roles` Edge Function, Auth Admin and `user_roles`; verifies signed-in Super Admin before privileged writes | Backend authorization exists in source; deployment/live execution pending |
| UNI | Web IDs exist but are omitted from `availableModuleIds`; no web route enabled | Registry can route to `LiveModuleScreen` | Eight production tables are referenced by React/Flutter scaffolding: `sai_download_resources`, `sai_inventory_items`, `sai_transport_routes`, `sai_student_portfolios`, `sai_housing_rooms`, `sai_certificates`, `sai_cms_pages`, `sai_alumni`; client CRUD is branch-filtered | Table existence is user-verified; per-table columns, grants, RLS and operation behavior are not. Missing local migration 029 does not prove absence, nor does table existence prove feature readiness |
| NAV | Web paths/roles from `navigation.ts` and `isModuleAvailable`; Super Admin catalog lists enabled routes | `Access` and module registry | Static client configuration only; it does not grant data access | Navigation works, but is not an authorization boundary; pending pages must not be presented as complete |
| NONE | No verified React route/component | No verified live Flutter counterpart | No table/RPC/Edge operation found | Not implemented; no role or read/write capability is claimed |

### Item-by-item classification

Each source label below is assigned to the matching audit profile. The profile
table contains its route, roles, backend operation, data scope, CRUD limits,
and security blockers.

#### 01 — مكتب الاستقبال (7)
- استعلام عن القبول — ADM; partial.
- كتاب الزوار — NONE; pending, no visitor log.
- سجل المكالمات الهاتفية — NONE; pending, no call log.
- الإرسال البريدي — NONE; pending, no dispatch log.
- استلام بريدي — NONE; pending, no received-mail log.
- يشتكي — NONE; pending, no complaints workflow.
- قائمة الغرض — NONE; pending, no purpose catalog.

#### 02 — معلومات الطلاب (15)
- تفاصيل الطالب — STU; partial directory, not complete legacy student record.
- قبول الطالب — ADM; partial, no verified admissions-to-enrollment conversion.
- القبول عبر الإنترنت — PUB; partial RPC contract, public UI/live endpoint unverified.
- الطلاب المعاقون — NONE; pending, no disability-specific fields/workflow.
- طالب متعدد الصفوف — NONE; pending, current student model has one class assignment.
- حذف مجمع — NONE; not supported; destructive bulk deletion is not implemented.
- فئات الطلاب — NONE; pending, no category service.
- بيت الطالب — UNI; pending, housing schema not verified.
- تعطيل السبب — STU; partial, no deactivation reason/audit UI.
- استيراد الطلاب — NONE; pending, no import/validation workflow.
- سجل الطلاب التاريخي — NONE; pending, no historical archive.
- تقرير أولياء الأمور — PROFILE; partial verified links, no dedicated report.
- بيانات دخول الطلاب — ROLE; partial account/role administration; no credential disclosure/reset UI.
- السيرة الذاتية — UNI; pending, portfolio schema not verified.
- نقل للفرع — NONE; pending, no safe branch-transfer transaction.

#### 03 — تحصيل الرسوم (9)
- تحصيل الرسوم — FIN; partial, payment RPC source exists, live backend unverified.
- دفع/بحث رسوم — FIN; partial payment/assignment APIs, live backend unverified.
- الرسوم المستحقة — FIN; partial assignment/balance contract, no live verification.
- سيد الرسوم — FIN; partial fee-group configuration only.
- مجموعة الرسوم — FIN; partial, supported by migration 019.
- نوع الرسوم — FIN; pending, no separate fee-type catalog.
- خصم الرسوم — FIN; partial discount amount in assignment contract; live verification pending.
- رسوم ترحيل — NONE; pending, no fee-transfer workflow.
- البنوك — NONE; pending, no bank-account directory.

#### 04 — الدخل (2)
- وصف الدخل — NONE; pending, no non-fee income catalog.
- إضافة دخل — NONE; pending, no non-fee income transaction.

#### 05 — المصروفات (2)
- أوصاف المصروف — NONE; pending, no expense category workflow.
- إضافة مصروف — NONE; pending, no expense transaction workflow.

#### 06 — الحضور (3)
- حضور الطلاب — ATT; working, staff register and scoped personal view.
- حضور QR — ATT; working, QR route with backend class scope.
- الحضور حسب التاريخ — REP; working, date-range/class-scoped attendance report.

#### 07 — الامتحانات (4)
- قائمة الامتحانات — NONE; pending, exam module hidden and exam schema unverified.
- جدول الامتحان — NONE; pending, mock dates are not a persisted schedule.
- سجل الدرجات — NONE; pending, no exam-attempt/marks backend.
- تقديرات الدرجات — NONE; pending, no grading-scale service.

#### 08 — امتحانات CBSE (10)
- الامتحانات — NONE; pending, CBSE exam schema unverified.
- مجموعة الامتحانات — NONE; pending, no exam-group management.
- جدول الامتحان — NONE; pending, no persisted CBSE schedule.
- نتيجة الامتحان — NONE; pending, no results backend.
- بطاقة قبول التصميم — NONE; pending, no admit-card designer.
- طباعة بطاقة الدخول — NONE; pending, no verified admit-card data.
- تصميم ماركشيت — NONE; pending, no marksheet template.
- طباعة ماركشيت — NONE; pending, no marksheet data/output.
- علامات الصف — NONE; pending, no class mark entry.
- قسم العلامات — NONE; pending, no marks-division configuration.

#### 09 — امتحان CBSE (8)
- امتحان — NONE; pending, no CBSE exam workflow.
- جدول الامتحان — NONE; pending, no persisted schedule.
- طباعة ماركشيت — NONE; pending, no marksheet generation.
- قالب — NONE; pending, no exam-template service.
- تعيين المراقبة — NONE; pending, no invigilation assignment.
- بطاقة القبول — NONE; pending, no admit-card service.
- التقارير — NONE; pending, no CBSE reports.
- جلسة — NONE; pending, no exam-session workflow.

#### 10 — الأكاديمية (6)
- الفصول والأقسام — STU; partial, scoped class management but no full section lifecycle.
- المواد — NONE; pending, no subject catalog/table.
- تعيين المواد والمعلمين — STU; partial class-teacher reference only; no subject assignment.
- الجدول الأسبوعي — ACA; pending, React is static mock data and mobile live view is unavailable.
- ترقية الطلاب — NONE; pending, no promotion transaction.
- خطة الدرس — LEARN; partial lessons exist, no approved lesson-plan workflow.

#### 11 — الواجب المنزلي (1)
- وصف الواجب — HW; working published homework, student submission, and grading.

#### 12 — مركز التحميل (2)
- المواد القابلة للتنزيل — UNI; pending, resource table/storage policy not verified.
- يوتيوب تعليمي — LEARN; partial lesson URLs only, no YouTube library/catalog.

#### 13 — المكتبة (3)
- قائمة الكتب — LIB; working branch-scoped catalog.
- إضافة كتاب — LIB; working librarian/admin-authorized writes.
- الإصدار والعودة — LIB; working server RPC circulation transactions.

#### 14 — النقل (3)
- المركبات — UNI; pending, transport schema not verified.
- الخطوط — UNI; pending, transport schema not verified.
- نقاط الالتقاط — UNI; pending, transport schema not verified.

#### 15 — السكن (1)
- الغرف — UNI; pending, housing schema not verified.

#### 16 — المخزون (2)
- الأصناف — UNI; pending, inventory schema not verified.
- حركة المخزون — UNI; pending, no movement ledger/transaction.

#### 17 — الموارد البشرية (5)
- دليل الموظفين — ROLE; partial account/role service only, no HR directory module.
- الحضور والغياب — NONE; pending, no staff attendance data.
- الرواتب — NONE; pending, no payroll data/permissions.
- الإجازات — NONE; pending, no leave workflow.
- تقييم المعلمين — NONE; pending, no evaluation records/rubric.

#### 18 — التواصل (3)
- لوحة الإعلانات — COM; working with branch/audience RLS.
- إرسال رسالة — COM; partial announcement/email only, not private messaging.
- سجل الرسائل — COM; partial announcement/delivery history only.

#### 19 — الدورات الإلكترونية (5)
- الدورات — LEARN; working class/teacher-scoped courses and lessons.
- بنك الأسئلة — NONE; pending, no question bank.
- الدفع دون اتصال — FIN; pending, no offline-payment review/approval workflow.
- تقرير الدورات — REP; partial learning/homework aggregates, no dedicated course report.
- امتحانات أونلاين — NONE; pending, no exam-attempt backend.

#### 20 — الحصص المباشرة (2)
- Zoom / Google Meet — NONE; pending, no meeting integration or attendance.
- تقرير الحصص — NONE; pending, no live-class session data.

#### 21 — السلوك (2)
- تعيين حادث — NONE; pending, no behavior-incident workflow.
- سجل الحوادث — NONE; pending, no behavior records.

#### 22 — الشهادات والبطاقات (3)
- إصدار شهادة — UNI; pending, proposed table only; no verified issuance/signature workflow.
- شهادة نقل — UNI; pending, no transfer-certificate workflow.
- بطاقة هوية — NONE; pending, no ID-card generation.

#### 23 — الجبهة الأمامية (1)
- الموقع التعريفي — CMS; blocked, reconstructed CMS migration has not been replay-verified.

#### 24 — الخريجون (2)
- إدارة الخريجين — UNI; pending, alumni schema not verified.
- أحداث الخريجين — NONE; pending, no alumni-events backend.

#### 25 — مركز الاستمرارية (1)
- مركز الاستمرارية — NONE; pending, no continuity module/backend.

#### 26 — التقويم (1)
- التقويم والمهام — ACA; partial static calendar demonstration, no persisted event/task CRUD.

#### 27 — التقارير (6)
- تقرير الطلاب — REP; working enrollment/student report, RLS-scoped.
- تقرير الرسوم — FIN; pending, no verified finance report UI/data in Reports.
- الرسوم المتوازنة — FIN; pending, no verified balance report.
- حركات مالية — FIN; partial payment-ledger source exists, dedicated report/live data unverified.
- تقرير الحضور — REP; working date-range attendance report.
- درجات الامتحانات — NONE; pending, no exam-marks backend.

#### 28 — الرسائل الداخلية (1)
- الرسائل — COM; partial announcements are not private/internal message threads.

#### 29 — الطالب (2)
- ملفي الدراسي — PROFILE; partial real learner history/dashboard, not complete academic record/certificate view.
- سيرتي الذاتية — UNI; pending, portfolio schema not verified.

#### 30 — ولي الأمر (3)
- أبنائي — PROFILE; working partial verified-child links; no live parent test account.
- رسوم الأبناء — FIN; partial role-gated source, live RLS unverified.
- واجب الأبناء — HW; partial, depends on verified-child RLS; live parent test pending.

#### 31 — النسخ الاحتياطي (1)
- النسخ والاستعادة — NONE; pending, no backup/restore UI; settings only describe policy.

#### 32 — إعدادات النظام (31)
- الإعداد العام — SET; partial settings UI; `sai_system_settings` exists in production, but its schema, grants, RLS and live operations are not yet verified.
- شعار وخلفية الدخول — NONE; pending, no asset-setting workflow.
- تطبيق الهاتف المحمول — NONE; pending, no mobile-app configuration service.
- لوحة الطالب / الوصي — SET; partial generic preferences only, no dashboard configuration behavior.
- مصاريف — FIN; partial source contract only, no live validation.
- إنشاء معرف تلقائي — NONE; pending, no configurable ID policy.
- نوع الحضور — NONE; pending, attendance statuses are fixed.
- إعداد الجلسة — SET; partial preference only; sessions are managed separately.
- إعداد الإخطار — SET; partial preference only; no push-delivery configuration.
- مراسلة واتساب — SET; partial preference only; no WhatsApp integration.
- إعداد الرسائل القصيرة — SET; partial preference only; no SMS integration.
- إعداد البريد الإلكتروني — SET; partial preference only; sending requires deployed provider/Edge Function.
- طرق الدفع — SET; partial display preferences; server validates actual payment methods.
- طباعة رأس التذييل — SET; partial fields exist; print-template integration unverified.
- الطباعة الحرارية — NONE; pending, no thermal-print configuration.
- إعداد CMS الأمامي — CMS; blocked, reconstructed schema/policies prepared but not replay-verified; original deployed contract still missing.
- تصاريح الأدوار — ROLE; working partial protected role assignment, no arbitrary permission matrix.
- استرجاع البيانات — NONE; pending, no browser-accessible restore operation.
- اللغات — SET; partial locale preferences, no translation editor.
- عملة — SET; partial preference only; finance schema constrains transaction currency.
- إضافات — SET; partial metadata only; no dynamic plugin execution/loading.
- المستخدمون — ROLE; partial protected account/role service; no credential exposure.
- الوحدات — SET; partial preference only; enabled modules are code-controlled.
- الحقول المخصصة — SET; partial schema descriptions stored, not rendered as dynamic forms.
- إعداد كلمة التحقق — NONE; pending, no captcha provider/integration.
- حقول النظام — NONE; pending, no field registry/mutation workflow.
- تحديث الملف التعريفي للطالب — PROFILE; working partial own-profile fields only.
- القبول عبر الإنترنت — PUB; partial RPC contract; public route/live behavior unverified.
- أنواع الملفات — NONE; pending, no centralized upload/type policy UI.
- قائمة الشريط الجانبي — NAV; partial static role/module map, not editable in settings.
- تحديث النظام — NONE; pending, no self-update/deployment operation.

### Audit blockers and next steps

- The supplied 147-label inventory is available as a user-provided, untracked
  worktree file; it was not staged or committed.
- Read-only production facts independently verified by the user for project
  `aeryusbrulqdxjdynwfh`: the three CMS tables and `sai_system_settings` exist;
  the eight tables listed under UNI also exist. All three CMS tables have RLS
  enabled, and their authenticated write policies authorize
  `super_admin`, `admin`, and `content_editor` through
  `private.sai_security_has_role`. CMS primary keys are `cms_programs.id`
  (UUID), `cms_news.id` (UUID), and `cms_site_content.key` (text);
  `cms_site_content.updated_by` references `auth.users(id)` with
  `ON DELETE SET NULL`. These facts correct the previous unsupported
  implications that table presence was unknown or that absent local migrations
  indicated missing production objects.
- Static route gates and Flutter `Access` checks do not replace backend RLS.
  Live role-specific tests for personal attendance, parent children, finance,
  CMS, and role assignment need authorized test accounts and verified policies.
- The eight operational tables and `sai_system_settings` exist in production,
  but no local creation migration for them was found. The web hides the
  operational routes; Flutter's registry includes table access. Schema,
  grants, RLS, and actual read/write behavior still require verification.
- The CMS primary keys and `cms_site_content.updated_by` foreign key listed
  above are confirmed; all other CMS columns, defaults, constraints, indexes,
  grants, full policy expressions, and the private helper signature/body need
  authoritative metadata before migrations can reproduce production.
- Migration 020 is only a proposed reconstruction. Its `CREATE TABLE IF NOT
  EXISTS`, defaults, indexes, grants, helper bodies, and fallback policies are
  not proven to match production and must not be treated as authoritative.
  It also omits the user-confirmed `cms_site_content.updated_by` foreign key.
  Migration 014 was edited in place; an environment that already recorded 014
  will not rerun it, so any required forward correction must respect recorded
  migration history rather than relying on that edit.
- No local Supabase CLI, Docker, PostgreSQL client/server, or Supabase project
  configuration is available in this workspace. The exact production metadata
  comparison and a clean migration replay therefore remain blocked; the
  external Supabase Preview result remains failed. Its reported project ref
  (`mgibjusuglafbnlrkbep`) differs from the authoritative production ref
  provided by the user (`aeryusbrulqdxjdynwfh`).

## Remaining work

- Obtain read-only metadata for CMS columns/types/defaults/nullability,
  constraints/foreign keys, indexes, table and sequence grants, RLS state and
  complete policy definitions, private helper signatures/attributes/ACLs, and
  migration-history rows from both the production project and Preview target.
  Compare the output with migrations 014 and 020 before finalizing either.
- After that comparison, replace only unverified CMS bootstrap definitions
  with production-matching DDL and security definitions, retaining the
  confirmed roles, primary keys, and `updated_by` foreign key. Use a forward
  migration for any correction needed in databases that already recorded 014;
  document that the historical-file edit affects clean replays only.
- Run the full migration sequence in an isolated Preview-equivalent database
  and rerun the external Preview check. Do not hand-apply SQL to production or
  skip the failing check.
- Obtain authorized Student, Parent, Teacher, and Super Administrator test
  accounts for live role-boundary and personal-attendance RLS tests.
- Determine whether authoritative source migrations are needed for the eight
  operational `sai_*` tables and `sai_system_settings`; table existence is
  confirmed, while feature readiness and migration-history status are not.
- Confirm the approved deployment method, VPS install path and web-server
  configuration; deploy only after the Preview blocker is resolved and
  explicit approval is given.
- Verify actual Storage object availability if the product needs a
  ready/missing media status rather than the current path-reference counts.
- Implement assessment attempts, achievements, and certificates only after
  their backend contracts are approved.

## Overlay integration comparison

The ten files in `D:\SAI-Overlay-Review` were compared against the current
worktree without replacing folders or applying database changes.

| Overlay file | Decision and reason |
|---|---|
| `docs/reports/ROLE_DASHBOARD_PERMISSION_CORRECTION.md` | Retained the newer report and its 147-entry audit; rejected the older replacement. Updated unverified-schema wording rather than claiming tables are absent. |
| `mobile/lib/core/access.dart` | Rejected restored Student/Parent general attendance and Receptionist class access. Existing Teacher assigned-class access remains. |
| `mobile/lib/ui/screens.dart` | Kept current screen implementation; the overlay removes a Student class favorite already filtered by the current access policy, so copying it is unnecessary. |
| `src/portal/lib/navigation.ts` | Rejected broader directory, class and attendance permissions, renamed catalog route, and activation of unfinished skills. Retained existing gates; clarified pending backend verification wording. |
| `src/portal/lib/sidebarSections.ts` | Kept `systemCatalog` and existing hidden skill entries instead of introducing the overlay's renamed route and unfinished links. |
| `src/portal/lib/systemInventory.ts` | Incorporated the 147 original Arabic/English entries in `systemInventoryEntries.ts`, reconciled against this audit; retained category mappings and added a guarded related-module link helper. |
| `src/portal/pages/ModuleEntry.tsx` | Kept `canAccessModule` and `systemCatalog`; rejected the renamed route and placeholder skill pages. |
| `src/portal/pages/SystemInventory.tsx` | Incorporated per-entry expandable tables while retaining the existing enabled-module list, category summary, pending list, design and route. Links indicate related modules, not feature completeness. |
| `tests/role-navigation.test.mjs` | Kept existing stronger role tests and added direct attendance and class-management denial checks instead of adopting tests that expect broader access. |
| `updates/2026-11-13-role-access/README.md` | No matching project file; did not copy its outdated verification claims or branch/commit/push instructions. |

## Changed files

- `src/portal/lib/navigation.ts`
- `src/portal/lib/attendance.ts`
- `src/portal/lib/roles.ts`
- `src/portal/lib/sidebarSections.ts`
- `src/portal/lib/systemInventory.ts`
- `src/portal/lib/systemInventoryEntries.ts`
- `src/portal/lib/finance.ts`
- `src/portal/pages/LearnerHome.tsx`
- `src/portal/pages/PortalHome.tsx`
- `src/portal/pages/SystemInventory.tsx`
- `src/portal/pages/home/FamilyHome.tsx`
- `src/portal/pages/home/PersonalAttendancePanel.tsx`
- `src/portal/pages/home/StaffHome.tsx`
- `src/portal/pages/home/SuperAdminOverview.tsx`
- `src/portal/pages/learning/CoursesView.tsx`
- `src/portal/pages/ModuleEntry.tsx`
- `supabase/functions/manage-roles/index.ts`
- `supabase/migrations/014_public_read_and_status_permissions.sql`
- `supabase/migrations/020_cms_schema_and_private_helpers.sql`
- `mobile/lib/core/access.dart`
- `tests/role-navigation.test.mjs`
- `tests/system-inventory.test.mjs`
- `mobile/test/access_test.dart`
- `docs/reports/ROLE_DASHBOARD_PERMISSION_CORRECTION.md`

## Verification

- `node --test tests/*.test.mjs` — passed, 19 tests, including navigation,
  dashboards, system inventory, and scoped attendance checks.
- From `web\`, `npm test` — passed, 39 compatibility/unit tests.
- `npm run type-check` — passed.
- `npm run lint` — passed.
- `npm run build` — passed; Vite reported a large existing minified JavaScript
  chunk (about 1.29 MB).
- From `mobile\`, `flutter analyze --fatal-infos --fatal-warnings` — passed
  with no issues.
- From `mobile\`, `flutter test` — passed, 26 tests.
- The Super Admin/Student/Teacher static and behavior tests passed; the live
  Edge Function and authenticated backend role boundaries were not exercised.
- `node --check supabase\functions\manage-roles\index.ts` — passed syntax
  parsing only; Deno type-check was unavailable.
- Audit coverage check — all 147 source labels are present in this report.
- Supabase CLI, Docker, and `psql` are unavailable. The locally available
  `pglast` parser accepted migrations 014 and 020 at the top-level SQL grammar;
  it does not execute the PL/pgSQL blocks or function bodies, so this is not a
  migration replay. No Preview migration was applied and no deployment was
  attempted.
- GitHub PR #4's recorded Supabase Preview check is still failed:
  `public.cms_programs` does not exist at `ALTER POLICY cms_programs_write`
  in Preview project `mgibjusuglafbnlrkbep`. It has not been rerun with the
  current local changes. Web and mobile checks pass.
