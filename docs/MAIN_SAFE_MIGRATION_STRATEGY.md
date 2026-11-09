# MAIN safe migration strategy

**Final verdict: BLOCKED.** This is a strategy, not an executable release.
No connection to MAIN or STAGING, SQL execution, deployment, history change,
or migration-file change was performed for this document. The selected scope
was planning only. Existing snapshots are evidence of an earlier state, not
proof of current production state. Both database behavior and recovery remain
unverified.

MAIN is `aeryusbrulqdxjdynwfh`; STAGING is `tvkohamtxrkppwcfsuex`. The
provided snapshots report MAIN history 001–004 and STAGING 001–007. Version
identifiers do not prove the schema, source bytes, privileges, or side effects.
The [admissions compatibility report](ADMISSIONS_PRODUCTION_COMPATIBILITY.md)
supersedes the earlier readiness report's separate 005 → 006 → 007 deployment
sequence. **Do not use that sequence on MAIN.**

## Decision and non-negotiable gates

- **A reviewed production-specific bundle is necessary under the currently
  known constraints** unless an independently validated, supported alternative
  proves the same invariants. It must not pretend to be historical 005.
- Keep original 001–007 files unchanged. Never execute original 005 against
  MAIN as a standalone committed migration: it replaces MAIN's
  `sai_admissions_prepare()` and can break public submissions. An ordinary
  008 is too late: 005 may commit, and a later migration may fail.
- Do not mark original 005 applied on MAIN. No mechanism has yet been
  demonstrated that reconciles Supabase's normal single history while
  preserving both the historical truth and MAIN's admissions behavior.
  Leave 005 **not applied** in that history. Do not repair, insert, or edit
  `supabase_migrations.schema_migrations` to disguise the difference.
- The proposed separate production runner and its separate ledger below are
  an **engineering design, not an implemented or Supabase-supported feature**.
  They create operational divergence from Supabase's normal runner. Production
  deployment is **NO-GO** until that divergence, provenance, all future
  migrations, operational ownership, backup/restore, and an exit path have
  been approved and tested. If that model cannot be accepted, remain blocked;
  consult Supabase support about an auditable reconciliation strategy.
- Do not apply 006 or 007 incidentally while resolving admissions. Do not
  enable financial write traffic until its own acceptance gate.

## Findings and drift to reconcile

