# Production deployment status and candidate manifest — Phase 7-R

**Owner-authorized execution policy — 18 November 2026:** Phase 7-M local reconciliation is **COMPLETE**. Phase 4B is **ACTIVE FOR LOCAL DEVELOPMENT**. Production migration reconciliation and deployment remain pending explicit approval, with `release_ready=false`; unfinished Phase 4B contracts remain excluded from the production manifest. Production NO-GO does not block local development. All 16 phases and 24 settings requirements remain required. Earlier paused-status statements below describe the prior checkpoint.

## SEC-02 integration readiness — 20 November 2026

- PR #8 is reconciled locally with `origin/main` at `38b03e096c9d61a68cac8438a7100a2a473c18f`; its pre-merge head is preserved on a local backup branch. The integrity conflict is resolved, the archived 017 migration remains out of `supabase/migrations/`, and the accidental empty file `0` is removed.
- Migration checksums and manifest integrity pass `python supabase\tools\validate_migrations.py --base-ref origin/main`; its tamper suite passes 8/8. Root 31/31, web 112/112, Flutter, native PostgreSQL and Phase 3B reconciliation checks pass. The production SPA build passes with non-secret CI fixture configuration.
- Read-only Supabase metadata confirms the authorized project ref/name and `BARH000M` organization. No key was retrieved. The validator enforces URL/project identity; opaque publishable-key ownership remains unprovable from the key prefix alone.
- GitHub Actions in the three root workflows are pinned to immutable commit hashes. The remote SPA check on the prior PR head failed due to missing CI configuration and is fixed locally. Supabase Preview still references a different project; no remote Supabase project was touched.

**Disposition: NO-GO.** Do not push until the owner confirms the Supabase Preview integration is rebound to the authoritative project or disabled. Recovery, external write-hold, hash-bound owner approval, hosted security fixes, authenticated acceptance, release signing and hosting approvals remain outstanding. No production SQL, migration, website deployment, or remote project mutation was performed.

## Final backend/synchronization follow-up — 19 November 2026

- **Local configuration:** `.env.local`, `web/.env.local`, `mobile/config/live.json` and `supabase/target.local.json` are synchronized to Main, ignored and untracked. The browser uses only `VITE_PUBLIC_SUPABASE_URL`, `VITE_PUBLIC_SUPABASE_ANON_KEY` and `VITE_SAI_TARGET=production`; the existing supported publishable key is reused and never printed. No privileged key was introduced.
- **Web architecture:** The root React app is authoritative and its Vite output is `out/`. Secondary `web/` dev/build/preview commands delegate to the root; the root GitHub workflow invokes the root build. The current GitHub workflows are checks-only, with no repository webhook, Actions deployment secrets/variables, Pages site, or deployment record. The public website loads but reports a CORS preflight failure to a non-Main Supabase function. The Hostinger panel could not be reached, so its external auto-deployment settings remain unverified; no changes were made to that other backend.
- **Live read-only checks:** Supabase Main is `ACTIVE_HEALTHY`, PostgreSQL 17.11, with 16 recorded migrations and seven active Edge Functions at the manifest's expected versions. The publishable-key Auth health request returned HTTP 200. This is endpoint/key connectivity, not a signed-in user acceptance test.
- **Migration status:** The 16 recorded versions are `001`–`006`, `008`–`014`, `20261110172940`, `20261110173339` and `20261110173506`. The package-receipt table is empty. The manifest validator and Phase 4B-exclusion test pass, but `release_ready=false`; live catalog checks show the examinations tables, mutation-hold state and atomic role-management RPC are still absent. Unreceipted production SQL steps are the mutation hold, Phase 3B role/teacher/onboarding, Phase 3C contact guard, Phase 4A examinations, and Phase 7M finance/settings packages; guard refresh, hold activation and coordinated Edge Functions are also not executed. Phase 7M admissions-tracking and event packages remain deferred. These are reviewed package candidates, not authorization to replay; the partial Phase 4B package remains outside the production manifest. No historical migration was replayed, no history was repaired, and no SQL or Edge function was deployed.
- **Recovery and release blockers:** The latest local backup inventory is only a 17 November 2026 record (backup `2295604002`); its current managed status/PITR window was not freshly queried. The existing native PostgreSQL restore is not a Supabase-compatible platform restore. Fresh managed recovery evidence, isolated compatible-restore proof, external write-hold attestation, and hash-bound owner approval are still required.
- **Git review:** At the start of this follow-up, local `main` was 12 commits ahead of `origin/main` (`af0c23bd1820472d014f43c1fe3d778996944fb2`) and had no divergence. Configuration/build corrections are committed locally as `9153079916433d32996857be951350d758c289b3`; all pre-existing commits were preserved, and no push was performed. No credential pattern was found in the unpublished diff. The only migration-package delta is the local/partial Phase 4B development proposal, excluded from the production manifest. No production operation was performed.

