# Yemen SAI V2 — Building and production roadmap

**Current main synchronization checkpoint — 20 November 2026:** PR #8 (SEC-02) is merged on `origin/main` at `f094b52`; local `main` combines it with the Phase 5A HR commit `14bfc10`. The combined implementation passed local validation; complete the local merge commit before resuming the remaining Phase 5A work. Do not push until the combined implementation passes validation and deployment safety is confirmed. Do not modify production or deploy.

**SEC-01 / SEC-02 history:** SEC-01 assessment findings and evidence are retained in `docs/security/SEC-01-AUDIT-REPORT.md` and the associated reports; its completed assessment does not mean hosted controls passed. SEC-02 local remediation and its successful PR #8 integration are recorded in `docs/security/SEC-02-REMEDIATION-CLOSEOUT.md`. The SEC-02 checks were run before this HR combination, so the results below must not be presented as validation of the combined tree. SEC-01 findings F01–F12 remain open for production until their required deployment and live evidence exist. The earlier PR check failure caused by missing SPA build configuration was corrected locally; the Supabase Preview integration still points at a different project. Do not push until the owner confirms it is rebound to the authoritative project or disabled.

**Outstanding security gates:** SEC-03 requires exact deployed web/mobile/database/RPC/Edge source parity, known Auth/Storage contracts and a signed distribution artifact. SEC-04 requires authenticated positive/negative privacy tests across student, parent, teacher, branch-admin, finance and super-admin boundaries. SEC-05 requires an authorized recovery drill, agreed RPO/RTO, key-custody recovery, runbooks and owner risk sign-off. Production remains **NO-GO**; no hosted security fix or release is claimed complete.

**Current owner-directed development priority — 20 November 2026:** Task 2 (Phases 5A–6B) is the exclusive active development scope. Phase 4B remains **PARTIAL**; defer its nonessential remainder. Defer Phase 4C until after core college launch. Stop Phase 7 preflight/audit work; perform the final integration and release checkpoint after Task 2. Preserve all completed functionality. Do not modify production, push, or deploy during Task 2.

| Module | Database implementation | React implementation | Flutter implementation | Authorization | Functional tests | Local commit | Remaining requirements |
|---|---|---|---|---|---|---|---|
| 5A HR | Branch-scoped migration registered as `NOT APPLIED`; isolated SQL behavior test passes | Shared staff module wired; focused tests pass | Shared staff module wired; 68 Flutter tests pass | Super Admin/Admin; branch RLS, cross-branch denial and no-delete checks pass | Root 31/31; web 115/115; native HR PostgreSQL test passes; Flutter analysis clean | `14bfc10` plus local integration | After this integration gate: managed departments/designations, contracts, documents, attendance, leave, payroll, salaries, payslips and reports |
| 5B Student services | Pending | Pending | Pending | Pending | Pending | Pending | Requests, certificates, ID cards, letters, transcripts, CV, documents, downloads, PDF and print |
| 5C Settings | Existing partial contract; requirements pending | Existing partial UI; pending | Existing partial UI; pending | Existing contract; verify behavior by setting | Pending | Pending | Implement and synchronize all 24 approved settings |
| 5D Communications | Existing partial contract; pending | Existing partial UI; pending | Existing partial UI; pending | Pending | Pending | Pending | Announcements, messaging, templates, recipients, read states and workflow integration |
| 5E Front CMS | Existing partial contract; pending | Existing partial UI; pending | Pending | Pending | Pending | Pending | Pages, programs, courses, news, events, galleries, admissions, menus, SEO and multilingual publishing |
| 6A Operations | Existing partial contracts; pending | Existing partial UI; pending | Existing partial UI; pending | Pending | Pending | Pending | Library, inventory, warehouses, assets, transport, dormitories and accommodation |
| 6B Advanced administration | Existing partial contracts; pending | Existing partial UI; pending | Existing partial UI; pending | Pending | Pending | Pending | Scholarships, aid, alumni, recruitment, applications, dashboards and printable reports |

Tracker statuses describe newly verified implementation in this task, not historic claims. Update it after each coherent module; do not mark a module complete from navigation, placeholder UI, or an unverified schema alone.

