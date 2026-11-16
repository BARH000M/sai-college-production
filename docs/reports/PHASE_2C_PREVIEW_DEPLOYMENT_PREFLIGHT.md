# Phase 2C-2 — Preview deployment preflight

Date: 2026-11-16. Live SQL observation: **2026-11-16 12:40:02 UTC**.
Workspace: `D:\SAI-College-Production-v2-completion`.
Branch: `feature/v2-completion`; HEAD: `201f08f48167105f1332ae1d4e42ddb68a8d8e48`.

## Decision: NO-GO for deployment

**Do not execute the earlier two-migration deployment plan. There are exactly zero pending migrations.** Preview already records both reviewed proposals, and their stored statement text matches the current local proposals. The Phase 2C-1 report's 36-migration baseline and object-absence findings are historical, not current. This preflight did not apply either migration and cannot establish who applied them, when, or under what approval.

The CLI deployment path is also not ready, and recoverable backup readiness is only partially established. Completed backup metadata is available, but a suitable pre-change recovery point and tested recovery procedure have not been demonstrated. Replaying CREATE statements or repairing migration history would be inappropriate.

| Gate | Result | Evidence / implication |
| --- | --- | --- |
| Preview endpoint | PASS | Explicit project `mgibjusuglafbnlrkbep` returns `https://mgibjusuglafbnlrkbep.supabase.co`. |
| Branch and preservation | PASS | Requested branch; working tree clean before this new report. Existing files retained. |
| Migration history comparison | PASS, changed baseline | 38 local and 38 remote versions; all version/name pairs match; no duplicates, remote-only entries or pending files. |
| Reviewed SQL fingerprints | PASS | Both proposal SHA-256 hashes and verification SQL hash match Phase 2C-1 exactly. |
| Stored proposal SQL comparison | PASS within stated limits | 21 service statements and 35 settings statements match local SQL in order. |
| Original deployment plan | FAIL / obsolete | Its two proposed migrations are already recorded as applied. |
| CLI target and command readiness | FAIL | No local link/config; documented binary absent; installed CLI does not advertise the documented deployment flags. |
| Backup availability | PASS for metadata only | Four completed physical backups; latest 2026-11-15 17:57:02.918 UTC; PITR disabled. |
| Recoverable pre-change backup readiness | NOT ESTABLISHED | No restore drill, exact pre-change recovery point, recovery duration or accepted data-loss window demonstrated. |
| Prior execution/security gates | UNRESOLVED | Earlier review does not certify isolated replay, authenticated behavior or deployed-function parity; this preflight did not repeat those audits. |

## Scope and evidence boundaries

Read `PHASE_2C_FINAL_MIGRATION_REVIEW.md` and the deployment-command section of `PHASE_2B_BACKEND_REPAIR_PACKAGE.md`. Checked current target, history, proposal fingerprints, narrowly scoped object presence and backup metadata. No broad application, policy, privilege or function audit was repeated; no test suite or local PostgreSQL replay was run.

All hosted requests explicitly named Preview `mgibjusuglafbnlrkbep`. The first hosted request was `get_project_url`. Database queries were SELECT-only against system catalogs/migration history and object existence; no application records or settings/audit values were read. No Production endpoint was accessed. No migrations, functions, hosted data, roles or policies were changed. No link/init, dry-run push, migration repair, restore, backup creation, commit, push, merge or branch switch occurred.

The installed CLI initially failed to write its user telemetry file inside the filesystem sandbox. Version/help and the explicit Preview backup-list request succeeded after execution permission was granted. That permits CLI telemetry outside the workspace; it is not deployment approval. No credentials or environment-variable values were printed.

## Current Preview identity and history

