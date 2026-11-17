# YEMEN SAI V2 — AUTHORITATIVE MASTER EXECUTION PLAN

## Locked project configuration

- Workspace: `D:\SAI-College-Production`
- GitHub: `BARH000M/sai-college-production`
- Branch: `main` only
- Supabase project: `aeryusbrulqdxjdynwfh`
- Supabase URL: `https://aeryusbrulqdxjdynwfh.supabase.co`
- Website: `www.sai-academic.com`
- Mobile: Yemen SAI Flutter application

One workspace, repository, branch and production database. No Preview environments, new branches, duplicate projects, Docker or pull requests.

## Current checkpoint

Phase 3B local development completed at `4610b20`. Task 2 reviewed changes were pushed normally to `main`; independently verified GitHub commit: `d4930fa0df349ac84c59b5e0f1a6ed4a3ea5eac3`. This roadmap is published in a subsequent documentation-only commit, identifiable in Git history.

Previously verified: 88 web tests, 7 Deno tests, isolated PostgreSQL security tests, TypeScript and ESLint passed. Do not repeat these completed checks unnecessarily. Supabase production deployment and complete backup/recovery verification remain pending.

The manually created archive became available during this resume at `D:\SAI-Production-Backups\MAIN-20261117-164017\MAIN_DATABASE.dump`. It was created by PostgreSQL 17.11 and contains 1,470 TOC entries. Earlier `MAIN-*` folders contain zero-byte `.partial` files and were not selected. The rejected password file was not reused; no production database connection was attempted.

## Execution order and evidence-backed status

### Task 1 — Backup — PARTIAL RECOVERY VERIFIED; FULL RECOVERY BLOCKED

Complete database, Storage, Edge Functions and local workspace backup. Preserve backups securely outside Git. Verify integrity and recovery coverage.

Existing backup checkpoint: `D:\SAI-Production-Backups\aeryusbrulqdxjdynwfh_20261117T125812Z`.

Resumed evidence and Storage package: `D:\SAI-Production-Backups\production-recovery-20261117`. The untracked package was moved outside the repository to preserve it outside Git.

Verified evidence:

- All 18 original evidence files passed SHA256 verification.
- Seven deployed Edge Function response bodies and configuration metadata are preserved in the existing evidence; runtime secrets are not exported.
- The single inventoried Storage object was downloaded (2,581,031 bytes), with size, ETag and SHA256 verified. This establishes coverage of the saved inventory, not a fresh inventory comparison.
- The resumed package passed SHA256 verification for 21 files.
- Manual archive SHA256 matches its supplied checksum: `a3217b751c88da283f1a521068276bb79db9cad0a7c456630e85874e227638ac`. Full decompression to SQL passed, beyond merely listing the TOC.
- Archive data includes 47 application (`public`), 27 Auth, 10 Storage and one Supabase migration-history data sections. Auth users' COPY columns include password hashes. The archive contains 379 ACL entries and 113 policy entries.
- Existing Edge Function and Storage evidence was consolidated under the selected `MAIN-20261117-164017\supplemental` directory. Forty-one consolidated files, including the final roadmap checkpoint, passed SHA256 verification. Original packages remain preserved.
- An isolated native PostgreSQL 17 cluster was initialized under the selected backup directory, bound to `127.0.0.1:55479`, and its actual `data_directory` verified before restore. All inherited PostgreSQL environment variables were removed for local subprocesses. No Docker, production connection or hosted project was used. The cluster was stopped after verification.
- Restore recovered 94 tables. Of 96 archive COPY data sections, 93 have exactly matching restored row counts; missing sections are `cron.job` (one row), `cron.job_run_details` (nine rows) and `vault.secrets` (zero rows). Application, Auth, Storage and migration-history row counts match their archive sections.
- All 113 restored policies match the saved policy evidence after normalizing PostgreSQL array serialization. Only the two extension-owned cron policies are missing. Application/Auth/Storage/migration relation owners, ACLs and RLS flags match the saved earlier security evidence. This is a catalog comparison, not a new Phase 3B security-test run.
- Password-free role attributes and memberships were reconstructed in the isolated cluster from saved evidence. Role configuration settings and original membership grantors were not replayed; original role passwords are absent. This does not establish a contemporaneous complete cluster-role export.
- Workspace snapshot: `D:\SAI-Production-Backups\workspace-20261117T133833Z`. All 40,336 enumerated regular files were archived and verified by SHA256, including `.git`, ignored files and local configuration. Forty-nine Windows path errors were repaired with extended-length paths; zero file errors or mid-read changes remain. Two directory links are recorded as metadata rather than traversed. The snapshot has a restricted Windows ACL, is not encrypted, and predates the final roadmap/status edits made during this resume.