**SEC-02 + Phase 5A combined local verification — 20 November 2026:** Root tests passed 31/31; web tests 115/115; TypeScript, ESLint, Flutter strict analysis and Flutter tests 68/68 passed. Migration inventory/checksum/manifest validation passed against `origin/main`, with all eight migration tamper tests passing. The isolated native PostgreSQL profile/contact, examinations and HR suites passed; Phase 3B security reconciliation passed. The root production SPA built successfully with the synthetic CI configuration (existing large-chunk warning). The HR migration is recorded in the lock as `history=false`, `NOT APPLIED`; historical migration entries and the archived demo 017 checksum are preserved, and HR is not added to the production deployment manifest. Production remains **NO-GO**; no production migration/write, deployment, or push occurred.

**SEC-02 pre-merge verification record — 20 November 2026:** Before the HR integration, PR #8's local source checks reported root tests 31/31, web tests 112/112, Flutter strict analysis and 67 tests, migration validation and eight tamper tests, native PostgreSQL contracts and Phase 3B reconciliation, and a production-mode SPA build with a synthetic publishable-key-shaped value. These are historical SEC-02 results, not results for the combined tree. Actions were pinned to immutable commits. Read-only project metadata confirmed the configured Main project and organization; no key was retrieved. No production migration, database write, website deployment or Supabase project mutation occurred. `supabase/migrations/017_demo_attendance_week.sql` remains archived at `supabase/archive/demo/017_demo_attendance_week.sql`; its historical checksum is preserved. The PR's earlier base was `38b03e096c9d61a68cac8438a7100a2a473c18f`; the merged target is now `f094b52`.

**Final backend/synchronization follow-up — 19 November 2026:** The four ignored local configuration files now share the Main URL and supported publishable key; the web variables match `src/portal/lib/supabase.ts` and set `VITE_SAI_TARGET=production`. The root React app remains authoritative, builds to `out/`, and `web/` dev/build/preview commands delegate to it. Focused integration tests, the secondary build, and the migration/manifest validator pass. The live Main project is `ACTIVE_HEALTHY` on PostgreSQL 17.11; read-only inventory confirms 16 recorded migrations and seven active Edge Functions at the expected versions. Auth health returned HTTP 200 with the local publishable key; no user sign-in was attempted.

Production remains **NO-GO**. Live catalog checks still find the proposed examinations tables, mutation-hold state and atomic role-management RPC absent; the package-receipt table has no applied records. The manifest remains `release_ready=false`; no SQL, migration-history repair, maintenance hold or Edge deployment was performed. Existing local backup evidence is dated 17 November 2026 and the prior native PostgreSQL recovery was application-scope only; a current managed backup/PITR check, Supabase-compatible restore, external write-hold attestation and hash-bound owner approval are still missing. GitHub `origin/main` is `af0c23bd1820472d014f43c1fe3d778996944fb2`; local `main` was 12 commits ahead with no divergence before this work. Configuration/build corrections are committed locally as `9153079916433d32996857be951350d758c289b3`; nothing was pushed. No credential pattern was found in the unpublished diff. Its only migration-package delta is the explicitly partial Phase 4B development proposal, which is excluded from the production manifest. Root GitHub workflows build/check only; GitHub reports no deployment record or webhook. The public website loads but reports a CORS preflight failure to a non-Main Supabase function; the Hostinger panel could not be reached, so its external auto-deployment settings remain unverified and publication is held. No changes were made to the other backend.

**Phase 7-M local commit:** `7de6eeff03e2552be7bf7243e79da57c0abe7f6b` on `main`; push postponed because production auto-deployment could not be ruled out. No production changes were made.