**Latest local launch-preparation refresh — 18 November 2026:** A true/false
lesson-practice flow was added and locally committed as
`5c61b7b0d87df23a042d1b8fbf20915b741de31d`. The isolated assessment,
native-contract, Phase 3B reconciliation, migration validation and six
migration-tamper tests pass; TypeScript check/lint pass; web tests pass 112/112;
Flutter analysis has no issues and Flutter tests pass 64/64. The React
production build succeeds and the public output contains no secret API-key
value or service-role JWT. The mobile publishable key passed a non-mutating
Main Auth health check (HTTP 200); its value was not logged. Live `origin/main`
matches the cached tracking ref; local `main` is clean, 11 commits ahead and
0 behind. No push, backup creation, production write, deployment or live
role workflow was performed.

**Disposition remains NO-GO.** Phase 4B remains PARTIAL and Phase 4C is not
started. The production manifest remains `release_ready=false`; production
password/security findings, current recovery evidence and Supabase-compatible
restore, external hosting/backend binding and security headers, hosted
Storage, authenticated nine-role acceptance, and Android release signing
remain open. `mobile/android/key.properties` is absent, so no signed release
APK/AAB can be produced. This update supersedes earlier local suite counts
and the earlier statement that mobile key project binding was unverified;
it does not authorize or request production release approval.

<!-- PHASE7M-CURRENT -->
**18 November 2026 update — Phase 7-M:** The refreshed Main inventory is **57 local files / 57 GitHub Main files / 16 production history records**. All migration files match origin/main bytes at `d9e15f3b5680b32323bde29d3f41bd3bf22b4716`. The earlier evidence below is historical wherever it differs. No production write, history repair or deployment occurred; Phase 4B remains paused.

**Phase 4B local refresh — 18 November 2026:** Phase 4B resumed for local
development and remains **PARTIAL**. Required local database runners, migration
integrity/tamper tests, 105 web tests, web type-check/lint/build, Flutter
analysis/61 tests and configured debug APK build passed. Assessment question
locking and practice/assessment separation are tested in the disposable
database. The feature remains excluded from the production manifest; no Main
SQL, Edge, website or mobile deployment occurred. The current public-key
project binding, hosted Storage behavior and authenticated live acceptance
remain unverified. This refresh supersedes the earlier "paused"/failed-Flutter
statements in this report only for local development evidence.

Verified partial progress is committed locally as
`2a13081f771e01f5b73e5fa5aa0648ac938b2054` on `main`; the documentation
closeout is separate. Neither commit was pushed. Production remains NO-GO.

**Current disposition: NO-GO.** [Phase 7-M](PHASE_7M_RECONCILIATION.md) supersedes earlier inventory/source assumptions below. Production has 47 public tables with RLS, no private 007 finance schema/owner, no proposed mutation hold or atomic-role RPC, and no examinations schema. Finance aggregate checks found one assignment and zero invalid scope/amount/duplicate-key results. The production baseline has not been changed.

