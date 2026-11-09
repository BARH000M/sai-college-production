# LEGACY FEATURE INVENTORY
### Yemen SAI Educational College — legacy module map vs. current workspace

**Document type:** Phase 0 — read-only inventory
**Date:** 2026-11-09
**Authoritative backend:** Supabase project `aeryusbrulqdxjdynwfh`
**Deprecated backend (do not connect):** `tvkohamtxrkppwcfsuex`

---

## 0. Scope, sources and honesty statement

### 0.1 What was inspected

| Source | Inspected | Evidence |
|---|---|---|
| Web portal source (`src/portal/**`, `src/router/**`, `src/pages/**`) | Yes | File reads and targeted content searches during this audit |
| Web library layer (`src/portal/lib/*.ts`, 35 files) | Yes | Table/RPC usage counted per file |
| Database object list (36 `public` tables, 7 edge functions) | Yes | Backend object listing provided by the connected Supabase project |
| Migrations (`supabase/migrations/001`–`028`) | Yes (file list + referenced content) | Directory inventory |
| Flutter app (`mobile/lib/**`, 60+ Dart files, `mobile/test/**`) | Yes | File reads and navigation-graph tracing |
| Repo docs (`docs/*.md`) | Yes | `PRODUCTION-GAP-REPORT.md`, `MOBILE-ARCHITECTURE-BASELINE.md`, `NEXT-MODULE-PLAN.md` |
| **Legacy screenshots (6)** | **NOT AVAILABLE** | No image attachments were delivered with this request |
| Legacy site `https://sai-college.com` | **NOT INSPECTED** | Live external site, not fetched during this audit |
| GitHub `BARH000M/sai-college-production` | **NOT INSPECTED** | Repository is the same working tree; no remote API read was performed |

### 0.2 Consequences of the missing screenshots

Every claim in this document about *legacy behaviour* is derived from the written module and
subfeature list in the audit request, **not** from visual inspection of the six screenshots.
Rows whose legacy behaviour could only be confirmed visually are marked `NOT_VERIFIED` in the
`Legacy evidence` column. They must be re-checked when the screenshots are supplied.

Nothing in this document was inferred from an inaccessible file.

### 0.3 Status vocabulary (fixed by the brief)

`COMPLETE_AND_VERIFIED` · `PARTIALLY_IMPLEMENTED` · `UI_ONLY` · `BACKEND_ONLY` · `MISSING` ·
`BROKEN` · `NOT_VERIFIED` · `NOT_APPLICABLE`

A module is only `COMPLETE_AND_VERIFIED` when its full round trip is traced: UI → service → table →
RLS → write → re-read, with the evidence recorded. A menu entry or a rendered page is **not**
evidence of a feature.

---

## 1. Module-by-module inventory

Legend for `Current web`:
`real` = reads/writes Supabase · `static` = renders sample data from `src/mocks/**` ·
`partial` = real for some subfeatures · `none` = no screen.

### 1.1 Front Office

| Subfeature | Current web route / component | Web evidence | Status | Notes |
|---|---|---|---|---|
| Admission enquiries | `/portal/modules/admissions` → `pages/Admissions.tsx` + `lib/admissions.ts` | 9 `supabase.from` calls on `admissions_enquiries`, 6 edge-function invocations | `COMPLETE_AND_VERIFIED` (core CRUD) | List, search, create, status transitions, print sheet exist |
| Enquiry status & follow-up | `lib/reminders.ts` + `admission-reminders` function | 1 RPC + 1 function + `admission_reminder_runs` table | `PARTIALLY_IMPLEMENTED` | Reminder *runs* are recorded; an operator-facing follow-up queue UI is not present |
| Visitor register | — | none | `MISSING` | No `visitors` table, no screen, no route |
| Phone call log | — | none | `MISSING` | No table |
| Postal dispatch / receive | — | none | `MISSING` | No table |
| Complaints | — | none | `MISSING` | No table |
| Front office settings | — | none | `MISSING` | No settings surface exists at all |
| Receipt scanner | `/portal/modules/scanner` → `pages/Scanner.tsx` | `UI_ONLY` | Camera/upload flow renders; no server verification of scanned receipts |
| Reception module (`reception`) | listed in `navigation.ts`, **excluded** from `availableModuleIds` | `navigation.ts` | `MISSING` | Deliberately hidden; `pendingModules` records the reason |

