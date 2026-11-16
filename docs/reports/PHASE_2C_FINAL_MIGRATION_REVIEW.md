# Phase 2C-1 final migration review

Date: 2026-11-16. Workspace: `D:\SAI-College-Production-v2-completion`. Branch confirmed: `feature/v2-completion`.

## Decision

| Migration | Initial finding | Final decision |
| --- | --- | --- |
| `20261116013951_phase2b_service_permissions.sql` | FAIL: provisioning's `overview` reads `classes.program`, but the proposed column grant omitted it. | **PASS — corrected local proposal; static/dependency/security review.** Added only SELECT on `classes.program`. |
| `20261116013952_phase2b_system_settings.sql` | Harden numeric conversion: do not rely on a compound SQL condition to guard a cast on arbitrary text values. | **PASS — corrected local proposal; static contract/security review.** Integer cast now occurs inside a procedural number-type branch. |

PASS means no remaining defect was identified within this read-only/static review. It does **not** mean either migration was executed, PostgreSQL parsed every body successfully, or Supabase authenticated behavior was verified. Approval must refer to the **new checksums below**, not the earlier Phase 2B fingerprints. A disposable execution test and deployed-source parity check remain gates before actual hosted application.

## Scope, Preview and preservation

The first hosted call was `supabase-preview.get_project_url`; it returned exactly **`https://mgibjusuglafbnlrkbep.supabase.co`**. All subsequent hosted calls used only that read-only MCP and SELECT-only catalogs/migration listing. No mutating endpoint, database write, migration execution, GRANT execution, account/role creation, function deployment, Docker, Production connection, Git commit/push/pull/reset/clean/merge/rebase or branch switch occurred.

Read `PHASE_2B_BACKEND_REPAIR_PACKAGE.md`, both exact SQL files, and `phase2b_read_only_verification.sql`; inspected relevant React/Flutter settings and account-service code. Existing uncommitted work was retained. This review did not change application source, UI layouts, Flutter files, MCP configuration, or the 36 historical migration files. It changed only the two proposals, their generator template, focused tests, the SELECT-only verification artifact, and this report. **The generator was not run.** Its template was updated to avoid reintroducing the reviewed omissions if generation is explicitly authorized later.

## Preview metadata findings

- Preview PostgreSQL is **17.11**; 36 deployed migrations end at `20261116013950_learning_scored_exercises`. The two proposals are newer, ordered `...951` then `...952`. All 38 local migration versions are unique.
- All referenced service tables/columns exist, including `classes.program`. SELECT/INSERT/UPDATE column privileges are absent for `service_role` across the 15 inspected dependency tables. Proposed DELETE on `user_roles`/`branch_memberships` is absent too.
- `service_role` has `public` schema USAGE and BYPASSRLS; it is not a superuser. Neither property supplies missing object ACLs.
- All public application tables inspected have RLS enabled. These proposals do not disable or alter any existing RLS policy. The service role intentionally bypasses RLS; its verified Edge Function caller checks remain essential.
- Authenticated already has private schema USAGE and EXECUTE on `private.sai_security_has_role(public.app_role)`. Authenticated EXECUTE on the existing linking RPC is true; service EXECUTE is false. No change is needed to these permissions.
- Both new settings tables, all three new private functions and `sai_settings_audit_writer` are absent. Their CREATE statements therefore have no known name collision. The planned migration principal `postgres` has CREATEROLE and BYPASSRLS; actual ownership-transfer execution remains untested.
- Preview's public-table default ACL for `postgres` includes non-DML rights for service, while INSERT/SELECT/UPDATE/DELETE are missing. Confirmed pre-existing service TRUNCATE/REFERENCES/TRIGGER on `user_roles`, `profiles`, `branch_memberships`; anon/authenticated do not have those rights on these three relations. **This package does not add those service rights.** Do not describe the existing service role as having no other privileges. Restricting them would be a separate reviewed correction, not an unannounced change here.
- The settings migration explicitly revokes inherited/default table/function access from PUBLIC, anon, authenticated and service before adding its intended grants. Schema-specific default ACLs were inspected; no new PUBLIC or anon grant is introduced.

## Full service grant review