The [updated manifest](../../supabase/deployment/phase7r/main-deployment-manifest.json) integrates existing maintenance/3B/3C/4A packages with tested Main-specific finance/settings corrections. Tracking/enrollment and protected events are pinned as deferred coordinated-cutover packages; unfinished Phase 4B/learning scoring and overlapping timestamped candidates are excluded from execution. The executor commits each package, postcondition and receipt atomically, rejects source changes/retries and follows manifest order. Its `release_ready=false` gate blocks execution.

The native combined replay, profiles/examinations, nine-role/finance/admissions/attendance security suites, concurrency, maintenance and actual executor atomicity tests passed. Drift gates passed; six tamper tests passed. Default executor dry run passed read-only. See [actual results and current source/manifest/executor hashes](../../supabase/deployment/phase7m/test-results.json); all earlier approval hashes below are obsolete. Two grant-only history repairs are proposed, not executed or authorized. New database CI has no production credentials or deployment job and has not run on GitHub.

Prior application-scope archive recovery evidence is reused, not rerun; full platform recovery, current recovery point, independently enforced write containment, owner approval, coordinated hosted compatibility and authenticated web/mobile acceptance remain required. Prior Flutter/signing blockers are unchanged. No commit/push or live write occurred.

<!-- END-PHASE7M-CURRENT -->

## Execution refresh — 18 November 2026 (Asia/Aden)

**Disposition: NO-GO.** Local recovery and safety tooling were exercised, but no production SQL, maintenance activation, Edge deployment, website deployment, migration repair, APK/AAB publication or authenticated live acceptance occurred. The owner must approve the exact final manifest before any production write; this report is not that approval.

- **Historical Phase 7-R preflight:** Git branch `main`, HEAD `f2ca63f08ed59455cd8cebb64f99aa0272c93af2`, and live `origin/main` matched in a read-only `ls-remote`; the worktree was clean before that preflight's documentation update. GitHub API reported zero hooks and zero deployments. The two active root workflows perform CI only. Hosting deployment settings were unverified, so no commit or push was made during that preflight. Later local commits are recorded above; no push was made.
- The configured Supabase Main identity is `aeryusbrulqdxjdynwfh`. No production SQL or Edge write was attempted. The latest managed backup status/PITR evidence available in this task remains the prior recorded result; it was not refreshed here.
- Isolated recovery runner: PASS in disposable native PostgreSQL; archive checksum verified; 85 application tables, 860 rows, 355 constraints, 105 functions, 44 triggers and 113 policies verified; no row-count mismatch. It reports the original raw restore's 56 errors and does not restore original role attributes, memberships or passwords. Evidence: `D:\SAI-Production-Backups\MAIN-20261117-164017\phase7r-recovery-9f6531a069a94427b6ba7c4fba73f012`. Supabase Auth, Storage, Realtime, Edge runtime/secrets, managed Cron, Vault and hosted-only extensions are outside this native recovery.
- Maintenance protection: local authorization, concurrent write barrier and rollback tests PASS. The local database mechanism and fail-closed Edge gates are not active on Main. External containment of legacy ingress, direct API access, managed jobs and privileged/platform writers remains an operator prerequisite. Recovery security checks also warn that 14 public wrappers still grant `EXECUTE` to `authenticated`; the Phase 3B grant restrictions must be applied and reverified before any cutover.
- Deployment executor `supabase/deployment/phase7r/Invoke-MainDeployment.ps1`: default dry-run PASS with no writes; wrong project ref and `-Execute` without attestations each failed safely. Executor SHA-256: `6268a825b37e29337bc924673a68be6cd4375ad66d066072574122f57da94e5e`. Manifest SHA-256: `341d66205f065a4ea31a28fde09f627eb7e80d0a073e00f184cd4d4b09d858fd`. Execution remains prohibited until every external attestation is valid and explicit owner approval binds these hashes and the commit.
- Read-only hosted Edge inventory: `manage-roles` v9 (`verify_jwt=false`), `school-admin` v7 (`false`), `provision-learning-account` v8 (`true`), `link-student-account` v4 (`true`), `admission-reminders` v7 (`true`), `admission-notify` v9 (`true`), `announcement-email` v3 (`true`). No function was deployed.

