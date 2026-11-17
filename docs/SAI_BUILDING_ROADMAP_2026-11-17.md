Yemen SAI V2 — Building and production roadmap
Roadmap revision: 17 November 2026
Disposition: Approved scope for incorporation into the existing master execution plan; deployment status must be verified against live evidence.
Identity: Yemen SAI Educational College — كلية ساي التعليمية اليمنية الصينية — 也门赛艾教育学院
1. Locked environment
- Development workspace: D:\SAI-College-Production only.
- GitHub: https://github.com/BARH000M/sai-college-production — main only.
- Supabase Main: aeryusbrulqdxjdynwfh — https://aeryusbrulqdxjdynwfh.supabase.co.
- Supabase dashboard: https://supabase.com/dashboard/project/aeryusbrulqdxjdynwfh.
- Website: https://www.sai-academic.com — React production portal.
- Mobile: Yemen SAI — existing Flutter Android and iOS application.
- Nine roles: super_admin, admin, teacher, accountant, receptionist, librarian, student, parent, content_editor. Preserve authorized multi-role accounts and branch/session scope.
- No new GitHub or Supabase branches, projects, development workspaces, Docker, force pushes, data resets or blind historical migration replay. Protected external backups and disposable native PostgreSQL test clusters are permitted solely for recovery/security testing.
2. Latest reported evidence and boundaries
This is a roadmap, not a fresh live database audit. Preserve newer verified repository evidence if it exists.
Checkpoint	Latest reported evidence	Remaining gate
Backup and recovery	Archive MAIN-20261117-164017 passed checksum/decompression; 94 restored tables, 93/96 data sections matched; 113 restored policies matched. Workspace backup verified 40,336 enumerated files, two directory links recorded as metadata. Edge and inventoried Storage backups preserved.	Partial restore only: five missing extensions, Windows-blocked pg_stat_statements, ensure_rls ownership and complete role/credential recovery remain unverified. Verify current managed backup/recovery option before production changes.
GitHub synchronization	cc6d389 checkpoint; Phase 3C and 4A subsequently reported pushed.	Verify current HEAD and remote without repeating completed audits.
Phase 3B	4610b20; 88 web tests, seven Deno tests, isolated role/RLS/concurrency tests passed.	SQL/Edge cutover and authenticated live acceptance pending.
Phase 3C	87bfc29; Main-only configuration and own-contact editing; 91 web, three integration, 53 Flutter tests reported passing.	New contact validation SQL and live verification pending; confirm active MCP session.
Phase 4A	0737f84; exams/results implemented, 98 web and 58 Flutter tests reported passing.	Later SQL/lint/analyzer failures appeared; final exit codes not supplied. Confirm corrections and deployment status.
Android/iOS release	Java 21 / Gradle 8.4 incompatibility reported.	Confirm current mutually compatible stable tooling, store SDK requirements, actual APK/AAB and macOS iOS build/signing.


Earlier Main reconciliation observed 40 local migrations, 16 recorded remotely, 13 matching versions and 27 local versions without matching history entries. Some effects already existed. Do not infer current counts or replay the backlog. System settings already existed and must be preserved. The independently provided YSMS V72–V77 settings audit is a requirements reference, not evidence that school_* objects or their reported functionality exist in Yemen SAI. Do not import its multi-tenant schema blindly.
3. The 16 phases
Status is source/deployment-specific. The scopes below are requirements, not claims of completion. Reuse existing features and validate gaps before writing new code.
Phase	Scope	Starting disposition
3B	Secure roles and account onboarding	Locally implemented/tested; reported pushed; production cutover pending
3C	Shared profiles and unified integration	Reported pushed; new SQL and live acceptance pending
3D	Admissions, enrollment and academic administration	Existing functionality; remaining contracts and parity unverified
3E	Attendance management	Existing functionality; live parity and gaps to verify
3F	Finance, fees and accounting	Existing functionality; scoped contracts and remaining gaps to verify
4A	Examinations and academic results	Reported pushed; final checks and deployment pending
4B	Learning exercises, assessments and homework	Existing partial implementation; resume after live baseline
4C	Chinese language learning engines	Further development required
5A	HR, staff profiles and documents	Partial/unverified; complete missing workflows
5B	Student services, certificates and printing	Partial/unverified; complete missing workflows
5C	System settings and configuration	Expanded phase; preserve existing settings and wire behavior
5D	Communications and notifications	Partial/unverified; provider integrations pending verification
5E	Front CMS and public website	Partial/unverified; complete publishing and parity
6A	Library, inventory, transport and dormitory	Mixed partial/unverified; complete real workflows
6B	Scholarships, alumni, recruitment and reports	Remaining implementation and acceptance to verify
7	Production deployment and acceptance testing	Begin now; continuous per-phase deployment and final acceptance


