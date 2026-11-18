# Phase 7-M — complete migration reconciliation checkpoint

**Owner-authorized execution policy — 18 November 2026:** Phase 7-M local reconciliation is **COMPLETE**. Phase 4B is **ACTIVE FOR LOCAL DEVELOPMENT**. Production migration reconciliation and deployment remain pending explicit approval, with `release_ready=false`; unfinished Phase 4B contracts remain excluded from the production manifest. Production NO-GO does not block local development. All 16 phases and 24 settings requirements remain required. Earlier paused-status statements below describe the prior checkpoint.


18 November 2026, Main `aeryusbrulqdxjdynwfh`, repository `BARH000M/sai-college-production`, branch `main`. **Production decision: NO-GO.** Local preparation and isolated tests do not authorize production execution. Phase 4B remains paused. No Docker, additional Git branches, replacement production database, production SQL changes, history repair, reset or hosted function deployment occurred.

## Inventory and refreshed evidence

| Inventory | Exact count / result |
|---|---|
| Local `supabase/migrations/*.sql` | **57**, including **six zero-byte placeholders** |
| Refreshed GitHub `origin/main` migration files | **57**; all 57 local files match GitHub blob bytes |
| Production `supabase_migrations.schema_migrations` | **16** |
| Recorded local versions | **16**; no currently remote-only version |
| Local versions absent from production history | **41**, NOT an apply queue |
| Duplicate migration version numbers | **0** |
| Main public application tables | **47**, all with RLS enabled |
| Latest recorded timestamp | **20261110173506**, 10 November 2026 |
| Local HEAD and refreshed origin/main | `d9e15f3b5680b32323bde29d3f41bd3bf22b4716` before these local edits |

The [complete 57-version matrix](PHASE_7M_MIGRATION_MATRIX.md) records existence, classification, schema/data effects, security effects, dependencies and corrective action for every file. [Machine-readable evidence](../../supabase/deployment/phase7m/evidence.json) adds per-file checksums, GitHub blob comparison, object/function presence, history statement counts, aggregate data observations and hashes of the detailed local catalog captures. [The inventory lock](../../supabase/deployment/phase7m/migration-lock.json) is the reviewed local baseline, not a claim of production installation.

Classification totals: **16 MATCHED, 10 APPLIED BUT NOT RECORDED, 6 NOT APPLIED, 2 PARTIALLY APPLIED, 15 SUPERSEDED, 8 CONFLICTING**. REMOTE ONLY, RECORDED BUT INCOMPLETE and PENDING VERIFICATION have zero rows under the documented retained-contract classification. Conflicts include the six empty candidates and the two historical Main-incompatible finance/settings files; tested substitute packages do not alter those historical sources.

The previous 17 November 40-file report is retained as historical evidence. Refreshing the catalog, grants, dependencies, identity/generated-column flags, history and aggregate state confirms its principal Main findings. The new inventory contains the three recovered Main migrations and fourteen overlapping production candidates. The recovered Main migrations `20261110172940`, `20261110173339`, `20261110173506` match stored SQL after normalizing line endings, boundary whitespace and trailing empty statements only; these are source comparisons, not behavioral certification. Nine recorded migrations still have NULL statement arrays. No recorded migration was proved currently missing its required retained contract; later helper implementations differ deliberately from historical bodies.

Detailed captures remain ignored under `.tmp-main-reconciliation/`; no credentials, production row exports or backups were added to Git. The checked-in Main replay fixture contains schema/function/policy/ACL metadata and synthetic Auth/Storage stand-ins, with no production records. Read-only Management API requests validate the exact Main identity and use read-only transactions; supplemental Main MCP queries returned aggregate finance/catalog checks.

## Migration 007 and finance contracts

`007_finance.sql` exists locally and on GitHub but has no production history entry. Both `sai_finance` and `sai_finance_owner` are absent on Main. Main instead has the six public ledger tables, receipt/refund sequences and public finance RPCs introduced by the alternative public ledger. Existing finance functions are owned by `postgres`; they did not retain 007's restricted owner. **Do not install or mark 007 applied.** It is a superseded private-ledger design, not a missing production prerequisite.

This matters for `20261115051532_finance_scoped_directories.sql` and its copied `20261117202811` candidate: both assume the absent owner exists. The original owner-dependent replay passed in a different historical fixture; it does not prove compatibility with Main. The new [Main finance proposal](../../supabase/deployment/phase7m/01_finance_main.sql) omits those inappropriate owner grants/policies, adds the missing directory contracts and finite-amount constraints, tightens the read predicate and fee-group policy, and preserves the public ledger and existing owner.

The Main replay then exposed an additional security gap: the existing postgres-owned payment/group RPC bodies include receptionist authorization, whereas the intended finance tests require denial. Since their owner bypasses RLS, owner policies would not enforce that denial. The proposal explicitly removes receptionist access in those two RPC bodies. The unchanged negative authorization/payment integrity assertions pass after that correction. No receptionist-payment exploit was executed in production.

