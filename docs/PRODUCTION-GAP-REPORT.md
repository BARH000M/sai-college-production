# SAI College Production Gap Report

## Scope and evidence

This report records the workspace state observed during Phase 1, including the approved design-review prototype under `prototype/SAI-College-Redesigned-App`. Later remote verification is recorded separately in `WAVE-1-IMPLEMENTATION.md` and `WAVE-1-SECURITY-REVIEW.md`; it supersedes earlier statements here that the account and remote RLS had not been inspected. This is not a production-readiness assessment. Environment variable values and credentials were not read or included.

The production `web` app and `supabase/migrations` contain the implementation files described below. The production `mobile` directory was empty. The approved prototype and its own `docs` are present under `prototype/SAI-College-Redesigned-App`; the production-level `docs` directory contained no prior report before this document was created. The prototype is a visual and behavior reference, not a production app.

## Approved prototype and reference coverage

- All ten requested inspection targets are present: `VISUAL-MOCKUP.html`, `WEBSITE-PREVIEW.html`, `browser-preview/model.js`, `browser-preview/logic.js`, `browser-preview/review.js`, `browser-preview/reference1087.css`, `docs/role-module-map.json`, `docs/feature-inventory.csv`, `QA-REPORT.md`, and `tests/review-regressions.cjs`. The approved image and logo are also present at `visuals/APPROVED-REFERENCE.png` and `browser-preview/assets/sai-logo.png`.
- The role map and model define exactly nine roles: `super_admin`, `admin`, `teacher`, `accountant`, `receptionist`, `librarian`, `student`, `parent`, and `content_editor`.
- The role map and feature inventory define 32 top-level modules across five pillars:
  - Institution (4): home, branches, reports, settings.
  - Administration (6): admissions, students, academics, timetable, attendance, QR attendance.
  - Learning (13): courses, listening, speaking, tones, vocabulary, handwriting, reading, spaced review, homework, quizzes, exams, certificates, progress.
  - Content (4): authoring, media, approvals, CMS.
  - Operations (5): finance, staff, reception, library, communications.
- **Visual application structure:** Arabic RTL review shell with college logo/brand and version banner; role/account picker; phone/web preview gallery and approved-reference shortcuts; desktop sidebar and header with search, notifications, profile, and branch/session context; dashboard welcome/KPI cards, chart, quick links, schedule and notices; section headings, tabs, cards, tables and filters; class capacity and family/guardian panels; content/learning cards with Chinese Hanzi and Pinyin; dialogs/forms, status tags, toast/status feedback, print layouts, and role-specific mobile bottom navigation. The separate public-site preview includes a sticky brand/navigation header, Chinese-learning hero, program cards and filters, college information/features, FAQ, enquiry/contact form, and footer.
- **Visual system:** local Cairo font assets; white surfaces, deep navy text, vivid red primary actions, restrained gold, compact cards, colored status tags, responsive phone/tablet/desktop breakpoints, visible keyboard focus, and reduced-motion/print styles. The reference stylesheet declares mobile behavior at 900px and narrower breakpoints, including 360px, and the QA report covers preview widths down to phone sizes.
- **Existing prototype interactions:** assigned-role account switching (no role assignment UI), role-specific module/tab navigation, branch/session sample scoping, global search, quick links, notification state, dashboard navigation, admission enquiry/stage changes, guardian-child link preview/confirmation, student/class views and capacity filtering/details, attendance marking, homework submission/grading, Chinese listening/speaking/tone/vocabulary/handwriting/reading/quiz/review flows, lesson authoring/revision/submission/review/approval/publish and prior-published snapshot, sample library issue/return, local finance/receipt entries, notices/templates, CMS draft state, audit trail, CSV preview/validation/import/export, print previews, website program filters and responsive navigation, FAQ expansion, and local-only enquiry confirmation.
- **Prototype data and boundary:** `model.js` provides fixed sample accounts, classes, students, and Chinese-learning content; `logic.js` and `review.js` enforce illustrative permission/scope rules and mutate in-memory/session state. CSV import only updates the prototype session. The prototype README and `logic.js` explicitly say that server/database authorization and persistence are required in production. The sample values, client-side guards, local confirmations, and prototype-generated audit/finance/content records are not production data or proof of authorization.
- **Test evidence:** `QA-REPORT.md` documents 26 automated checks and browser checks, while explicitly noting that they do not cover a real backend, authentication, database authorization, payment provider, native app build, microphone assessment, QR scanning, or production deployment. During this inspection, `node --test prototype/SAI-College-Redesigned-App/tests/review-regressions.cjs` passed all 26 tests, including a mocked render of 563 account/role/module/tab combinations. This is prototype-only evidence, not production web/mobile validation.
- `reference-source/previous-flutter-app` and `reference-source/previous-windows-app` are explicitly described by the prototype README as preserved earlier projects, not the current approved nine-role implementation. They do not make the production `mobile` directory a Flutter app.