**Latest local integration and release-preparation refresh — 18 November 2026:** Added true/false lesson practice through the existing question schema, server-side grading, React authoring, Flutter interaction and focused SQL/web/mobile tests; local commit `5c61b7b0d87df23a042d1b8fbf20915b741de31d`. Assessment and practice separation remains intact. Full local checks now pass: isolated assessment and native database suites, Phase 3B reconciliation, migration integrity and 6 tamper tests, TypeScript check, lint, 112 web tests, Flutter analysis and 64 Flutter tests. The production web build succeeds; its bundle scan found no secret API key or service-role JWT values. A non-mutating Auth health request using the configured mobile publishable key returned HTTP 200 for Main without revealing the key. Local `main` is clean and 11 commits ahead of the live `origin/main` ref, with no commits behind; nothing was pushed or deployed. Phase 4B remains **PARTIAL**, Phase 4C has not started, and production remains **NO-GO**: the deployment manifest is not release-ready, security and recovery gates remain open, hosting/backend binding and authenticated role acceptance are incomplete, and Android release signing is unavailable because `mobile/android/key.properties` is absent. This update supersedes earlier statements that the full local suites had not been rerun or that mobile key ownership was unverified. See the [Phase 4B completion report](reports/PHASE_4B_COMPLETION_REPORT.md), [feature completion matrix](reports/FEATURE_COMPLETION_MATRIX.md), and [production release readiness checklist](reports/RELEASE_READINESS_CHECKLIST.md). All 16 phases and 24 system-settings requirements remain.

**Phase 4B functional sprint checkpoint — 18 November 2026:** The earlier assessment integrity and practice-isolation protections remain. The local assessment proposal now adds scheduling/time limits, class and individual assignment, duplication, categorized question reuse, randomized question snapshots, multiple-select and ordering questions with server grading, teacher previews, debounced cross-client autosave, and closed-assessment history/result release. The isolated assessment suite passed, including concurrency, timed finalization, bank authorization/import, multi-answer/order grading, save/resume and closed-history access; focused web assessment tests passed 10/10, TypeScript check passed, Flutter focused analysis was clean and the Flutter settings tests passed 2/2. Full regression/build suites have not been rerun after these changes. Current progress is committed locally through `6d695b2` (`fix(learning): preserve closed assessment history`); no push. Phase 4B remains **PARTIAL**; the SQL proposal remains undeployed and the production manifest excludes it. The next unimplemented requirement is the full reusable Workstream B exercise catalog and interactions, including image/audio and specialized Chinese types. See the [Phase 4B completion report](reports/PHASE_4B_COMPLETION_REPORT.md). All 16 phases and 24 system-settings requirements remain.


<!-- PHASE7M-CURRENT -->
**Historical Phase 7-M checkpoint — 18 November 2026:** The refreshed Main inventory was **57 local files / 57 GitHub Main files / 16 production history records**. Migration files matched `origin/main` at `d9e15f3b5680b32323bde29d3f41bd3bf22b4716`. At that checkpoint Phase 4B was still paused. The later Phase 4B local-development refresh above superseded that status; no production write, history repair or deployment occurred.

**Historical Phase 7-M evidence and restrictions:** Local reconciliation preparation and native SQL/security testing passed at that checkpoint; the production baseline was unchanged and remained NO-GO. Retain all **16 development phases** and **24 system-settings requirements** below. Phase 7-M is a checkpoint, not an additional development phase or a waiver of provider/release requirements.

- Use the [complete matrix](reports/PHASE_7M_MIGRATION_MATRIX.md), [current reconciliation report](reports/PHASE_7M_RECONCILIATION.md) and [updated Phase 7-R manifest](../supabase/deployment/phase7r/main-deployment-manifest.json).
- Never replay 007 or the historical backlog. Quarantine the fourteen overlapping production candidates, including six empty placeholders. Apply only reviewed Main-compatible package routes after approval.
- Native Main replay passed 3B roles/onboarding, 3C profiles, 4A examinations, finance/settings corrections, deferred admissions regressions, all-nine-role tests, last-admin concurrency and maintenance containment. Actual executor receipt/rollback/tamper tests passed. Drift negative tests passed 6/6; CI is prepared without production deployment. Hosted acceptance remains unverified.
- Only grant-only 030 and 20261116013951 have individually verified repair proposals; no repair is authorized. Packages outside migrations receive atomic hash-bound receipts, never synthetic historical completion records.
- Next: review exact hashes and recovery/containment evidence, obtain explicit deployment approval, perform the coordinated cutover and live acceptance, then update production status. Resume Phase 4B only after the required production baseline is reconciled and verified. Existing Flutter/signing and full platform recovery blockers remain open.