| Check | Latest actual result |
|---|---|
| Root TypeScript type-check, lint and React production build | PASS, exit 0; build retains existing large-chunk warning |
| Root Main configuration/workflow integration tests | PASS, 3/3, exit 0 |
| Web test suite | PASS, 105 tests, exit 0 |
| Deno focused tests / changed-file checks | PASS, 7 tests; `deno check` passed for 10 changed entrypoint/shared files |
| Native isolated recovery and application integrity | PASS; counts and scope above; not a Supabase-compatible platform restore |
| Maintenance authorization / concurrency / rollback | PASS in isolation; production hold not activated |
| Deployment executor dry-run | PASS, exit 0; no database or Edge writes |
| Executor wrong-project / missing-attestation gates | Expected failures, exit 1 before writes |
| Flutter `pub get --offline` | PASS, exit 0, Flutter 3.47.9 / Dart 3.13.7 |
| Flutter analysis | FAIL, exit 1, 30 issues including file-picker API mismatch, duplicate `_notice`, missing homework-file method and missing `launchUrl` |
| Flutter tests | FAIL, exit 1; 41 passed and 5 files failed to compile, including abstract `PlatformFile` construction and the analyzer errors above |
| Android debug APK | FAIL, exit 1 after Gradle entered `assembleDebug`; Dart compilation errors stopped the build |
| Java / Android toolchain | OpenJDK 21.0.13 LTS verified. Gradle wrapper 8.14.3 and AGP 8.11.1; this attempt failed at Dart compilation, so it does not establish a Java/Gradle incompatibility or Android readiness. |
| Android release signing | NOT VERIFIED; `android/key.properties` absent; no signed AAB produced |
| Production writes / releases / live nine-role acceptance | NONE |

The archive-level recovery result supersedes the earlier missing-`authenticated`-role rehearsal: the updated runner reconstructs local role names and completes application-scope testing, but not source grants/role attributes or managed services. This remains partial recovery, not a rollback certificate. Preserve paused Phase 4B code; no backup, credential or generated release artifact was added to the repository. No reset, Docker, force push, production operation or push was performed.

## 1. Main and Git identity

| Item | Observed value |
|---|---|
| Supabase project | `aeryusbrulqdxjdynwfh` (`sai-college-production`) |
| Project status / region | `ACTIVE_HEALTHY`, `ap-northeast-1` |
| Database | PostgreSQL 17.11 |
| Git branch / HEAD | `main` / `f2ca63f08ed59455cd8cebb64f99aa0272c93af2` |
| Live `origin/main` | `f2ca63f08ed59455cd8cebb64f99aa0272c93af2` at read-only `ls-remote` |
| Worktree | Clean before this documentation update; preserve paused Phase 4B source |
| GitHub Actions / hook inventory | Two active root workflows run CI only; authenticated GitHub API reported zero hooks/deployments. Hostinger control-panel settings remain unverified. |
| Main public catalog | 47 listed tables; RLS enabled on all listed tables. Proposed examination tables are absent. Existing legacy homework tables are present. |
| Main migration history | 16 records: `001`–`006`, `008`–`014`, `20261110172940`, `20261110173339`, `20261110173506`. Do not replay old migrations or repair history by inference. |

The project/catalog values are earlier read-only observations, not proof of
application behavior, production authorization or successful restore. The
Git identity and recovery result above are the latest 18 November checks.

## 2. Recovery gate and limits

### Existing evidence