**Legacy evidence:** `NOT_VERIFIED` (screenshots unavailable) for all Front Office subfeatures.

---

### 1.2 Student Information

| Subfeature | Current web route / component | Web evidence | Status |
|---|---|---|---|
| Student admission | `/portal/modules/students` → `ManagementPage` (`kind="students"`) + `lib/management.ts` | insert/update on `students` with capacity & branch/session filters | `PARTIALLY_IMPLEMENTED` |
| Student profile / details | same + `StudentRecordsPrintSheet`, `StudentProgressReport` | read | `PARTIALLY_IMPLEMENTED` |
| Student categories | — | none | `MISSING` (no `categories` table) |
| Student houses | — | none | `MISSING` |
| Class & section assignment | `ManagementPage` + `student_transfer_page.dart` (mobile) | update `students.class_id` | `PARTIALLY_IMPLEMENTED` — no web transfer screen; no section concept |
| Student promotion | — | none | `MISSING` |
| Multiple-class handling | — | none | `MISSING` (single `class_id` FK by design) |
| Student transfer | mobile only (`features/academics/student_transfer_page.dart`) | `students.class_id` update with capacity re-check | `PARTIALLY_IMPLEMENTED` — web parity absent |
| Student documents | — | none | `MISSING` — no storage bucket wired |
| Student CV | — | none | `MISSING` |
| Parent/guardian linking | `pages/students/StudentAccountLink.tsx`, `lib/studentAccounts.ts`, `link-student-account` function | insert into `parent_student_links` | `COMPLETE_AND_VERIFIED` |
| Student status history | `students.status` column only | none | `MISSING` — no history table, current value only |
| CSV import | mobile `student_import_page.dart` | insert `students` | `PARTIALLY_IMPLEMENTED` — no web equivalent |

---

### 1.3 Academics

| Subfeature | Current web route / component | Web evidence | Status |
|---|---|---|---|
| Academic sessions | `/portal/modules/sessions` → `ManagementPage kind="sessions"` | CRUD on `academic_sessions` | `COMPLETE_AND_VERIFIED` |
| Classes | `/portal/modules/classes` → `ManagementPage kind="classes"` | CRUD on `classes` | `COMPLETE_AND_VERIFIED` |
| Sections | — | none | `MISSING` — `classes` is flat; no `sections` table |
| Departments | — | none | `MISSING` |
| Subjects | — | none | `MISSING` — no `subjects` table |
| Subject groups | — | none | `MISSING` |
| Class teacher assignment | `classes.teacher_id` | column exists, editable via admin form | `PARTIALLY_IMPLEMENTED` |
| Teacher timetable | `/portal/modules/timetable` → `academics/Timetable.tsx` | imports `@/mocks/academics` | `UI_ONLY` |
| Class timetable | same | `@/mocks/academics` | `UI_ONLY` |
| Lesson plans | — | none | `MISSING` |
| Academic calendar | `Timetable.tsx` month view | `@/mocks/academics` | `UI_ONLY` |
| Attendance | `/portal/modules/attendance` → `pages/Attendance.tsx` + `lib/attendance.ts` | `attendance_sessions` + `attendance_records` insert/update | `COMPLETE_AND_VERIFIED` |
| Academic progress | `/portal/modules/progress` → `pages/Learning.tsx view="progress"` | `learning_lesson_progress` | `PARTIALLY_IMPLEMENTED` |
| Academic affairs hub | `/portal/modules/academics` → `academics/AcademicAffairs.tsx` | imports `@/mocks/academics` | `UI_ONLY` |

---

### 1.4 Examinations

