# MAIN production deployment readiness

**Verdict: BLOCKED.** Audit date: 2026-11-08. This is a read-only assessment,
not an authorization to deploy. No migration, database test, reset, restore,
push, or migration-history change was performed for this audit.

The reported project IDs are MAIN `aeryusbrulqdxjdynwfh` and STAGING
`tvkohamtxrkppwcfsuex`. The supplied preflight and the saved migration lists
show MAIN at 001–004 and STAGING at 001–007. The saved MAIN schema supports
the reported absence of attendance and finance objects. These are snapshots,
not proof of the current live database or of equivalent migration contents.
The branch-list API currently reports both projects `ACTIVE_HEALTHY` and
`FUNCTIONS_DEPLOYED`; this is not a schema or behavioral verification.

## Executive blockers

1. **Confirmed admissions regression in 005.** MAIN's dumped
   `sai_admissions_prepare()` has a `sai.public_web_enquiry` branch that the
   local replacement removes. It skips staff branch-authorization and
   assignee checks for the public-web path; 005 always performs them. The
   `sai_public_admission_submit()` sets that flag before inserting, so the
   replacement rejects that flow unless its execution context independently
   satisfies the staff authorization check. Reconcile this production-specific
   behavior securely before any deployment. MAIN also has
   admission-related routines, reminder tables and other objects not
   accounted for by 005–007 or the staging comparison.
2. **Recovery is not proven.** A custom-format MAIN archive and its table of
   contents exist, but no successful test restore or data reconciliation was
   found. Coverage of global roles, grants, Storage object bytes, configuration,
   and external integrations is **UNVERIFIED**. Neither an archive listing
   nor the schema-only dump proves recoverability.
3. **Exact-release testing and privilege parity are unverified.** STAGING's
   recorded version 007 does not establish that it executed the current local
   007 text. The actual MAIN deployment executor and its effective role,
   ownership and grant capabilities are unverified. The current migration
   files themselves say they are prepared for review/isolated testing.
4. **No safe production application mechanism has been validated.** Direct
   `psql -f` does not automatically register Supabase migration history.
   The production Git integration, its target, exact revision and atomic
   history behavior must be verified before an eventual deployment.
5. **Application and authorization behavior is unverified on a
   production-equivalent database.** In particular, test the admissions
   replacement, teacher/parent/student isolation, finance RLS and concurrent
   financial operations, as well as deployment-owner and default privileges.

## Evidence and scope

- Audited all migration files [001](../supabase/migrations/001_initial_schema.sql),
  [002](../supabase/migrations/002_security_policies.sql),
  [003](../supabase/migrations/003_staff_management_policies.sql),
  [004](../supabase/migrations/004_admissions.sql),
  [005](../supabase/migrations/005_admissions_session_directory.sql),
  [006](../supabase/migrations/006_attendance.sql), and
  [007](../supabase/migrations/007_finance.sql), in order; 005–007 were
  inspected including routine bodies, policies, grants and dynamic SQL.
- Reviewed [attendance tests](../supabase/tests/attendance_behavior.sql),
  [finance tests](../supabase/tests/finance_behavior.sql), the
  [database-test runner](../supabase/tests/run-wave1-local.cjs), and the
  admissions, attendance and finance client contracts.
- Snapshot evidence: [MAIN schema](../database-backups/main_schema.sql),
  [MAIN migration list](../database-backups/main_migrations.csv),
  [STAGING migration list](../database-backups/staging_migrations.csv),
  [schema diff](../database-backups/schema_comparison.txt),
  [object comparison](../database-backups/database_objects_comparison.txt),
  and [archive TOC](../database-backups/main_backup_contents.txt). The
  MAIN schema dump is dated 2026-11-08 18:57 local; it is not an ACL dump.
  The staging schema dump is locally modified: do not assume the comparison
  was generated from its current bytes.
