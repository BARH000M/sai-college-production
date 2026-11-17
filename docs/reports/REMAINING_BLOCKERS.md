# Remaining blockers — Phase 7-R

Status refreshed 18 November 2026. **Production remains NO-GO.** No production
SQL, hold activation, Edge deployment, website deployment, mobile publication or
live acceptance was performed.

## P0 — production recovery and cutover

1. **Recovery is application-scope only.** The disposable native PostgreSQL
   rehearsal verified 85 tables, 860 rows, 355 constraints, 105 functions, 44
   triggers and 113 policies with no row-count mismatches. The original raw
   `pg_restore` had 56 errors. The test did not restore original role
   attributes, memberships or passwords, or Supabase Auth, Storage object
   bytes, Realtime, Edge runtimes/secrets, managed Cron, Vault or hosted-only
   extensions. Obtain an operator-supported Supabase-compatible restore and
   verify platform components before any production change.
2. **External write containment is not proven.** Local database hold
   authorization, concurrency barrier and rollback tests passed, and local
   Edge gates are fail-closed. Neither mechanism is active on Main. An
   operator must separately contain legacy Edge ingress, direct PostgREST/RPC
   writes, scheduled jobs and privileged/platform writers, while preserving
   emergency Super Admin access.
3. **Fourteen wrapper grants remain pending.** Isolated security verification
   warns that 14 public wrappers still grant `EXECUTE` to `authenticated`.
   Apply and verify the intended Phase 3B grant restrictions before any cutover.
4. **No production approval for the tested exact executor/manifest.** The
   executor's default dry-run passed; wrong-project and missing-attestation
   negative checks failed safely. Manifest SHA-256 is
   `341d66205f065a4ea31a28fde09f627eb7e80d0a073e00f184cd4d4b09d858fd`;
   executor SHA-256 is
   `6268a825b37e29337bc924673a68be6cd4375ad66d066072574122f57da94e5e`.
   Obtain explicit owner approval bound to the exact hashes and commit plus
   fresh recovery and external-hold attestations. No automatic release or
   rollback is permitted.
5. **No general inverse for committed SQL/Edge changes.** Apply one reviewed
   step at a time under a verified hold, stop at the first discrepancy, and
   retain containment. Use only a tested forward correction or the
   operator-approved Supabase recovery route; do not infer a rollback from
   transaction boundaries.

## P1 — feature and release validation

6. Phases 3B/3C/4A are not deployed or live-verified. Proposed contracts are
   absent from the hosted application state; all nine roles, account links,
   cross-client persistence and negative authorization cases still need
   controlled acceptance. Do not repair migration history or replay the
   historical migration directory.
7. Phase 4B remains paused and incomplete. The latest web suite passed 105
   tests, and earlier focused SQL/web tests passed. Flutter analysis failed
   with 30 issues; Flutter tests had 41 passing and five files failing to
   compile. Errors include file-picker API mismatches, duplicate `_notice`,
   missing homework-file opening/`launchUrl`, and abstract `PlatformFile`
   construction. Preserve the feature work and fix these compile/test failures
   before a mobile release.
8. The Android debug APK build failed after entering `assembleDebug` because
   Dart compilation failed. OpenJDK 21.0.13 was verified; Gradle 8.14.3 and
   AGP 8.11.1 emitted future-support warnings, but this attempt did not
   establish a Java/Gradle compatibility failure. `android/key.properties` is
   absent, so release signing and a signed AAB are not verified.
9. The web production build passed locally, but deployed artifact identity,
   authenticated behavior and live backend requests are unverified.
   Hostinger control-panel/server deployment configuration is also
   unverified.
10. No controlled authenticated nine-role web/mobile production acceptance,
    cross-client data check, or production negative-authorization test was
    performed.

## Git and deployment controls

- Read-only check: local `main` and live `origin/main` matched at
  `f2ca63f08ed59455cd8cebb64f99aa0272c93af2`; worktree was clean before this
  documentation update.
- Authenticated GitHub API reported zero hooks and zero deployments. The two
  active root workflows are CI-only. Hostinger control-panel settings and
  external deployment integrations remain unverified; therefore this task
  made no commit or push.
- Keep GitHub `main` as the source of truth. Do not stage Phase 4B source with
  unrelated operational files; preserve work. Keep Supabase MCP read-only
  except for separately approved controlled deployment tooling.
- No production writes, database resets, Docker, force pushes or credential
  exposure were performed.