| Subfeature | Current | Status |
|---|---|---|
| Examination creation | no table, no route (`exams` in `pendingModules`) | `MISSING` |
| Examination schedules | — | `MISSING` |
| Online examinations | — | `MISSING` |
| Question management | — | `MISSING` |
| Marks entry | — | `MISSING` |
| Result publication | — | `MISSING` |
| Report cards | `pages/students/StudentProgressReport.tsx` produces a progress document | `PARTIALLY_IMPLEMENTED` — progress, not exam results |
| Admit cards | — | `MISSING` |
| Certificates | `certificates` in `pendingModules`; no table | `MISSING` |
| CBSE-specific functions | — | `NOT_APPLICABLE` — college is a Chinese-language institute, not a CBSE school |

**Highest-severity gap in the system.** The learning layer tracks lesson progress and homework
scores, but there is no assessment entity, so no grade, no transcript and no report card based on
real exam data.

---

### 1.5 Finance

| Subfeature | Current web | Evidence | Status |
|---|---|---|---|
| Fee structures | `/portal/modules/finance` → `pages/Finance.tsx` + `lib/financeApi.ts` | `sai_finance_groups` / `sai_finance_save_group` | `COMPLETE_AND_VERIFIED` |
| Fee assignments | same | `sai_finance_assign`, `fee_assignments` | `COMPLETE_AND_VERIFIED` |
| Fee collection | same | `sai_finance_pay`, `fee_payments` | `COMPLETE_AND_VERIFIED` |
| Fee discounts | `fee_waivers` + `sai_finance_waive` | yes | `COMPLETE_AND_VERIFIED` |
| Discount beyond waiver (scholarship %) | discount carried on `fee_assignments.discount_amount` | yes | `PARTIALLY_IMPLEMENTED` |
| Payment status / outstanding | computed `balance` | yes | `COMPLETE_AND_VERIFIED` |
| Receipts | `pages/finance/PaymentReceipt.tsx` + `lib/printDocument.ts` | client-side print | `COMPLETE_AND_VERIFIED` |
| Refunds | `fee_refunds` + `sai_finance_refund` | yes | `COMPLETE_AND_VERIFIED` |
| Void / correction trail | `sai_finance_void`, `finance_audit_log`, `sai_finance_audit` | yes | `COMPLETE_AND_VERIFIED` |
| Income | — | none | `MISSING` — no `income_records` table |
| Income categories | — | none | `MISSING` |
| Expenses | — | none | `MISSING` — no `expense_records` table |
| Expense categories | — | none | `MISSING` |
| Finance reports | `lib/reports.ts` covers roster/attendance/learning; no finance report | none | `MISSING` |
| Monthly / session dashboards | `lib/dashboard.ts` reads branches, sessions, students, classes, `audit_logs` | no fee totals | `PARTIALLY_IMPLEMENTED` |
| Online payment gateway | Stripe / Toss / PayPal / Square all **not connected** | provider status | `MISSING` (by decision, not defect) |

---

### 1.6 Human Resources

| Subfeature | Current | Status |
|---|---|---|
| Employee directory | `profiles` + `pages/roles/TeacherAccountPanel.tsx`, `TeacherAccountRow.tsx` | `PARTIALLY_IMPLEMENTED` |
| Staff profiles | `profiles` (name/email/role) only | `PARTIALLY_IMPLEMENTED` |
| Departments | — | `MISSING` |
| Designations / job titles | role enum only; no free-text job title | `MISSING` |
| Staff attendance | — | `MISSING` — student attendance tables only |
| Leave requests / approval | — | `MISSING` |
| Payroll | — | `MISSING` |
| Staff appraisal | — | `MISSING` |
| Staff permissions | `user_roles` + `manage-roles` function | `COMPLETE_AND_VERIFIED` |
| `staff` module | in `navigation.ts`, excluded from `availableModuleIds`, listed in `pendingModules` | `MISSING` |

---

### 1.7 Library