Production aggregate finance inspection: one assignment; zero payments, refunds and waivers; zero invalid assignment amounts, duplicate payment keys or assignment/student branch mismatches. These are bounded consistency checks, not a cash-flow audit or financial-data certification. Thirty vocabulary rows, 25 attendance sessions, 73 attendance records, seven settings, eight legacy settings audits and one Storage object remain in the refreshed aggregate evidence. Production inspection was read-only.

## Corrective SQL and deployment routes

The updated [Phase 7-R hash-pinned manifest](../../supabase/deployment/phase7r/main-deployment-manifest.json) has an explicit Phase 7-M `release_ready=false` gate. It continues to use the existing project and executor. The selected route is:

1. Install the disabled mutation-hold mechanism under an independently enforced external write hold.
2. Phase 3B role contract: helper ACL restrictions, deny the legacy role writer, atomic role management, last-admin protection and membership lockdown. This replaces overlapping historical and timestamped role proposals without deleting old audit rows.
3. Phase 3B serialized teacher assignment and verified onboarding packages.
4. Phase 3C own-contact validation.
5. Phase 4A examinations/results.
6. Phase 7-M Main finance correction.
7. Phase 7-M additive settings correction.
8. Refresh mutation guards, activate the authenticated maintenance hold and perform only the separately approved compatible Edge cutover. The executor deliberately leaves the hold active for acceptance and separately approved release.

Existing Phase 7-R recovery, exact-hash owner approval, independent ingress/job containment, clean reviewed source and authenticated acceptance gates remain required. The database hold starts disabled; the external hold must cover the entire package sequence before database activation. Package transactions are separate and cannot make Edge deployment atomic. No automatic production deployment or hold release is configured.

The [settings proposal](../../supabase/deployment/phase7m/02_settings_main.sql) adds typed metadata, immutable identity, credential-pattern checks and a restricted private audit writer. It derives metadata without changing existing values, timestamps, provenance or legacy audit rows. Historical public audit rows remain historical; they are not copied into the new trusted audit. The existing non-HTTPS website value is grandfathered unchanged; inserted or changed website values require HTTPS. It does not activate providers, rewrite URLs or seed settings. All 24 roadmap settings requirements remain in force; metadata validation does not establish provider readiness.

Two **deferred, tested** packages are pinned separately and are not executed by Phase 7-R:

- [03_admissions_remaining.sql](../../supabase/deployment/phase7m/03_admissions_remaining.sql): enrollment/status contract plus only the missing tracking slice. It preserves the stronger Phase 3B link functions and avoids duplicate creation.
- [04_admission_events.sql](../../supabase/deployment/phase7m/04_admission_events.sql): protected status events, after tracking; current-state snapshots only, never backfill trusted history from client-writable audit rows.

These require a separately reviewed public-admissions/`admission-tracking` Edge cutover, because the new endpoint is absent from the approved hosted baseline. Installing the tracking revocations alone could break the current public workflow. Learning completion/scoring and the unfinished Phase 4B assessment package are excluded from the active route. Their absence is reported as backlog, not silently marked complete.

All fourteen `20261117*` production candidate migrations are quarantined from the selected route. Six are empty: `20261117202743`, `20261117202759`, `20261117202817`, `20261117202821`, `20261117202830`, `20261117202835`. They remain preserved for review, are checksum-locked, and cannot be treated as executed work. Neither `supabase db push` nor a broad migration replay is an approved deployment mechanism for this repository state.

## Individual history repair proposals — NOT EXECUTED

Only two grant-only files passed complete effect-specific read-only checks using [the verification query](../../supabase/inspection/phase7m_equivalence.sql):

| Version | Proof | Approval status |
|---|---|---|
| `030` | No table-wide authenticated INSERT/UPDATE, and exact allowed/denied INSERT/UPDATE checks across every admissions column match the file | Proposed only |
| `20261116013951` | All **73** specified service-role table/column privileges already effective; the file contains only GRANTs and transaction boundaries, with no data/schema effects | Proposed only |

Current grant equivalence establishes that these particular scripts would make no effective privilege change at inspection time. It does not establish when or how those grants were installed. No other migration has been cleared for repair merely from table presence or matching function bodies.

After explicit owner approval, validate the linked ref is exactly `aeryusbrulqdxjdynwfh`, rerun the SELECT-only checks against that project immediately before each repair, compare source checksums and preserve the prior history snapshot. The commands below are proposals, one version at a time:

```powershell
# APPROVAL REQUIRED — commands below have not run.
supabase migration repair --linked --status applied 030
supabase migration repair --linked --status applied 20261116013951
```

