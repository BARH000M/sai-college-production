# Phase 3B-1 — Secure account onboarding

Date: 2026-11-16  
Workspace: `D:\SAI-College-Production-v2-completion`  
Branch: `feature/v2-completion`  
Preview: `mgibjusuglafbnlrkbep`  
Production: `aeryusbrulqdxjdynwfh` — not accessed

## Verdict: READY FOR CONTROLLED PREVIEW DEPLOYMENT REVIEW

The onboarding and role-management changes below are local only. Both confirmed security blockers are fixed in local code (section 9) and all local validation passes. The new SQL migrations remain unapplied proposals. Read-only Preview metadata and catalog queries were performed; no Preview/Production writes, migrations, Edge Function deployments, role grants/revokes, account links, Docker operations, commits, or pushes were performed. **Review gate:** the isolated SQL tests in section 9 could not execute locally (no PostgreSQL binaries; Docker prohibited) and must pass in a disposable database before any Preview application.

Prior authenticated testing remains unavailable. In particular, the System Settings smoke test and real RLS/role enforcement are **NOT TESTED**; local tests are not evidence of authenticated backend behavior. See [Phase 3A authenticated verification](./PHASE_3A_AUTHENTICATED_APPLICATION_VERIFICATION.md) and [Phase 2C post-deployment verification](./PHASE_2C_POST_DEPLOYMENT_VERIFICATION.md).

## 1. Local implementation

| Area | Implemented locally |
| --- | --- |
| Role directory and grant UI | `Roles.tsx` and `roles.ts` display waiting-for-access accounts, email-confirmation and profile status, existing roles, and current branch scope. Role selection requires confirmation; Super Admin grants require a second confirmation. Staff roles require explicit active branch selection. Existing branch memberships may be preselected, but all active branches are not automatically assigned. |
| Server request contract | `manage-roles` validates actions/roles/branch IDs and email confirmation, authorizes the caller as Super Admin, uses a safe error-code allowlist, and sends role changes through the proposed atomic RPC. Service clients disable session persistence, auto-refresh, and URL session detection. |
| Atomic role proposal | [20261116142308_atomic_role_management.sql](../../supabase/migrations/20261116142308_atomic_role_management.sql) is a local, unapplied proposal. It validates actor and branch scope, preserves supported multi-role assignments, prevents duplicate assignments and last-Super-Admin lockout, and records the role change/audit entry transactionally. Function execution is restricted to `service_role`; the RPC is `SECURITY INVOKER` with an empty `search_path`. This is not a claim that the proposal has passed a live or local database execution. |
| Completion feedback | A successful operation reloads the directory rather than optimistically changing a role. Submissions are disabled while busy; Arabic success/error messages are shown. A reload failure is explicitly reported instead of being presented as a successful refresh. |
| Waiting/onboarding | “Check again” reloads the current session and role state without asking for another sign-in. Auth state carries email verification and RLS-visible checks for staff branch membership, student record, verified parent link, and teacher-assigned class. Missing visible links and failed checks are distinguished; notices do not claim that an invisible record does not exist. |
| Profile initialization | Fresh-profile INSERT omits `email`, which the authenticated client is not permitted to write, and initialization failures are surfaced. |
| Regression coverage | Added web tests, Edge Function tests, and isolated SQL/RLS test proposals for role assignment, branch scope, multi-role behavior, audit, confirmation, last-admin protection, onboarding, and account isolation. |

No client-side visibility rule is treated as server authorization. Existing RLS and server authorization remain authoritative. No database privilege or RLS policy was weakened.

## 2. Existing Preview test-account state

The prior SELECT-only Preview check found that all five proposed synthetic accounts exist with profiles and confirmed email addresses. They have no role assignments or active branch memberships. No branches or matching synthetic student records were found; no student-parent links or teacher class assignments were found. This state is carried forward from the prior read-only check; this implementation pass did not query or change hosted data.

