# Production release readiness — Phase 7-R

**Status: NO-GO.** This is a local readiness record, not deployment approval.
No production SQL, maintenance activation, Edge deployment, website/mobile
publication or authenticated live acceptance occurred.

## Latest local evidence — 18 November 2026

| Area | Result |
|---|---|
| Isolated application recovery | PASS: checksum verified; 85 tables, 860 rows, 355 constraints, 105 functions, 44 triggers and 113 policies; no row-count mismatch. Not a Supabase-compatible platform restore. |
| Maintenance protection | Local authorization, concurrent write barrier and rollback tests PASS. Not active on Main; external ingress/jobs/privileged writer hold remains unverified. |
| Deployment executor | Default dry-run PASS; wrong project and missing-attestation gates failed safely. No production writes. |
| Web | Type-check, lint, production build and 105 tests PASS; 3 configuration/workflow integration tests PASS. |
| Edge | 7 focused Deno tests and checks of 10 changed files PASS. |
| Flutter | Offline dependencies PASS. Analysis FAIL (30 issues); tests FAIL (41 passed, five files failed compilation); debug APK FAIL at Dart compilation. |
| Android | OpenJDK 21.0.13; Gradle 8.14.3 / AGP 8.11.1. Java/Gradle compatibility failure not established by this build. Release signing not verified; `android/key.properties` absent. |
| Git / publication | Local `main` matched live `origin/main` at `f2ca63f`. No push because Hostinger settings remain unverified. |

## Recovery and change safety

- [ ] Confirm latest completed managed Main backup, ID, timestamp, retention,
  restore availability and PITR window from the Supabase dashboard; task-time
  backup status was not refreshed.
- [ ] Use operator-supported recovery in an isolated Supabase-compatible
  target, including Auth/roles, extensions, grants, triggers, RLS, migration
  records, counts and required platform behavior.
- [x] Run a disposable native PostgreSQL application-scope recovery and record
  its limits. The earlier raw restore had 56 errors; local role attributes,
  memberships and passwords plus managed Auth, Storage, Realtime, Edge, Cron,
  Vault and hosted-only extensions are not recovered.
- [ ] Independently preserve and verify Storage object bytes, Edge source,
  secrets and function configuration.
- [x] Test local maintenance authorization, concurrent write barrier and
  rollback; do not activate it on production.
- [ ] Independently enforce a production hold over legacy Edge ingress, direct
  API/RPC access, scheduled jobs and privileged/platform writers; preserve
  emergency Super Admin access and prove safe release.
- [ ] Approve the exact SQL/Edge manifest, hashes, ordering, maintenance
  window, stop criteria, recovery route and acceptance plan.

## Database and Edge

- [ ] Reconcile current Main catalog and migration history against each
  proposal; do not blindly replay historical migrations or repair history.
- [ ] Resolve the isolated warning that 14 public wrappers still grant
  `EXECUTE` to `authenticated`; verify Phase 3B restrictions.
- [ ] Run isolated Main-baseline positive/negative RLS, RPC and concurrency
  tests, including last usable Super Admin and branch/account isolation.
- [ ] Confirm all legacy writers are externally held before installing guards.
- [x] Validate executor dry-run and negative project/attestation gates. The
  executor defaults to dry-run and does not automatically release a hold.
- [ ] Execute only after owner approval binds the current manifest, executor
  and commit plus fresh recovery and external-hold attestations.
- [ ] Record actual deployed SQL hashes, Edge versions/configuration,
  timestamps and test outcomes. Keep hold active after any failed step.

## Web, mobile and live acceptance

- [x] Run web type-check, lint, production build, test suite and focused
  configuration/integration tests locally.
- [ ] Verify production build uses approved Main URL/public key and has no
  service-role/secret key in public output.
- [ ] Verify Hostinger deployment configuration, HTTPS, SPA routing, Arabic
  RTL, assets, deployed artifact identity and rollback before website
  deployment.
- [ ] Fix Flutter analyzer/test compilation failures before release validation.
- [ ] Produce a successful Android debug APK; verify signed AAB separately
  when signing inputs are securely configured. Build/sign iOS on macOS if
  required.
- [ ] Test all nine roles on web and mobile with controlled accounts: login,
  logout, onboarding, profile, admissions, student/teacher, attendance,
  finance, learning/homework, examinations/results, library and other claimed
  modules.
- [ ] Verify authorized cross-client persistence and unauthorized access
  denial; do not modify real student records for testing.
- [ ] Verify loading, empty, error/retry, responsive and Arabic RTL behavior.

## Git, governance and release

- [x] Read-only `git ls-remote` confirmed local `main` and live `origin/main`
  matched before documentation edits.
- [x] Authenticated GitHub API reported no hooks or deployments; active root
  workflows were CI-only.
- [ ] Verify Hostinger control-panel/server deployment settings and any
  external CI/CD before committing or pushing documentation/source.
- [ ] Preserve paused Phase 4B implementation; stage only explicitly reviewed
  Phase 7-R files if a push is proven not to trigger production deployment.
- [ ] Obtain explicit project-owner approval before any production write,
  migration, Edge deployment, website deployment or publication.
- [ ] Release any write hold only after all post-deployment checks pass and
  approved safe-exit conditions are met.

Manifest SHA-256:
`341d66205f065a4ea31a28fde09f627eb7e80d0a073e00f184cd4d4b09d858fd`

Executor SHA-256:
`6268a825b37e29337bc924673a68be6cd4375ad66d066072574122f57da94e5e`