Inspect history after each approved repair. Counts would move from 16 to 17 and then 18 only if both were individually approved and completed. Do these checks before any package that intentionally changes the same privileges: Phase 3B removes direct service role-table writes, and the enrollment package removes direct status updates. Do not infer equivalence after those changes. Installed CLI **2.111.0** help confirms this syntax; see [Supabase migration repair documentation](https://supabase.com/docs/reference/cli/supabase-migration-repair).

## Packages outside the migrations directory

The executor includes [package tracking SQL](../../supabase/deployment/phase7m/00_package_tracking.sql) inside each selected package transaction. The transaction obtains a deployment advisory lock, checks for an existing package receipt, runs the reviewed package, asserts its postcondition, and writes `private.sai_deployment_packages` before committing. Each receipt binds package ID, source path/hash, manifest hash, Git commit and verification time. Browser and service roles have no ledger access. Source and bootstrap bytes are checked against the manifest again at execution time.

Failure rolls back that package's SQL and receipt together. A lost client acknowledgement is resolved by reading the receipt and inspecting actual schema; retries are rejected, including identical retries, until reconciled. Never record a package merely because its psql process started. Prior successful packages remain committed if a later package fails; keep containment active and investigate. JSONL operational records retain Edge and hold transitions separately. The package ledger is not a fake Supabase migration record; historical files are repaired only using the individually approved equivalence procedure above. Verify ledger contents and source hashes at every future audit.

## Actual validation and limits

The final run identifiers, source hashes and exit codes are recorded in [test results](../../supabase/deployment/phase7m/test-results.json). Executed locally:

| Check | Result |
|---|---|
| Exact inventory, duplicate/missing versions, normalized migration checksums, applied-file comparison with origin/main, dependency graph, manifest hashes | PASS |
| Drift gate negative tests: duplicate, missing file, altered applied checksum, changed manifest/order, closed release gate | **6/6 PASS** |
| Main catalog replay and 3B role/onboarding/RLS/atomicity/preservation | PASS; all nine enum roles exercised |
| Actual executor function: receipt commit, duplicate retry denial, source change after preflight, failed postcondition and transactional DDL/receipt rollback | PASS |
| Additive settings and legacy data/audit preservation; identity, credential and HTTPS denials; trusted audit | PASS |
| Main public finance completion | PASS; role/branch/family isolation, receipts, idempotency, overpayment/refund/void/waiver and finite-amount assertions retained |
| Deferred admissions packages and admissions/tracking/protected-events/student-parent/attendance suites | PASS |
| Concurrent last-admin revocations | PASS; one commit, one SQLSTATE `23514`; survivor verified; unsupported isolation rejected |
| Maintenance authorization, privileged/service/Auth writes, DML/DDL/TRUNCATE containment, recovery and rollback | PASS |
| Portable profile and examination SQL runners | PASS; nine-role/negative cases in existing suites retained |
| Updated executor default read-only dry run | PASS; no database/Edge writes |
| Release validator | Expected FAIL / NO-GO; production not enabled |
| New GitHub workflow execution | NOT RUN remotely; prepared locally, no commit/push or auto-deploy |

Earlier failed iterations were corrected in actual source: sandbox PostgreSQL startup required an authorized retry; the catalog replay omitted sequence ACL restoration; tracking fixtures assumed an otherwise empty branch inventory; student-parent fixtures prelinked accounts before invoking guarded RPCs; attendance fixture staff lacked confirmed email. The real finance authorization failure was corrected in forward SQL. No assertion was removed, failing suite skipped or production privilege relaxed.

The prior Phase 7-R native recovery evidence remains applicable to the unchanged protected archive and recovery tooling: 85 application tables / 860 rows / 355 constraints / 105 functions / 44 triggers / 113 policies were reported verified. It was **not rerun** here. That evidence covers application-scope recovery and earlier maintenance concurrency testing; it does not restore managed Auth/Storage/Realtime/Edge/Cron/Vault services or original role memberships/attributes. The new proposals were tested against refreshed schema/ACL metadata with synthetic records, not a newly restored copy of all production rows. Storage object bytes and authenticated hosted behavior were not tested in this run. No new backup or production restore was performed.

Supplemental read-only inspection identifies the MCP actor as `supabase_read_only_user`, and Main exposes Supautils settings plus the existing postgres-owned `ensure_rls` event trigger. Supabase documents [postgres event-trigger support through Supautils](https://supabase.com/docs/guides/database/postgres/event-triggers). Native superuser tests do not prove every hosted DDL privilege or interception of platform-reserved actors; independent platform/job/ingress containment remains a required gate. No production event-trigger creation or capability write probe was attempted.

## Drift prevention and release decision

[Local validation](../../supabase/tools/validate_migrations.py) and [database CI](../../.github/workflows/database-ci.yml) enforce the complete inventory lock, duplicate detection, the legacy 001–031 sequence including 007, applied migration immutability against the base commit, checksum consistency, pinned package/Edge inputs, ordered dependencies, and rejection of unfinished Phase 4B inputs. CI runs the existing security SQL suites in disposable native PostgreSQL 17 without production credentials or Docker. Exact-byte attributes keep manifest pins stable between Windows and Linux. Pin refresh is an explicit review action, never an automatic CI repair. Repository branch protection/reviewer policy is external and was not changed.

**NO-GO for production.** Required next gates are owner review of the concrete hashes/proposals, current recovery point and Supabase-compatible recovery/containment proof, coordinated compatibility review for hosted writers, the appropriate separately approved cutover, and authenticated nine-role web/mobile acceptance. Existing Flutter/signing/release blockers remain as recorded in the production status report; they were not retested or waived. No production history or baseline has changed. Phase 7-M is a prepared and locally tested checkpoint inside Phase 7; Phase 4B must remain paused until production baseline reconciliation and acceptance are complete.