| Proposed account | Intended role | Current verified state | Activation constraint |
| --- | --- | --- | --- |
| `e2e-v2-admin@example.test` | `admin` | Account/profile and confirmed email; no role or branch membership | Admin is branch-scoped; no branch is currently available to select. |
| `e2e-v2-teacher@example.test` | `teacher` | Account/profile and confirmed email; no role or branch membership | Requires an approved active branch and separately verified class assignment. |
| `e2e-v2-student@example.test` | `student` | Account/profile and confirmed email; no role; no matching linked student record | Must identify the correct existing student record before linking; role is not enrollment. |
| `e2e-v2-student2@example.test` | `student` | Account/profile and confirmed email; no role; no matching linked student record | Same prerequisite; do not link to the first student or create a synthetic relationship by inference. |
| `e2e-v2-parent2@example.test` | `parent` | Account/profile and confirmed email; no role or verified child link | The intended child and existing student record must be explicitly identified and verified first. |

This is a proposed matrix only. No roles were assigned. Account existence and email confirmation do not prove academic enrollment, teacher assignment, branch authorization, or family relationship.

## 3. Activation plan and approval gates

### Minimum safe sequence

1. **Resolve prerequisites without writing:** an authorized operator identifies the approved active branch for Admin/Teacher tests, the exact existing student record for each student account, the exact child record for the parent, and the classes the teacher may access. Do not infer records from names or account ordering.
2. **Review and approve deployment separately:** review the local migration proposal and the `manage-roles` Edge Function change. Deploying either is not part of this task. The proposal is not applied and the Edge Function is not deployed.
3. **Run one controlled Preview activation only after the prerequisites are known and explicitly approved.** The role grant and any required record-link operation must name the exact synthetic account, intended role, branch/record IDs, and expected result. Never bulk-grant all five accounts.
4. **Verify with read-only checks:** confirm the intended role, exact active branch membership where applicable, exact student/parent/teacher link, and the account’s permitted dashboard/data. Confirm no unrelated roles, memberships, links, or records changed.
5. Proceed to the next account only after reviewing the first result and receiving the required approval for any additional write. Role assignment and academic/family linkage remain separate actions.

### Per-account prerequisites

- **Admin:** explicitly select an approved active branch. The role and branch scope are shared account-level membership state; do not grant broad branch access by default.
- **Teacher:** explicitly select the approved active branch, then assign only the pre-approved classes through the existing authorized workflow. No class assignment was found in the prior read-only check.
- **Each Student:** identify the exact existing student row first, then grant the role and link only that row using the verified linking contract. Enrollment/class access must already be authorized. No matching row was found.
- **Parent:** identify the exact existing child row and verify the family relationship through the authorized workflow before granting/establishing access. No verified link was found.
- Email confirmations were reported present for these synthetic accounts in the prior read-only check; recheck them at the activation time. Do not ask for passwords or tokens.

### Exact approval required for the first controlled test

There is **no currently executable account-activation approval** because the required branch and academic record IDs are not established. Do not use a placeholder ID or create/link a record to make the test pass.

Before any Preview schema/deployment change, obtain explicit approval naming project `mgibjusuglafbnlrkbep` and separately authorizing:

1. Applying the reviewed local migration `20261116142308_atomic_role_management.sql`; and
2. Deploying the reviewed `manage-roles` Edge Function version.

Before the first account mutation, obtain a second explicit approval limited to **one** synthetic account and naming its email, intended role, exact existing branch/record IDs, approved grant/link action, and read-only verification criteria. The approval must not authorize other accounts, role changes, provisioning, or settings writes. Current missing branch/student/link prerequisites must be resolved first.

## 4. Deployment state

| State | Items |
| --- | --- |
| **Implemented locally** | React role/onboarding UX; role client contract; server handler changes; regression tests; SQL migration proposal and SQL test proposals. |
| **Already deployed** | The earlier Phase 2C migrations remain recorded on Preview as documented in the prior verification report. No Phase 3B code or migration from this task is deployed. |
| **Requires Edge Function deployment** | The updated `manage-roles` contract/RPC invocation. No function deployment was performed. Any changes to other linking/provisioning functions would require their own review and approval; this task did not deploy them. |
| **Requires database migration** | The atomic role-assignment RPC and its narrowly scoped execution grant in the local proposal. It has not been applied. |
| **Requires explicit approval for a Preview write** | Migration application, Edge Function deployment, branch creation/changes, role grants/revokes, class assignment, student/parent linking, or any account provisioning. No approval was inferred. |