The earlier raw `pg_restore` attempt documented below failed; the updated
isolated runner result is recorded in the execution refresh above. Its PASS
applies only to reconstructed application schema/data in native PostgreSQL.

- The archive `D:\SAI-Production-Backups\MAIN-20261117-164017\MAIN_DATABASE.dump`
  has recorded SHA-256
  `a3217b751c88da283f1a521068276bb79db9cad0a7c456630e85874e227638ac`; its
  recorded checksum matched and full decompression passed.
- Its isolated PostgreSQL restore is explicitly **PARTIAL**: 94 tables
  restored; 93/96 archive data-section counts matched; 113/115 policy entries
  restored; restore exited 1. The native target lacked five required extensions,
  Windows blocked `pg_stat_statements`, and restore of the `ensure_rls` event
  trigger failed on ownership. Auth role configuration and original grantors
  were not restored; passwords are absent. This is not a complete Supabase
  restore or a production recovery certificate.
- The workspace archive reports 40,336 of 40,336 enumerated files verified,
  zero errors and two directory links represented as metadata. It is protected
  by a restricted Windows ACL but is **not encrypted** and is not a production
  database recovery point.
- One inventoried Storage object and Edge source/configuration were separately
  recorded. Database backup alone does not preserve Storage file bytes.
- The 17 November Main reconciliation report recorded eight completed managed
  backups from 9–16 November, latest reported at 16 November 2026
  16:01:38.482 UTC (ID `2285443784`), with WAL-G enabled and PITR disabled.
  That is the latest known prior observation, not a backup-list refresh in this
  pass. No managed-backup listing tool/current scoped evidence was available.

### Required before any production write

1. Operator supplies read-only dashboard evidence for the latest completed
   backup ID/time/status, retention, restore availability, PITR state/window,
   and whether a fresh snapshot is needed for the planned maintenance window.
2. Produce an approved fresh protected recovery point if the previous snapshot
   is stale; capture schema, data, Auth/user linkage, migration history,
   required ACL/grants and sequences using protected TLS configuration.
3. Restore to an isolated Supabase-compatible environment and verify schema,
   application/Auth data, roles, extensions, policies, triggers, migration
   records, counts, sequences and required platform behavior. Preserve and
   verify Storage object bytes, Edge source and Edge configuration separately.
4. Record discrepancies, recovery time/point limits and owner-approved
   recovery procedure. Do not treat the partial native PostgreSQL restore as a
   production rollback path.

## 3. Hosted Edge state and local source fingerprints

Hosted metadata and downloaded source were inspected read-only. The hosted
`ezbr_sha256` values below are platform-reported fingerprints; they are not
assumed equivalent to a local file SHA-256.

| Function | Hosted state/version | `verify_jwt` | Hosted source fingerprint |
|---|---:|---:|---|
| `manage-roles` | ACTIVE v9 | false | `17bbfaab3103d98e6c3303154188aa0a00091e141636ba0e6d4595558f72076f` |
| `school-admin` | ACTIVE v7 | false | `de829b86793f9f515b329ad3c58d34b5ec500e2dd6b88b7c7971e6a4bd738289` |
| `provision-learning-account` | ACTIVE v8 | true | `387c1be9769a97ffc9c0b4e19d322adfe4503ce4b18546d62a2c2040479b9cc5` |
| `link-student-account` | ACTIVE v4 | true | `e685c77004a122e884762644a46ede56bfb360eb0ad48b7f5e2755984a7db7076` |
| `admission-reminders` | ACTIVE v7 | true | Platform fingerprint not captured in the current record |
| `admission-notify` | ACTIVE v9 | true | Platform fingerprint not captured in the current record |
| `announcement-email` | ACTIVE v3 | true | Platform fingerprint not captured in the current record |