- Local review revision `1fbf3a94ca6874b9fddb5996f9b6c297c1cf24cc`;
  worktree also had unrelated pre-existing modifications. Hash the release
  files again before use:

  | File | SHA-256 at audit |
  |---|---|
  | 005 | `B4583CA59440A52C39EDD2401D25430D69ADB054EFBEE3D672974C4F43F5053F` |
  | 006 | `CBFAD5A4A73D03EDDD0F80520905498BEDE46252AEE5CE4D25AE28DF20DD643E` |
  | 007 | `628A7297753F8C062DE0BD7F308DFBB16B7C012C33622C7F95F46B87BFC34B9B` |
  | attendance test | `75DF9DCB2457061D02E10D43C721419529848292797F61B7A008DE6A231617FA` |
  | finance test | `A62E71C23799C4BBB6D3EB4845BFC9FCE96950DE9670DBA9D76B7C475D670E87` |

No live SQL query, migration, behavior test or restore was run in this audit.
Earlier session observations are not a substitute for tests of the exact
release on a production-equivalent database.

## Migration-by-migration findings

| Version | Findings and production consequences |
|---|---|
| 001 | Creates `pgcrypto`, `app_role`, profiles, user roles, branches, sessions, memberships, classes, students, parent links and `audit_logs`; references `auth.users` and UUID generation. These foundational objects and types must match, not merely be recorded in history. |
| 002 | Enables RLS, sets grants, creates security-definer authorization helpers and policies. Its guard rejects unexpected public tables; do **not** replay it over a later or divergent schema. The direct authenticated audit INSERT policy permits caller-controlled audit fields; those rows are not authoritative. |
| 003 | Adds `classes.is_active` and `branch_memberships.is_active`, narrow management grants, policies and trigger/audit functions. Later migrations rely on these columns, policy semantics and helpers. Existing policies/columns make blind replay unsafe. |
| 004 | Creates `admissions_enquiries`, grants, policies, indexes, directories, preparation and audit triggers. MAIN's dump contains the table, preparation function and trigger, but production's additional admissions objects mean the full live behavior must be reconciled. |
| 005 | Adds/replaces `sai_admissions_sessions(uuid)` and replaces `sai_admissions_prepare()`. Local 004 and 005 preparation bodies match, but MAIN's saved function differs: it skips staff branch/assignee checks when `sai.public_web_enquiry` is `on`; 005 removes that branch. It also changes the ordering of assignee and active-session checks, potentially changing which error surfaces. Existing function ACLs survive `CREATE OR REPLACE`; 005 does not re-revoke the preparation function. The directory exposes active session IDs/names only after a branch authorization check. This migration immediately changes the live admissions function on success. |
| 006 | Creates two public attendance tables, indexes, RLS policies, narrow grants, three access helpers, two preparation triggers, two audit triggers and class/roster RPCs. Sessions are class/date unique; future dates and inconsistent branch/class/session assignments are rejected. Receptionists may correct existing records but not create them. Audit writes are transactional, and audit failures block attendance writes. Attendance RLS is enabled, **not forced**: owners/BYPASSRLS roles and security-definer owners can bypass it. |
| 007 | Creates a non-login, non-superuser finance owner, private schema, six tables, sequences, FORCE RLS, functions, grants and policies. Temporarily grants SET/INHERIT to the executing role and CREATE on `public` to the finance owner, then revokes those temporary grants. Finance RPCs insert/update financial records and audit rows; issuance consumes nontransactional sequence values. No existing production finance rows are migrated or reconciled. |

`005` and `006` do not issue top-level DML against existing business rows.
`007`'s top-level DDL, grants, policies and ownership changes are persistent
schema/security changes, not merely additions. Future calls perform the
mutations described below.

## Dependency matrix