<!-- END-PHASE7M-CURRENT -->

**Roadmap revision:** 18 November 2026 — Phase 7-R local recovery and deployment safeguards verified; production remains NO-GO

**Historical Phase 7-R preflight checkpoint:** Local Main `f2ca63f08ed59455cd8cebb64f99aa0272c93af2` matched live `origin/main` in a read-only check at that time; GitHub reported no hooks or deployments. No commit or push was made during that preflight because hosting deployment settings were unverified. The hash-verified backup was recovered into a disposable native PostgreSQL cluster for application-scope testing: 85 tables, 860 rows, 355 constraints, 105 functions, 44 triggers and 113 policies passed integrity checks. The original full `pg_restore` had 56 errors; Supabase-managed Auth, Storage, Realtime, Edge, Cron, Vault and hosted extensions were not recovered. Local maintenance authorization, concurrency and rollback tests passed, with 14 public wrappers still awaiting the Phase 3B grant restrictions. The guarded executor dry-run passed; wrong-project and missing-attestation gates failed safely. Web type-check, lint, build and 105 tests passed; the 3 integration tests and 7 Deno tests passed. Flutter dependency resolution passed, but analysis (30 issues), tests (5 test files failed to compile) and debug APK build failed at that preflight. Java 21.0.13 is available; release signing was not verified. No production write or deployment occurred during that checkpoint.

**Historical Phase 7-R disposition:** Production deployment was blocked by incomplete Supabase-compatible recovery, external hold and live acceptance; Phase 4B was paused at that checkpoint. Current Phase 4B status and local validation are above. Production remains NO-GO; keep all 16 phases and 24 system-settings requirements intact.

**Identity:** Yemen SAI Educational College — كلية ساي التعليمية اليمنية الصينية — 也门赛艾教育学院

## 1. Locked environment

- Development workspace: `D:\SAI-College-Production` only.
- GitHub: https://github.com/BARH000M/sai-college-production — `main` only.
- Supabase Main: `aeryusbrulqdxjdynwfh` — https://aeryusbrulqdxjdynwfh.supabase.co.
- Supabase dashboard: https://supabase.com/dashboard/project/aeryusbrulqdxjdynwfh.
- Website: https://www.sai-academic.com — React production portal.
- Mobile: Yemen SAI — existing Flutter Android and iOS application.
- Nine roles: `super_admin`, `admin`, `teacher`, `accountant`, `receptionist`, `librarian`, `student`, `parent`, `content_editor`. Preserve authorized multi-role accounts and branch/session scope.
- No new GitHub or Supabase branches, projects, development workspaces, Docker, force pushes, data resets or blind historical migration replay. Protected external backups and disposable native PostgreSQL test clusters are permitted solely for recovery/security testing.

## 2. Historical Phase 7 preflight evidence and boundaries

The following table records the earlier preflight checkpoint; it is not current live status or a fresh database audit. Preserve newer verified repository evidence and do not infer current counts from these snapshots.