Every recipient in the following two tables is database **`service_role`**. Each listed privilege is currently absent in Preview. There are no REVOKEs in the service proposal. No GRANT OPTION is given. No SQL assignment to application user-role rows occurs.

| Relation | Exact SELECT columns | Required by / purpose |
| --- | --- | --- |
| `public.user_roles` | `user_id, role` | manage-roles caller check, directory, summary, grant/revoke checks; provisioning caller/teacher check; linking caller roles. |
| `public.profiles` | `id, full_name, email` | Both main functions' directory/overview/account details; linking account display. |
| `public.branches` | `id, name, is_active` | Role-management staff membership selection; provisioning teacher branch display/notification. |
| `public.branch_memberships` | `user_id, branch_id, is_active` | Role revoke/cleanup; teacher reconciliation; Admin linking branch scope. |
| `public.students` | `id, full_name, admission_no, class_id, user_id, status, branch_id` | Provision overview/validation/workload, summary counts; existing student linking. |
| `public.parent_student_links` | `parent_user_id, student_id, verified_at` | Provision overview and existing parent-link detection. |
| `public.classes` | `id, name, program, branch_id, teacher_id, is_active` | Provision overview including **program**, teacher class assignment/workload; summary counts. |
| `public.academic_sessions` | `id` | manage-roles summary count. |
| `public.learning_courses` | `id, class_id, teacher_id, title, is_active, branch_id` | Teacher ownership/workload/reconciliation and summary. |
| `public.learning_lessons` | `id, is_published, content_path, content_body, content_url, content_kind` | Summary counts and content-completeness predicates; WHERE columns need SELECT as well. |
| `public.learning_lesson_progress` | `lesson_id, status` | Summary progress counts. |
| `public.learning_homework` | `id, course_id` | Teacher workload. |
| `public.learning_homework_submissions` | `id, homework_id, status` | Teacher pending grading and summary. |
| `public.admissions_enquiries` | `id, status` | Summary pending admissions count. |

Read security implication: the existing privileged server credential can read these columns across rows because it bypasses RLS. No browser role receives these grants. These columns were compared with literal selections **and filters** in manage-roles, provision-learning-account and link-student-account, with a regression covering more than 100 references. This source check is not an AST proof of every generated PostgREST query or a deployed-code parity guarantee.

| Relation | Exact write operations/columns | Why necessary / escalation boundary |
| --- | --- | --- |
| `public.profiles` | INSERT and UPDATE `(id, full_name, email)` | Existing merge-upsert includes PK in payload. No phone/locale/delete grant. Privileged service could change these identity-display fields; verified server authorization is required. |
| `public.user_roles` | INSERT `(user_id, role, assigned_by)`; table DELETE | Existing ignoreDuplicates upserts and role revoke. No UPDATE needed or granted. These are deliberately powerful permissions; only the Super-Admin-authorized service may exercise them. |
| `public.branch_memberships` | INSERT and UPDATE `(user_id, branch_id, is_active)`; table DELETE | Merge-upsert, deactivate and cleanup. Includes PK columns because they are present in merge payloads. Cannot change roles, but can alter branch access. |
| `public.classes` | UPDATE `(teacher_id)` | Teacher assignment/removal. No class identity/branch/capacity write. |
| `public.learning_courses` | UPDATE `(teacher_id)` | Corresponding teacher course ownership. No other course edits. |
| `public.audit_logs` | INSERT `(actor_user_id, action, entity_type, entity_id, metadata)` | Existing service audit writes; no SELECT/UPDATE/DELETE. These informational events are not the new trusted settings audit. |

This is the minimum inspected column operation surface for the existing service design. No schema grant, Auth-table grant, sequence grant, RPC EXECUTE, blanket ALL, PUBLIC/anon elevation or financial/student-link mutation grant is added. There is no new SECURITY DEFINER function in the service proposal.

Local service clients use service credentials without forwarding the caller JWT. They separately verify bearer tokens through Auth and read database-assigned caller roles. Linking uses a separate caller-session client for authorized RPCs. These checks remain unchanged. **A leaked service credential is privileged by design; RLS is not an isolation control for this role.**