3B — Secure roles and account onboarding
Nine roles, multi-role identity, staff/teacher/student/parent onboarding, verified invitations and links, atomic role assignment, last-usable-Super-Admin protection, membership lockdown, all alternate role writers, granular action permissions (view/create/edit/delete/approve/export/print/manage settings), protected transactional audits and server-side enforcement. Coordinate manage-roles, school-admin, provision-learning-account and link-student-account with SQL contracts. Preserve existing accounts, memberships and access. Confirm management authorization/atomicity/mutation tests and authenticated Super Admin flow. Prevent forged client audit entries.
3C — Shared profiles and unified integration
One Main backend across React/Flutter, Main-only MCP and runtime configuration, own-row contact name/phone/locale, Auth-managed email and identity, role and timestamp protection, session persistence, student/parent links, privacy and cross-client synchronization. Preserve the three-column own-contact contract and validate server-side timestamps.
3D — Admissions, enrollment and academic administration
Enquiries and public applications, status/history/tracking, duplicate detection, scoped assignment and approval, enrollment into existing student records, private document uploads, eligibility and configurable fields, admission fees, terms and guardian acknowledgement, reference numbers and printable applications. Branches, sessions, classes, sections, subjects/courses, teacher assignments, timetables, transfers, promotions and graduation. Preserve history and establish retention rules.
3E — Attendance management
Assigned teachers and administrative review; student/staff attendance; present, absent, late, excused; uniqueness and concurrent submissions, timezone/date semantics, correction and approval, historical class/session ownership, student/verified-parent views, absence notification, reports and printing.
3F — Finance, fees and accounting
Fee schedules/groups, balances/installments, payment and receipt numbering, adjustments, discounts, refunds, income/expenses, currency/rates/rounding, payment methods, scoped accounting roles, append-only or immutable transaction history, idempotency, concurrent payment handling, reconciliation, decimal arithmetic, retention, reports, A4 and thermal receipts. External payment providers require explicit configuration and supported availability; never claim an unconnected provider works.
4A — Examinations and academic results
Exam scheduling, session/class/course/subject, teacher assignment, marks grid and server validation, grade bands and passing marks, draft/marks-entry/review/published transition and controlled reopen, audit trail, student and verified-parent published-only access, reports, transcripts and print/PDF support. Confirm any later failing checks are resolved before deploying.
4B — Learning exercises, assessments and homework
Course and lesson assessments, question banks, MCQ, true/false, matching, fill-in-the-blank, written responses, attempt limits/deadlines, saved attempts, server-side objective grading, manual teacher grading, feedback/result release, secure answer keys, assignments, private text/file submissions, progress, parent monitoring and notifications. Reuse existing learning and homework tables/contracts; no duplicate schemas.
4C — Chinese language learning engines
Listening, speaking/pronunciation, reading, character writing/stroke practice, vocabulary/image flashcards, pinyin and tones, spaced repetition, HSK/YCT preparation, achievements, personalized progress, offline downloads and synchronization. Voice/child privacy, appropriate retention and consent. Keep independent ScriptSai application architecture separate unless explicitly authorized to integrate.
5A — HR, staff profiles and documents
Employee and department directory, teachers and staff, qualifications, experience, employment contracts, protected documents, leave, attendance and payroll integration, staff ID cards, performance and employment reports. Keep HR/financial details restricted to authorized roles.
5B — Student services, certificates and printing
Service requests and approval, enrollment letters, certificates/transcripts, student IDs, download center, QR/barcode verification, official numbering and history, letterheads, PDF/print/export, admission and examination sheets, A4/thermal layout and supported thermal/ESC-POS integration. Preserve branding and prevent unauthorized exports.
5C — System settings and configuration
General/academic settings, institutional identity and branding, languages/translations, custom fields and system field visibility/required/read-only controls, student profile settings, upload size/type policies, module activation and backend enforcement, dashboard widget controls, settings history and auditing. Accept a setting as complete only if a saved value demonstrably changes an intended authorized behavior. Keep provider credentials outside ordinary settings.
5D — Communications and notifications
Announcements, inbox, scoped audiences and recipient isolation, in-app/push notifications, email/SMTP, WhatsApp/SMS, fee/attendance/exam/homework reminders, consent, quiet hours, retention, delivery logs, deduplication and retry. Provider integration must use supported server-side delivery and protected credentials; report unavailable providers honestly.
5E — Front CMS and public website
Website activation, homepage/theme/layout, pages and menus, header/footer, news/events/gallery, programs and courses, draft/preview/publish/unpublish, SEO metadata/sitemap, multilingual Arabic/English/Chinese content and public admission integration. Preview here means a content preview UI, not a new environment or branch. Only published content is public.
6A — Library, inventory, transport and dormitory
- Library: catalog, physical copies, availability/search, issue/return/renewal, limits/due dates, branch scope, duplicate issue prevention and history.
- Inventory: assets, items, stores, suppliers, stock movements/adjustments, assignments and reports.
- Transport: vehicles, routes, drivers, student assignments, fees, parent information.
- Dormitory: buildings/rooms/beds, occupancy, availability, assignments, fees and reports.
6B — Scholarships, alumni, recruitment and reports
Scholarship requests, eligibility, approval and awards; alumni records/communications; student CVs/achievements; vacancies, applications, review and interviews; academic/administrative/finance reports with branch/course/session filters, historical semantics, reconciled totals, pagination, loading/empty/error, PDF/CSV/Excel, explicit export/print rights. Do not treat missing data as zero.
7 — Continuous production deployment and acceptance
Verified recovery options, versioned reviewed SQL, dependency order and rollback, Edge Function deployments, Main-only CI/CD with manual approval, database and RLS checks, hosted React deployment, Flutter APK/AAB and signed iOS build on macOS, current stable store-compatible toolchain, actual device and live role testing, web/mobile consistency, performance/security, backup administration, deployment evidence and final store submission readiness. Backup/restore operations remain operator-controlled, not exposed to ordinary school users.
4. All 24 system-settings requirements
The reference report's row-level classifications total 4 complete, 7 partial, 4 placeholder and 9 missing (one by design), but these are not Yemen SAI status measurements.
#	Requirement	Owner phase
1	General: timezone, formats, language, week start, audit visibility	5C
2	Academic: sessions, passing mark, late threshold, promotion policy, certificate prefix	5C / 4A / 3D
3	College profile and branding	5C
4	Notification preferences, reminders and quiet hours	5D
5	WhatsApp provider, sender and templates	5D
6	SMS provider and templates	5D
7	SMTP/email sender, TLS and test-send	5D
8	Payment methods	3F
9	Print headers and templates	5B
10	Thermal printing	5B / 3F
11	Front CMS	5E
12	Roles and granular action permissions	3B / 5C
13	User administration	3B
14	Language switching and translations	5C
15	Currencies and exchange rates	3F
16	Custom fields (text/number/date/select/checkbox/file)	5C
17	System fields (visibility/required/read-only)	5C
18	Student profile settings	3C / 5C
19	Online admission window, fees, terms, eligibility and documents	3D
20	File types, max size and private Storage policies	5C
21	Modules and feature activation, enforced by backend	5C
22	Operator-controlled backup administration	7
23	Protected audit history	All phases
24	Student/parent portal widgets with actual behavior	5C