## What is currently real

- The web app is a minimal React/TypeScript/Vite scaffold.
- `web/src/lib/supabase.ts` creates a Supabase client using `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`, and throws if either is missing.
- Both `web/.env` and `web/.env.local` exist. Both contain non-empty values for those two variable names. No service-role variable name was found in either file, and no service-role reference was found in `web/src`. This confirms local variable presence only; it does not validate the values or establish a live connection.
- `web/src/App.tsx` and `web/src/lib/auth.ts` implement email/password sign-in/out, persisted-session restoration, and authenticated `public.profiles` / `public.user_roles` lookups by user ID. The verification panel shows assigned roles and surfaces profile, role-query, and auth errors without substituting a role when lookup fails.
- `supabase/migrations/001_initial_schema.sql` defines the `app_role` enum with the nine requested roles and these tables: `profiles`, `user_roles`, `branches`, `academic_sessions`, `branch_memberships`, `classes`, `students`, `parent_student_links`, and `audit_logs`.
- The initial migration has indexes for class branch/session scope, student branch/class scope, and parent-to-student links.

Live authentication, data access, account access, and the `info@saicollege.com` role assignment were not verified. The workspace inspection does not establish that migration 001 is applied to the remote project.

## Phase 2 connection verification

- `web/.env.local` contains exactly the two expected variable names, `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`; their values were not displayed. No service-role key reference was found in the browser source.
- The browser client uses only those Vite variables. A request to the configured Supabase Auth health endpoint returned HTTP 200, confirming that the endpoint is reachable.
- The app now restores the persisted Supabase session on page load and displays an explicit signed-out/loading/authenticated state with a verification panel. A browser refresh was checked and correctly displayed signed-out because there was no active saved session in that browser.
- The sign-in and sign-out flows are implemented, but no password was available for `info@saicollege.com`; no live sign-in or sign-out was attempted. Therefore account detection, assigned roles, profile loading, `user_roles` loading, and their live RLS outcomes remain unverified. The report does not claim the expected `super_admin` role was confirmed.
- `npm run build` passed from the `web` project directory after the TypeScript configuration was added. This verifies compilation/bundling only, not remote authentication or authorization.

## What is currently mock or incomplete

- No existing web data mutation or product workflow was found. The current UI does not contain evidence of mock database-backed records, but it is only a sign-in/profile/role display and is not the production application.
- The displayed `SAI` mark is styled text rather than the supplied logo. The page uses Arial rather than Cairo.
- The web app does not provide application routes, route guards, role selection, branch/session selection, navigation, or role-specific dashboards.
- `loadUser` does not report `getUser` failures or profile-query errors. Authentication and profile data have not been tested against Supabase.
- `web/src/lib/supabase.yaml` contains a duplicate Supabase client implementation written as TypeScript, despite the `.yaml` extension; it is not imported by the current app.
- The prototype is available and provides clear visual/feature references, but its styles and sample behavior have not been integrated into the production web app. Its client-side permissions and in-memory state must not be copied as production authorization or persistence.

