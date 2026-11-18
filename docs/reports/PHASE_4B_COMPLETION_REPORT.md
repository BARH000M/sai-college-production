# Phase 4B completion and acceptance report

**Disposition: PARTIAL.** Local development only; Phase 4B is not complete or
accepted. The production manifest remains `release_ready=false`; no SQL,
Edge Function, website or mobile deployment has been performed. Phase 7-M
commit `7de6eeff03e2552be7bf7243e79da57c0abe7f6b` remains local and unpushed.

The starting point was the existing uncommitted assessment and homework work,
including the assessment question-locking and practice-isolation changes.
The checklist below records implementation and evidence, not an assertion that
untested requirements are absent from every part of the application.

## Master checkpoint checklist

- [x] Checkpoint 01 — PASS: web migration regression corrected and validated.
- [ ] Checkpoint 02 — PARTIAL: assessment integrity improved; required lifecycle
  and assignment workflows remain.
- [ ] Checkpoint 03 — PARTIAL: practice and formal assessment separation tested;
  required exercise catalog is incomplete.
- [ ] Checkpoint 04 — PARTIAL: existing homework reused; full lifecycle and
  hosted attachment acceptance remain.
- [ ] Checkpoint 05 — PARTIAL: existing grading reused; analytics and reporting
  requirements remain.
- [ ] Checkpoint 06 — PARTIAL: current role-aware screens reused; full parity
  and role acceptance remain.
- [ ] Checkpoint 07 — PARTIAL: all invoked local suites pass; requested
  comprehensive requirement coverage is not yet complete.
- [ ] Checkpoint 08 — PARTIAL: web build and configured debug APK pass; key
  ownership, signing and device acceptance remain unverified.
- [x] Checkpoint 09 — PASS for the checkpoint-scoped local progress commit only;
  this does not signify Phase 4B completion.
- [ ] Checkpoint 10 — BLOCKED: Phase 4B acceptance gates are not all met and
  Phase 4C readiness is not established.

| Checkpoint | Starting status and reused functionality | Implementation and files changed in this work | Tests and actual results | Missing work / final status |
|---|---|---|---|---|
| 01 Web regression | One of 105 web tests failed because it assumed historical migrations were the latest. Reused the migration lock, integrity validator and deployment manifest. | Updated `web/tests/phase2c-migration-review.test.cjs` to check full migration/lock inventory and checksums, unique versions, pinned historical hashes and relative order, deployment dependency order, pinned SQL package paths, and Phase 4B exclusion/NO-GO without assuming no later migrations. Existing SQL security assertions remain. | Focused test: 3/3 passed. `npm --prefix web test`: 105/105 passed, none skipped. `python supabase/tools/validate_migrations.py --base-ref origin/main`: passed. `python supabase/tests/test_migration_validation.py`: 6/6 passed, including migration and manifest tamper cases. | **PASS.** Future additive migrations remain supported when included in the lock and integrity review. |
| 02 Assessments | Partial: existing SQL proposal and web/mobile assessment screens support draft/publish, several question kinds, attempts, objective and written grading. | Preserved question locking and practice separation; restricted direct question-bank reads; enforced real-time deadlines; added a deletion guard that prevents published assessments and their grading history from being cascaded away. Changed `supabase/deployment/phase4b-assessments/001_learning_assessments.sql` and `supabase/tests/learning_assessments_behavior.sql`. | Isolated assessment suite passed: student/parent question-bank denial, authorized attempt, deadline during long transactions, duplicate submission, max grade, attempt limit, question mutation, concurrent start/insert, direct delete denial and trigger-level history preservation. | **PARTIAL.** Scheduling windows, time limits, lifecycle states, duplication, assignments, snapshots/versioning where needed and complete authorization/concurrency acceptance remain. |
| 03 Interactive exercises | Partial: scored vocabulary/listening practice and five assessment kinds exist. | Reused the pending filters in `src/portal/lib/exercises.ts` and `mobile/lib/ui/live_courses.dart` and the practice RPC changes in the SQL proposal. | Isolated tests exercised the actual historical scored-practice migration and confirmed practice grading/admin reads exclude assessment questions; web practice tests passed. | **PARTIAL.** Multiple answers, ordering, media, specialized Chinese exercise types, feedback/review and reusable cross-client coverage are not complete. |
| 04 Homework | Partial: existing homework screens, private attachment proposal and text/file submissions. | Reused existing homework guard and storage policies; no new homework feature was claimed complete. | Isolated assessment suite exercised protected homework grading. Web homework file tests passed as part of 105/105. | **PARTIAL.** Full lifecycle, multiple attachments, resubmission, notifications and managed Storage acceptance remain unverified/incomplete. |
| 05 Grading and analytics | Partial: objective and written grading, homework grading, progress views and exports exist. | Reused existing grading and progress contracts; added an invalid written-score regression in `supabase/tests/learning_assessments_behavior.sql`. | Isolated assessment suite passed automatic grading, written grading and score-bound checks. | **PARTIAL.** Multiple-answer/partial scoring, grade corrections, audit/history, comprehensive analytics and reporting remain. |
| 06 Role-based web/mobile integration | Partial: existing React and Flutter learning, assessment and homework screens. | Reused current clients and practice filters; no claim of complete parity. Relevant files include `src/portal/pages/learning/AssessmentsPanel.tsx` and `mobile/lib/ui/live_assessments.dart`. | Web type-check and lint passed; Flutter analysis reported no issues and 61 tests passed in this run; all 105 web tests passed. | **PARTIAL.** Full role/branch isolation, content-editor contract, accessibility, responsive and cross-client acceptance remain. |
| 07 Database, web and mobile tests | Reused isolated native PostgreSQL infrastructure and existing web/mobile suites. | Added focused regression cases in `supabase/tests/learning_assessments_behavior.sql`, Flutter practice filtering, and stronger migration regression assertions. | `run_learning_assessments.py`: PASS including question locking/concurrency. `run_native_contracts.py`: PASS. `phase3b-main/run_local.py --reconciliation`: PASS. Migration validator and its 6 tamper tests: PASS. Root type-check/lint: PASS. Web: 105/105, no skips. Flutter analyze: no issues; Flutter tests: 61/61. | **PARTIAL.** Although the required local runners passed, coverage for the full requested homework, media, analytics, cross-branch, all-role and hosted Storage scenarios is not complete. No hosted database was tested or changed. |
| 08 Web and Android build | Existing root React/Vite application and `mobile/` Flutter project. | Built the root production portal and configured debug APK; no generated artifact was staged. | `npm run build`: PASS; output in `out/`. Configured `flutter build apk --debug --no-pub --dart-define-from-file=config/live.json`: PASS. APK is 194,102,078 bytes, SHA-256 `ce925355b2a9c9b347ec4b9e799eabc4d3d7b65b7d583b08b3618325bcbd5d46`, built 2026-11-18 19:13 +03:00, version 1.2.1, application ID `com.saicollege.mobile`, source commit `7de6eef`. | **PARTIAL.** Config URL and runtime variable match the target contract; key format is valid and preview mode is disabled, but key ownership cannot be proven from its format. No device/live acceptance or release signing was performed. Flutter emitted future toolchain-support warnings; Vite emitted a large-chunk warning. |
| 09 Local commit | Phase 7-M is committed; Phase 4B changes were initially uncommitted. | Committed the reviewed assessment-integrity, practice-isolation and regression work; separate documentation closeout is recorded in Git history. | Implementation commit `2a13081f771e01f5b73e5fa5aa0648ac938b2054`, message `fix(learning): preserve assessment and practice integrity`, seven implementation/test files. Local `main` is ahead of `origin/main`; no push. | **PASS** for this verified partial-progress commit only. Phase 4B is not represented as complete. |
| 10 Acceptance / Phase 4C | Phase 4B incomplete and production NO-GO. | This report and `docs/MASTER_EXECUTION_PLAN.md` record the current state. | The local checks above are not live role/device/Storage acceptance. | **BLOCKED.** Phase 4B is not accepted and readiness for Phase 4C has not been established. |

