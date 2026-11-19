# Phase 4B completion and acceptance report

**Disposition: PARTIAL.** Local development only; Phase 4B is not complete or
accepted. The production manifest remains `release_ready=false`; no SQL,
Edge Function, website or mobile deployment has been performed. Phase 7-M
commit `7de6eeff03e2552be7bf7243e79da57c0abe7f6b` remains local and unpushed.

## Latest local verification refresh — 18 November 2026

Added true/false lesson practice using the existing question and answer
contract, with fixed Arabic choices, server-side grading, React authoring,
Flutter student interaction and focused positive/negative tests. Formal
assessment answer keys remain protected. Implementation commit:
`5c61b7b0d87df23a042d1b8fbf20915b741de31d`.

| Verification | Actual result |
|---|---|
| Learning assessment SQL harness | PASS; concurrency, answer-key protection, practice grading and assessment integrity |
| Native contracts and Phase 3B reconciliation | PASS |
| Migration integrity validator and tamper tests | PASS; 6/6 tamper tests |
| TypeScript check and lint | PASS |
| Web compatibility suite | PASS; 112/112, no skipped tests |
| Flutter package resolution and analysis | PASS; no analyzer issues |
| Flutter tests | PASS; 64/64 |
| Production React build | PASS; `out/`, 19,295,908 bytes; Vite reported the existing large-chunk warning |
| Public web artifact credential scan | PASS; no secret API key value or service-role JWT found |
| Mobile configured publishable-key binding | PASS; non-mutating Auth health returned HTTP 200 for Main, with the key value suppressed |
| Android production signing | BLOCKED; `mobile/android/key.properties` is absent; no signed APK/AAB was built |
| Git synchronization | Clean `main`; 11 commits ahead and 0 behind the live `origin/main` ref; no push |

The web JavaScript bundle is
`out/assets/index-BAmm5zIQ.js` (1,446,340 bytes; SHA-256
`5938bc49c6b6638a89a615578f7f8b26d990c2e8c025dfacd0deb3668bbe8ec1`).
The index is `out/index.html` (1,599 bytes; SHA-256
`2c94df0d293b7e6c39c3fda66ca463ac343174b4bf025515b2c6e35b3940c2de`).
These are local artifacts, not deployed releases.

Phase 4B remains **PARTIAL** and Phase 4C has not started. Production remains
**NO-GO**: `release_ready=false`, leaked-password protection and other
production security findings remain unresolved, a fresh recovery point and
Supabase-compatible restore are not verified, hosting/backend binding and
security headers remain unverified, hosted Storage and authenticated role
acceptance are incomplete, and release signing is unavailable. No production
write, backup, push or deployment was performed. This section supersedes older
test-count and key-binding statements below; historical checkpoint rows retain
the evidence available when they were written.

## Functional completion sprint refresh — 18 November 2026

The latest local assessment work adds scheduling windows, timed attempts,
attempt and passing limits, stable randomized question order, individual
assignment, assessment duplication, lifecycle state guards, a categorized
reusable question bank, multiple-select and ordering questions, teacher
previews, and debounced answer autosave in React and Flutter. Closing an
assessment now preserves attempts and permits later result release; eligible
students and verified parents can view its closed history without restarting
it. These changes remain an additive SQL deployment proposal and are not
deployed to Supabase Main.

| Workstream | Starting status | Existing functionality reused | Sprint implementation and files | Verification performed | Remaining limitation / status |
|---|---|---|---|---|---|
| A — assessment management | PARTIAL; draft/publish, attempts, grading and integrity protections existed | Shared `learning_exercise_questions`, lesson/course authorization, isolated PostgreSQL harness and current React/Flutter assessment screens | Added assessment schedule/limits, targeted assignments, duplication, lifecycle handling, categorized bank/import RPCs, multiple-select and ordering data/answers, learner previews, autosave and closed-history access. Updated `supabase/deployment/phase4b-assessments/001_learning_assessments.sql`, `supabase/tests/learning_assessments_behavior.sql`, React assessment service/panel, Flutter `live_assessments.dart`, and focused web/mobile tests. | `python supabase/tests/run_learning_assessments.py`: PASS including concurrency, timed finalization, answer-key protection, bank access denial/import, multi-select/order grading, autosave resume, closure/history visibility and restart denial. `node --test web/tests/learning-assessment-workflow.test.cjs`: 10/10 PASS. `npm run type-check`: PASS. Flutter focused analysis: no issues; assessment settings tests: 2/2 PASS. | PARTIAL for Phase 4B acceptance: SQL remains proposal-only; full regression/build suites and live acceptance are pending. |