Remaining recovery blockers and unfinished coverage:

- Full restore exited with code 1 and 56 errors, including missing-extension cascades. The partial restore must not be promoted to complete recovery.
- Local PostgreSQL 17 lacks `hypopg`, `index_advisor`, `pg_cron`, `pg_net` and `supabase_vault`. Compatible extension binaries and any required Vault recovery configuration must be supplied without Docker; omissions or stubs do not establish full recovery.
- Windows Application Control explicitly blocked loading the installed `pg_stat_statements.dll`; resolving that policy requires an approved compatible binary or administrator-managed policy change. No bypass was attempted.
- Restoring the owner of event trigger `ensure_rls` failed with permission denied. Stock PostgreSQL does not reproduce every hosted Supabase privilege mechanism; exact event-trigger ownership remains unverified.
- Role settings, original membership grantors, role-password recovery, Supabase runtime services and runtime secrets remain outside the demonstrated restore coverage. Vault has no secret rows in this archive, but extension recovery still failed.

Non-Docker extension recovery requirements:

- Use PostgreSQL-major-compatible upstream packages or source builds in an isolated local cluster. Never fabricate extension control files or silently omit extension objects.
- `hypopg` 1.4.1, `index_advisor` 0.2.1, `pg_cron` 1.6.4, `pg_net` 0.20.4 and `supabase_vault` 0.3.1 are recorded in the saved production extension inventory; compatibility with the eventual archive must be checked.
- Upstream [HypoPG](https://github.com/HypoPG/hypopg) documents installation against PostgreSQL development headers. Upstream [index_advisor](https://github.com/supabase/index_advisor#install) depends on HypoPG. Neither copying a control file alone nor substituting an empty extension is valid recovery.
- Upstream [pg_cron installation](https://github.com/citusdata/pg_cron#installing-pg_cron) documents package/source installation and preload configuration. The isolated target must prevent restored schedules from running.
- Upstream [pg_net installation](https://supabase.github.io/pg_net/installation/) documents a native build with libcurl and PostgreSQL development tooling. Restored HTTP work must not contact external services during verification.
- [Supabase Vault documentation](https://github.com/supabase/vault) explains encrypted dump contents and separately managed encryption keys. Installing the extension does not by itself prove secret recovery; validate required key availability without exposing secrets.
- Native source-build tools (`make`, `gcc`, `clang`, `nmake`) were not found on PATH; the WSL distribution listing returned no installed distribution. These upstream package/source routes therefore remain unexecuted on this host. No extension binary was installed, no application-control policy was weakened and no platform component was stubbed. A compatible approved non-Docker extension runtime is the remaining prerequisite for another full recovery attempt.

Detailed protected evidence: `MAIN-20261117-164017\recovery-status.json`, `restore.log`, `restored-table-counts.json`, `restored-policies.json`, `restored-relation-security.json`, `VERIFIED-SHA256SUMS.json`; workspace evidence: `workspace-status.json`, `workspace-file-manifest.json`, `workspace-links.json`, `SHA256SUMS.json` in the snapshot folder. No Tasks 2–7 work was started.

Do not declare BACKUP VERIFIED until all required recovery coverage is demonstrated.

### Task 2 — GitHub synchronization — COMPLETE

Review outstanding changes, including configuration and dependency files. Commit legitimate reviewed changes directly to `main`. Push normally and verify remote synchronization.

Verified execution on 2026-11-17:

- Confirmed workspace branch `main`, approved repository origin and freshly fetched remote `main`. Initial state was zero commits behind and one ahead: existing commit `f0f9243488822bd69ddafb8af80d9e7263646982`.
- Reviewed that existing commit without rewriting it. `.mcp.json` changes only the Supabase project reference to Main and retains `read_only=true`; no credential fields were found. Its legacy `supabase-preview` server label remains for Task 3. `mobile/pubspec.lock` updates `intl`, `matcher`, `meta`, `test_api` and `vector_math`; versions match the installed Flutter 3.47.9 SDK constraints, and all five package hashes match the installed package-cache hash files. No dependency re-resolution or application source changes were made.
- Both GitHub workflows were reviewed: web type/build/unit checks and mobile analysis/tests only, with read-only repository permissions. No deployment, SQL write or Edge Function deployment step exists. Local Git hooks contain samples only. GitHub API reports no repository webhooks, deployment records or Pages site; remote Main's existing Supabase app check was skipped. This establishes the reviewed push paths, not approval for a future production deployment.
- Added ignore rules for database archives/evidence, PostgreSQL connection files, browser sessions/captures/test outputs and local workspace safety copies. Existing temporary reconciliation directories remain ignored. Static `prototype/**/browser-preview` application assets are legitimate tracked source and were preserved.
- Removed `.env` and all nine `database-backups/` artifacts from the Git index only. Their local files remain intact; no backup or credential file was newly added. The old artifacts were already in remote Git history and remain there: no history rewrite or force push was performed.
- Committed repository hygiene as `d4930fa0df349ac84c59b5e0f1a6ed4a3ea5eac3` (`chore: keep local backups and connection files out of Git`). Normal push advanced remote Main from `4610b20` through the reviewed existing commit to `d4930fa`. Independent `git ls-remote --heads origin main` matched the local commit; ahead/behind was `0/0` before this roadmap follow-up.
- Reviewed outgoing added/modified files for private keys, privileged Supabase keys, service-role JWTs and GitHub tokens: zero findings. Verified ignore rules and absence of tracked environment/backup files. Diff whitespace checks passed with CRLF recognized for the pre-existing lockfile. No backup, database authentication, extension installation, Phase 3B test or production deployment was repeated.

Task 3 is ready to begin when requested; it has not started. Preserve the Task 1 partial recovery result. Full managed-platform recovery is unverified, and production deployment remains blocked until the recovery risks are reviewed and deployment is explicitly approved.

### Task 3 — Unified integration — NOT STARTED

Connect all application components, development tools and deployment configurations to the approved GitHub repository and Supabase Main project. Eliminate active references to obsolete environments. Protect credentials.

### Task 4 — Production deployment — NOT STARTED

Only after recovery verification and deployment approval, deploy the Main-compatible Phase 3B SQL package, Edge Functions and compatible web application. Build the Flutter APK against the same backend. Do not blindly replay historical migrations.

### Task 5 — Web acceptance testing — NOT STARTED

Test the actual hosted website, authentication, nine roles, permissions, academic workflows and administrative features.

### Task 6 — Mobile acceptance testing — NOT STARTED

Test the actual installed Flutter application, authentication, persistent sessions, role permissions, functionality and live synchronization with the web application.

### Task 7 — Continue development — NOT STARTED

Only after Tasks 1–6 are complete, review development phases and existing modules. Confirm the latest completed phase, identify unfinished functionality and resume implementation from the verified checkpoint.

## Governance

This file is the single authoritative project roadmap. Update task status only with actual execution evidence. Work directly on `main`. Never force push, reset production data, delete existing projects, expose secrets or create branches in GitHub or Supabase. Preserve existing data and working functionality. Do not perform unrelated audits or repeat successful checks unnecessarily. Execute one task at a time and report concise results.

## Active instruction

Stop after Task 2 synchronization and this roadmap checkpoint. Do not start Tasks 3–7 during this task. Task 1 remains at partial recovery; do not repeat backups, database authentication troubleshooting or extension installation attempts. Task 3 integration is the next authorized scope only when requested. Production SQL writes and deployment remain blocked pending recovery-risk review and explicit deployment approval.