| Checkpoint | Latest reported evidence | Remaining gate |
|---|---|---|
| Backup and recovery | Archive `MAIN-20261117-164017` passes checksum/decompression; recovery record reports 94 restored tables, 93/96 data sections matched, and 113/115 policies restored. Workspace backup verified 40,336 enumerated files, with two directory links recorded as metadata. One inventoried Storage object and Edge sources/configuration were separately captured. A same-day Main reconciliation reported eight completed managed backups through 16 November 2026 and PITR disabled. | The local restore is partial: five required extensions unavailable, `pg_stat_statements` blocked, `ensure_rls` ownership failed, archive/restore row counts and policies differ, and complete role/platform recovery is unverified. The backup listing was not freshly available through the read-only tools in this pass. Verify the current managed recovery point and complete Supabase-compatible restore before production changes. |
| GitHub synchronization | Read-only check: branch `main`, local HEAD and `origin/main` all `0737f84b1e06be009cf6a5bc46c01ff2364fdac8`. Worktree remains dirty with Phase 4B and other local changes. Existing `web-ci.yml` and `mobile-ci.yml` run CI only; no automatic migration or production deploy action was found. | Preserve all changes; do not stage or push as part of this recovery preflight. |
| Phase 3B | `4610b20`; 88 web tests, seven Deno tests, isolated role/RLS/concurrency tests passed. | Preflight confirmed required role RPCs absent and legacy Edge handlers do not honor the proposed flag. SQL/Edge cutover and authenticated live acceptance blocked. |
| Phase 3C | `87bfc29`; Main-only configuration and own-contact editing; 91 web, three integration, 53 Flutter tests reported passing. | Preflight confirmed contact guard absent. SQL and live verification blocked pending recovery/approval. |
| Phase 4A | `0737f84`; exams/results implemented, 98 web and 58 Flutter tests reported passing. | Latest preflight reported targeted SQL, lint, Flutter analysis and focused Flutter tests passed. Examination tables absent on Main. Record exact test output where available; deployment and live acceptance blocked. |
| Android/iOS release | Java 21 / Gradle 8.4 incompatibility reported. | Confirm current mutually compatible stable tooling, store SDK requirements, actual APK/AAB and macOS iOS build/signing. |

**Phase 7-R local verification (18 November 2026):** Current Main project identity is `aeryusbrulqdxjdynwfh`; no production writes were attempted. The recovery runner reports application-scope `PASS`, with 85 tables, 860 data rows, 355 constraints, 105 functions, 44 triggers and 113 policies verified in an isolated native PostgreSQL cluster. It does not reproduce Supabase-managed services or prove a production restore. The separately tested maintenance hold passed authorization, concurrent-write-barrier and rollback checks locally; external ingress, managed jobs and privileged/platform writers still require an operator-enforced hold. Executor dry-run passed without writes; wrong-project and missing-attestation executions failed closed. Web and Edge checks passed, but Flutter analysis/tests/debug APK failed. Release signing and live nine-role acceptance remain unverified. Production disposition remains **NO-GO**; detailed evidence, hashes and limits are in `docs/reports/PRODUCTION_DEPLOYMENT_STATUS.md`.

Earlier Main reconciliation observed 40 local migrations, 16 recorded remotely, 13 matching versions and 27 local versions without matching history entries. Some effects already existed. Do not infer current counts or replay the backlog. System settings already existed and must be preserved. The independently provided YSMS V72–V77 settings audit is a **requirements reference**, not evidence that `school_*` objects or their reported functionality exist in Yemen SAI. Do not import its multi-tenant schema blindly.

## 3. The 16 phases

Status is source/deployment-specific. The scopes below are requirements, not claims of completion. Reuse existing features and validate gaps before writing new code.

| Phase | Scope | Starting disposition |
|---|---|---|
| 3B | Secure roles and account onboarding | Implemented/tested and pushed; production cutover blocked; required RPCs absent |
| 3C | Shared profiles and unified integration | Pushed; contact guard absent; production cutover blocked |
| 3D | Admissions, enrollment and academic administration | Existing functionality; remaining contracts and parity unverified |
| 3E | Attendance management | Existing functionality; live parity and gaps to verify |
| 3F | Finance, fees and accounting | Existing functionality; scoped contracts and remaining gaps to verify |
| 4A | Examinations and academic results | Pushed; targeted checks reported passing; exam tables absent; production cutover blocked |
| 4B | Learning exercises, assessments and homework | PARTIAL; local progress committed as `2a13081f771e01f5b73e5fa5aa0648ac938b2054`; local tests/build pass as recorded above; no production deployment |
| 4C | Chinese language learning engines | Further development required |
| 5A | HR, staff profiles and documents | Partial/unverified; complete missing workflows |
| 5B | Student services, certificates and printing | Partial/unverified; complete missing workflows |
| 5C | System settings and configuration | Expanded phase; preserve existing settings and wire behavior |
| 5D | Communications and notifications | Partial/unverified; provider integrations pending verification |
| 5E | Front CMS and public website | Partial/unverified; complete publishing and parity |
| 6A | Library, inventory, transport and dormitory | Mixed partial/unverified; complete real workflows |
| 6B | Scholarships, alumni, recruitment and reports | Remaining implementation and acceptance to verify |
| 7 | Production deployment and acceptance testing | Active; recovery, write-hold and manifest approval gates blocked; continuous thereafter |