## 5. Settings and authenticated testing

The required read-only Super Admin Settings smoke test is **NOT TESTED** because an authorized existing Super Admin session was unavailable. No settings were read or saved during this task. The previous Preview report verified the settings database objects and policy/grant structure only; it did not establish authenticated UI/RLS behavior.

The nine-role matrix remains **NOT TESTED** with live sessions, including Admin vs Super Admin, route boundaries, teacher assigned-class restriction, student/parent isolation, and multi-role union behavior. No live HTTP status or post-repair Edge Function result is claimed. Historical pre-repair HTTP 500s remain historical evidence only.

## 6. Automated test results

| Check | Result |
| --- | --- |
| `npm run type-check` | PASS, exit 0 |
| `npm run lint` | PASS, exit 0 |
| `npm run build` | PASS, exit 0; existing chunk-size warnings only |
| `npm --prefix web test` | PASS, exit 0; 77 passed, 0 failed |
| `npx --yes deno@2.5.6 test -A supabase/functions/manage-roles/index_test.ts` | PASS, 1 test passed |
| Deno check of the handler and test | PASS, exit 0 |
| `git diff --check` | PASS, exit 0; checks tracked diff, not untracked files |
| SQL test files | NOT RUN; no database execution or Docker was used |
| Flutter | No Flutter source changed. Prior recorded status: analysis PASS and 48 tests PASS; not rerun. |

An existing Phase 2C web test expected the old migration inventory count. It now asserts that the 38-migration Phase 2C baseline remains intact alongside the new local Phase 3B proposal; the suite passes. Tests validate local contracts and code, not hosted RLS enforcement.

## 7. Remaining blockers and security notes

- Preview deployment prerequisites and approval are outstanding; all Phase 3B implementation is local.
- The absence of a branch, matching student records, verified parent link, and teacher class assignments blocks complete activation of the proposed accounts.
- SQL regression files are unexecuted. The migration and Edge handler require review before deployment.
- No new live security assessment was performed. Prior Phase 2C report items remain separately tracked: mutable `search_path` on `public.sai_library_issue` and `public.sai_library_return`, disabled leaked-password protection, and the reported `postgres` membership in `sai_settings_audit_writer`. They were not changed or revalidated here.
- No claim is made that the deployed Preview function matches the locally modified handler.

## 8. Final stabilization — 2026-11-16

### Git and validation

`git diff --check` initially exited **2**. All reported errors were CRLF line endings against LF in HEAD, not spaces or tabs: `src/portal/components/AppShell.tsx:1-66`, `src/portal/components/WaitingForRole.tsx:1-34`, `src/portal/lib/auth.ts:1-358`, `src/portal/pages/Roles.tsx:1-250`, `supabase/functions/manage-roles/index_test.ts:1-135`, and `supabase/tests/student_parent_access.sql:1-150`. Only those six changed files had line endings normalized to LF; no content was discarded. Final `git diff --check` exits **0**. Git's check excludes untracked files.

Final commands from the root, run after the code fixes:

| Command | Exit | Result |
| --- | ---: | --- |
| `npm run type-check` | 0 | PASS |
| `npm run lint` | 0 | PASS |
| `npm run build` | 0 | PASS; 262 modules, chunk-size warning |
| `npm --prefix web test` | 0 | PASS; 77 passed, 0 failed |
| `npx --yes deno@2.5.6 test -A supabase/functions/manage-roles/index_test.ts` | 0 | PASS; 1 passed, 0 failed |
| `npx --yes deno@2.5.6 check supabase/functions/manage-roles/index.ts supabase/functions/manage-roles/index_test.ts` | 0 | PASS |
| `git diff --check` | 0 | PASS |

These are local automated checks, not SQL execution or authenticated authorization tests. No Flutter source was changed or Flutter checks rerun.

