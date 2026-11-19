# Feature completion matrix

**Owner-authorized execution policy — 18 November 2026:** Phase 7-M local reconciliation is **COMPLETE**. Phase 4B is **ACTIVE FOR LOCAL DEVELOPMENT**. Production migration reconciliation and deployment remain pending explicit approval, with `release_ready=false`; unfinished Phase 4B contracts remain excluded from the production manifest. Production NO-GO does not block local development. All 16 phases and 24 settings requirements remain required. Earlier paused-status statements below describe the prior checkpoint.

## Latest local feature and release-preparation update — 18 November 2026

Commit `5c61b7b0d87df23a042d1b8fbf20915b741de31d` adds true/false lesson
practice to the existing learning question contract, React authoring, Flutter
student interaction and isolated server-grading tests. The web and Flutter
full suites pass at 112/112 and 64/64, respectively; assessment, native
database, Phase 3B reconciliation and migration integrity suites pass. The
React production artifact builds and its credential-value scan passes. The
configured mobile publishable key returned HTTP 200 from Main's non-mutating
Auth health endpoint. Local `main` is clean, 11 commits ahead and 0 behind the
live remote ref; no push or deployment occurred.

Interactive exercises remain **PARTIAL**; image/audio and specialized Chinese
practice types remain incomplete. Phase 4B is **PARTIAL**, Phase 4C is not
started, and production remains **NO-GO**. Android release signing is blocked
by absent `mobile/android/key.properties`; hosting/backend binding, fresh
recovery verification, production security findings, hosted Storage and
authenticated role acceptance remain unresolved. The earlier dated rows
below preserve their checkpoint-specific evidence and are superseded where
test counts or key-binding status differ.

## Phase 4B local refresh — 18 November 2026

Phase 4B remains **PARTIAL**. The previously uncommitted assessment integrity
and practice-isolation changes were preserved and tested; the migration
regression was strengthened for the full lock inventory, checksums and
deployment dependencies. The web suite passed 105/105, the isolated assessment,
native contracts and Phase 3B reconciliation suites passed, web type-check/lint
passed, Flutter analysis reported no issues and Flutter tests passed 61/61.
The configured web build and Android debug APK also built successfully. These
results are local only and do not imply hosted deployment or live acceptance.

The November 18 functional sprint subsequently added assessment scheduling,
assignments, duplication, lifecycle/history handling, categorized question
reuse, multiple-select and ordering questions, teacher preview and cross-client
autosave. The focused assessment database, web, TypeScript and Flutter checks
passed. The SQL remains a proposal and the broader Phase 4B workstreams and
full regression/build rerun remain incomplete; see the refreshed
[completion report](PHASE_4B_COMPLETION_REPORT.md).

| Area | Current disposition | Remaining gap |
|---|---|---|
| Assessment management and integrity | PARTIAL; schedule/time limits, assignment variants, duplication, categorized question reuse, random-order snapshots, autosave, lifecycle/history, answer-key separation and grading are implemented in the local proposal and targeted-tested | SQL deployment, full regression/build rerun and live/device authorization acceptance |
| Interactive exercises | PARTIAL; vocabulary/listening practice remains isolated; assessment supports multiple-select and ordering on both clients with server validation/grading | Image/audio and specialized Chinese types, translation/sentence-arrangement practice, feedback/review and complete reusable engine |
| Homework | PARTIAL; existing submissions, private attachments and grading contracts are reused | Full lifecycle, multiple attachments, resubmission/notifications and hosted Storage acceptance |
| Grading and analytics | PARTIAL; objective/manual assessment grading and existing progress contracts are reused | Partial weighting, audit/correction history and requested student/teacher/parent analytics |
| Teacher, student and parent portals | PARTIAL; current role-aware web/mobile learning flows are reused | Full role/branch isolation, reporting, responsive/accessibility and parity acceptance |
| Administration and content management | PARTIAL; existing role navigation and question authoring are reused | Complete admin oversight and content-editor permission contract |

<!-- PHASE7M-CURRENT -->
**Current Phase 7-M refresh — 18 November 2026:** This checkpoint supplements every existing phase row below; no prior implementation or live-acceptance blocker is waived.

| Checkpoint | Database / security | Web / mobile | Actual local checks | Git / deploy / live |
|---|---|---|---|---|
| 7-M within Phase 7 | 57 local / 57 GitHub files / 16 production history; 007 superseded; finance/settings forward corrections and deferred admissions packages prepared; atomic package receipts integrated | At that Phase 7-M checkpoint, Phase 4B was still paused; later local work is recorded below | Main replay, nine-role/onboarding, finance, settings preservation, admissions, parent/student, attendance, maintenance, concurrency and actual executor atomicity PASS; profiles/exams PASS; drift negative tests 6/6 PASS | At that checkpoint, no hosted SQL, repair or deployment occurred; Phase 4B local development resumed later. Production NO-GO; authenticated acceptance NOT VERIFIED |

Authoritative [report](PHASE_7M_RECONCILIATION.md), [57-version matrix](PHASE_7M_MIGRATION_MATRIX.md), and [test evidence](../../supabase/deployment/phase7m/test-results.json). All 16 development phases and 24 settings requirements remain preserved. Earlier Git hashes/results below are historical snapshots.