Existing application risks remain: role grants add staff membership to all active branches; some teacher mutations/audit calls are non-atomic or do not check every response. They were already documented in Phase 2B and were not silently changed. ACL restoration must not be presented as verification of mutation atomicity, email delivery, or account provisioning/link completeness.

## Full settings GRANT/REVOKE review

All settings objects and the dedicated writer role are new, so no existing settings permissions or records are removed. The schema/auth helper dependencies already exist.

| Exact proposed ACL statement(s) | Recipient / object | Security review |
| --- | --- | --- |
| REVOKE ALL, then GRANT EXECUTE | Revoke from PUBLIC/anon/authenticated/service on `private.sai_setting_definition(text,text)`; grant only to authenticated | Immutable literal metadata, no data lookup or elevation. Used by CHECK, RLS and validation. No secret values returned. |
| REVOKE ALL, then SELECT | Revoke from PUBLIC/anon/authenticated/service on `public.sai_system_settings`; grant SELECT to authenticated | RLS limits actual rows to Super Admin or Admin non-sensitive categories. Ordinary and unassigned roles have no matching policy. |
| INSERT/UPDATE `(category,setting_key,value_text)` | authenticated on `public.sai_system_settings` | Super-Admin-only USING/WITH CHECK. Includes PK for existing upsert; trigger prohibits changing identity. No scope/type/actor/timestamp write grant. No DELETE/TRUNCATE. |
| REVOKE ALL | PUBLIC/anon/authenticated/service on `private.validate_system_setting()` | Trigger-only invoker function. No directly callable privileged API. Trigger execution must be checked in the approved replay. |
| REVOKE ALL, then SELECT | Same four revocations on `private.sai_system_settings_audit`; SELECT only authenticated | RLS requires Super Admin. No caller INSERT/UPDATE/DELETE. Private schema must remain unexposed by Data API; no audit read RPC added. |
| Temporary role membership grant, revoked after ownership transfer | `sai_settings_audit_writer` to the migration executor, SET true/INHERIT false | Required for ownership transfer. No membership is granted to application users. Post-apply metadata must show no surviving memberships. Grantor/dependency cleanup must be tested under the real migration principal. |
| USAGE on `private,auth`; EXECUTE `auth.uid()` | `sai_settings_audit_writer` | Required for schema-qualified audit insertion/current actor; no `auth.users` table access. |
| INSERT on `private.sai_system_settings_audit` | `sai_settings_audit_writer` | Append-only writer under INSERT RLS requiring actor=auth.uid(). No SELECT/UPDATE/DELETE, no BYPASSRLS, no login. |
| REVOKE ALL | PUBLIC/anon/authenticated/service on `private.audit_system_setting()` | Prevents callers attaching or directly executing it. Its only elevation is narrowly owned audit insertion. |
| Temporary CREATE on private, revoked after ownership transfer | `sai_settings_audit_writer` | Needed by ALTER FUNCTION OWNER. No persistent schema CREATE. |

No GRANT OPTION, unsafe definer shortcut, caller role mutation, or disabling RLS appears. REVOKE ALL applies only to newly created settings objects, not existing application relations. Temporary writer grants are the only new database-role membership; no new application role is introduced.

## Settings schema, authorization and API compatibility