### Confirmed security finding — FIXED LOCALLY in Phase 3B-1B (section 9)

The existing Preview `branch_memberships_update_self_or_super_admin` RLS policy allows an authenticated Admin to update an existing own active membership; its `WITH CHECK` requires only that the new `user_id` is the caller and the caller has the Admin role. The Preview catalog also reports authenticated UPDATE privileges on `user_id`, `branch_id`, and `is_active` (table-level `arw` plus redundant column grants). The only non-internal trigger on the table is an AFTER audit trigger, not a scope guard. **Together, these allow a qualifying Admin to move their own active membership to another existing branch, subject to normal foreign-key/uniqueness constraints**, potentially gaining that branch's Admin access. No exploit was performed, no account was changed; the finding is based on actual deployed policy, column privileges, and trigger definitions. It is pre-existing and was not repaired by the role RPC.

**Resolution:** local migration `20261116151509_branch_membership_write_lockdown.sql` (section 9) — not applied; requires its own review and explicit approval.

### Scoped implementation review and residual risks

- The local `manage-roles` handler validates the authenticated caller's Super Admin assignment, reads email confirmation from Auth, requires a selected active branch for scoped roles, and requires a separate Super Admin grant confirmation. The new RPC validates branch IDs, rejects null confirmations, and serializes its own role mutations with a transaction advisory lock. No role is automatically assigned every branch by this path.
- The role/membership mutation and the explicit `role_grant`/`role_revoke` audit insert are in one PostgreSQL function transaction. This is a source-level assessment only: execution, permissions, rollback on audit failure, and concurrent calls have not been verified against a database.
- A non-staff role revocation previously removed unrelated memberships when no scoped staff role remained. The local proposal now removes memberships only when the revoked role is scoped staff and no scoped staff role remains. Granting a scoped role still **replaces the account-level branch scope**, shared by all staff roles; reviewers must approve the effect on every existing role.
- ~~The last-Super-Admin check counts assigned `super_admin` rows, not accounts that can actually authenticate.~~ **Fixed in Phase 3B-1B (section 9):** the RPC now requires another Super Admin whose Auth account is email-confirmed, not deleted, and not currently banned, checked under the transaction advisory lock. Residual race: an Auth ban/change outside this function's lock between check and commit cannot be serialized by a database lock; documented in section 9.
- The Edge handler now rejects a missing, malformed, or mismatched RPC acknowledgement rather than reporting success; this is an indeterminate outcome, so the operator must refresh before retrying. The client also rejects a missing directory user list instead of showing a false empty state. A focused regression covers each condition.
- Preview's deployed private class/student helper definitions express assigned-class and active-branch restrictions for teachers, ownership for students, and verified relationships for parents. Their OR-composition intentionally permits the union of each legitimately held role, including broader permissions for roles such as Admin. Source/catalog inspection cannot prove effective record isolation; the RLS SQL tests and real sessions remain unrun.
- Existing `provision-learning-account` teacher reassignment also changes account-level memberships, with separate, non-atomic operations; it is not covered by the new RPC or its lock and can affect a multi-role account's other staff scopes. Coordinate its use separately and test its cross-role effects before activation.
- Source scanning found no literal service-role key or `SUPABASE_SERVICE_ROLE_KEY` in browser source. This does not certify every possible build environment or deployed artifact. The new RPC is `SECURITY INVOKER`, has an empty `search_path`, explicitly revokes execution from `PUBLIC`, `anon`, and `authenticated`, and grants it to `service_role`. Preview confirms `service_role` has `BYPASSRLS`; therefore the RPC must be treated as a trusted service-only interface and its actor/confirmation inputs must never be accepted from untrusted callers directly. It does not independently bind `p_actor_id` to a JWT.
- The SQL proposal uses existing role/table/column contracts and the service grants recorded in Phase 2C, but there is no isolated database execution or full runtime privilege verification. It is **not deployment-ready**. Preview currently has no proposed RPC and migration version `20261116142308` is not recorded.

### Preview metadata and dependency order