### 3B — Secure roles and account onboarding

Nine roles, multi-role identity, staff/teacher/student/parent onboarding, verified invitations and links, atomic role assignment, last-usable-Super-Admin protection, membership lockdown, all alternate role writers, granular action permissions (view/create/edit/delete/approve/export/print/manage settings), protected transactional audits and server-side enforcement. Coordinate `manage-roles`, `school-admin`, `provision-learning-account` and `link-student-account` with SQL contracts. Preserve existing accounts, memberships and access. Confirm management authorization/atomicity/mutation tests and authenticated Super Admin flow. Prevent forged client audit entries.

### 3C — Shared profiles and unified integration

One Main backend across React/Flutter, Main-only MCP and runtime configuration, own-row contact name/phone/locale, Auth-managed email and identity, role and timestamp protection, session persistence, student/parent links, privacy and cross-client synchronization. Preserve the three-column own-contact contract and validate server-side timestamps.

### 3D — Admissions, enrollment and academic administration

Enquiries and public applications, status/history/tracking, duplicate detection, scoped assignment and approval, enrollment into existing student records, private document uploads, eligibility and configurable fields, admission fees, terms and guardian acknowledgement, reference numbers and printable applications. Branches, sessions, classes, sections, subjects/courses, teacher assignments, timetables, transfers, promotions and graduation. Preserve history and establish retention rules.

### 3E — Attendance management

Assigned teachers and administrative review; student/staff attendance; present, absent, late, excused; uniqueness and concurrent submissions, timezone/date semantics, correction and approval, historical class/session ownership, student/verified-parent views, absence notification, reports and printing.

### 3F — Finance, fees and accounting

Fee schedules/groups, balances/installments, payment and receipt numbering, adjustments, discounts, refunds, income/expenses, currency/rates/rounding, payment methods, scoped accounting roles, append-only or immutable transaction history, idempotency, concurrent payment handling, reconciliation, decimal arithmetic, retention, reports, A4 and thermal receipts. External payment providers require explicit configuration and supported availability; never claim an unconnected provider works.

### 4A — Examinations and academic results

Exam scheduling, session/class/course/subject, teacher assignment, marks grid and server validation, grade bands and passing marks, draft/marks-entry/review/published transition and controlled reopen, audit trail, student and verified-parent published-only access, reports, transcripts and print/PDF support. Latest targeted checks reported passing; preserve evidence, confirm full regression coverage and approved dependencies before deploying.

### 4B — Learning exercises, assessments and homework

Course and lesson assessments, question banks, MCQ, true/false, matching, fill-in-the-blank, written responses, attempt limits/deadlines, saved attempts, server-side objective grading, manual teacher grading, feedback/result release, secure answer keys, assignments, private text/file submissions, progress, parent monitoring and notifications. Reuse existing learning and homework tables/contracts; no duplicate schemas.

### 4C — Chinese language learning engines

Listening, speaking/pronunciation, reading, character writing/stroke practice, vocabulary/image flashcards, pinyin and tones, spaced repetition, HSK/YCT preparation, achievements, personalized progress, offline downloads and synchronization. Voice/child privacy, appropriate retention and consent. Keep independent ScriptSai application architecture separate unless explicitly authorized to integrate.

### 5A — HR, staff profiles and documents

Employee and department directory, teachers and staff, qualifications, experience, employment contracts, protected documents, leave, attendance and payroll integration, staff ID cards, performance and employment reports. Keep HR/financial details restricted to authorized roles.

### 5B — Student services, certificates and printing

Service requests and approval, enrollment letters, certificates/transcripts, student IDs, download center, QR/barcode verification, official numbering and history, letterheads, PDF/print/export, admission and examination sheets, A4/thermal layout and supported thermal/ESC-POS integration. Preserve branding and prevent unauthorized exports.