- Definition allowlist matches the React source: **16 categories / 43 keys**. Categories: general, sessions, notifications, sms, whatsapp, email, payments, printing, cms, backups, languages, currencies, extensions, custom_fields, verification, updates. Each key's type/options/sensitivity matches the checked-in client. Tests compare the complete maps rather than only counts.
- PK `(category,setting_key)` matches React/Flutter `onConflict`. Selected fields remain `category,setting_key,value_text,updated_at,updated_by` (Flutter omits updated_by); save acknowledgement remains `setting_key`. New type/scope columns need no client payload.
- Required columns and checks: bounded non-null value, server-derived value_type, immutable category/key/global scope, current actor FK and timestamp, known-key CHECK. BEFORE trigger supplies server fields before NOT NULL validation. No branch inheritance exists; this is the actual application's global preference API.
- Boolean/enumeration validation is exact; numbers are integer strings in 0–3650, email allows empty optional values but validates nonempty input, website requires HTTPS without embedded credentials, known credential patterns are rejected. Arbitrary text fields are bounded non-executable preferences; they do not become JSON evaluators, plugin loaders or operational configuration automatically.
- No password/API-key/payment-secret/service-key fields exist. Pattern rejection is defense in depth and cannot detect every arbitrary secret pasted into prose. Only non-secret preferences belong in this store; raw settings/audit values must not be dumped into diagnostics.
- Writes require explicit database-assigned `super_admin` for **all** categories. Sensitive reads (`backups`, `extensions`, `verification`, `updates`) also require Super Admin. Admin intentionally retains non-sensitive read-only access. Student, Parent, Teacher, Accountant, Receptionist, Librarian, Content Editor and unassigned accounts have no settings row access. Multiple ordinary roles cannot satisfy the Super Admin write predicate.
- RLS SELECT/INSERT/UPDATE are explicit; UPDATE has both USING and WITH CHECK. Existing private authorization helper is reused, not reimplemented. No settings DELETE policy exists.
- Audit is private, append-only and atomic with the row write; errors are not swallowed. Only the trigger-owned NOLOGIN/NOBYPASSRLS writer can append. Its fixed `pg_catalog` search_path and qualified objects avoid name substitution. Trigger verifies table/schema/timing/row context; no arbitrary SQL is accepted. It cannot update settings or role tables. No-op value merges update stamps but do not fabricate a value-change event.
- No settings rows or fixtures are seeded. Unconfigured values stay absent; no integration is activated. Failed/null backend reads keep React controls unavailable; Flutter already renders an error/retry branch before editing. A successful empty table read means the contract exists and explicit configuration may begin.

SQL review identified no further source error after the corrections. **PostgREST column privilege handling, merge-upsert RETURNING behavior, trigger execution after EXECUTE revocation, audit-writer ownership/membership cleanup, real signed-session RLS and exposure/cache readiness have not been executed or certified.**

## SQL changes and verification artifact

1. Added only `program` to SELECT on `public.classes`. Preview confirms column exists and service SELECT is false. Regression initially failed on this exact missing dependency and passes after correction.
2. Replaced the compound numeric-type/cast condition with nested PL/pgSQL IFs. This makes the cast guard explicit instead of relying on SQL expression evaluation order. No new permission, API or value range was added.
3. Extended SELECT-only verification to inspect audit-role memberships, surviving private CREATE, both settings tables' RLS, anon SELECT and caller DELETE/TRUNCATE denial. These checks do not create rows and return safely when new objects/role are absent.
4. Updated the unexecuted generator template and the prior exact-column test; added `web/tests/phase2c-migration-review.test.cjs` covering version uniqueness/order, destructive SQL absence, function query/filter grant coverage, cast guard and audit-authority cleanup.

## Exact final SHA-256 checksums

| File | SHA-256 |
| --- | --- |
| `supabase/migrations/20261116013951_phase2b_service_permissions.sql` | `F5D38FC2F3413F24CF29393411F947701A16354B2810FB401801A39BE731CE28` |
| `supabase/migrations/20261116013952_phase2b_system_settings.sql` | `88C5595CCA3EF84A5919002183D33DCEE8D1C60F87DE8CD162D10F639C014BB7` |
| `supabase/tests/phase2b_read_only_verification.sql` | `A6EB4BEC077AC3ADDF7E8D011C84A88DDA157156CD9A33A4DA964C340451742D` |

The Phase 2B fingerprints `44776D...` and `C4D76C...` describe superseded contents and must not be used for approval. No migration versions were changed during this review.

## Actual checks and results