The saved [MAIN schema](../database-backups/main_schema.sql#L349) contains a
trigger function that skips staff authorization and assignee validation when
`sai.public_web_enquiry = 'on'`; `sai_public_admission_submit` sets that flag,
inserts, resets it and returns a reference. Original
[005](../supabase/migrations/005_admissions_session_directory.sql) drops the
conditional behavior by replacing the function. Its session-directory RPC
is useful but does not require replacing the trigger. MAIN's dump also has
the public `sai_submit_application` function which sets JWT claims to a
super-admin identity: it is a separate trust/attribution risk.

MAIN-only differences in the saved
[object comparison](../database-backups/database_objects_comparison.txt)
include admissions public submit/status/history, admissions history/export,
reminders and reminder tables, `sai_directory`, `sai_staff_directory`,
`sai_set_role`, `rls_auto_enable`, an admissions-number sequence and audit
index. The local 004 file defines the directory but the MAIN schema dump does
not. MAIN defaults `application_no` to `SAI-APP-` plus a sequence; local
004 uses an `ADM-` UUID. MAIN's `audit_logs.id` is UUID, matching local 001
on that specific column; other columns and constraints still require
comparison. Do not rebuild or overwrite these objects from historical
migrations.

The staging dump and saved diff reflect attendance/finance objects and
different preparation function definitions. The staging dump is locally
modified; comparison freshness, dump scope and exact applied migration bytes
are **UNVERIFIED**. The MAIN schema dump omits object ACLs and owners, so
grants, memberships, default privileges and security-definer ownership
cannot be inferred from it. Identify **all** remaining drift using fresh,
authorized catalog comparisons before release: functions and overloads,
tables/columns/defaults, types, sequences/values, constraints, indexes,
triggers/event triggers, policy expressions, RLS/FORCE flags, owners, ACLs,
role memberships, default ACLs, extensions, search paths, API settings and
configuration. Protect MAIN-only objects; don't treat textual dump differences
or matching version numbers as a complete diff.

## Public-enquiry security review

Custom GUCs are not authentication tokens. A role able to set
`sai.public_web_enquiry` and reach a privileged write path might bypass the
trigger's branch/assignee checks. Whether an exploitable path exists depends
on grants, RLS, callable `SECURITY DEFINER` routines, role membership, direct
connections and pooling; it is **UNVERIFIED**, not a proven exploit. The
trigger skips checks for both INSERT and UPDATE when the flag is on. Test
arbitrary direct writes, entry-point nesting, exceptions, caller-controlled
settings and reuse of the same transaction/session. Verify that clearing the
flag does not accidentally change an outer caller's intended state.

`sai_submit_application` assigns super-admin JWT claims transaction-locally;
test whether a subsequent operation in the same transaction can retain or
abuse that identity, and verify audit attribution. Review public status and
history exposure, reference unpredictability and abuse protection separately.
Existing `public.audit_logs` self-insert policy means client-provided source
metadata is not proof of an authentic trigger event. Preserve current public
availability while designing a **security-reviewed constrained entry point**;
do not blindly copy the GUC bypass or assume `SECURITY DEFINER` is safe.

## Proposed isolated bundle and truthful history

The following are **exact proposed paths**; none exists or is deployable as a
result of this planning task. They are outside `supabase/migrations` so the
normal Git/Supabase runner must not discover them:

```text
release\main-20261108\
  manifest.json
  0100_main_admissions_directory.sql
  0200_main_attendance.sql
  0300_main_finance.sql
  verify_main_readonly.sql
  test_main_public_admissions.sql
  test_permissions_and_rls.sql
  deploy-main.ps1
```

`0100` should be drafted from the
[review-only directory proposal](ADMISSIONS_SESSION_DIRECTORY_REVIEW_ONLY.sql)
after checking live production signatures, body, ACL and trigger state. It
adds only the authorized active-session directory and does **not** replace
the admissions preparation, submission, audit functions or triggers. Its
fail-if-exists guard is intentional; if a directory exists, compare it and
prepare a separately reviewed path. Include revoke/grant atomically with
function creation. Reconfirm definer owner and untrusted CREATE restrictions.

`0200` and `0300` are new, reviewed **production artifacts** derived from
006 and 007 only after all drift and security findings are addressed.
They must have independent identifiers and hashes, not be falsely labelled
as original 006/007 in Supabase history. They may require changes for actual
MAIN dependencies. The manifest must state source revision, exact SHA-256,
target project, ordered artifacts, dependency expectations, intended
deviations from historical migrations, execution/rollback semantics and
the approved runner version. No copying with the same version identifier
as an existing but different migration.

### Execution model to build and validate

1. Disable or otherwise isolate all Supabase/Git auto-deployment paths that
   could apply `supabase/migrations/005_*` to MAIN. This state must persist
   after this release; merely pausing it during the window is insufficient.
   Establish what GitHub branch/CI targets STAGING and production. Normal
   Supabase tooling may reject a release directory missing recorded
   migrations; do not assume alternate `--workdir` solves this.
2. Build an independently reviewed migration-aware production runner.
   It must verify target using the authenticated management identity plus
   connection endpoint/tenant—not just database name—and abort on unknown
   state, unexpected prior history or artifact hash. Its protected,
   access-controlled ledger must identify actual bundle ID, immutable SHA-256,
   release ID, target, deployment identity and result. Exact schema and
   bootstrap migration must be reviewed before use; they are **not designed
   or implemented yet**.
3. Use a single database transaction per artifact: lock against concurrent
   release runners, check identity and preconditions, execute artifact,
   verify required postconditions, append the *actual bundle ID/hash* to the
   separate ledger, then commit. Failure rolls back both DDL and that record.
   Avoid autocommit windows for new SECURITY DEFINER functions. Verify this
   with failure injection, retry, race and lost-connection tests; detect
   unknown/partial commits and differing checksums. Capture evidence and audit
   records securely. DDL locks, external calls and sequence consumption must
   be accounted for separately.
4. MAIN's Supabase history remains 001–004 and original 005/006/007 remain
   unrecorded there unless actually executed by a truthful, approved future
   reconciliation. The separate ledger records only the distinct bundle
   artifacts that really executed. This is intentionally divergent; it is
   not a claim that the projects share a migration history. Document
   monitoring, access controls, roll-forward, future version selection and
   the **explicit indefinite prohibition** on ordinary MAIN `db push` or
   Git auto-migration until a supported reconciliation is proven.
5. STAGING remains on its own reported Supabase history 001–007. Do not
   re-execute 005 or the MAIN-only patch there. If a staged correction is
   needed, design an independently reviewed forward migration with a new
   timestamp generated by the Supabase CLI and compare its existing state.
   Preserve MAIN-specific behavior only where the relevant entry points
   exist; neither environment is a substitute for the other.

This design deliberately avoids `migration repair`: that command changes
tracking records, not SQL. Neither Supabase's repair guidance nor the
separate-ledger proposal demonstrates safe merging of the two histories.
Re-enabling ordinary migration automation before reconciliation risks
replaying 005. The documented GitHub integration applies pending versions
in order and uses one transaction **per migration file**, not one transaction
for an entire series.

## Finance and attendance prerequisites

`007` needs more than a database login: CREATEROLE, ADMIN authority on the
created role, database/schema CREATE, ability to grant membership with SET
and INHERIT, parent-table REFERENCES, relevant ownership and grant rights,
policy creation and ownership transfer authority. Production executor and
role graph are **UNVERIFIED**. PostgreSQL 16+ can leave an automatically
granted ADMIN membership even after the explicit SET/INHERIT grant is
revoked; check grantors, transitive memberships, effective privileges and
browser isolation. Confirm untrusted users cannot CREATE in searched schemas.

Finance grants column UPDATE on `students.class_id` and `classes.session_id`
for row locking; `WITH CHECK (false)` policies do not override other
permissive policies combined with OR. Test effective access under all roles.
Confirm all six finance tables have RLS **and FORCE**, private schema and
sequence privileges are denied to browser roles, functions have correct
owner/search path, and RPC scope/idempotency/locking works. The current 007
has no payment/refund/waiver/audit immutability triggers; branch consistency
is not uniformly protected by composite foreign keys. Resolve ledger-integrity
requirements before real money is accepted.

006 enables but does not FORCE attendance RLS. Its definer owners may bypass
RLS; verify expected owner behavior and client policy results. Attendance
writes invoke audit and may block if audit fails; `FOR UPDATE`/`FOR SHARE`
locks can affect concurrent admissions/student/class changes.

## Docker-free disposable test design

**No tests were run in this phase.** Native PostgreSQL 17 tools were not
found on PATH during inspection; `supabase.exe` 2.111.0 is present. The
commands below are examples for a later isolated rehearsal, not commands
executed here. Install native tools only through the organization's approved
process. A plain PostgreSQL instance does **not** automatically reproduce
Supabase Auth, roles, extension versions, Data API, connection pooler or
PostgREST JWT behavior. A sanitized production-equivalent fixture and
separately provisioned compatible services are required; do not claim parity
from PostgreSQL-only tests. Never use a real production credential in this
fixture or store credentials in scripts, logs, documents or command arguments.

1. Provision two dedicated disposable environments: MAIN-like with original
   001–004 history and saved production-only objects; STAGING-like with its
   independently captured 001–007 state. Use synthetic data, verified
   roles/`auth.uid()`/extensions/ACLs and RLS. Reproducing a production
   schema from a schema-only dump alone is insufficient. Verify exact
   connection target out-of-band and isolate networking before any writes.
   For full backup recovery rehearsal use a separate approved disposable
   Supabase-compatible target and protected data handling; do not restore
   an untrusted dump or run restore against a shared environment.
2. Check local executables and artifact fingerprints without any database:

   ```powershell
   Set-Location D:\SAI-College-Production
   Get-Command psql, pg_dump, pg_restore, initdb, pg_ctl
   Get-FileHash .\supabase\migrations\004_admissions.sql, .\supabase\migrations\005_admissions_session_directory.sql, .\supabase\migrations\006_attendance.sql, .\supabase\migrations\007_finance.sql, .\docs\ADMISSIONS_SESSION_DIRECTORY_REVIEW_ONLY.sql -Algorithm SHA256
   node --test .\web\tests\admissions.test.cjs
   ```

   Client tests use mocks; they do not prove database authorization. Record
   results for the exact release, do not infer them from earlier runs.
3. Independently verify the disposable cluster and isolate its network.
   The following example is deliberately restricted to a dedicated local
   cluster: before starting it, the provisioner must set the unguessable
   `sai.disposable_cluster_id` in that cluster's protected server
   configuration, and the operator must set the same value in the
   process-local `SAI_DISPOSABLE_CLUSTER_ID` through an approved channel.
   The check does not substitute for inspecting the cluster's provisioning
   record. Explicit connection parameters prevent inherited environment
   variables from selecting a remote target. Do not use a production
   credential. Use a separate reviewed configuration for STAGING-like tests.

   ```powershell
   if ([string]::IsNullOrWhiteSpace($env:SAI_DISPOSABLE_CLUSTER_ID)) {
     throw 'Missing independently verified disposable cluster ID.'
   }
   $conn = @('-X', '-W', '-h', '127.0.0.1', '-p', '55439',
             '-d', 'sai_main_rehearsal', '-U', 'sai_test_operator',
             '-v', 'ON_ERROR_STOP=1')
   $identity = & psql @conn -Atq -c "select current_database() || '|' || current_user || '|' || current_setting('sai.disposable_cluster_id', true);"
   if ($LASTEXITCODE -ne 0 -or
       $identity -cne "sai_main_rehearsal|sai_test_operator|$env:SAI_DISPOSABLE_CLUSTER_ID") {
     throw 'Disposable target identity check failed; no tests run.'
   }
   $tests = @(
     @{ Marker = 'sai.wave1_isolated_test'; File = '.\supabase\tests\admissions_behavior.sql' },
     @{ Marker = 'sai.attendance_isolated_test'; File = '.\supabase\tests\attendance_behavior.sql' },
     @{ Marker = 'sai.finance_isolated_test'; File = '.\supabase\tests\finance_behavior.sql' }
   )
   foreach ($test in $tests) {
     & psql @conn -c "set $($test.Marker) = 'yes';" -f $test.File
     if ($LASTEXITCODE -ne 0) { throw "Disposable test failed: $($test.File)" }
   }
   ```

   These scripts create fixtures and some alter constraints; finance and
   admissions sequences can advance despite rollback. They are **never** to
   be run on MAIN or shared STAGING. Every test uses its marker in the same
   session. `-W` prompts per invocation; configure secure credentials without
   exposing them. If a script lacks required
   fixtures/roles or depends on a production-only RPC, stop and build a
   verified test fixture rather than weakening a guard.
4. Once the proposed runner and bundle actually exist and have been reviewed,
   execute 0100, then 0200, then 0300 on the MAIN-like target using the exact
   future runner and identity; capture its ledger and object diffs. Run an
   independent STAGING-forward rehearsal. Verify each artifact's checksum and
   stop on errors. `psql -1 -f` can test SQL atomicity in a disposable DB, but
   it does **not** implement Supabase history or prove the release runner.
5. Rehearse restore of a recent backup to an isolated compatible target.
   Verify all database data and relevant auth tables, sequences, role/ACL
   coverage, extensions, RLS, customizations, migration history, application
   checks, Storage object bytes and integrations. Record RPO/RTO and test
   duration. An archive TOC/list is not a successful restore.

## Mandatory regression matrix

| Area | Acceptance tests on disposable targets |
|---|---|
| Admissions | Public submissions before/after: valid and invalid input, no active branch/session/creator, identical reference/fields; atomic audit success/failure, status/closed timestamps, same actor; admin/receptionist branch scope, assignee validation, teacher assigned-only reads, unauthorized mutations. Exercise both public APIs. |
| Directory | Super admin and active branch admin/receptionist see only active session IDs/names; anon, unrelated, inactive, wrong branch and null/nonexistent branch denied. Check effective ACL, ownership and direct `academic_sessions` RLS unchanged. |
| Bypass | Set custom GUC from untrusted roles, direct insert/update and all exposed definer entry points; manipulate claims, nested calls, exceptions and connection-pool reuse. No unauthorized write or retained privileged state. If current baseline fails, security remediation is a release blocker, not waived by compatibility. |
| Attendance | Class/branch/session consistency, future date, duplicates, open/closed/cancelled, audit atomicity, authorized teachers/receptionists and student/verified-parent visibility, cross-branch denials, anon denial, concurrent session and roster changes. |
| Finance | Role matrix including anon, teacher, parent, student, receptionist, accountant, admin, super admin and outsider; group/assignment branch consistency; numeric bounds, idempotent retries, cross-key conflicts, partial/overpayment, void/waive/refund/cancel, concurrent double payments/refunds and audit rollback. Verify receipt/sequence behavior and no unexpected direct writes. |
| Security/RLS | Complete owner/ACL/default ACL, member SET/INHERIT/ADMIN paths and `auth.uid()` context; FORCE flags, multiple permissive policies and column grants, definer search paths, public function EXECUTE and Data API exposure. Verify denial and row counts, not only UI controls. |
| Runner | Wrong target and wrong hash abort before mutation; concurrent deployment, forced failure at each boundary, retry, connection loss, rollback, ledger atomicity and crash recovery; prove no original 005 runs and no partial public outage; independently validate STAGING. |
| Restore | Actual restore in disposable target plus functional checks, data/sequence reconciliation and measured RPO/RTO; test failure scenarios and recording of missing role/Storage/config assets. |

## Deployment go/no-go sequence — future operation only

| Gate | GO requires | NO-GO if |
|---|---|---|
| 0 Target & automation | Operators verify intended project/tenant, deployment identity, immutable revision and disable competing automation for MAIN **persistently** until history reconciliation. | Target ambiguous; pending 005 can be picked up; manifest/runner not reviewed. |
| 1 Baseline & security | Fresh drift/ACL/function/trigger inventory matches approved manifest; GUC/claims/public-access risks resolved; production-only objects preserved. | Unexplained drift, missing permissions, suspected authorization bypass, unknown API exposure. |
| 2 Recovery | Recent verified consistent backup, complete scope and successful isolated test restore; RPO/RTO accepted and incident/cutover owners available. | Archive exists but restore/data coverage is unverified. |
| 3 Rehearsal | Exact immutable artifacts, actual runner/identity and both MAIN-like/STAGING-like paths pass all regression/failure tests, history/ledger checks and deployment-time budget. | Any test unrun/failed, history lies, exposed intermediate function, or runner not implemented. |
| 4 Admissions | With release freeze, apply only reviewed 0100 atomically with its truthful ledger record; compare body/ACL/triggers and run approved non-mutating smoke checks. | Unexpected replacement, failed audit/public path, missing ledger record or wrong hash. Stop; do not continue to attendance. |
| 5 Attendance | After separate approval, apply 0200 transactionally and verify schema/RLS/ACL, health and application read checks. | Failure, lock contention, unexpected grants or admissions regression. |
| 6 Finance | After separate approval and privilege verification, apply 0300, inspect owner/role grants/FORCE RLS/ledger, and keep finance writes disabled pending full business acceptance. | Any permission mismatch, integrity or security finding unresolved. |
| 7 Release | Compare catalog and both histories/ledgers; run approved smoke/read checks, monitor logs/API cache and latency; document operator, hashes and evidence. | History divergence is not operationally controlled or monitoring/recovery owner absent. |

The future `deploy-main.ps1` must be implemented and security-reviewed before
it is invoked. **No production invocation command is provided:** presenting a
placeholder as an executable deployment would be unsafe. For future read-only
checks, an authorized operator may use `psql -X -W -v ON_ERROR_STOP=1 -c`
with catalog queries only after verifying the endpoint and authenticating
without exposing credentials. Freeze writes before any invasive remediation.

## Recovery and verification

Before any commit, verify the failing artifact's transaction and separate
ledger entry both rolled back; inspect actual catalog and record outcome.
Earlier committed bundle artifacts remain. Do not assume a failed 0300
reverts 0100/0200. Disable affected features and stop the runner.

After commit, do not delete objects or replay old migrations blindly. Preserve
admissions/attendance/finance writes, audit evidence, receipt/refund numbers,
external payments and current incident snapshot. Prefer a reviewed forward
fix if integrity is retained. If recovery is required, restore to a separate
compatible project first; verify data, users, roles/grants, RLS, configuration,
Storage bytes, external systems, migration histories and new bundle ledger.
Select a cutoff, reconcile transactions after it and decide controlled
cutover versus selective recovery. In-place restore replaces database state,
causes downtime and can lose later writes. No backup has been proven
recoverable until a documented test restore and validation succeed.

## Evidence and sources

Inputs reviewed: [readiness](MAIN_PRODUCTION_DEPLOYMENT_READINESS.md),
[admissions compatibility](ADMISSIONS_PRODUCTION_COMPATIBILITY.md),
[review-only SQL](ADMISSIONS_SESSION_DIRECTORY_REVIEW_ONLY.sql), migrations
[004](../supabase/migrations/004_admissions.sql),
[005](../supabase/migrations/005_admissions_session_directory.sql),
[006](../supabase/migrations/006_attendance.sql),
[007](../supabase/migrations/007_finance.sql), and
[MAIN schema snapshot](../database-backups/main_schema.sql).
At inspection, 005/006/007 SHA-256 were respectively
`B4583CA59440A52C39EDD2401D25430D69ADB054EFBEE3D672974C4F43F5053F`,
`CBFAD5A4A73D03EDDD0F80520905498BEDE46252AEE5CE4D25AE28DF20DD643E`,
`628A7297753F8C062DE0BD7F308DFBB16B7C012C33622C7F95F46B87BFC34B9B`.
Recompute and compare before any future operation.

Official references: [Supabase deployment migrations](https://supabase.com/docs/guides/deployment/database-migrations),
[branching workflow](https://supabase.com/docs/guides/deployment/branching/github-integration),
[backups](https://supabase.com/docs/guides/platform/backups),
[PostgreSQL role attributes](https://www.postgresql.org/docs/17/role-attributes.html),
and [custom options](https://www.postgresql.org/docs/17/runtime-config-custom.html).