| Consumer | Required existing objects and columns | Required capabilities / assumptions |
|---|---|---|
| All | Database, `public`, `auth`, `auth.users(id)`, `auth.uid()`, `anon`, `authenticated`, UUID generation via `gen_random_uuid()`/baseline `pgcrypto`, `public.app_role`; trusted `public` search path. | The executor must be able to create in `public`, reference required objects and grant/revoke needed rights. 005–007 abort if PUBLIC, `anon` or `authenticated` can CREATE in `public`. |
| 005 | `branches.id`; `academic_sessions.id/name/is_active`; `branch_memberships.user_id/branch_id/is_active`; `user_roles.user_id/role`; `sai_security_has_role`, `sai_security_branch_member`; 004's admissions trigger and trigger-row columns `branch_id`, `academic_session_id`, `assigned_to`, `status`, `updated_at`, `closed_at`. | Executor can replace existing function it owns and manage its ACL; trusted security-definer owner and baseline trigger must exist. Trigger changes affect subsequent admissions inserts/updates. |
| 006 | `branches.id`, `academic_sessions.id`, `classes.id/branch_id/session_id/name/teacher_id`, `students.id/user_id/branch_id/class_id/full_name`, `parent_student_links.student_id/parent_user_id/verified_at`, `audit_logs.actor_user_id/action/entity_type/entity_id/metadata`; `sai_security_has_role`, `sai_security_branch_member`, `sai_security_can_read_class`, `auth.uid()`. | CREATE table/index/function/trigger/policy; REFERENCES on parent keys; GRANT privileges; trusted security-definer ownership and accessible audit insert. `Asia/Aden` time-zone data and application Data API exposure must be present. |
| 007 | All referenced parent IDs on `branches`, `academic_sessions`, `classes`, `students`, `auth.users`; `students.user_id/branch_id/class_id`, `classes.branch_id/session_id`, `user_roles.user_id/role`, `branch_memberships.user_id/branch_id/is_active`, `parent_student_links.student_id/parent_user_id/verified_at`; `auth.uid()`, UUID generation, PL/pgSQL and `Asia/Aden`. | `CREATEROLE`, database CREATE, temporary SET/INHERIT membership, schema CREATE, ownership/GRANT authority and permissions to create policies and grant SELECT/column UPDATE on existing tables. The migration role must be able to create references to all parents. Check actual deployment identity, not merely an administrative dashboard session. |

Additionally check exact types, nullability, unique/primary keys, triggers,
extension versions and `auth.uid()` implementation; a name match is not a
compatibility check. The finance student/class column UPDATE grants support
row locks; corresponding RLS `WITH CHECK (false)` policies are meant to
prevent updates. Confirm no other permissive policies for the finance owner
make those column grants writable: PostgreSQL combines permissive policies
with OR.

## Security, ownership and permission risks

- **007 requires elevated administrative permissions, but not necessarily
  PostgreSQL superuser.** PostgreSQL 16+ grants a non-superuser creator
  ADMIN but not SET/INHERIT on a new role. 007 explicitly grants itself SET
  and INHERIT before `CREATE SCHEMA ... AUTHORIZATION` and ownership
  transfers. The user must have `CREATEROLE` and ADMIN authority for the new
  role, database CREATE, required object ownership/grant authority, and
  authority to grant CREATE on `public`. It must be able to act with the
  necessary schema privileges while creating and transferring finance
  objects. PostgreSQL rejects owner transfer if these requirements are not
  met. Supabase service executors may differ from the dashboard or STAGING;
  MAIN capability is **UNVERIFIED**.
- The final REVOKE removes the grant made by the migration. On PostgreSQL 16+
  the creator's separate automatically generated ADMIN membership can remain
  with SET and INHERIT false; it can allow that administrator to grant itself
  access again. Do not interpret NOLOGIN or the final REVOKE as protection
  from a database administrator. Inspect all membership grants and grantors.
- Finance owner has NOLOGIN/NOBYPASSRLS and all six finance tables use FORCE
  RLS. Finance functions are SECURITY DEFINER and are transferred to that
  owner; browser roles receive RPC EXECUTE, not direct schema access. Verify
  every owner's identity, every effective ACL, inherited membership, exposed
  schema and RLS policy, including unexpected policies. FORCE does not
  constrain superusers/BYPASSRLS roles.
- 005/006 security-definer routines use `search_path = public`; 007 uses
  `pg_catalog, public, auth`. The untrusted-CREATE guards are necessary but
  not sufficient: verify all writable search-path schemas and function owners.
  Newly created functions default to PUBLIC EXECUTE until revoked; ensure the
  runner actually commits each migration atomically, so intermediate grants
  are not exposed.
