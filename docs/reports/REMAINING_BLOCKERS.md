# Remaining blockers — Phase 7-R

Status reconciled 17 November 2026. Production remains unchanged and deployment
is **NO-GO**.

## P0 — production recovery and cutover

1. **Recovery proof is insufficient.** The SHA-256-verified database archive
   decompresses, but its isolated restore is partial: 94 tables restored,
   93/96 data-section counts matched, 113/115 policy entries restored, missing
   Supabase extensions/platform services, `ensure_rls` ownership failure, and
   role configuration/credentials not recovered. A same-day Main reconciliation
   previously reported the latest managed backup at 2026-11-16 16:01:38.482 UTC
   and PITR disabled; the backup list was not refreshed in this preflight.
   Verify current retention/status and complete an isolated Supabase-compatible
   recovery, including required Storage bytes and Edge configuration.
2. **No universal write hold is proven.** Hosted legacy role, provisioning and
   linking functions remain active and their downloaded sources do not enforce
   the proposed `PHASE3B_MUTATIONS_DISABLED` flag. A UI banner or function
   environment flag alone is insufficient. Prove a safe, independent hold over
   HTTP/Edge, direct database/RPC, background and privileged writers, and test
   its release while preserving an available Super Admin.
3. **No explicit production approval.** The pinned candidate manifest is
   documentation only. Do not execute SQL, deploy Edge functions, enable a
   maintenance hold, deploy the website or build/publish a release from it.
4. **SQL and Edge cutover is not atomic across artifacts.** Each SQL proposal
   commits independently; an Edge update is a separate deployment. Stop at the
   first mismatch or failed verification, keep a proven hold in place, and do
   not proceed with later files. There is no general reverse migration.

## P1 — feature and release validation

5. Phase 3B/3C/4A are local proposals/implementations, not Main-deployed or live
   verified. The current Main catalog has 16 migration records and no proposed
   exam tables; do not repair migration history or replay the historical
   migration directory.
6. Phase 4B remains paused with uncommitted changes. The isolated SQL fixture
   and focused web tests passed earlier, but post-fix web type-check/ESLint and
   Flutter analysis/tests remain unverified.
7. Java/Gradle compatibility, Android APK/AAB, iOS signing, current production
   web build identity, Hostinger access and authenticated website behavior are
   not verified.
8. No controlled authenticated nine-role web/mobile production acceptance,
   cross-client data check, or production negative-authorization test was
   performed.

## Git and deployment controls

- Local `main`, `origin/main`, and HEAD currently match at
  `0737f84b1e06be009cf6a5bc46c01ff2364fdac8`. The worktree is dirty.
- Existing GitHub workflows run CI only; no migration/deployment action was
  found. Keep GitHub `main` as the source of truth and do not stage or push
  mixed Phase 4B and recovery-preflight edits.
- Keep Supabase MCP read-only for routine work. Use an approved, protected,
  project-verified deployment method only after the recovery, hold and
  approval gates pass.