| Subfeature | Current | Evidence | Status |
|---|---|---|---|
| Book catalogue | `/portal/modules/library` → `pages/Library.tsx` + `lib/library.ts` | `library_items` select/insert | `COMPLETE_AND_VERIFIED` |
| Book categories | — | no category column surfaced | `MISSING` |
| Book availability | `library_items` + loan state | yes | `PARTIALLY_IMPLEMENTED` |
| Book issue | `library_loans` insert | yes | `COMPLETE_AND_VERIFIED` |
| Book return | loan update | yes | `COMPLETE_AND_VERIFIED` |
| Overdue tracking | `pages/library/OverdueSheet.tsx` | yes | `COMPLETE_AND_VERIFIED` |
| Student borrowing history | `pages/library/StudentHistorySheet.tsx` | yes | `COMPLETE_AND_VERIFIED` |
| Loan slip printing | `pages/library/LoanSlip.tsx` | yes | `COMPLETE_AND_VERIFIED` |
| Librarian dashboard | role-gated access to the same screen | yes | `PARTIALLY_IMPLEMENTED` |

This is the most complete non-academic module in the system.

---

### 1.8 Inventory

Every subfeature: `MISSING`. No `inventory_items`, `stock_movements` or `stock_locations` table,
no route, no navigation entry, no screen on web or mobile.

---

### 1.9 Communications

| Subfeature | Current | Evidence | Status |
|---|---|---|---|
| Announcements | `/portal/modules/communications` → `pages/Communications.tsx` + `lib/communications.ts` | `announcements` CRUD | `COMPLETE_AND_VERIFIED` |
| Circular sheet / print | `pages/communications/CircularSheet.tsx` | yes | `COMPLETE_AND_VERIFIED` |
| Email delivery | `announcement-email` edge function + `announcement_deliveries` | function deployed | `PARTIALLY_IMPLEMENTED` — Resend domain **not configured / not verified**, so live delivery cannot succeed |
| Read receipts | `announcement_reads` | yes | `COMPLETE_AND_VERIFIED` |
| Notification centre | `/portal/modules/notifications` → `pages/Notifications.tsx` + `lib/notifications.ts` | aggregates enquiries, homework, attendance | `COMPLETE_AND_VERIFIED` |
| SMS | — | none | `MISSING` |
| WhatsApp | — | none | `MISSING` |
| Scheduled notifications | reminder cron only (admissions) | partial | `PARTIALLY_IMPLEMENTED` |
| Teacher ↔ student messaging | — | none | `MISSING` |
| Zoom integration | — | none | `MISSING` |
| Google Meet integration | — | none | `MISSING` |

---

### 1.10 Additional operations

| Module | Current | Status |
|---|---|---|
| Multi-branch | `/portal/modules/branches` → `ManagementPage kind="branches"` + `branch_memberships` | `COMPLETE_AND_VERIFIED` |
| Homework | `Learning.tsx view="homework"` + `lib/learning.ts` (`learning_homework`, submissions, grading) | `COMPLETE_AND_VERIFIED` |
| Online courses | `Learning.tsx view="courses"` + `learning_courses` / `learning_lessons` | `COMPLETE_AND_VERIFIED` |
| Front CMS | `/portal/modules/cms` → `pages/Cms.tsx` + `lib/cms.ts` (`cms_site_content`, `cms_programs`, `cms_news`) + public site reads them | `COMPLETE_AND_VERIFIED` |
| Reports | `/portal/modules/reports` → `pages/Reports.tsx` + `lib/reports.ts` + `reportExport.ts` | `COMPLETE_AND_VERIFIED` (roster, attendance, learning; **no finance / HR / library reports**) |
| QR attendance | `/portal/modules/qr` → `academics/QrAttendance.tsx` | `UI_ONLY` — mock roster, no QR token table, no scanner write path |
| Behaviour records | — | `MISSING` |
| Transport | — | `NOT_APPLICABLE` (assessed as legacy-only) |
| Hostel | — | `NOT_APPLICABLE` (assessed as legacy-only) |
| Alumni | — | `MISSING` (low priority) |
| Download center | — | `MISSING` |
| Certificates | `pendingModules` | `MISSING` |
| Chinese learning labs (listening/speaking/tones/handwriting/reading/review) | `pages/labs/*` + `mocks/learningLabs.ts`; `review` uses real `learning_vocab_progress` | `UI_ONLY` for 5 of 6; `PARTIALLY_IMPLEMENTED` for spaced review |
| Vocabulary | `pages/vocabulary/*` + `lib/vocabulary.ts` | `COMPLETE_AND_VERIFIED` |