- 006 grants authenticated users column-scoped attendance writes subject to
  RLS and trigger checks. Its public audit log is not tamper-proof: baseline
  002 permits authenticated direct audit inserts with caller-supplied
  action/entity/metadata for their own actor ID. A forged `source` field
  cannot prove an event came from a trigger. Finance uses the separate
  `sai_finance.audit_log`; do not conflate the two.
- The checked-in 007 has **no immutability triggers** on payments, waivers,
  refunds or its audit table. Direct browser access is revoked and intended
  mutations go through RPCs, but owners/privileged maintenance users can
  change data. Branch/session consistency for finance relationships is
  enforced in intended RPC paths, not by composite foreign keys on every
  related branch column. Decide whether this is acceptable for the finance
  ledger and add independent protections/tests if required.
- Confirm real authenticated roles and `auth.uid()` context, including
  anonymous sign-ins, revoked users and cross-branch cases. Test API grants
  and Data API exposure independently of RLS.

## Data modification, locks and transaction compatibility

- The 005 trigger replacement changes future admission validation and
  timestamps; no top-level existing admissions rows are updated.
- 006 functions and triggers create/update attendance rows, set actor/time
  fields and INSERT into `public.audit_logs`. Record preparation locks the
  session `FOR UPDATE` and the selected student `FOR SHARE`; this can
  serialize concurrent operations and block related writes.
- 007 RPCs INSERT/UPDATE fee groups, assignments, payments, waivers, refunds
  and `sai_finance.audit_log`; void and cancellation change existing rows.
  `FOR SHARE` on students/classes and `FOR UPDATE` on assignments can
  block concurrent changes. Receipt/refund `nextval()` calls consume sequence
  values even if the surrounding transaction rolls back; gaps are expected.
  Existing production users, students and classes are not backfilled, but
  new policies, column grants, locks and RPC access change their effective
  database security and runtime behavior.
- Dynamic SQL in 007 grants/revokes membership using `format('%I',
  current_user)`. Test and audit scripts also perform inserts and DDL.
  No `DROP`, `TRUNCATE`, top-level business-data DELETE, `CREATE INDEX
  CONCURRENTLY`, `VACUUM`, `CREATE DATABASE`, or other known transaction-
  prohibited operation was found in 005–007. Ordinary indexes and role/DDL
  operations are transactional in PostgreSQL. This is a static conclusion,
  not a substitute for running the exact release with the actual runner and
  verifying its per-migration transaction boundaries.
- Object creation, RLS/GRANT changes and `CREATE OR REPLACE FUNCTION` take
  locks; estimate lock duration and existing long-running transactions during
  the maintenance window. No rollback of an already committed prior
  migration is implied if a later migration fails.

## Schema drift and history