Read-only identity check returned `https://mgibjusuglafbnlrkbep.supabase.co`; migration history still ends at `20261116013952`. Explicit Preview function metadata reports `manage-roles` **ACTIVE v7**, `provision-learning-account` **ACTIVE v6**, and `link-student-account` **ACTIVE v2**. Metadata does not establish deployed source parity. Current React deployment/version was not independently identified, and the local React changes are not proven deployed.

After resolving the blockers and obtaining explicit approval for each operation, the dependency order is:

1. Review and test the branch-scope remediation and last-usable-Super-Admin protection; verify backups/recovery and the exact Preview target and full pending migration set.
2. Apply the reviewed SQL migration(s) to Preview, including `20261116142308`, only after explicit migration approval and successful isolated tests. Verify function privileges and behavior. No migration was applied here.
3. Deploy the reviewed `manage-roles` Edge Function after its RPC exists, only with separate deployment approval. The existing function can mutate roles outside the new advisory lock during the transition; freeze role changes until the new function is active. Rolling back to the old function likewise loses the new protections.
4. Deploy the reviewed root React UI after the new function: its directory expects branch-scope fields absent from the older contract and fails closed if they are missing. Confirm the deployed UI targets Preview. UI deployment requires separate approval.
5. Only then obtain approval for one named synthetic account and exact role, branch and/or student/child/class IDs; make the approved write, then verify read-only before considering the next account. No activation is authorized by this report.

### Isolated SQL test procedure — prepared, not executed

No `psql`, `postgres`, or `pg_ctl` binary was found on the local PATH; Docker is prohibited. No database was started or contacted for SQL tests. A future operator should:

1. Provision an explicitly disposable, isolated PostgreSQL/Supabase-compatible test database **not connected to Preview or Production**, with the required Auth schemas, roles, RLS, baseline migrations and reviewed Phase 2C grants. Use a uniquely named local test database and verify host, port, database name, and isolation before every command. Never use a hosted connection string or production data.
2. Apply the candidate migration only in that isolated database, then inspect the RPC's owner, invoker setting, `search_path`, execute ACL, and role privileges. Test `anon`/`authenticated` denial and `service_role` execution.
3. In the **same local psql connection**, explicitly set `sai.role_management_isolated_test` to `yes`, then execute `supabase/tests/role_management_atomic.sql` with `ON_ERROR_STOP=1`. The file no longer sets its own guard; the marker must be supplied by the operator. Use an otherwise empty test database with no pre-existing Super Admin assignments, since the last-admin assertion depends on it. Fixtures are in a transaction rolled back by the script.
4. In a separate local test run, set `sai.wave1_isolated_test` to `yes` in that same connection and run `supabase/tests/student_parent_access.sql` with `ON_ERROR_STOP=1`; its transaction rolls back its fixtures. Both files execute writes and must **never** be run on Preview or Production.
5. Add and run isolated negative/concurrency tests for audit-insert failure rollback, simultaneous Super Admin revocations, disabled/unusable remaining admins, null inputs, unauthorized callers, branch tampering, teacher reassignment, student/parent isolation, and multi-role scope. Verify authenticated tests separately; a static source assertion is not a substitute.

For example, after independently verifying an isolated local server, use a single connection for each marker and test (replace `<isolated-port>` with its verified port; do not copy this command for a tunnel or hosted server):

```powershell
psql -X -h 127.0.0.1 -p <isolated-port> -d sai_onboarding_isolated_test -v ON_ERROR_STOP=1 -c "select set_config('sai.role_management_isolated_test','yes',false)" -f supabase\tests\role_management_atomic.sql
psql -X -h 127.0.0.1 -p <isolated-port> -d sai_onboarding_isolated_test -v ON_ERROR_STOP=1 -c "select set_config('sai.wave1_isolated_test','yes',false)" -f supabase\tests\student_parent_access.sql
```

The last-usable-admin and Admin branch-scope fixes are now implemented locally (section 9) with dedicated test files; execution of these SQL tests remains the mandatory pre-application gate.

### Files in the Phase 3B changeset