- Project URL: `https://mgibjusuglafbnlrkbep.supabase.co`.
- SQL session: database `postgres`, query role `postgres`, PostgreSQL **17.11**. These SQL names alone are not project identity; project selection and the URL check provide the target binding.
- Live migration count: **38**, ending at `20261116013952_phase2b_system_settings`.
- Local inventory: **38** uniquely versioned SQL files. Exact version/name set comparison returned empty lists for pending files, remote-only versions and name mismatches.
- `public.sai_system_settings`, `private.sai_system_settings_audit` and role `sai_settings_audit_writer` all exist. This corroborates the history change without certifying their complete deployed behavior or ACLs.

| Version | Name | Current remote status | Pending? |
| --- | --- | --- | --- |
| `001`–`031` | Historical numbered migrations | All 31 version/name pairs match local | No |
| `20261115001316` | `secure_admission_tracking_and_verified_links` | Recorded | No |
| `20261115014149` | `protected_admission_status_events` | Recorded | No |
| `20261115051532` | `finance_scoped_directories` | Recorded | No |
| `20261116000437` | `learning_lesson_completion_basis` | Recorded | No |
| `20261116013950` | `learning_scored_exercises` | Recorded | No |
| `20261116013951` | `phase2b_service_permissions` | Recorded; 21 stored statements | No |
| `20261116013952` | `phase2b_system_settings` | Recorded; 35 stored statements | No |

The exact pending migration set is **`[]`**. This is a direct local/remote inventory comparison, not output from `db push --dry-run` or CLI `migration list`; neither was run against a database.

The project-detail connector request using required `id` returned `Project not found`; an alternate `project_id` request failed schema validation. No project enumeration or other-project fallback was used. This limits control-plane project-detail verification, but does not negate the successful explicitly scoped URL, SQL, migration-list and backup-list results.

## SQL checksums and stored-text parity

SHA-256 was recomputed from current local file bytes:

| File | SHA-256 | Matches final review? |
| --- | --- | --- |
| `supabase/migrations/20261116013951_phase2b_service_permissions.sql` | `F5D38FC2F3413F24CF29393411F947701A16354B2810FB401801A39BE731CE28` | Yes |
| `supabase/migrations/20261116013952_phase2b_system_settings.sql` | `88C5595CCA3EF84A5919002183D33DCEE8D1C60F87DE8CD162D10F639C014BB7` | Yes |
| `supabase/tests/phase2b_read_only_verification.sql` | `A6EB4BEC077AC3ADDF7E8D011C84A88DDA157156CD9A33A4DA964C340451742D` | Yes |

Read the two proposal entries' `statements` arrays from `supabase_migrations.schema_migrations` and compared each statement against the local file in order, normalizing CRLF/LF and decoding transported newline escapes. Only whitespace and statement-separator semicolons were permitted between matched statements and after the last statement. Both comparisons returned **true**; comments and SQL bodies were included. An initial Node inline comparison failed on shell argument quoting; the subsequent PowerShell comparison completed successfully. No comparison helper file was created.

For evidence correlation, PostgreSQL MD5 of the stored statements joined with LF was `93045c24c10f2c701c2fbf2501adbf76` for `...951` and `59acdfb5d037d4a9e655e7cc08863cf2` for `...952`. These are fingerprints of that stored representation, not SHA-256 hashes of original deployed file bytes. Migration history does not establish byte-for-byte original deployment provenance, deployment approval, or absence of later manual schema changes. Historical migration contents were not re-audited or certified against stored SQL.

## CLI target readiness

- Resolved executable: `C:\supabase\supabase.exe`, version **2.111.0**.
- Read current `--help`, `migration list --help`, `db push --help`, `backups --help` and `backups list --help`.
- Workspace `supabase/config.toml` and `supabase/.temp/project-ref` are absent. No implicit linked CLI target is verified. Neither was created.
- Existing `.mcp.json` and `.codex/config.toml` URLs specify Preview with `read_only=true`; MCP scoping does not supply a CLI link.
- The Phase 2B executable under `C:/Users/STR/AppData/Local/npm-cache/_npx/...` does not exist here. Its shown `--remote=...` and `--skip-vault` flags are absent from installed `db push --help`.
- Installed `migration list` advertises `--db-url`, `--linked` and `--local`; installed `db push` advertises those target choices and `--dry-run`. No secure explicit Preview database connection was established for them. No guessed flags, credentials, auto-confirmation or implicit target were used.
- Backup listing supports an explicit project ref. Executed only `supabase backups list --project-ref mgibjusuglafbnlrkbep --output json`, exit **0**. This verifies that operation's target, not a future migration command's target.

