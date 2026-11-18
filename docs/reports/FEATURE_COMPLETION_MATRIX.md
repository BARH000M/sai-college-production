# Feature completion matrix

**Owner-authorized execution policy — 18 November 2026:** Phase 7-M local reconciliation is **COMPLETE**. Phase 4B is **ACTIVE FOR LOCAL DEVELOPMENT**. Production migration reconciliation and deployment remain pending explicit approval, with `release_ready=false`; unfinished Phase 4B contracts remain excluded from the production manifest. Production NO-GO does not block local development. All 16 phases and 24 settings requirements remain required. Earlier paused-status statements below describe the prior checkpoint.

## Phase 4B local refresh — 18 November 2026

Phase 4B remains **PARTIAL**. The previously uncommitted assessment integrity
and practice-isolation changes were preserved and tested; the migration
regression was strengthened for the full lock inventory, checksums and
deployment dependencies. The web suite passed 105/105, the isolated assessment,
native contracts and Phase 3B reconciliation suites passed, web type-check/lint
passed, Flutter analysis reported no issues and Flutter tests passed 61/61.
The configured web build and Android debug APK also built successfully. These
results are local only and do not imply hosted deployment or live acceptance.

| Area | Current disposition | Remaining gap |
|---|---|---|
| Assessment management and integrity | PARTIAL; draft/publish, attempt/save/submit, answer-key separation, grading and question-locking contracts are present and isolated database-tested | Scheduling/time limits, assignment variants, duplication/versioning and full authorization lifecycle acceptance |
| Interactive exercises | PARTIAL; vocabulary/listening practice is isolated from assessment questions on web, mobile and server contracts | Remaining requested question kinds, media, review/feedback and complete reusable cross-client engine |
| Homework | PARTIAL; existing submissions, private attachments and grading contracts are reused | Full lifecycle, multiple attachments, resubmission/notifications and hosted Storage acceptance |
| Grading and analytics | PARTIAL; objective/manual assessment grading and existing progress contracts are reused | Partial weighting, audit/correction history and requested student/teacher/parent analytics |
| Teacher, student and parent portals | PARTIAL; current role-aware web/mobile learning flows are reused | Full role/branch isolation, reporting, responsive/accessibility and parity acceptance |
| Administration and content management | PARTIAL; existing role navigation and question authoring are reused | Complete admin oversight and content-editor permission contract |

<!-- PHASE7M-CURRENT -->
**Current Phase 7-M refresh — 18 November 2026:** This checkpoint supplements every existing phase row below; no prior implementation or live-acceptance blocker is waived.

| Checkpoint | Database / security | Web / mobile | Actual local checks | Git / deploy / live |
|---|---|---|---|---|
| 7-M within Phase 7 | 57 local / 57 GitHub files / 16 production history; 007 superseded; finance/settings forward corrections and deferred admissions packages prepared; atomic package receipts integrated | No feature-completion upgrade; Phase 4B remains paused; prior Flutter/signing blockers retained | Main replay, nine-role/onboarding, finance, settings preservation, admissions, parent/student, attendance, maintenance, concurrency and actual executor atomicity PASS; profiles/exams PASS; drift negative tests 6/6 PASS | Local changes only; no commit/push, SQL, repair or hosted deployment. CI prepared, not remotely run. Production NO-GO; authenticated acceptance NOT VERIFIED |

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
| 4B Assessments and homework | Existing legacy homework tables are present; assessment-specific proposal remains local | Assessment and homework changes in progress | Homework/file and assessment changes in progress | Isolated assessment behavior and 7 focused web tests passed earlier; latest web suite 105 tests passed. Flutter analysis failed with 30 issues; Flutter tests had 41 passes and 5 files failing compilation. Preserve unfinished work. | Source preserved on local `main`; no separate Phase 7-R commit or push | NOT DEPLOYED | PAUSED / INCOMPLETE; fix Flutter compilation and complete parity/security validation |
| 4 Lesson 101 and 5 Learning engines | PARTIAL; existing learning tables, full lesson/media completion contract not certified | PARTIAL | PARTIAL | Provider, authentic-media, checkpoint/resume and sync tests absent | Existing code; no completion commit claimed | Existing partial contracts only | NOT COMPLETE |
| 6 Nine-role authorization and security | PARTIAL; Main public tables inspected with RLS enabled; required new contracts absent | Role/navigation support exists; full permission parity unverified | Role/navigation support exists; full permission parity unverified | Some local isolated tests; no current all-nine-role live matrix | Existing `main`; no new release commit | NOT DEPLOYED for proposed contracts | NOT CERTIFIED; require positive/negative role, branch and account isolation tests |
| 7 Production deployment and acceptance | Main project is configured; no SQL changes executed. Disposable application recovery passed but is not Supabase-compatible; 14 wrapper grants remain pending | Type-check/lint/build and 105 tests passed; live build identity/auth unverified | Flutter deps passed; analysis/tests/debug APK failed; signing not verified | Deno 7 tests and 10 changed-file checks passed; recovery and maintenance local tests passed; executor dry-run passed and negative gates failed safely. No authenticated live role tests. | Live `main` matched local HEAD `f2ca63f`; docs updated locally. No push because Hostinger settings remain unverified. | NO-GO; no SQL, Edge, website or mobile deployment | BLOCKED by full recovery, operator-enforced hold, Flutter/signing, owner approval and live acceptance |

No phase is marked live-complete from a schema listing, navigation item or local
test alone. All deployment proposals remain unapproved and unexecuted.