- React: `src/portal/AppRoot.tsx`, `src/portal/components/AppShell.tsx`, `src/portal/components/WaitingForRole.tsx`, `src/portal/lib/auth.ts`, `src/portal/lib/functionErrors.ts`, `src/portal/lib/onboarding.ts`, `src/portal/lib/roles.ts`, `src/portal/pages/Roles.tsx`, `src/portal/styles.css`.
- Backend proposal and tests: `supabase/functions/manage-roles/index.ts`, `supabase/functions/manage-roles/index_test.ts`, `supabase/migrations/20261116142308_atomic_role_management.sql`, `supabase/tests/role_management_atomic.sql`, `supabase/tests/student_parent_access.sql`.
- Web regressions: `web/tests/auth-onboarding.test.cjs`, `web/tests/role-management.test.cjs`, `web/tests/preview-blockers.test.cjs`, `web/tests/phase2b-backend-package.test.cjs`, `web/tests/phase2c-migration-review.test.cjs`.
- Report: `docs/reports/PHASE_3B_1_SECURE_ACCOUNT_ONBOARDING.md`. Earlier untracked reports remain preserved.

## 9. Final security completion — Phase 3B-1B (2026-11-16)

### Exact root causes

1. **Branch-membership privilege escalation.** Preview's `public.branch_memberships` relacl grants `authenticated` table-level INSERT/SELECT/UPDATE (`arw`), plus redundant column-level grants (`user_id`/`branch_id` INSERT, `is_active` INSERT/UPDATE). Policy `branch_memberships_update_self_or_super_admin` used WITH CHECK `(self AND admin)` without validating the new `branch_id`, so an Admin could retarget their own active membership to any existing branch and inherit that branch's scope. The AFTER audit trigger records but never prevents writes.
2. **Last-Super-Admin protection counted role rows only.** `count(*) <= 1` treats banned, deleted, or email-unconfirmed accounts as protection. `service_role` cannot read `auth.users` (verified: all `has_*_privilege('service_role','auth.users',...)` checks false), so the invoker RPC could not prove usability itself.

### Files changed (this phase)

- **New migration:** `supabase/migrations/20261116151509_branch_membership_write_lockdown.sql` (created via `supabase migration new`; unapplied).
- **Updated migration:** `supabase/migrations/20261116142308_atomic_role_management.sql` (adds `private.sai_has_other_usable_super_admin(uuid)` and replaces the row-count check; still unapplied).
- `supabase/functions/manage-roles/index.ts` — 23514 message now says "last *usable* Super Admin" (Arabic).
- `supabase/functions/manage-roles/index_test.ts` — adds the 23514 revoke → HTTP 409 mapping case.
- **New tests:** `web/tests/branch-membership-lockdown.test.cjs`, `supabase/tests/branch_membership_lockdown.sql`.
- Updated tests: `web/tests/role-management.test.cjs`, `web/tests/phase2c-migration-review.test.cjs` (Phase 2C 38-migration baseline asserted alongside both Phase 3B proposals), `supabase/tests/role_management_atomic.sql` (banned/deleted/unconfirmed Super Admin cases).

### Before / after authorization model (branch memberships)

| Operation | Before (Preview) | After (proposed, unapplied) |
| --- | --- | --- |
| `authenticated` INSERT/UPDATE/DELETE privilege | Table-level `arw` + column grants | Revoked at both levels; SELECT retained |
| UPDATE RLS policy | `..._self_or_super_admin`: self+admin, new branch unchecked | `branch_memberships_update_super_admin`: super_admin in USING **and** WITH CHECK |
| SELECT policies | Self or Super Admin (unchanged) | Unchanged — read-only self-access preserved |
| Server writes | service_role Edge Functions (bypass RLS) | Unchanged — now the only write path |
| Records | — | No data modified; RLS never disabled; no broad grants |

Dependency review before revoking: browser code (`src/portal/lib/auth.ts`, `src/portal/lib/management.ts`) only SELECTs `branch_memberships`; every writer is a service-role Edge Function (`manage-roles`, `provision-learning-account`, `link-student-account`). `anon` and `sai_finance_owner` were never granted writes and are untouched.