| Local candidate source | SHA-256 |
|---|---|
| `supabase/functions/manage-roles/index.ts` | `28db90d00ad7dab2bdabfa888546f358fec39fe300db87bd0a2739c679fd8217` |
| `supabase/functions/school-admin/index.ts` | `45667f463eaa6992f9dc7dc2c1d25f86eb63c58bf3f45cf1aa21b9cccafaf848` |
| `supabase/functions/provision-learning-account/index.ts` | `dc33a9aef2742747c4bcfd337d0386d3224b526b90d0585e2379a8983cb54490` |
| `supabase/functions/link-student-account/index.ts` | `b22ecd7198708a87b31addad320b77f824294ac7f6432a9a1eee0e7d3bde665c` |
| `supabase/functions/admission-reminders/index.ts` | `301e50fc2d4f1d66223be8e04b88aa7b7fc8b30eada94d6153ca9a9c95a0aa72` |
| `supabase/functions/admission-notify/index.ts` | `d6e8b83aa8686c0233f26779e0107c1f1e3c13d616cdd08fa4a0ebdd4ec0a285` |
| `supabase/functions/announcement-email/index.ts` | `1f1077f56a197dbba4e8105c1923f4c728cdd3d49e3e0e27937cd0dd39367f46` |
| `supabase/functions/_shared/role-management-handler.ts` | `38f1efc49e21f1ad5aae858d7f25c5613919886aea9a11b23c3ce531267753f7` |
| `supabase/functions/_shared/mutation-gate.ts` | `80dd24600a5748116f00aafe36799d332b80d3c888bd78f5b34a6eab4167acef` |
| `supabase/functions/_shared/client-ip.ts` | `015f547c2382273c5639fe4f8970926fecdef7611beaadc2e92091f47ec0b5e7` |

The deployed legacy functions remain active. Their inspected code does not
enforce `PHASE3B_MUTATIONS_DISABLED`; `manage-roles` and `school-admin` also
report `verify_jwt=false` and perform application-level authentication inside
their handlers. A UI flag or setting that variable on the newer local source is
not an enforceable hold for already deployed versions.

## 4. Hash-pinned SQL candidate manifest

All files below are reviewed **proposals**, not migrations approved for
execution. Each listed file contains its own transaction boundary; the set is
not one atomic transaction and is not atomic with Edge deployments.
The tested executor pins these reviewed SQL and function sources. Its current
manifest and executor hashes are recorded in the execution refresh above;
owner approval must bind those exact current hashes rather than this table
alone.

| Order | File | SHA-256 | Dependency / purpose | Rollback boundary |
|---:|---|---|---|---|
| 1 | `supabase/deployment/phase3b-main/01_role_contract.sql` | `8b2a2db0c4db8b33c0190a3e538414ba1a5781a8d5697e5785683236ce817417` | Main 3B prerequisite. Last-usable-Super-Admin guard, atomic role RPC, `sai_set_role` retirement-by-denial, membership/table ACL hardening and helper execute restrictions. | Transaction rolls back if it fails before commit. No inverse after commit; the resulting lockdown must be paired with compatible Edge routes under a verified global hold. |
| 2 | `supabase/deployment/phase3b-main/02_teacher_assignment.sql` | `1f3e35c4897814258a99053ba8b16543aae339d8ebbff0ef77c6879b9814fe4e` | Requires order 1; adds serialized teacher assignment RPCs. | Per-file transaction only; no reviewed inverse. |
| 3 | `supabase/deployment/phase3b-main/03_verified_onboarding.sql` | `edf88c5e0012762fc781079e996386455b5fd3e97d1fc0d6fb8f1872151fd05c` | Requires order 1 and Main baseline; guarded student/parent link and verification contracts. Legacy direct writers must be held before guards are installed. | Per-file transaction only; no reviewed inverse. |
| 4 | `supabase/deployment/phase3c-main/001_own_contact_validation.sql` | `17f33774dda9200ed371ccf59eae3ebba8584074bf9eb4600746897ff8d84afe` | After 3B; validates own-profile contact fields and server-managed timestamps. | Per-file transaction only; no reviewed inverse. |
| 5 | `supabase/deployment/phase4a-examinations/001_examinations.sql` | `36f90b4ba4e01481731912787144e098ef0efc8a026695ad511a9e7fa6b135f2` | After role/identity prerequisites; adds exams/results, state validation, grade triggers, RLS and class/roster RPCs. | Per-file transaction only; no reviewed inverse. |
| Containment only | `supabase/deployment/phase3b-main/rollback_hold.sql` | `f7cafebe02a105ef4361c3bf73eeceeeb5800dc105f3d8e86fda205cd344d553` | Explicit operator-approved revocation of execution on the new RPCs after their installation. Not a restore or a universal write hold. | Does not undo DDL/data and does not disable already deployed legacy direct writers. |

