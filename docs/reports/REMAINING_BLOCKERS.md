# Remaining blockers — Phase 7-R

<!-- LIVE-VERIFICATION-2026-11-20 -->
## Live re-verification — 20 November 2026

Read-only inspection of the connected Supabase project corrects several items
below. Full evidence: `docs/security/LIVE-SECURITY-VERIFICATION-2026-11-20.md`.

- RLS is enabled on **all 51 public tables**; the only zero-policy table is
  deny-all and unused. The earlier "RLS/policy pending" concern is resolved.
- **49 audit triggers** exist and `audit_logs` is healthy.
- Every `SECURITY DEFINER` RPC callable by `authenticated` enforces a role/scope
  gate through a private/public helper. The "14 unlocked wrappers" note no
  longer matches the live function set; the gates resolve correctly.
- `exams`, `exam_results`, HR, certificates, alumni, housing, inventory,
  transport, downloads, portfolios, CMS pages, `sai_backup_runs` and the
  `backups` bucket **now exist** — the "absent schema" blockers are stale.
- `sai_mutation_hold` remains absent **by design** (cutover-only tool).

Still genuinely open (non-code): managed-backup/PITR evidence, Supabase-compatible
restore proof, signed AAB (`key.properties` missing), GitHub authorization, and
the authenticated nine-role acceptance pass.
<!-- END-LIVE-VERIFICATION -->

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
7. Phase 4B is active for local development but remains incomplete. The
   refreshed web suite passed 105/105; assessment, native contract and Phase
   3B reconciliation database runners passed; Flutter analysis reported no
   issues and Flutter tests passed 61/61. Remaining feature gaps include the
   full exercise catalog, assignment lifecycle, complete grading/analytics,
   cross-role/branch acceptance and hosted Storage behavior. See
   `PHASE_4B_COMPLETION_REPORT.md`; do not infer completion from passing
   existing tests.
8. The configured Android debug APK now builds successfully. The public-key
   format and target URL/runtime variable were checked without printing the
   value, but key ownership was not independently verified. The local release
   keystore exists and is ignored; `mobile/android/key.properties` is absent,
   so release signing, a signed AAB and device acceptance remain unverified.
   Gradle 8.14.3, AGP 8.11.1 and Kotlin 2.2.20 emitted future-support warnings.
9. The web production build passed locally, but deployed artifact identity,
   authenticated behavior and live backend requests are unverified.
   Hostinger control-panel/server deployment configuration is also
   unverified.
10. No controlled authenticated nine-role web/mobile production acceptance,
    cross-client data check, or production negative-authorization test was
    performed.

## Git and deployment controls

- Local Phase 7-M commit remains preserved. Verified Phase 4B partial progress
  was committed on `main` as `2a13081f771e01f5b73e5fa5aa0648ac938b2054`;
  documentation closeout is separate. Local `main` is ahead of the
  `origin/main` tracking ref. No current live-remote synchronization check or
  push was performed.
- Authenticated GitHub API reported zero hooks and zero deployments. The two
  active root workflows are CI-only. Hostinger control-panel settings and
  external deployment integrations remain unverified; therefore this task
  made no commit or push.
- Keep GitHub `main` as the source of truth. Preserve the checkpoint-scoped
  local Phase 4B commit; do not push while automatic deployment settings are
  unverified. Keep Supabase MCP read-only except for separately approved
  controlled deployment tooling.
- No production writes, database resets, Docker, force pushes or credential
  exposure were performed.