### Confirmed SQL privileges (read-only Preview catalog evidence, 2026-11-16)

- `branch_memberships` relacl: `postgres=arwdDxtm`, `service_role=dDxtm`, `authenticated=arw`, `sai_finance_owner=r`.
- Column ACLs: `branch_id: authenticated=a`, `user_id: authenticated=a`, `is_active: authenticated=aw` (all grantor `postgres`); service_role column grants `arw` (from Phase 2C).
- `service_role` has **no** SELECT on `auth.users` (table or the three needed columns); `authenticated`/`anon` likewise. Hence the narrow private definer helper.
- `service_role` has USAGE on `private` schema, so the invoker RPC can call the helper.

### Last-usable-Super-Admin model (after)

- `private.sai_has_other_usable_super_admin(uuid)`: SQL, STABLE, SECURITY DEFINER, `search_path = pg_catalog, public, auth`; returns only a boolean; EXECUTE revoked from PUBLIC/anon/authenticated, granted to `service_role`. Usable = email confirmed AND not deleted AND (not banned or ban expired).
- The invoker RPC checks it under the existing `pg_advisory_xact_lock(831704, 1)`, which serializes all role mutations through this function: two concurrent revokes of the last two usable Super Admins are ordered; the second sees the committed state and fails closed. The actor must itself hold `super_admin` (checked first). No automatic promotion; no auth data exposed to clients.
- Residual, documented: an Auth ban/unconfirm performed **outside** this function between its check and commit cannot be serialized by a database lock. Operational mitigation: ban/suspend operations on Super Admin accounts should follow the same review discipline; a defense-in-depth follow-up could route Auth user suspension through an audited server contract.

### Security tests — real results

| # | Test | Where | Result |
| --- | --- | --- | --- |
| 1 | Admin cannot add themselves to another branch | `supabase/tests/branch_membership_lockdown.sql` | **BLOCKED — not executed** (no local PostgreSQL; Docker prohibited). Static contract assertions PASS (web suite). |
| 2 | Admin cannot modify another user's membership | same | **BLOCKED — not executed**; static PASS |
| 3 | Admin cannot change membership ownership (`user_id`) | same | **BLOCKED — not executed**; static PASS |
| 4 | Super Admin manages an explicitly selected branch via server contract | `branch_membership_lockdown.sql` (service_role block) + `role_management_atomic.sql` | **BLOCKED — not executed**; static PASS; Deno handler test PASS (branch scope forwarded to RPC) |
| 5 | Unauthorized caller cannot invoke role operation | Deno `index_test.ts` (non-Super-Admin → 403, zero RPC calls) | **PASS** |
| 6 | Last usable Super Admin cannot be revoked | `role_management_atomic.sql` + Deno 23514→409 mapping | SQL **BLOCKED — not executed**; Deno **PASS** |
| 7 | Concurrent revocations cannot remove all usable Super Admins | Advisory-lock serialization in RPC; sequential-lock scenario asserted in SQL test design | **BLOCKED — not executed** (requires live DB); design review only |
| 8 | Role operation + audit atomicity | Single-function transaction; audit-count assertion in SQL test | **BLOCKED — not executed**; static PASS |
| 9 | Multi-role does not bypass branch isolation | `student_parent_access.sql` (existing, extended) | **BLOCKED — not executed** |
| 10 | Teacher/Student/Parent isolation intact | same | **BLOCKED — not executed**; Preview policy/helper definitions re-verified read-only (unchanged, super/branch/assigned-class/ownership/verified-link scoping present) |

### Automated validation — real results