## What must become real database/server behavior

- Authentication, profile reads, and assigned-role visibility must use the authenticated Supabase session and actual `profiles`/`user_roles` rows. Role changes must remain server-controlled; a prototype account/role selector is not a production role-assignment flow.
- Branch and academic-session lists/selections, membership, and all scoped queries must use authorized database records. Student ownership, verified parent-child links, and teacher class assignments must be enforced by RLS/server-side checks, not the prototype's JavaScript filters.
- Student, class, admission, guardian-link, timetable, attendance, homework/submission/grading, course/lesson/progress, quiz/exam/result, certificate, fee/invoice/payment/receipt, income/expense, staff, reception, library loan, notice/message, and CMS workflows need persisted schema, validated mutations, ownership/scope rules, and user-visible loading/success/validation/server/permission errors.
- Lesson authoring, revisions, submission, review, approval, publication, and published snapshots require server-side workflow state and audit records; content editors must not approve their own content. Media requires safe storage and metadata policies.
- CSV validation/preview can be client-assisted, but duplicate detection, branch/session/class capacity, authorization, import commit, and any account invitation must be validated server-side. The current sample import must not be mistaken for a persisted import.
- Audit events must be written and protected on the server/database. Finance records shown in the prototype are local samples, not payments or evidence of a payment integration.
- Search, notifications, public-site enquiry submission, and any actual QR scanning, speaking assessment, handwriting recognition, and certificate issuance need real integrations/validated persistence before being presented as completed production actions. The prototype expressly marks some of these as illustrative or placeholders.

## Missing database tables

The following requested MVP tables are absent from migration 001 and no later migration exists in the workspace:

- Learning/content: `course_catalog`, `course_levels`, `lessons`, `lesson_translations`, `lesson_media`, `lesson_revisions`, `lesson_approvals`, `lesson_publications`, `vocabulary`, `vocabulary_reviews`, `homework`, `homework_submissions`, `quizzes`, `quiz_questions`, `quiz_attempts`, `exams`, `exam_results`, and `certificates`.
- Academy operations: `attendance_records`, `fee_groups`, `fee_discounts`, `invoices`, `invoice_items`, `payments`, `income_records`, `expense_records`, `staff_profiles`, and `admission_enquiries`.
- Communications, library, and CMS: `notices`, `message_templates`, `library_books`, `library_loans`, `cms_pages`, `cms_navigation`, and `cms_banners`.

The existing `classes` and `students` tables are only foundational schema; they do not supply the missing workflows or data models above.

## Missing RLS and authorization evidence

- Migration 001 contains no `ENABLE ROW LEVEL SECURITY` statements or `CREATE POLICY` statements. No row-level authorization policies are present in the inspected migrations.
- No migration-defined server-side authorization helpers, role-management workflow, or policies enforcing branch/session scope, student ownership, parent-linked-child access, or teacher class assignments were found.
- No visible policy prevents browser clients from inserting or changing `user_roles`.
- The visible schema has no branch-scoped staff assignments or attendance/finance/library/content permissions to enforce for the requested roles.
- Remote Supabase RLS state was not queried, so the absence of policies in local migrations is not a claim about the current remote database configuration.

## Missing web screens and flows

The only screen is sign-in and a basic authenticated profile/role summary. No requested role-specific dashboard or product screen is implemented for any of the nine roles.

Missing shared application capabilities include the role-aware route guard, role selector limited to assigned roles, branch/session switchers, search, notifications, quick links, desktop sidebar, role-specific mobile navigation, responsive layouts, the approved logo/Cairo/RTL visual system, and consistent loading/empty/error/success states. These are visible in the prototype but absent from production.

Missing role workflows include:

- Super admin: users/profiles, branches, sessions, audit logs, and settings.
- Admin: admissions, student/class management, timetables, attendance, finance overview, approvals, and reports.
- Teacher: assigned classes/students, attendance, homework grading, exams, and permitted lesson authoring.
- Accountant: fee groups, invoices, discounts, payments/receipts, income/expenses, and reports.
- Receptionist: enquiries, registration, visitors, and communication records.
- Librarian: catalogue, issue/return, and overdue records.
- Student: classes, learning content, homework, quizzes/exams, attendance, fees, progress, and certificates.
- Parent: linked children, attendance, grades, homework, fees, and announcements.
- Content editor: multilingual lesson authoring, media metadata, revisions, submission, and review status.
- Preserved prototype-specific flows: guardian linking, class capacity, CSV validation/import, and role audit.

## Missing mobile screens

The production `mobile` directory contains no files. The Flutter project, `pubspec.yaml`, Supabase integration, secure session handling, RTL/Cairo setup, role-aware routing, and all requested mobile role flows are absent. An older Flutter project is archived inside the prototype's `reference-source/previous-flutter-app`; it is not the production mobile implementation or the approved current nine-role app.

## Missing tests and checks

- No web tests or test files were found. `web/package.json` defines `npm run test` as a deliberate “no test specified” failure.
- `npm run check` is not defined.
- `npm run build` is configured but was not run during this inspection.
- No SQL/RLS verification scripts, database tests, Flutter tests, or mobile routing tests were found.
- Flutter commands cannot run against this workspace as there is no Flutter project or `pubspec.yaml`.

## Blockers

1. The approved prototype is available, but its in-memory fixtures are not connected to production; design reuse must preserve the prototype and avoid treating sample data or client-side guards as production behavior.
2. The remote Supabase project, applied migration state, working credentials, authentication, and super-admin account/role assignment remain unverified. Do not treat `.env` variable presence as successful connectivity.
3. There is no local RLS policy implementation or verification. Sensitive production workflows must not be built on client-only authorization.
4. The database currently lacks the product-domain tables required by the MVP.
5. The web scaffold has no role-specific screens, route protection, production tests, or runnable test/check scripts. Prototype test results apply only to the prototype.
6. There is no production Flutter project to inspect or validate; the archived earlier app is not a substitute.
7. Actual production records and account data were not inspected; implementation must not infer or fabricate them.

## Recommended implementation order

1. Use the existing approved prototype at `prototype/SAI-College-Redesigned-App` as the visual/feature source of truth. Keep the prototype unchanged; do not copy its mock state or client-only authorization into production.
2. In a separate verification phase, safely validate the Supabase URL/key configuration, remote project, applied schema, authentication, and `info@saicollege.com` profile and assigned roles. Do not print or commit credential values; stop on unresolved access or role errors.
3. Design and add sequential, non-destructive migrations for the MVP domain tables, constraints, indexes, and audit behavior. Preserve migration 001.
4. Implement RLS and server-side authorization for all nine roles, including branch/session scope, student ownership, verified parent-child links, teacher assignments, finance/library/content permissions, and protected role assignment.
5. Add SQL verification for each critical policy path and prove unauthorized reads/writes are denied before exposing new data workflows.
6. Harden reusable web authentication/profile/role utilities and role-aware route protection, surfacing actual auth, profile, and role lookup errors.
7. Build the shared Arabic RTL/Cairo application shell from the restored prototype; then deliver web workflows incrementally, starting with foundational administration and enrollment/academics, followed by teaching, finance, reception, library, student/parent learning, and content authoring/approval.
8. Add validated CSV student/guardian import only after server-side authorization and capacity/duplicate rules exist. Do not assign roles or create passwords from the public client.
9. Build the Flutter application against the same Supabase project and role model after the shared schema and authorization contracts are stable.
10. Add and run web, SQL/RLS, and Flutter tests; build/analyze both clients; then complete the dedicated security review and production-readiness checklist. Do not claim production readiness while any critical verification remains outstanding.