### 5C — System settings and configuration

General/academic settings, institutional identity and branding, languages/translations, custom fields and system field visibility/required/read-only controls, student profile settings, upload size/type policies, module activation and backend enforcement, dashboard widget controls, settings history and auditing. Accept a setting as complete only if a saved value demonstrably changes an intended authorized behavior. Keep provider credentials outside ordinary settings.

### 5D — Communications and notifications

Announcements, inbox, scoped audiences and recipient isolation, in-app/push notifications, email/SMTP, WhatsApp/SMS, fee/attendance/exam/homework reminders, consent, quiet hours, retention, delivery logs, deduplication and retry. Provider integration must use supported server-side delivery and protected credentials; report unavailable providers honestly.

### 5E — Front CMS and public website

Website activation, homepage/theme/layout, pages and menus, header/footer, news/events/gallery, programs and courses, draft/preview/publish/unpublish, SEO metadata/sitemap, multilingual Arabic/English/Chinese content and public admission integration. Preview here means a content preview UI, not a new environment or branch. Only published content is public.

### 6A — Library, inventory, transport and dormitory

- Library: catalog, physical copies, availability/search, issue/return/renewal, limits/due dates, branch scope, duplicate issue prevention and history.
- Inventory: assets, items, stores, suppliers, stock movements/adjustments, assignments and reports.
- Transport: vehicles, routes, drivers, student assignments, fees, parent information.
- Dormitory: buildings/rooms/beds, occupancy, availability, assignments, fees and reports.

### 6B — Scholarships, alumni, recruitment and reports

Scholarship requests, eligibility, approval and awards; alumni records/communications; student CVs/achievements; vacancies, applications, review and interviews; academic/administrative/finance reports with branch/course/session filters, historical semantics, reconciled totals, pagination, loading/empty/error, PDF/CSV/Excel, explicit export/print rights. Do not treat missing data as zero.

### 7 — Continuous production deployment and acceptance

Verified recovery options, versioned reviewed SQL, dependency order and rollback, Edge Function deployments, Main-only CI/CD with manual approval, database and RLS checks, hosted React deployment, Flutter APK/AAB and signed iOS build on macOS, current stable store-compatible toolchain, actual device and live role testing, web/mobile consistency, performance/security, backup administration, deployment evidence and final store submission readiness. Backup/restore operations remain operator-controlled, not exposed to ordinary school users.

## 4. All 24 system-settings requirements

The reference report's row-level classifications total 4 complete, 7 partial, 4 placeholder and 9 missing (one by design), but these are not Yemen SAI status measurements.

| # | Requirement | Owner phase |
|---|---|---|
| 1 | General: timezone, formats, language, week start, audit visibility | 5C |
| 2 | Academic: sessions, passing mark, late threshold, promotion policy, certificate prefix | 5C / 4A / 3D |
| 3 | College profile and branding | 5C |
| 4 | Notification preferences, reminders and quiet hours | 5D |
| 5 | WhatsApp provider, sender and templates | 5D |
| 6 | SMS provider and templates | 5D |
| 7 | SMTP/email sender, TLS and test-send | 5D |
| 8 | Payment methods | 3F |
| 9 | Print headers and templates | 5B |
| 10 | Thermal printing | 5B / 3F |
| 11 | Front CMS | 5E |
| 12 | Roles and granular action permissions | 3B / 5C |
| 13 | User administration | 3B |
| 14 | Language switching and translations | 5C |
| 15 | Currencies and exchange rates | 3F |
| 16 | Custom fields (text/number/date/select/checkbox/file) | 5C |
| 17 | System fields (visibility/required/read-only) | 5C |
| 18 | Student profile settings | 3C / 5C |
| 19 | Online admission window, fees, terms, eligibility and documents | 3D |
| 20 | File types, max size and private Storage policies | 5C |
| 21 | Modules and feature activation, enforced by backend | 5C |
| 22 | Operator-controlled backup administration | 7 |
| 23 | Protected audit history | All phases |
| 24 | Student/parent portal widgets with actual behavior | 5C |