<!-- END-PHASE7M-CURRENT -->

Status is separated by layer; local implementation or a passing isolated test
does not imply production deployment or live acceptance. Main was inspected
read-only; no production writes were performed. The deployment/recovery
decision and pinned candidate manifest are in
[`PRODUCTION_DEPLOYMENT_STATUS.md`](./PRODUCTION_DEPLOYMENT_STATUS.md).

| Phase / feature | Database contract | React web | Flutter mobile | Automated tests / validation | GitHub | Production deploy | Authenticated live acceptance / exit |
|---|---|---|---|---|---|---|---|
| 1 Audit and baseline | PARTIAL; catalog and migration history inspected, not fully reconciled | PARTIAL | PARTIAL | No complete nine-role end-to-end baseline | `main` at `f2ca63f`; live `origin/main` matched in read-only check | Not applicable | NOT COMPLETE; full baseline evidence required |
| 2 Design and accessibility | N/A | PARTIAL | PARTIAL | Responsive/accessibility review incomplete | Existing source on `main`; no release commit for current dirty work | Not deployed as a new release | NOT COMPLETE; approved visual/accessibility evidence required |
| 3 Core database foundation | PARTIAL; Main has deployed legacy contracts and documented migration drift | Existing features | Existing features | Read-only catalog checks; isolated recovery is application-scope only | Local `main` and live `origin/main` matched at `f2ca63f` before documentation edits | Existing contracts only; no new deployment | NOT CERTIFIED; complete RLS and nine-role scenarios remain |
| 3B Role management, teacher assignment, verified onboarding | Reviewed additive package exists; required atomic RPCs and write lockdown absent on Main | Locally implemented against proposed RPC contracts | Existing onboarding/account flows; live contract not verified | Local package report: web/type/lint, 88 web tests, 7 Deno tests and isolated PostgreSQL behavior passed; current recovery security check still flags 14 wrapper grants pending Phase 3B restrictions | Existing source is on `main`; current documentation changes are local only | NOT DEPLOYED; hosted legacy Edge versions remain active | BLOCKED by Supabase-compatible recovery, external write hold and approved coordinated cutover |
| 3C Shared profile and contact editing | Additive own-contact validation proposal absent on Main | Implemented locally | Implemented locally | Previously reported 91 web, 3 integration and 53 Flutter tests passed; not rerun in this preflight | `87bfc29` reported as implementation commit; current `main` head is `0737f84` | NOT DEPLOYED | NOT LIVE-VERIFIED; requires approved SQL and cross-client acceptance |
| 4A Examinations and results | Additive `exams`/`exam_results` proposal absent on Main; public catalog has no exam tables | Implemented locally, including print view | Implemented locally | Previously reported isolated SQL, 98 web and 58 Flutter tests, lint, type-check and analysis passed; not rerun in this preflight | `0737f84` implementation commit | NOT DEPLOYED | NOT LIVE-VERIFIED; requires approved SQL and role/family acceptance |
| 4B Assessments and homework | Existing homework contracts reused; enhanced assessment SQL remains a local un-deployed proposal | Added schedule/assignment/duplicate/category-bank, preview, multiple-select/order and autosave workflows; homework and broader role workflows remain incomplete | Matching assessment management, question reuse, preview, multiple-select/order and autosave added; broader parity remains incomplete | Focused assessment SQL PASS; assessment web tests 10/10; TypeScript check PASS; Flutter focused analysis clean and settings tests 2/2. Earlier full suites/builds passed before these changes and have not yet been rerun. See the Phase 4B report. | Latest assessment progress `6d695b2`; local main eight commits ahead at this checkpoint; no push | NOT DEPLOYED | PARTIAL / INCOMPLETE; Workstreams B–E, full regression/build, hosted Storage and authenticated acceptance remain |
| 4 Lesson 101 and 5 Learning engines | PARTIAL; existing learning tables, full lesson/media completion contract not certified | PARTIAL | PARTIAL | Provider, authentic-media, checkpoint/resume and sync tests absent | Existing code; no completion commit claimed | Existing partial contracts only | NOT COMPLETE |
| 6 Nine-role authorization and security | PARTIAL; Main public tables inspected with RLS enabled; required new contracts absent | Role/navigation support exists; full permission parity unverified | Role/navigation support exists; full permission parity unverified | Some local isolated tests; no current all-nine-role live matrix | Existing `main`; no new release commit | NOT DEPLOYED for proposed contracts | NOT CERTIFIED; require positive/negative role, branch and account isolation tests |
| 7 Production deployment and acceptance | Main unchanged; no production SQL or Edge changes | Local type-check/lint/build and 105 tests pass; live identity/auth unverified | Flutter analysis/tests and configured debug APK pass; signing/device acceptance unverified | Required local DB suites and migration validation pass. No authenticated live role tests. | Local `main` is ahead of `origin/main`; no push and no current remote sync claim | NO-GO; no SQL, Edge, website or mobile deployment | BLOCKED by full recovery, external hold, signing, owner approval and live acceptance |

No phase is marked live-complete from a schema listing, navigation item or local
test alone. All deployment proposals remain unapproved and unexecuted.