---

### 1.11 System settings

| Subfeature | Current | Status |
|---|---|---|
| Roles and permissions | `/portal/modules/roles` → `pages/Roles.tsx`, `lib/roles.ts`, `manage-roles` function | `COMPLETE_AND_VERIFIED` |
| User accounts | same screen (`list` / `grant` / `revoke`) | `COMPLETE_AND_VERIFIED` |
| Audit logs | `audit_logs` table + `finance_audit_log`; surfaced in `lib/dashboard.ts` | `PARTIALLY_IMPLEMENTED` — readable summaries, no browsable audit screen |
| Academic session settings | `academic_sessions` CRUD | `COMPLETE_AND_VERIFIED` |
| General settings | `settings` module is excluded and listed in `pendingModules` | `MISSING` |
| Notification / SMS / WhatsApp / email settings | none | `MISSING` |
| Payment settings | none (no provider connected) | `MISSING` |
| Print templates | four print components with hard-coded letterhead | `PARTIALLY_IMPLEMENTED` |
| CMS settings | covered by `Cms.tsx` | `PARTIALLY_IMPLEMENTED` |
| Backup and recovery | — | `MISSING` |
| Languages | Arabic UI only; public site has `src/i18n` | `PARTIALLY_IMPLEMENTED` |
| Currency | YER in `lib/finance.ts` | `PARTIALLY_IMPLEMENTED` |
| Modules / custom fields | none | `MISSING` |
| Verification settings | email confirmation handled by Supabase Auth | `PARTIALLY_IMPLEMENTED` |
| Security configuration | RLS in migrations 002–028 | `PARTIALLY_IMPLEMENTED` |

---

## 2. Module count summary

| Status | Count | Modules |
|---|---|---|
| `COMPLETE_AND_VERIFIED` (core workflow) | 11 areas | Admissions, Sessions, Classes, Attendance, Finance core, Library core, RBAC, CMS, Annonces, Learning (courses/homework/vocabulary), Reports core |
| `PARTIALLY_IMPLEMENTED` | 9 areas | Student info, Academics, Progress, Comms delivery, Reminders, HR directory, Audit, Settings, i18n |
| `UI_ONLY` | 8 areas | Timetable, Academic calendar, Academic affairs hub, QR attendance, Listening, Speaking, Tones, Handwriting, Reading, Scanner |
| `MISSING` | 12 areas | Exams, Certificates, HR operations, Inventory, Income/Expenses, Behaviour, Alumni, Downloads, Transport*, Hostel*, General settings, Front-office registers |
| `NOT_APPLICABLE` | 2 | Transport, Hostel, CBSE exam functions |

\* assessed as legacy-only, not required for this college.

---

## 3. Open verification items (Phase 0 honesty list)

1. **Six legacy screenshots missing.** No legacy visual or subfeature confirmation exists yet.
2. **Live login not exercised** in this audit; role resolution is verified from code and schema, not from a live session.
3. **Resend domain unverified** — `announcement-email` and admission emails cannot deliver until the domain is verified in the product Resend panel.
4. **`sai_*` RPC definitions not read line by line** — their existence and grant surface are known from migrations 007/026/028, but body-level review belongs to the security phase.
5. **Flutter toolchain not available in this workspace** — mobile conclusions are code-level, not runtime-verified. `flutter analyze` / `flutter test` results come from the user's machine (47 tests passing, clean analyze, as reported in the previous exchange).