Before any later CLI deployment work, establish a supported, securely authenticated, explicitly verified Preview path and inspect the exact installed command behavior. Do not reuse the old command verbatim or upgrade/install/link anything as an implicit part of this preflight. With no pending migrations, there is no migration payload to deploy now.

## Backup and recovery readiness

The Preview-only backup-list response reported region `ap-northeast-1`, `walg_enabled=true`, `pitr_enabled=false`, and an empty `physical_backup_data` object:

| Backup ID | Reported inserted_at (UTC) | Status | Physical |
| --- | --- | --- | --- |
| `2275813299` | `2026-11-15T17:57:02.918Z` | COMPLETED | Yes |
| `2265817177` | `2026-11-14T17:57:02.200Z` | COMPLETED | Yes |
| `2255808906` | `2026-11-13T17:56:58.680Z` | COMPLETED | Yes |
| `2248168760` | `2026-11-13T01:18:19.279Z` | COMPLETED | Yes |

The latest reported backup insertion is approximately **18 hours 43 minutes** before the SQL observation. `inserted_at` is reported metadata, not a proven exact restore boundary. No successful restore, selectable recovery boundary, restore permissions, downtime estimate, or acceptable loss of intervening data was verified. Application time for the two already recorded migrations is unknown, so these backups cannot be certified as the correct immediately-before-change snapshots. PITR is explicitly disabled; do not assume arbitrary timestamp recovery.

Existing local `database-backups` inventory includes `main_before_sync_20261108_183109.dump` (415,350 bytes), `main_schema.sql`, `main_backup_contents.txt`, comparison reports and short main/staging migration CSVs. The saved TOC header dates the archive to **2026-11-08**, with PostgreSQL 17.11 and custom format; the CSVs list only 4 main / 7 staging migrations. These old, main-labelled artifacts are **not verified current Preview recovery backups**. Only local inventory/header/history metadata was inspected; no archive restore, data extraction or Production connection occurred. They do not close the Preview backup gate.

Supabase documents database backups and their recovery limitations, including separate handling of Storage objects: [Database Backups](https://supabase.com/docs/guides/platform/backups). Account plan assumptions do not substitute for the actual project metadata above. Current CLI behavior was taken from installed help; the [CLI v3 changelog](https://supabase.com/changelog/supabase-cli-v3) reinforces the need to verify version-specific targeting rather than transplant commands across versions.

Recovery readiness requires a Preview-specific recovery point with an accepted data-loss window, an authorized operator and tested procedure, preservation of necessary roles/ACLs/migration history, and separate configuration/Storage coverage where relevant. These are outstanding evidence requirements, not actions performed or permission requests in this report.

## Required next disposition

1. Reconcile the already-applied `...951` and `...952` entries with deployment/approval records. Preserve history and existing objects. Do not reapply, rename versions, use `--include-all`, repair history or roll back speculatively.
2. Treat this as an already-deployed state requiring a separately scoped verification decision. The final review's authenticated RLS/PostgREST/audit behavior and deployed-source parity gates remain unresolved by this preflight; history/text parity is not behavioral certification.
3. Establish a suitable recoverable Preview backup and supported explicit CLI target before any future approved change. Do not treat a COMPLETED backup listing as a restore drill.
4. Recheck identity, exact version/name set and hashes immediately before any future authorized operation. Any new migration or changed SQL requires a fresh bounded review and explicit application approval.

**Final disposition: NO-GO for the requested Preview deployment plan; pending migrations = 0. Read-only preflight complete.** Only this report was added to the workspace.
