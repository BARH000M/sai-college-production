# Production release readiness — Phase 7-R

**Status: NO-GO.** This is an evidence checklist, not deployment approval.

## Recovery and change safety

- [ ] Confirm latest completed managed Main backup, ID, timestamp, retention,
  restore availability and PITR window from the Supabase dashboard.
- [ ] Create a fresh protected recovery point only if the previous one is stale
  for the approved maintenance window.
- [ ] Restore into an isolated Supabase-compatible target and verify database,
  Auth/roles, extensions, grants, triggers, RLS, migration records and counts.
- [ ] Independently preserve and verify Storage object bytes, Edge source and
  function configuration; database backup alone is insufficient.
- [ ] Prove and rehearse a cross-path write hold for direct clients, Edge
  functions, RPC, background jobs and privileged services.
- [ ] Approve the exact SQL and Edge manifest, ordering, maintenance window,
  stop criteria, rollback/recovery route and acceptance plan.

## Database and Edge

- [ ] Reconcile the current Main catalog and migration history against each
  proposal; do not blindly replay historical migrations or repair history.
- [ ] Run isolated Main-baseline positive/negative RLS, RPC and concurrency
  tests, including last usable Super Admin and branch/account isolation.
- [ ] Confirm all legacy writers are held before installing guards.
- [ ] Apply only one approved package step at a time; verify catalog, grants,
  policies, triggers, RPC calls and logs before proceeding.
- [ ] Record actual deployed SQL hashes, Edge versions/configuration, timestamps
  and test outcomes. Keep hold active after any failed step.

## Web, mobile and live acceptance

- [ ] Verify the production build uses the approved Main URL and public client
  key; ensure no service-role/secret key appears in public output.
- [ ] Verify existing Hostinger configuration, HTTPS, SPA routing, Arabic RTL,
  assets, deployed artifact identity and rollback before website deployment.
- [ ] Run web type-check, lint, focused/full tests and production build.
- [ ] Run `flutter analyze`, `flutter test`, Android debug APK, signed AAB (when
  signing is available), and physical-device tests. Resolve Java/Gradle/AGP
  compatibility first. Build/sign iOS on macOS if required.
- [ ] Test all nine roles on web and mobile with controlled accounts: login,
  logout, onboarding, profile, admissions, student/teacher, attendance,
  finance, learning/homework, examinations/results, library and other claimed
  modules.
- [ ] Verify authorized cross-client persistence and unauthorized access
  denial; do not modify real student records for testing.
- [ ] Verify loading, empty, error/retry, responsive and Arabic RTL behavior.

## Git, governance and release

- [x] Local `main` and `origin/main` matched at
  `0737f84b1e06be009cf6a5bc46c01ff2364fdac8` at this preflight.
- [x] Existing `web-ci.yml` and `mobile-ci.yml` inspected; no production
  deployment or migration action found.
- [ ] Preserve the dirty Phase 4B worktree; review and stage only explicitly
  approved files in a separate change.
- [ ] Obtain explicit project-owner approval before any production write,
  migration, Edge deployment, website deployment or publication.
- [ ] Release the write hold only after all post-deployment checks pass and the
  approved safe-exit conditions are met.

No hosted writes, deployments, APK/AAB builds or authenticated live acceptance
were performed in this preflight.