### Candidate execution order if all gates later pass

1. Obtain the recovery proof and written approval for the exact hashes above.
   Establish and rehearse a **separate, independently enforceable global write
   hold** first, covering old Edge instances, direct PostgREST/RPC writes,
   background jobs and privileged writers. The present `rollback_hold.sql`
   does not meet this requirement.
2. Under that verified hold, apply SQL orders 1, 2 and 3 sequentially. After
   each commit, verify expected RPC definitions, function grants, role/
   membership ACLs, triggers and RLS from read-only catalog checks and isolated
   positive/negative authorization tests. Stop on any discrepancy.
3. Still under hold, deploy reviewed local replacements for
   `manage-roles`, `school-admin`, `provision-learning-account` and
   `link-student-account`. Preserve unrelated school-admin operations and
   ensure all role, teacher and link writes use the corresponding guarded
   contracts. Record the platform-returned versions, fingerprints and
   `verify_jwt` settings. Test real authenticated denial/allow paths without
   production student mutations.
4. Apply SQL order 4, then 5, each separately, after schema preconditions and
   isolated tests pass. Verify profile validation, exam schedule/marks/state/
   grade policies and student/verified-parent visibility.
5. Only after backend acceptance, build and deploy the reviewed React/mobile
   clients, verify Main configuration and all nine roles, and release the
   external hold only after approved safe-exit checks pass.

This sequence is conditional. The exact deployed function interleaving must be
reviewed with the tested package, and the independent hold is currently
unproven; therefore **do not execute**.

## 5. Stop and rollback procedure

- Stop immediately on an unexpected catalog, migration, grant, policy, trigger,
  RPC, function-version or authorization result. Do not run later files.
- If an individual SQL file errors before `COMMIT`, allow that file's
  transaction to roll back; verify no partial effects before retrying.
- If a file committed or an Edge deployment completed, keep the external hold
  in place. Do not assume a SQL rollback script exists. Preserve logs and
  fingerprints; use only a reviewed forward correction or an owner-approved,
  tested recovery procedure based on the verified recovery point.
- Prefer out-of-place restore and validation before any in-place restoration.
  Restoring an older snapshot can discard legitimate writes and is not an
  automatic response to a function deployment failure.
- `rollback_hold.sql` only revokes new RPC execution. It does not roll back
  schema/data changes, restore old function versions, or block legacy service
  role writes.
- Do not use `supabase db push`, replay the historical migration directory,
  repair migration history, reset Main, force-push Git, or deploy from a CI
  workflow.

## 6. Approval and evidence record

| Record | Status |
|---|---|
| Approval | NOT REQUESTED / NOT GRANTED |
| Deployment timestamp | NONE |
| Production SQL writes | NONE |
| Edge deployments | NONE |
| Website deployment | NONE |
| APK/AAB | NONE |
| Authenticated live acceptance | NOT RUN |
| Deployment record / resulting versions | Not applicable until a separately approved deployment is executed |

Before any later approval, attach operator-supplied current backup/PITR
evidence, isolated full-recovery results, the global hold rehearsal, exact
manifest review, application acceptance identities and explicit project-owner
approval. No secrets or credentials should be sent in chat or committed.
