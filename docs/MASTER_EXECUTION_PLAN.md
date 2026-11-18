# Yemen SAI V2 — Building and production roadmap

**Owner-authorized execution policy — 18 November 2026:** Phase 7-M local reconciliation is **COMPLETE**. Phase 4B is **ACTIVE FOR LOCAL DEVELOPMENT**. Production migration reconciliation and deployment remain pending explicit approval, with `release_ready=false`; unfinished Phase 4B contracts remain excluded from the production manifest. Production NO-GO does not block local development. All 16 phases and 24 settings requirements remain required. Earlier paused-status statements below describe the prior checkpoint.


<!-- PHASE7M-CURRENT -->
**18 November 2026 update — Phase 7-M:** The refreshed Main inventory is **57 local files / 57 GitHub Main files / 16 production history records**. All migration files match origin/main bytes at `d9e15f3b5680b32323bde29d3f41bd3bf22b4716`. The earlier evidence below is historical wherever it differs. No production write, history repair or deployment occurred; Phase 4B remains paused.

**Current checkpoint within Phase 7: Phase 7-M.** Local reconciliation preparation and native SQL/security testing passed; the production baseline is unchanged and remains NO-GO. Retain all **16 development phases** and **24 system-settings requirements** below. Phase 7-M is a checkpoint, not an additional development phase or a waiver of provider/release requirements.

- Use the [complete matrix](reports/PHASE_7M_MIGRATION_MATRIX.md), [current reconciliation report](reports/PHASE_7M_RECONCILIATION.md) and [updated Phase 7-R manifest](../supabase/deployment/phase7r/main-deployment-manifest.json).
- Never replay 007 or the historical backlog. Quarantine the fourteen overlapping production candidates, including six empty placeholders. Apply only reviewed Main-compatible package routes after approval.
- Native Main replay passed 3B roles/onboarding, 3C profiles, 4A examinations, finance/settings corrections, deferred admissions regressions, all-nine-role tests, last-admin concurrency and maintenance containment. Actual executor receipt/rollback/tamper tests passed. Drift negative tests passed 6/6; CI is prepared without production deployment. Hosted acceptance remains unverified.
- Only grant-only 030 and 20261116013951 have individually verified repair proposals; no repair is authorized. Packages outside migrations receive atomic hash-bound receipts, never synthetic historical completion records.
- Next: review exact hashes and recovery/containment evidence, obtain explicit deployment approval, perform the coordinated cutover and live acceptance, then update production status. Resume Phase 4B only after the required production baseline is reconciled and verified. Existing Flutter/signing and full platform recovery blockers remain open.

<!-- END-PHASE7M-CURRENT -->

**Roadmap revision:** 18 November 2026 — Phase 7-R local recovery and deployment safeguards verified; production remains NO-GO

**Current execution checkpoint:** Local Main `f2ca63f08ed59455cd8cebb64f99aa0272c93af2` matched live `origin/main` in a read-only check; GitHub reported no hooks or deployments. No commit or push was made in this task because Hostinger control-panel deployment settings remain unverified. The hash-verified backup was recovered into a disposable native PostgreSQL cluster for application-scope testing: 85 tables, 860 rows, 355 constraints, 105 functions, 44 triggers and 113 policies passed integrity checks. The original full `pg_restore` had 56 errors; Supabase-managed Auth, Storage, Realtime, Edge, Cron, Vault and hosted extensions were not recovered. Local maintenance authorization, concurrency and rollback tests passed, with 14 public wrappers still awaiting the Phase 3B grant restrictions. The guarded executor dry-run passed; wrong-project and missing-attestation gates failed safely. Web type-check, lint, build and 105 tests passed; the 3 integration tests and 7 Deno tests passed. Flutter dependency resolution passed, but analysis (30 issues), tests (5 test files failed to compile) and debug APK build failed due Dart/file-picker/homework API errors. Java 21.0.13 is available; release signing is not verified. No production write or deployment occurred. Preserve Phase 4B work and do not replay the historical migration backlog.

**Disposition:** Production deployment blocked by incomplete Supabase-compatible recovery, externally enforced maintenance hold, mobile build failures, unverified Hostinger configuration and live acceptance. Phase 4B remains paused. This is the active roadmap record; keep all 16 phases and 24 system-settings requirements intact.

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

## 2. Latest reported evidence and boundaries

This is a roadmap, not a fresh live database audit. Preserve newer verified repository evidence if it exists.

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
| 4B | Learning exercises, assessments and homework | Partial implementation, uncommitted; paused until live baseline |
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

## 5. Immediate execution sequence — recovery-first

### 7-R — Recovery and cutover readiness (active; operational gate, not a new feature phase)

1. Preserve uncommitted Phase 4B and documentation changes. Verify `main`, HEAD, origin, project identity, backup inventory and current diff. Do not clean, reset, merge, or discard work. Check automated deployment hooks before any push.
2. Obtain authorized read-only evidence of latest completed Main managed backup, PITR status and recovery window. If inaccessible, provide exact dashboard evidence required of the operator. Do not invent timestamps or request secrets in chat.
3. Keep the successful application-scope native recovery rehearsal disposable and separate from any production restore. The original full restore had 56 errors; native roles were placeholders without original attributes, memberships or passwords. Auth, Storage object bytes, Edge runtimes/secrets, Cron, Vault and hosted extensions remain outside this recovery. Require operator-supported Supabase-compatible recovery and verified Storage/Edge restoration before any production change.
4. Preserve the locally tested, disabled-by-default database hold and fail-closed Edge gates. Before any cutover, independently enforce and verify containment of legacy Edge ingress, direct API/RPC mutations, scheduled jobs and privileged/platform writers. Keep emergency Super Admin access and rehearse denial and release; do not activate the local hold on Main.
5. Use the dry-run-first executor and pinned manifest in `supabase/deployment/phase7r/`; verify current backup/PITR, Supabase-compatible recovery, external hold, SQL/function hashes and owner approval bound to the exact manifest/executor/commit. Resolve Flutter failures, release signing and authenticated acceptance first. Do not replay migration history. Until every gate passes, report NO-GO and leave production unchanged.