5. Immediate execution sequence
1. Synchronize this roadmap into the existing master plan and feature matrix. Verify current repository status and Main identity. Do not invent deployment evidence.
2. Complete targeted Phase 4A validation and inspect the exact production dependency gap for already built features. Complete management authorization tests applicable to the changed workflows.
3. Before the first hosted write, confirm current recovery point and availability of managed physical restore, fresh backup coverage as required, partial recovery limitations, exact SQL/Edge package dependencies, maintenance window, rollback and operator approval.
4. Deploy Phase 3B using the reviewed supabase/deployment/phase3b-main/ package and coordinated Edge cutover; verify authenticated administration and role safeguards. Use a reviewed Main-specific compatibility package rather than the historical migration backlog.
5. Deploy Phase 3C using supabase/deployment/phase3c-main/; verify contact persistence and role denials across clients.
6. Deploy Phase 4A using supabase/deployment/phase4a-examinations/ after validation/dependency approval; verify schedule, grading, publication, family visibility and report permissions.
7. Activate reviewed missing contracts of admissions, attendance and finance and verify existing academic administration. Preserve existing working data and schema. Prioritize genuine gaps; do not rebuild completed workflows.
8. Deploy verified React build to the existing hosting, build a Main-connected Flutter APK, validate release tooling and test physical devices; verify nine-role access and cross-client persistence. Deploy compatible backend before enabling dependent client features.
9. Resume 4B, then remaining roadmap phases; use one complete feature at a time. Phase 7 remains continuous.
6. Permanent completion criteria and status tracking
For every feature record: database contract and migration/package path; web status; mobile status; automated tests and exit codes; GitHub commit; hosted deployment status and actual object/function versions; authenticated live acceptance result; unresolved dependency/blocker. Use separate statuses for missing, placeholder, partial, implemented locally, tested locally, pushed, deployed and live-verified. A navigation item, table, static screen, saved setting or compiled APK alone does not establish readiness. Never fabricate evidence.