| Check | Actual result |
| --- | --- |
| First focused review run | Exit **1**; 11 passed / 1 failed. Found missing `classes.program`. This was a real proposal defect, not a hosted test failure. |
| Focused review rerun after correction | Exit **0**; 12 passed, 0 failed/skipped. |
| `npm --prefix web test` | `WEB_TEST_EXIT=0`; **72 passed**, 0 failed/skipped. |
| `node --experimental-strip-types --test tests/*.test.mjs` | `ROOT_TEST_EXIT=0`; **23 passed**, 0 failed/skipped. |
| `git diff --check` | `DIFF_CHECK_EXIT=0`; line-ending conversion notices only. |
| `node --check scripts/prepare-phase2b.cjs` | `GENERATOR_SYNTAX_EXIT=0`; parses the template script without executing generation. |
| Protected-file hashes | All five unchanged: `.mcp.json`, `.codex/config.toml`, `auto-imports.d.ts`, Flutter lockfile and generated Android plugin registrant. |
| Local PostgreSQL binary availability/version | `initdb.exe`/`psql.exe` exist; `postgres.exe --version` reports **18.7**. No server started. |
| Preview metadata | SELECT-only checks succeeded; identity/migrations/ACLs/dependencies/absence/default ACLs reviewed as above. |
| Type-check/lint/build/Flutter | Not rerun this review: application source is unchanged. Phase 2B results remain historical evidence only. |
| PostgreSQL migration replay / authenticated Supabase tests | **NOT RUN.** No database modified, including local databases. |

These tests are unit/source checks, not full SQL parsing, database behavior testing, JWT verification or live security certification. Existing nine-role/route/inventory regression tests remain passing.

## Isolated local PostgreSQL procedure — prepared, not executed

Feasible after separate approval: the workspace already has a non-Docker PostgreSQL bootstrap/procedure in `supabase/tests/admissions-pg18`. Installed PostgreSQL 18.7 differs from Preview 17.11; prefer a matching PostgreSQL 17 environment for the final compatibility run. PG18 can provide additional syntax/ACL regression evidence, not exact-version proof.

1. Create a **new uniquely named cluster directory** under an approved temporary path. Refuse an existing directory, existing port, inherited connection target or external database URL. Use explicit loopback host/unused port/database/user on every command. Never reuse/reset an existing database.
2. Initialize/start that new cluster only after local database-write/process approval. No Docker. Use the existing minimal Auth/Storage bootstrap as a reviewed compatibility layer; do not claim it emulates Supabase Auth, signatures, PostgREST, Storage API or Edge runtime.
3. Replay the 36 baseline files then the two exact checksum-matched proposals with stop-on-error. Capture ACLs before/after and inspect all new role attributes, grantors, memberships, schema CREATE, function ownership and RLS. Roles are cluster-wide: use one freshly initialized cluster per independent replay, or explicitly adapt/test role reuse. **Do not run the old admissions replay script unchanged**: its selected target and multi-database role adapters do not cover the new writer role/settings contract.
4. With separately approved synthetic local identities, test all nine roles, empty and multi-role combinations, valid/invalid/unknown settings, global-scope and stamp spoofing, identity mutation, INSERT/UPDATE/DELETE denial and trusted audit immutability/atomicity. Simulated `request.jwt.claim.sub` tests validate database policy predicates only; they do not authenticate a signed Supabase token.
5. Validate precise service column grants including denied extra columns, both PK-bearing merge-upserts and ignore-duplicate role upserts, table DELETE scope and existing baseline security suites. Verify text settings do not hit the numeric cast. Test no-op and changed-value audit semantics.
6. Stop only the newly created process, preserve logs and record exact versions/exit codes. Directory cleanup requires checking its resolved path; do not touch any existing PostgreSQL installation/data directory.
7. Separately exercise real PostgREST with approved Preview identities after an approved hosted apply to establish schema exposure, error codes and RETURNING semantics. Plain PostgreSQL cannot supply that evidence or verify email/Auth Admin actions.

## Safe deployment order and approval gates

No command below was executed as part of this review. The safe sequence is:

1. Approve the bounded isolated local validation above, then review successful results. Obtain deployed/local Edge Function source parity and configuration-presence evidence through separately authorized read-only tooling; do not print secret values. If that access is unavailable, explicitly accept/defer the unresolved parity risk.
2. Recheck exact Preview identity, unchanged SQL hashes, 36-migration baseline and object/role absence. Capture pre-apply ACL/ownership/default-ACL evidence. Verify the migration principal can own/grant the targeted objects and complete restricted role ownership transfer.
3. After a separate approval for a Preview-only dry-run, inspect the plan. It must contain exactly `...951` then `...952`, with no other migrations, seeds, role imports, Vault updates or implicit linked target. Do not use include-all or migration-history repair.
4. After explicit approval of the **corrected hashes**, apply service permissions first and settings second, using the existing documented Preview-targeted CLI path and `--skip-vault`. Each file is transactional and intended to run once. This report does not authorize execution, and no `db push` was run.
5. Run SELECT-only post-apply inspection, then only the specifically approved authenticated operations below. No deployment is included. Local web diagnostic improvements require separate publication if wanted on a hosted website; SQL compatibility does not authorize that publication.