### Approved cutover sequence (future, after all gates pass)

6. Activate and verify the approved write hold **before** SQL; deploy reviewed Phase 3B package `supabase/deployment/phase3b-main/01_role_contract.sql` → `02_teacher_assignment.sql` → `03_verified_onboarding.sql`, coordinated with `manage-roles`, `school-admin`, `provision-learning-account`, `link-student-account`. Exact Edge/SQL interleaving and dependencies must be proven before execution. Verify atomic roles, usable-super-admin protection, negative permission tests and authenticated cutover.
7. Deploy Phase 3C `supabase/deployment/phase3c-main/001_own_contact_validation.sql`; verify own name/phone/locale, server timestamps, protected role/email and cross-client persistence.
8. Deploy Phase 4A `supabase/deployment/phase4a-examinations/001_examinations.sql` after prerequisites and acceptance plan are verified. Verify exam workflow, published family visibility, grading and reports. On failure stop subsequent steps, retain hold and use approved recovery procedure. A later transaction failure does not undo earlier successful steps.
9. Verify existing admissions, attendance, finance and academic administration (3D/3E/3F); implement and deploy only missing reviewed contracts. Confirm migration effects and history separately.
10. Deploy the compatible React build to existing hosting; build Main-connected Flutter APK/AAB; verify Android toolchain/signing without revealing secrets, and iOS build/signing prerequisites. Run physical-device and authenticated nine-role web/mobile acceptance, authorized cross-client persistence, and negative authorization checks. Release holds only under the approved manifest and verified safe exit criteria.
11. Resume existing Phase 4B work, completing assessments and homework before Phase 4C and 5A–6B. Continue Phase 7 throughout. Never enable client features against absent backend contracts.

## 6. Permanent completion criteria and status tracking

For every feature record: database contract and migration/package path; web status; mobile status; automated tests and exit codes; GitHub commit; hosted deployment status and actual object/function versions; authenticated live acceptance result; unresolved dependency/blocker. Use separate statuses for missing, placeholder, partial, implemented locally, tested locally, pushed, deployed and live-verified. A navigation item, table, static screen, saved setting or compiled APK alone does not establish readiness. Never fabricate evidence.

Cross-cutting standards: Arabic-first RTL with English/Chinese support; responsive accessible interfaces; loading/empty/error/retry states; branch/session/account scoping and all nine roles; RLS and restricted RPCs; trusted audit events; transactional data integrity, concurrency and negative permission tests; private Storage and protected providers; no secrets in Git or synthetic production data. Keep previous working functionality.

## 7. Synchronization and release governance

- Merge this revision into `docs/MASTER_EXECUTION_PLAN.md` (authoritative). Preserve existing history, recovery evidence, operational restrictions and newer verified results.
- Update `docs/reports/FEATURE_COMPLETION_MATRIX.md` with each phase and module as separate database/web/mobile/test/Git/deploy/live columns.
- Maintain `docs/reports/PRODUCTION_DEPLOYMENT_STATUS.md` with verified live contract inventory, deployment package paths, dependencies, exact SQL/source hashes and hosted Edge versions/configuration, commit, approval state, timestamps and test outcomes. Avoid duplicate tracking documents if an equivalent exists.
- Link the canonical roadmap from README/current documentation index and applicable agent instructions; mark older conflicting roadmaps superseded without deleting history.
- Use GitHub `main` as the sole version-controlled source. Keep Supabase MCP read-only for normal work; approved changes use controlled, project-verified deployment tooling. GitHub integration must not trigger unreviewed migrations. Review CI and external hosting hooks before pushing. Do not create a roadmap table in the application database solely to mirror Markdown. Track actual database changes in the existing reviewed migration/deployment mechanism; do not repair migration history without proven equivalence.
- Check that old `.env`, dumps, browser files and test metadata remain excluded. Historical committed copies remain a separate security risk: assess credential exposure and rotate exposed credentials securely; no unapproved history rewrite.

**Required development cycle:** Build → Test → Commit → Push → Approve and deploy → Verify live → Update roadmap → Continue.

**Immediate action:** Preserve the tested local recovery and maintenance artifacts and paused Phase 4B work. The exact manifest and executor have passed dry-run and negative-gate checks, but no production execution is authorized by this record. Do not perform hosted writes, deploy, publish releases or resume Phase 4B until recovery, external hold, Flutter/signing, live acceptance and exact-manifest approval gates pass. Do not push while Hostinger auto-deployment settings remain unverified.

**Source of this revision:** 17 November 2026 deployment preflight report (`Pasted text(20261117-185858).txt`, final findings lines 345–410) and the previous `SAI_BUILDING_ROADMAP_2026-11-17.md`. This updated copy has not itself been written into the Windows workspace or GitHub.