Cross-cutting standards: Arabic-first RTL with English/Chinese support; responsive accessible interfaces; loading/empty/error/retry states; branch/session/account scoping and all nine roles; RLS and restricted RPCs; trusted audit events; transactional data integrity, concurrency and negative permission tests; private Storage and protected providers; no secrets in Git or synthetic production data. Keep previous working functionality.
7. Synchronization and release governance
- Merge this revision into docs/MASTER_EXECUTION_PLAN.md (authoritative). Preserve existing history, recovery evidence, operational restrictions and newer verified results.
- Update docs/reports/FEATURE_COMPLETION_MATRIX.md with each phase and module as separate database/web/mobile/test/Git/deploy/live columns.
- Maintain docs/reports/PRODUCTION_DEPLOYMENT_STATUS.md (or the existing equivalent) with verified live contract inventory, deployment package paths, dependencies, exact SQL/Edge versions, commit, approvals, timestamps and test outcomes. Avoid duplicate tracking documents if an equivalent exists.
- Link the canonical roadmap from README/current documentation index and applicable agent instructions; mark older conflicting roadmaps superseded without deleting history.
- Use GitHub main as the sole version-controlled source. Keep Supabase MCP read-only for normal work; approved changes use controlled, project-verified deployment tooling. GitHub integration must not trigger unreviewed migrations. Review CI and external hosting hooks before pushing. Do not create a roadmap table in the application database solely to mirror Markdown. Track actual database changes in the existing reviewed migration/deployment mechanism; do not repair migration history without proven equivalence.
- Check that old .env, dumps, browser files and test metadata remain excluded. Historical committed copies remain a separate security risk: assess credential exposure and rotate exposed credentials securely; no unapproved history rewrite.
Required development cycle: Build → Test → Commit → Push → Approve and deploy → Verify live → Update roadmap → Continue.

Immediate action: Publish the consolidated roadmap on main, reconcile deployment records against Supabase Main read-only, and prepare the exact next controlled production deployment. Do not start additional unrelated features or execute hosted SQL solely to synchronize documentation.