The saved diff is MAIN (`-`) versus STAGING (`+`). The dumped MAIN
`sai_admissions_prepare()` at [MAIN schema line 354](../database-backups/main_schema.sql#L354)
tests `sai.public_web_enquiry`; [005's replacement](../supabase/migrations/005_admissions_session_directory.sql)
does not. This is a concrete behavioral conflict, not a formatting difference.
The dumped `sai_public_admission_submit()` sets the flag, inserts an
admissions enquiry and resets it at
[MAIN schema line 663](../database-backups/main_schema.sql#L663). Under 005,
that insert raises `Not authorized for this branch` unless its execution
context independently passes the staff role/branch check. The separate
`sai_submit_application()` path sets JWT claims instead, so its outcome must
be evaluated independently.
Validate the live definition and preserve the intended public-submission
workflow through a security-reviewed design; do not blindly copy a bypass
without verifying who can set the flag and reach the trigger.

The comparison also lists MAIN-only
admissions history/export/status/reminder and public submission functions,
`sai_directory`, `sai_staff_directory`, `sai_set_role`, and `rls_auto_enable`;
it also shows MAIN-only `admission_reminder_log`, `admission_reminder_runs`,
an admissions sequence and audit index. These are not explained by simply
adding 005–007. The dump confirms MAIN has `admissions_enquiries`,
`sai_admissions_prepare()` and its trigger.

Do not treat every text-diff line as meaningful drift: generated pg_dump
restriction tokens, ordering, dump flags and versions can create noise.
Conversely, no `GRANT`, `REVOKE`, role creation or default-privilege
statements are present in the MAIN schema-only dump, so it cannot establish
ACL or role parity. Refresh separately and compare canonical function
definitions/signatures, owners, constraints, indexes, triggers, policies,
RLS/FORCE flags, ACLs, extensions and settings; explain every difference.
Protect production-only objects and establish whether 005 overwrites any
production customization.

The `schema_migrations` list proves only recorded version identifiers. It
does not prove local SQL equals the originally executed SQL, that each object
exists, or that its definition and privileges still match. STAGING already
recorded 005–007, so pushing modified files under the same versions will not
replay them. Do not silently rewrite applied migration history or insert
history records to make a check pass; establish a reviewed reconciliation
and forward-migration strategy where required.

## Test consistency and coverage

- The SQL tests refer to the current attendance/finance function names and
  columns. The finance test checks non-login/non-bypass owner attributes,
  forced RLS, lack of direct browser access, and absence of SET/INHERIT
  membership for its own `current_user`. That last assertion does **not**
  check a different deployment executor or every membership path.
- Both SQL scripts explicitly create test users and business rows. The
  attendance test additionally alters `public.audit_logs`; its rollback is
  not permission to run it on MAIN or shared STAGING. Finance tests consume
  sequences that rollback does not restore. Use an independently verified
  disposable database only.
- The existing JS runner supports management and admissions only; it is not
  an attendance or finance SQL test runner. Client finance tests mock RPCs,
  so they do not prove database RLS, permissions, history, transaction
  behavior or production integration. No database or application tests were
  executed for this audit. Evidence that tests passed against these exact
  migration hashes and the actual production-equivalent identity is
  **UNVERIFIED**.
- Add/verify tests for unauthorized direct access and helper RPCs; existing
  admissions flows and production-specific functions; concurrent payments,
  idempotency, void/refund/waiver races and locking; audit forgery and
  append-only expectations; grants to other roles; user deactivation and
  cross-branch/student/parent isolation.

## Required corrections before release

1. Correct the confirmed 005 conflict with the production public-web
   admissions path and test authorized and unauthorized paths. Reconcile and
   document all unexplained MAIN/STAGING drift against the current live
   catalog and the original executed migrations. Preserve production-only
   admissions and reminder behavior and confirm ACL effects.
2. Freeze an immutable release revision and hashes. Determine whether the
   staged 007 is identical to this local 007; if not, use a reviewed
   forward-compatible correction and test the actual upgrade path as well as
   a fresh database. Do not edit an applied migration as a substitute for
   migrating existing databases.
3. Prove the actual production executor's capabilities and role membership;
   verify post-deployment revocation and no unexpected effective writes to
   existing student/class columns. Resolve security and financial-integrity
   concerns, including audit trust, before enabling finance.
4. Obtain an appropriate, recent consistent backup and demonstrate a restore
   to an isolated compatible target. Verify data, constraints, owners, ACLs,
   roles, migration history, auth, Storage metadata and external object
   coverage; record measured recovery time and acceptable data loss.
5. Rehearse exact migrations, behavior tests, failed-migration rollback,
   deployment history and recovery on disposable production-equivalent
   infrastructure. Resolve all failures; do not run the SQL test scripts on
   production or shared staging.
6. Confirm a single Docker-free, migration-aware deployment mechanism and its
   target, transaction and history behavior. Disable or coordinate competing
   GitHub automation before any release action.

## Ordered Docker-free deployment procedure

**Future procedure only; none of the following was executed during the audit.**
Proceed only after all blockers above are resolved. Never paste passwords or
connection URIs into the report, shell history, command arguments, or logs.
Use PostgreSQL 17-compatible Windows `psql`, `pg_dump`, `pg_restore`, and a
secure interactive credential prompt or approved secret manager. Verify TLS,
host, tenant, project reference and environment through the Supabase
Dashboard; `current_database() = 'postgres'` alone does not identify a project.
The native PostgreSQL executables were not found on PATH during this audit;
availability is **UNVERIFIED** on the future operator's host.

1. Freeze deployment automation, obtain maintenance window and owner/contact
   list, identify active clients and define stop/rollback criteria. Review
   Supabase Git integration: a push to its configured production branch can
   deploy migrations automatically. Do not push merely to test.
2. Confirm project/endpoint identity out of band and compare baseline state:
   migration history, all expected definitions/owners/ACLs and RLS, absence
   of collisions for new objects, all dependencies, privilege guards,
   long-running transactions, and production-only drift. Example read-only
   PowerShell commands, after connection parameters have been set by the
   operator without putting passwords on the command line:

   ```powershell
   Get-Command psql, pg_dump, pg_restore
   Get-FileHash .\supabase\migrations\00*.sql -Algorithm SHA256
   psql -X -W -v ON_ERROR_STOP=1 -c "select current_database(), current_user, session_user, version();"
   psql -X -W -v ON_ERROR_STOP=1 -c "select version, name from supabase_migrations.schema_migrations order by version;"
   psql -X -W -v ON_ERROR_STOP=1 -c "select rolname, rolsuper, rolcreaterole, rolbypassrls from pg_roles where rolname = current_user;"
   psql -X -W -v ON_ERROR_STOP=1 -c "select has_database_privilege(current_user,current_database(),'CREATE') as db_create, has_schema_privilege('public','public','CREATE') as public_create, has_schema_privilege('anon','public','CREATE') as anon_create, has_schema_privilege('authenticated','public','CREATE') as authenticated_create;"
   psql -X -W -v ON_ERROR_STOP=1 -c "select to_regnamespace('sai_finance') as finance_schema, to_regclass('public.attendance_sessions') as sessions, to_regclass('public.attendance_records') as records, exists(select 1 from pg_roles where rolname='sai_finance_owner') as finance_owner_exists;"
   ```

   The final three CREATE checks should be false; db CREATE and CREATEROLE
   alone do **not** establish all 007 grant/ownership privileges. Capture
   catalog snapshots securely; stop on unexpected results, permissions,
   objects, function overloads or unexplained drift.
3. Take a consistent backup with approved retention and protected storage;
   enumerate archive contents with `pg_restore --list` and hash it. Separately
   account for role definitions/memberships, secrets and Storage object bytes
   without exposing credentials. Test restore into a dedicated compatible
   disposable environment, verify data and restore-time capabilities, and
   record RPO/RTO. Do not restore into production as a preflight.
4. Rehearse on an isolated production-equivalent database with the intended
   executor. For an explicitly verified **disposable** target only, native
   `psql -X -W -v ON_ERROR_STOP=1 -1 -f <migration-file>` can test each file
   in order. It does **not** update Supabase migration history. Run the
   attendance and finance scripts only there, with their documented
   `sai.attendance_isolated_test` / `sai.finance_isolated_test` markers set in
   the same session; review their DDL and sequence effects first. Compare
   result, security catalog and application behavior with MAIN requirements.
5. Select one proven migration-aware hosted deployment runner, for example
   the configured Supabase Git integration, after verifying the exact project,
   release commit, executor and history semantics. Arrange for it to apply
   **005, then 006, then 007** in separate atomic migrations and record
   matching history. Monitor each migration and stop after any failure. Do
   not combine direct `psql -f` against MAIN with an unaware automated runner;
   raw psql execution leaves Supabase history unrecorded.
6. Keep traffic/feature exposure controlled until post-deployment checks
   pass. If a failure occurs, identify which migrations committed, compare
   actual catalogs and history, and follow the recovery decision below.
   Do not assume a failed 007 undoes committed 005 or 006.

## Post-deployment verification

Using a confirmed MAIN connection and read-only catalog queries:

1. Verify migration versions 001–007 and the deployment log/release hashes;
   compare object definitions to the reviewed release rather than trusting
   history. Confirm production-only admission functions/tables still exist.
2. Check 005's function body, trigger attachment, owner and EXECUTE ACL;
   compare admission functionality before and after the change.
3. Confirm both attendance tables, columns, unique constraints, indexes,
   four triggers, RLS enabled, policies, column grants and function owners.
   Validate PostgREST schema visibility. Use approved non-mutating API checks
   on production; exercise write and denial tests only in disposable test.
4. Confirm the finance schema owner, six tables, sequences, all RPC
   signatures, definer owners, RLS enabled **and forced**, policy predicates,
   browser schema/table/sequence denials, temporary public CREATE removal
   and all grants/memberships including separate ADMIN grants. Example:

   ```powershell
   psql -X -W -v ON_ERROR_STOP=1 -c "select n.nspname, c.relname, c.relrowsecurity, c.relforcerowsecurity, pg_get_userbyid(c.relowner) as owner from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='sai_finance' and c.relkind='r' order by c.relname;"
   psql -X -W -v ON_ERROR_STOP=1 -c "select r.rolname as member, g.rolname as grantor, m.admin_option, m.inherit_option, m.set_option from pg_auth_members m join pg_roles r on r.oid=m.member join pg_roles g on g.oid=m.grantor where m.roleid='sai_finance_owner'::regrole;"
   psql -X -W -v ON_ERROR_STOP=1 -c "select has_schema_privilege('authenticated','sai_finance','USAGE') as browser_usage, has_schema_privilege('sai_finance_owner','public','CREATE') as owner_public_create;"
   ```

   Expect six finance tables with RLS and FORCE true; `browser_usage` and
   `owner_public_create` false. Review all role memberships, including
   indirect memberships and the actual migration executor; automatic
   ADMIN-only membership may remain. A true superuser automatically passes
   many privilege checks and needs separate interpretation.
5. Check health, logs, Data API schema cache, admissions reads, authorized
   attendance reads, finance reads, latency, lock contention and unexpected
   authorization errors. Test positive/negative write flows and financial
   reconciliation in the disposable environment; production smoke writes
   require a separate controlled business process, not these SQL fixtures.

## Backup and recovery considerations

The existing archive
`database-backups\\main_before_sync_20261108_183109.dump` is approximately
415 KB; its TOC identifies PostgreSQL/pg_dump 17.11, 567 entries and includes
public, auth, storage metadata and migration-history table data entries.
The listing does not establish row counts, successful restoration, global
roles, credentials, object ACLs, storage files, external integrations, or
restore compatibility. The schema-only dump is not a data backup. Whether
automated backups/PITR are enabled, retention and latest recovery point are
**UNVERIFIED**. Supabase notes that database backups do not include Storage
object bytes and that custom role passwords require separate handling.

If failure occurs **before commit**, confirm the runner actually rolled back
the failed migration, including role/grant changes; prior committed
migrations may remain. Keep application access gated, collect logs and
catalog/history evidence, and correct forward after review. If the database
has accepted real attendance or financial writes, do not blindly drop new
objects or replay the archive: preserve and reconcile those records, receipt
numbers, audit events and external payments.

For a serious post-commit incident, freeze writes, capture a fresh incident
snapshot and coordinate the database owner, finance and application teams.
Prefer a reviewed forward fix if it preserves data. Otherwise consider
point-in-time or backup restoration **to a new isolated project first**,
validate users/data/roles/privileges/configuration and compare the lost-write
window. Any in-place restore replaces database state and incurs downtime/data
loss; decide cutover or selective recovery only after reconciling changes,
Storage bytes and external systems. Restore time, recoverability and the
appropriate RPO/RTO remain **UNVERIFIED** until a full test succeeds.

## References

- [Supabase deployment and migration guidance](https://supabase.com/docs/guides/deployment/database-migrations)
- [Supabase GitHub branching deployments](https://supabase.com/docs/guides/deployment/branching/github-integration)
- [Supabase backups and PITR](https://supabase.com/docs/guides/platform/backups)
- [PostgreSQL 17 role-creation membership semantics](https://www.postgresql.org/docs/17/role-attributes.html)
- [PostgreSQL CREATE SCHEMA authorization requirements](https://www.postgresql.org/docs/17/sql-createschema.html)
- [PostgreSQL psql](https://www.postgresql.org/docs/17/app-psql.html)