## 5. Immediate execution sequence — Task 2

1. Complete the local SEC-02 + Phase 5A synchronization checkpoint before continuing HR development. The employee-directory first slice is implemented in the shared React and Flutter module flows; register its local migration through the reviewed migration lock/integrity process and verify isolated RLS behavior. Then continue with managed departments/designations, contracts, documents, attendance, leave and payroll, keeping financial and contract data separately permissioned.
2. Continue automatically through 5B, 5C, 5D, 5E, 6A and 6B. Integrate financial transactions with the existing accounting contract. Keep settings synchronized across clients and retain the nine-role model, Arabic RTL, Cairo font and institutional branding.
3. Keep all schema changes in reviewed local migration files and tests. Do not apply database changes to production, push, deploy, run readiness audits, or resume 4B/4C work during Task 2.
4. Commit each verified coherent module locally, updating the single tracker above. If work pauses before Task 2 is complete, report the exact next unfinished administrative feature.
5. After 5A–6B are implemented, run one consolidated integration/regression checkpoint. Phase 7 release work starts only after that checkpoint.

## 6. Permanent completion criteria and status tracking

For every feature record: database contract and migration/package path; web status; mobile status; automated tests and exit codes; GitHub commit; hosted deployment status and actual object/function versions; authenticated live acceptance result; unresolved dependency/blocker. Use separate statuses for missing, placeholder, partial, implemented locally, tested locally, pushed, deployed and live-verified. A navigation item, table, static screen, saved setting or compiled APK alone does not establish readiness. Never fabricate evidence.

Cross-cutting standards: Arabic-first RTL with English/Chinese support; responsive accessible interfaces; loading/empty/error/retry states; branch/session/account scoping and all nine roles; RLS and restricted RPCs; trusted audit events; transactional data integrity, concurrency and negative permission tests; private Storage and protected providers; no secrets in Git or synthetic production data. Keep previous working functionality.

## 7. Synchronization and release governance (after Task 2)

- Merge this revision into `docs/MASTER_EXECUTION_PLAN.md` (authoritative). Preserve existing history, recovery evidence, operational restrictions and newer verified results.
- Update `docs/reports/FEATURE_COMPLETION_MATRIX.md` with each phase and module as separate database/web/mobile/test/Git/deploy/live columns.
- Maintain `docs/reports/PRODUCTION_DEPLOYMENT_STATUS.md` with verified live contract inventory, deployment package paths, dependencies, exact SQL/source hashes and hosted Edge versions/configuration, commit, approval state, timestamps and test outcomes. Avoid duplicate tracking documents if an equivalent exists.
- Link the canonical roadmap from README/current documentation index and applicable agent instructions; mark older conflicting roadmaps superseded without deleting history.
- Use GitHub `main` as the sole version-controlled source. During Task 2, commit locally only: do not push or deploy. After Task 2, keep Supabase MCP read-only for normal work; approved changes use controlled, project-verified deployment tooling. GitHub integration must not trigger unreviewed migrations. Do not create a roadmap table in the application database solely to mirror Markdown. Track actual database changes in the existing reviewed migration/deployment mechanism; do not repair migration history without proven equivalence.
- Check that old `.env`, dumps, browser files and test metadata remain excluded. Historical committed copies remain a separate security risk: assess credential exposure and rotate exposed credentials securely; no unapproved history rewrite.

**Task 2 development cycle:** Implement → Focused test → Local commit → Update tracker → Continue. Push, production approval/deployment and release verification are outside Task 2.

**Immediate action:** Finish this local integration and validation, then resume the remaining Phase 5A HR requirements and continue through Phase 6B. The production NO-GO evidence is retained for the later Phase 7 checkpoint; it is not an instruction to perform audits or preflight work during Task 2.

**Roadmap provenance:** This canonical roadmap consolidates the 17 November deployment preflight evidence, the SEC-01/SEC-02 reports and the 20 November owner-directed Phase 5A–6B execution scope. Older checkpoint-specific evidence remains historical and is superseded wherever the current status above differs.