## Feature and acceptance classification

| Requirement area | Local classification | Production / live classification |
|---|---|---|
| Assessment management, integrity and grading history | PARTIAL | PRODUCTION DEPLOYMENT PENDING |
| Interactive exercise types and Phase 4C interfaces | PARTIAL | PRODUCTION DEPLOYMENT PENDING |
| Homework lifecycle and private attachment behavior | PARTIAL | PRODUCTION DEPLOYMENT PENDING |
| Scoring, learning analytics and reports | PARTIAL | PRODUCTION DEPLOYMENT PENDING |
| Teacher, student and parent portals | PARTIAL | PRODUCTION DEPLOYMENT PENDING |
| Admin oversight and content-editor permissions | PARTIAL | PRODUCTION DEPLOYMENT PENDING |
| Invoked local PostgreSQL, web and Flutter suites | COMPLETE AND LOCALLY TESTED | Not production evidence |
| Production web and configured Android debug builds | COMPLETE AND LOCALLY TESTED | Not deployed or device-accepted |
| Phase 4B SQL contract | Implemented as an un-deployed proposal | PRODUCTION DEPLOYMENT PENDING |
| Authenticated live acceptance and hosted Storage | BLOCKED / not run | BLOCKED |
| Final rerun failures in the commands recorded above | None | N/A |

## Build evidence

Builds are local, generated, ignored artifacts, not deployments. The mobile
configuration is ignored by Git; no key value is included here. The runtime
uses `SUPABASE_PUBLIC_KEY` and the approved hard-coded project URL. The
configuration has live preview disabled and an `sb_publishable_`-format key;
format alone does not establish that the current key belongs to the project.

Web build output SHA-256 (current local build; Vite reported a large-bundle warning):