### Post-deployment checklist

- [ ] Migration history shows exactly both new versions once; all prior versions unchanged.
- [ ] Column-level service grants exactly match the reviewed matrix; verify negative columns too. Table-level `has_table_privilege` alone may remain false and is insufficient.
- [ ] Existing RLS stays enabled; linking RPC remains caller-authenticated and service EXECUTE remains false.
- [ ] No PUBLIC/anon new access; no caller settings DELETE/TRUNCATE or audit INSERT/UPDATE/DELETE.
- [ ] Audit writer has no login/superuser/BYPASSRLS/schema CREATE or surviving memberships; function owner and pinned search_path match the proposal.
- [ ] Super Admin directory/summary and learning/teacher overviews read successfully. Invalid session 401 and unauthorized caller denial are confirmed with real authenticated identities.
- [ ] Admin reads only permitted settings; all ordinary/unassigned roles denied; sensitive categories and all writes require explicit Super Admin, including multi-role users.
- [ ] Exact existing React read/upsert/select-ack requests succeed for authorized callers; failed writes never show success; Flutter remains compatible.
- [ ] Reject unknown keys, invalid type/range/email/URL/credential patterns, identity/scope/stamp spoofing and unauthorized deletes server-side.
- [ ] Audit insertion/value-change/no-op semantics and audit-failure transaction rollback verified; no direct caller audit forgery.
- [ ] Record environment, identity/roles, timestamp, expected/actual result, HTTP status and audit evidence without tokens/passwords/secret values.
- [ ] Role-grant/account-provision/email operations remain untested unless their exact mutations and recovery are separately approved. Directory success does not authorize or certify these actions.

## Recovery limitations

Both migrations use transaction boundaries, with no DROP/TRUNCATE or existing-row DML. Existing table shapes/policies and all old migration files are unchanged. The new FK/index/trigger objects concern only the empty settings store and new audit store. Installation errors should roll back the transaction; inspect actual history/transaction outcome before retrying. CREATE object/role statements intentionally fail on duplicate names rather than reusing an untrusted object.

Service rollback is a new reviewed forward migration revoking only the exact new column/DELETE grants that were actually added, after comparing any intervening ACL changes. Preserve pre-existing rights. Revocation restores service failures and does not undo separately executed account/role/membership changes. No blanket REVOKE ALL/CASCADE or manual migration-history editing.

Settings recovery should revoke caller writes first while retaining settings/audit data and triggers. Read access can be suspended separately. Do not drop the writer role while it owns its function, or remove the audit path while writes remain possible. Any destructive removal/data archival requires its own approval. Correction of an existing preference should be an authorized audited update, not deletion of history.

## Exact actions requiring approval

1. Disposable local PostgreSQL initialization/start/replay and bounded local synthetic-data policy tests; no existing database reuse.
2. Additional read-only Preview deployment/source/configuration-presence inspection beyond the current MCP's capabilities.
3. Preview-only dry-run, followed by a **separate explicit migration-application approval** for the two corrected file hashes and order. No other pending migration/seed/role/Vault operation.
4. Specific authenticated read/denial verification and, separately, exact settings-save/role/provisioning mutations if desired. No standing permission to create accounts or assign roles is inferred.
5. Any frontend/function publication, Git operation or later recovery migration is separate. Production remains off-limits.

This is a completed static review with corrected proposals, not a claim of executed migration or live isolation verification. PostgreSQL evaluation-order and privilege semantics were checked against [PostgreSQL GRANT](https://www.postgresql.org/docs/current/sql-grant.html) and [expression evaluation](https://www.postgresql.org/docs/current/sql-expressions.html#SYNTAX-EXPRESS-EVAL); project findings are from local source and read-only Preview catalogs.

READY FOR PREVIEW APPROVAL