Current sprint commits on local `main` (not pushed): `54deda5`, `42c85a6`,
`b6cccbf`, `77088f7`, `bbf71e3`, `d759e3b`, `4dd16e2`, and `6d695b2`.
This status refresh is committed as `1443683`.
The next unimplemented mandatory requirement is Workstream B's full reusable
exercise engine across student-facing React and Flutter clients, including
image/audio questions and specialized Chinese character, pinyin, tone,
translation and sentence-arrangement interactions.

The starting point was the existing uncommitted assessment and homework work,
including the assessment question-locking and practice-isolation changes.
The checklist below records implementation and evidence, not an assertion that
untested requirements are absent from every part of the application.

## Master checkpoint checklist

- [x] Checkpoint 01 — PASS: web migration regression corrected and validated.
- [ ] Checkpoint 02 — PARTIAL: management, assignments, schedules, duplication,
  categorized question reuse, autosave and closed history implemented/tested;
  SQL remains undeployed and comprehensive acceptance remains.
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
| 02 Assessments | Partial: existing SQL proposal and React/Flutter screens support attempts and objective/written grading. | Preserved question locking, practice separation and answer-key protections; reused the common question table and native PostgreSQL harness. | Added scheduled/timed attempts, random-order snapshots, assignments, duplication, lifecycle guards, categorized reusable questions, multiple-select and ordering types, teacher previews, debounced autosave, closed history access. Updated the assessment SQL proposal, native behavior tests, React service/panel, Flutter assessment page and focused tests. | Isolated assessment suite PASS, including timeouts, concurrency, protected question-bank import/denial, multiple-answer and ordering grading, save/resume, closure/result release and history access. Focused web workflow tests 10/10; TypeScript check PASS; Flutter focused analysis clean and settings tests 2/2. | **PARTIAL.** SQL is not deployed; all-role/device acceptance and full regression/build suites remain. |
| 03 Interactive exercises | Partial: scored vocabulary/listening practice and five assessment kinds existed. | Reused the common question/answer table, server-side grading and existing practice separation. | Added validated multiple-select and ordering assessment questions, plus true/false lesson practice to the existing proposal, React authoring and Flutter student flow; server-side correctness checks and focused tests cover the supported paths. | Native PostgreSQL acceptance, web validation and Flutter interaction tests passed; the latest full suites pass 112 web and 64 Flutter tests. | **PARTIAL.** Image/audio authoring and rendering, Chinese character/pinyin/tone, translation, sentence-arrangement and full reusable practice-engine coverage remain. |
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
| Assessment management, integrity and grading history | PARTIAL; sprint features locally tested, SQL proposal only | PRODUCTION DEPLOYMENT PENDING |
| Interactive exercise types and Phase 4C interfaces | PARTIAL; multiple-select and ordering added; requested catalog incomplete | PRODUCTION DEPLOYMENT PENDING |
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
- Documentation closeout:
  `8758103b70a75922c0446041ae3f821c3afd0522`
  (`docs(learning): record Phase 4B partial acceptance and blockers`), with
  the roadmap and six report files. A final Git-evidence refresh follows this
  closeout.
- Evidence refresh:
  `b203b0ad2ad8507ba12ed90c495c0c0b86573fc5`
  (`docs(learning): finalize Phase 4B local acceptance evidence`), updating
  the build and Phase 4B reports. This final roadmap reconciliation is included
  in the current local report closeout.
- At final report closeout, local `main` is six commits ahead of the
  `origin/main` tracking ref (including the preserved Phase 7-M commit).
  The worktree has one unrelated tracked modification at
  `prototype/reference-source/previous-flutter-app/mobile/lib/main.dart`;
  it appeared after the initial status check and was not inspected, staged or
  changed. No GitHub push was performed or verified. No generated APK, private
  key, `live.json`, build output, database dump, or temporary cluster was
  staged.
- Local implementation gaps: remaining question types and media; complete homework lifecycle;
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
