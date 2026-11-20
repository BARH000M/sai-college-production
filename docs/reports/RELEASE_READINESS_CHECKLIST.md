# Production release readiness — Phase 7-R

**Status: NO-GO.** This is a local readiness record, not deployment approval.
No production SQL, maintenance activation, Edge deployment, website/mobile
publication or authenticated live acceptance occurred.

## SEC-02 integration verification — 20 November 2026

| Area | Result |
|---|---|
| PR/main reconciliation | Local SEC-02 branch reconciled with `origin/main` at `38b03e0`; pre-merge head backed up. One integrity conflict resolved. No force-push. |
| Migration disposition | Archived 017 migration preserved outside production migrations; accidental zero-byte `0` removed. Validator and 8 tamper tests PASS. |
| Root/web | Root 31/31, type-check and lint PASS; web 112/112 PASS. |
| Flutter | Strict analysis PASS; full tests PASS (67 tests). |
| Native PostgreSQL | Profile/contact, examinations, learning assessment, native contracts and Phase 3B reconciliation PASS on isolated loopback clusters; no Docker. |
| Production SPA | Build PASS with authorized URL and synthetic non-secret publishable-key-shaped CI fixture; existing large-chunk warning remains. No deployment. |
| GitHub Actions | All workflow action references are immutable commit hashes. Existing remote PR checks refer to the prior commit; rerun is pending push. |
| Supabase project identity | Read-only project metadata verifies the authorized ref/name and `BARH000M` organization. No key value accessed. |
| Remote preview integration | Supabase Preview check links to a different project. Push is blocked pending owner confirmation/rebinding so a retired/non-authoritative project cannot be modified. |

Production remains **NO-GO**. No production migration, hosted database write, deployment, release, or GitHub settings change occurred.

## Latest local evidence — 18 November 2026

The latest local integration refresh supersedes earlier local suite counts
and key-binding uncertainty in the historical checklist below. Phase 4B is
still partial; this is not production release approval.

| Area | Result |
|---|---|
| Isolated application recovery | PASS: checksum verified; 85 tables, 860 rows, 355 constraints, 105 functions, 44 triggers and 113 policies; no row-count mismatch. Not a Supabase-compatible platform restore. |
| Maintenance protection | Local authorization, concurrent write barrier and rollback tests PASS. Not active on Main; external ingress/jobs/privileged writer hold remains unverified. |
| Deployment executor | Default dry-run PASS; wrong project and missing-attestation gates failed safely. No production writes. |
| Database and migration tests | Assessment and native contract suites PASS; Phase 3B reconciliation PASS; migration validator PASS; tamper tests 6/6 PASS. |
| Web | TypeScript check, lint and production build PASS; tests 112/112 PASS; built public assets contain no secret API-key value or service-role JWT. Vite reports a large-chunk warning. |
| Flutter | `flutter pub get` PASS; analysis PASS with no issues; tests PASS 64/64. |
| Mobile runtime configuration | Main project URL and runtime variable are configured; publishable-key Auth health request returned HTTP 200 without logging the key. This verifies project binding only, not authenticated application workflows. |
| Android | Prior configured debug APK evidence remains; no new APK/AAB was built in this refresh. Release signing is blocked because `mobile/android/key.properties` is absent. |
| Phase 4B status | PARTIAL. True/false lesson practice is added and locally tested; broad exercise, homework, analytics, authorization and role-parity requirements remain. |
| Git / publication | Commit `5c61b7b0d87df23a042d1b8fbf20915b741de31d`; clean `main`, 11 ahead / 0 behind the live remote ref. No push. Remote auto-deployment linkage remains unverified. |

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
- [x] Flutter analyzer has no issues and all 61 current tests pass locally.
- [x] Produce the configured Android debug APK.
- [ ] Verify signed AAB separately when signing inputs are securely configured;
  build/sign iOS on macOS if required.
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
- [x] Commit reviewed Phase 4B partial progress locally; keep the push
  postponed. Current implementation commit:
  `2a13081f771e01f5b73e5fa5aa0648ac938b2054`.
- [x] Authenticated GitHub API reported no hooks or deployments; active root
  workflows were CI-only.
- [x] Preserve the Phase 4B partial-progress local commit; do not push until
  external automatic-deployment settings are verified.
- [ ] Obtain explicit project-owner approval before any production write,
  migration, Edge deployment, website deployment or publication.
- [ ] Release any write hold only after all post-deployment checks pass and
  approved safe-exit conditions are met.

Manifest SHA-256:
`341d66205f065a4ea31a28fde09f627eb7e80d0a073e00f184cd4d4b09d858fd`

Executor SHA-256:
`6268a825b37e29337bc924673a68be6cd4375ad66d066072574122f57da94e5e`