| Command | Exit | Result |
| --- | ---: | --- |
| `git diff --check` | 0 | PASS |
| `npm run type-check` | 0 | PASS |
| `npm run lint` | 0 | PASS |
| `npm run build` | 0 | PASS (chunk-size warnings only) |
| `npm --prefix web test` | 0 | PASS — **83 passed, 0 failed** |
| `npx --yes deno@2.5.6 test -A supabase/functions/manage-roles/index_test.ts` | 0 | PASS — 1 passed |
| Deno check (handler + test) | 0 | PASS |
| Isolated SQL tests (`role_management_atomic`, `branch_membership_lockdown`, `student_parent_access`) | — | **BLOCKED**: no `psql`/`postgres`/`pg_ctl` on this machine and Docker prohibited. They are operator-gated (markers must be supplied in-session) and rollback-only. |

### Remaining dependencies before deployment

1. A disposable isolated PostgreSQL environment (Supabase-compatible, Auth schema present) to execute the three SQL test files — **hard gate**.
2. Independent review of both migration files and the `manage-roles` diff.
3. Verified current Preview backup/restore posture before any change (per Phase 2C gates).
4. Existing authorized Super Admin session for post-deploy authenticated verification.
5. Known branch/student/child/class record IDs for the synthetic accounts (still missing — no activation possible).

### Correct deployment order (each step separately approved)

1. Run isolated SQL tests → all pass.
2. Apply `20261116142308_atomic_role_management.sql` then `20261116151509_branch_membership_write_lockdown.sql` to Preview (forward-only; do not reapply history). Verify: RPC/helper ACLs, `authenticated` membership privileges = SELECT-only, update policy = super-only.
3. Deploy updated `manage-roles` Edge Function. Freeze role changes between steps 2 and 3 (old function mutates outside the advisory lock; new UI fails closed against the old contract).
4. Deploy the reviewed React UI (Preview-targeted).
5. Authenticated read-only verification, then — only with named-account approval — the first controlled synthetic activation.

### Preview-only verification steps (post-deploy, read-only unless approved)

1. Catalog: `has_table_privilege('authenticated','public.branch_memberships','UPDATE')` = false; no column-level write grants remain; update policy list contains only the super-admin policy; helper EXECUTE limited to `service_role`.
2. As an authenticated Admin (browser): attempt to update own membership → expect permission denied; confirm own membership still readable.
3. As Super Admin via Role Management UI: grant a scoped staff role with an explicit branch on an approved synthetic account → success + audit row; attempt to revoke the last usable Super Admin → 409 `23514` with the Arabic "last usable" message; confirm directory refresh shows the change.
4. Negative: a second Super Admin session confirms multi-role accounts keep branch isolation (teacher sees only assigned classes in scope).

### Rollback considerations

- The lockdown migration revokes privileges and replaces one policy. Rollback = re-grant `insert, update on public.branch_memberships to authenticated` (table + columns) and restore the old self-update policy — this **reopens the escalation**; prefer fixing forward. No data is touched, so no data rollback exists.
- The atomic migration adds/replaces functions only; rollback = drop `private.sai_has_other_usable_super_admin(uuid)` and restore the prior `public.sai_manage_role_assignment` definition from migration history — but the prior definition does not exist on Preview (the RPC is new), so rollback is `drop function public.sai_manage_role_assignment(...)` plus redeploying the previous `manage-roles` Edge Function version (v7 metadata known). Role changes made through the RPC remain valid data.
- A completed physical backup predating these changes must be confirmed before application (PITR is disabled).

### Precise approval requirements

1. **Approval A (schema):** apply `20261116142308_atomic_role_management.sql` and `20261116151509_branch_membership_write_lockdown.sql` to Preview `mgibjusuglafbnlrkbep`, only after the isolated SQL tests pass.
2. **Approval B (function):** deploy the updated `manage-roles` Edge Function to Preview.
3. **Approval C (UI):** deploy the reviewed Preview-targeted React build.
4. **Approval D (data):** one named synthetic account, intended role, exact branch/record IDs, approved grant/link action, and read-only verification criteria — per account, never bulk.

**Final disposition: READY FOR CONTROLLED PREVIEW DEPLOYMENT REVIEW.** Both confirmed blockers are fixed in local code with passing static/unit/Edge tests; the isolated SQL behavior tests are written but could not run on this machine and are a mandatory pre-application gate. Nothing was applied, deployed, granted, committed, or pushed.