```text
b2fe037498de4e3667efbdd046852936995ac2964d88b8f89fafb928142e0f8e  out/index.html
7ecb9b6a465072bce7b0e2a6d2d0355add8151fa9f8f342b516b57b26a2914c6  out/assets/Cairo-400-CGxveJD7.ttf
ed4acaa1f0bc99766193cb9536d166daa74aa09ea412e9ce7448ffdf75a997da  out/assets/Cairo-600-BmUJLdo4.ttf
cad8564334938a5867e2b8200e9b882067811bc09e26314f2d3aa95ccfe54015  out/assets/Cairo-700-Dy3AzUHx.ttf
29725d8334a823475701834a814033c8886a3a14b5e3613ee5af43a8a4795282  out/assets/index-BvcV7fMC.js
e6a9a50d11ec31361c181412d8ee920bfeb0574034626f750906be4001e0f1bf  out/assets/index-BvcV7fMC.js.map
59e18a80e9b78a7a9b2365d4a356c89ee0a9837619184dfc1079b0ab10fb48dd  out/assets/index-Ck1OPDtp.css
c4554f8dbb864352837a197b1fcf9361e36a22639b5df812577e7b0f8e865e70  out/assets/NotoSansSC-Cen0R61N.otf
0e0ea685d88257e940feed9ef908ba85ac21964303da516a94aa6a31bd3b4cfa  out/assets/sai-logo-BBZTfevt.png
```

Android debug APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`;
SHA-256 `ce925355b2a9c9b347ec4b9e799eabc4d3d7b65b7d583b08b3618325bcbd5d46`.

The APK is a debug artifact, not proof of signing, hosted integration or device
acceptance. `mobile/config/live.json` uses the approved project URL and the
`SUPABASE_PUBLIC_KEY` runtime variable, with preview disabled. Its public-key
format was checked without printing the value; project ownership was not
independently verified. The release keystore exists locally and is ignored by
Git, but `mobile/android/key.properties` is absent, so release signing remains
unconfigured. The database tests use disposable loopback clusters and
synthetic records; they do not prove managed Supabase Storage behavior.

## Database implementation

The existing Phase 4B SQL proposal reuses `learning_exercise_questions`,
`learning_homework`, `learning_homework_submissions`, the existing role/course
authorization helpers and private homework Storage bucket contracts. Its
additive assessment objects are `learning_assessments`,
`learning_assessment_attempts` and `learning_assessment_answers`, plus the
`assessment_id` association on exercise questions. The proposal defines
assessment lifecycle guards, question synchronization/locking, attempt and
answer RLS policies, answer-key-safe start/save/submit/grading/results RPCs,
and practice-only exercise authoring/scoring RPCs. The new deletion trigger
protects published assessments and attempt history.

The SQL is a local reviewed deployment proposal, not a file in
`supabase/migrations/`; it has not been applied to Main. RLS and Storage
contracts were exercised against a disposable native PostgreSQL fixture.
Managed Supabase Storage upload/signed-download behavior and production RLS
remain unverified. Required SQL runners did not write to the hosted project.

## Web and Flutter implementation

The existing React assessment, homework and portal screens were reused. The
web practice question client now filters to the practice kinds and its test
asserts this restriction; type-check, lint and all 105 web tests passed. The
existing Flutter lesson player/repository was reused and filters practice
questions to `vocabulary` and `listening`; Flutter analysis and 61 tests passed.
This is not complete React/Flutter parity for the full requested assessment,
homework, teacher analytics, parent reports or exercise catalog.

## Git, blockers and next-phase recommendation

- Previous verified commit: `7de6eeff03e2552be7bf7243e79da57c0abe7f6b`
  (`feat(database): complete Phase 7-M migration reconciliation and deployment safeguards`).
- Phase 4B implementation progress commit:
  `2a13081f771e01f5b73e5fa5aa0648ac938b2054`
  (`fix(learning): preserve assessment and practice integrity`). Files:
  `mobile/lib/ui/live_courses.dart`, `src/portal/lib/exercises.ts`,
  `supabase/deployment/phase4b-assessments/001_learning_assessments.sql`,
  `supabase/tests/learning_assessments_behavior.sql`,
  `supabase/tests/run_learning_assessments.py`,
  `web/tests/learning-assessment.test.cjs`, and
  `web/tests/phase2c-migration-review.test.cjs`.
- The report and roadmap closeout are committed separately; `main` remains
  local and ahead of the `origin/main` tracking ref. GitHub push was not
  performed. No generated APK, private key, `live.json`, build output,
  database dump, or temporary cluster was staged.
- Local implementation gaps: assessment scheduling/assignment/lifecycle
  breadth; remaining question types and media; complete homework lifecycle;
  analytics and report coverage; and full role/branch parity.
- Testing gaps: comprehensive all-role negative authorization, hosted Storage
  acceptance, cross-client persistence and device acceptance. All recorded
  local test commands passed.
- Release blockers: the current public key's project ownership, release
  signing and live authentication are unverified. Production remains NO-GO;
  no SQL or application deployment occurred. GitHub synchronization remains
  pending because push was postponed.

**Phase 4C recommendation: NOT READY.** No Phase 4C implementation was
started. When Phase 4B is accepted, candidate reusable pieces are the existing
lesson player, practice/assessment separation, safe question/result contracts
and server-side scoring. Future 4C planning may scope listening, speaking,
reading, Chinese character writing, vocabulary/images, pinyin/tones and
spaced repetition, with HSK/YCT, offline synchronization, achievements and
child/voice privacy. Owner approval is required before that work begins.
