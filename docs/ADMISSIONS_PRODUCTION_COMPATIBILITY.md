# Admissions production compatibility: review-only proposal

**Status: BLOCKED — not deployment-ready.** This phase proposes a narrow
session-directory patch and a regression plan. No connection to MAIN or
STAGING, database test, migration, deployment SQL, Docker operation, or
migration-history change was performed. Historical migrations were not
modified. The source of MAIN behavior below is the saved schema dump, not a
fresh catalog query.

## Deliverables and intended scope

- [Review-only SQL proposal](ADMISSIONS_SESSION_DIRECTORY_REVIEW_ONLY.sql):
  creates the session-directory RPC, without replacing the preparation,
  audit or public-submission functions and without changing their triggers.
- [Existing admissions SQL regression suite](../supabase/tests/admissions_behavior.sql):
  staff/directory tests for an explicitly disposable database; it does not
  cover the production-specific public RPC.
- The regression matrix below specifies additional public-enquiry and
  authorization tests. It is a test plan, not evidence that these tests ran.

This is **not** a migration file and is deliberately outside
`supabase/migrations`. It must not be executed or automatically picked up as
part of this task. It is a proposed building block for a future, independently
reviewed forward-only release; it does not solve migration bookkeeping or
claim that the pre-existing admissions design is secure.

## Precise behavior difference

In the saved [MAIN trigger function](../database-backups/main_schema.sql#L349),
`sai_admissions_prepare()` checks `sai.public_web_enquiry`. When the setting
is `on`, it skips both staff branch/role authorization and assignee
validation. Otherwise it requires a super admin, or an active branch member
with admin/receptionist role, and checks changed/new assignees are active
staff in the same branch. It always validates a new/changed session is active
and maintains `updated_at` and lifecycle `closed_at`.

The saved [public website RPC](../database-backups/main_schema.sql#L624)
validates inputs, chooses an active branch/session and super-admin creator,
sets the flag, inserts an enquiry, clears the flag and returns its reference.
The [audit trigger](../database-backups/main_schema.sql#L320) writes the
admissions event on insertion/update; the two trigger attachments appear at
lines 1447 and 1454 of that dump.

[005](../supabase/migrations/005_admissions_session_directory.sql) replaces
the trigger function with the local 004 logic, which does not inspect the
flag. It unconditionally requires staff authorization and then validates
the session before validating the assignee. Thus an anonymous website RPC
without independently satisfying staff checks reaches the trigger and fails
with `42501`, `Not authorized for this branch`. Staff behavior is broadly
similar, but when multiple fields are invalid, the error order can change.
`CREATE OR REPLACE` keeps an existing function's owner and ACL, but changes
its implementation; the production trigger remains attached. The separate
`sai_submit_application(...)` manipulates JWT claims to a super-admin identity;
its behavior and security must be tested separately, not assumed equivalent.

The local [004](../supabase/migrations/004_admissions.sql) already defines the
session directory, but MAIN's saved schema does not. This is a material
example of why version 004 in the history is not proof of local-004 parity.
The saved STAGING schema does define the directory and the 004/005-style
trigger. The local staging dump was modified before this work; saved schema
and comparison can be stale and omit owners/ACLs. Reconcile actual deployed
definitions, signatures, triggers, privileges and historical checksums before
selecting a release path.

## Why the proposal preserves behavior

The proposed SQL copies the 005 directory semantics: an existing branch and
super-admin, or active branch membership plus admin/receptionist role, are
required; only active session IDs and names are returned in name/ID order.
The directory does not broaden the table's ordinary `academic_sessions` RLS.
The proposal creates a new function rather than `CREATE OR REPLACE`, failing
closed if an exact-signature function already exists. It checks for expected
production routines and enabled trigger attachments and refuses untrusted
CREATE on `public`, then revokes default function EXECUTE from PUBLIC/anon
and grants it to authenticated.

Those checks are **not a proof of compatibility or security**: they do not
compare function bodies, complete ACLs, RLS policy, trigger event masks or
roles, and the same-named functions could differ. Before any future
application, separately compare exact catalog definitions and effective
privileges with an approved baseline, ensure the function owner can read the
intended rows and is trusted, verify all search-path schemas, and verify
schema exposure and `auth.uid()`/helper semantics. The runner must wrap
creation and revoke/grant in **one transaction**; an autocommit invocation
could expose the default PUBLIC EXECUTE grant before revocation. No transaction
wrapper is included because the eventual migration runner must own and verify
the transaction boundary.

The patch does not touch the website function, trigger, policies or audit
function; preserving them is a narrow compatibility strategy, **not an
endorsement of the existing bypass**:

- Custom PostgreSQL settings are not inherently authenticated capabilities.
  An untrusted role with a way to set `sai.public_web_enquiry` and perform a
  relevant write may exploit the bypass, depending on actual RLS, grants,
  callable definer functions and connection paths. Whether such a path exists
  is **UNVERIFIED**. Test it on a disposable clone and independently review
  database and API exposure.
- The second website RPC sets request claims to a super-admin context; audit
  attribution and unintended privilege or claim leakage require separate
  review. The schema dump does not establish effective function ACLs.
- PUBLIC/authenticated INSERT privileges on `audit_logs` in the baseline can
  make client-supplied events forgeable; trigger-generated audit rows must not
  automatically be treated as an immutable or authoritative ledger.

If existing bypass or claim-impersonation behavior is unsafe, a security-
reviewed redesign with a constrained trusted entry point and explicit
authorization should replace it. Do not copy the bypass into a new function
or claim that this directory-only patch fixes that risk.

## Forward-only ordering and history — unresolved gate

MAIN is reported at 001–004; STAGING is reported at 001–007. Standard
Supabase branching processes unapplied migration files in order, and runs each
file in its own transaction. Therefore:

1. Adding a normal `008` after existing `005` **does not prevent the MAIN
   outage**. MAIN would first commit 005's incompatible trigger; 006/007 or
   an eventual corrective migration might fail, leaving the public path broken.
   Even if 008 eventually restores behavior, the interval between commits is
   unsafe. Never rely on later repair or on history matching as proof.
2. The supplied proposal is a **MAIN-specific deployment patch design**, not
   an executable end-to-end migration-history strategy. It assumes the
   directory is absent and deliberately raises if it exists. STAGING already
   has the directory in the saved dump; this exact SQL cannot be applied there
   unchanged. A future STAGING-forward migration must independently compare
   the existing RPC/ACL and preserve its own intended trigger behavior; it
   must not blindly install MAIN's public bypass.
3. Before any release, establish a supported, migration-aware reconciliation
   strategy that retains immutable historical files, does not falsify 005's
   execution, prevents automated replay of 005 on MAIN, and preserves correct
   history on both projects. A reviewed baseline/independent deployment
   stream, or a runner proven to atomically execute the approved equivalent
   of 005 and the required reconciliation without exposing an intermediate
   broken state, may be evaluated; none is demonstrated here. Do not insert
   history rows, repair history, delete/rename old files, or use raw `psql`
   to imply that 005 was applied. A production-safe release remains blocked
   until the concrete mechanism, artifact, transaction and history behavior
   are proven against disposable MAIN-like and STAGING-like targets.
4. On STAGING, version 005 will not rerun merely because its file is changed.
   The exact deployed function body/ACL and original migration content are
   **UNVERIFIED**. A new reviewed forward migration must be tested against
   that actual state if a change is required. Do not alter existing history.

Coordinate any Git integration so a push cannot automatically replay 005 on
MAIN before this gate is solved. Do not deploy attendance/finance as an
incidental consequence of the admissions work.
This ordering constraint supersedes the earlier readiness report's proposed
separate 005 → 006 → 007 sequence; that sequence must not be used as written.

## Regression test plan

### Environment and fixtures

Run database cases only on a verified **disposable isolated PostgreSQL /
Supabase-compatible database** with MAIN-like schema, ACLs, authenticated and
anonymous roles, production-specific RPCs, trigger bodies and policies.
Do not run the SQL test suite against MAIN or shared STAGING. Reproduce the
real API/PostgREST role switching and JWT claims; a raw superuser query cannot
prove API authorization. Capture the function definitions, owners, trigger
attachments, effective privileges and policy snapshot before/after. Use
synthetic data only. Construct two branches, two active sessions and an
inactive session; super admin, branch-A admin/receptionist, assigned teacher,
branch-B staff, inactive member and unrelated authenticated user. Ensure a
known valid creator and deterministic website branch/session selection, and
test no-active/no-owner cases on separate disposable fixtures.

The existing SQL suite requires its `sai.wave1_isolated_test` marker in the
same session. It inserts test users/rows, changes an audit constraint and
rolls back; it is not safe for a shared database and is not sufficient for
the MAIN-only RPC. Sequence values and external effects are not guaranteed
to roll back. Add dedicated executable public tests only after the actual
production ACL and identity behavior have been captured; do not make them
silently skip a missing public RPC.

### Database/API cases to implement and run on disposable targets

| ID | Setup and action | Required assertion |
|---|---|---|
| P1 | Anonymous API call to `sai_public_admission_submit` with valid name, phone, email and message on MAIN-like baseline, then after proposed patch. | Both calls succeed with nonempty unique references; exactly one new enquiry per call has expected website source, selected branch/session, initial status, creator and sanitized fields. Function remains accessible only to intended roles. |
| P2 | Anonymous public calls with invalid/short name or phone, malformed email, >500-character message, no active session/branch, no creator. | Same documented error class/message as baseline; zero enquiries and audit rows per failure. |
| P3 | Capture row and audit state for P1, then force a controlled audit failure on disposable target. | One legitimate trigger audit entry per successful insert, expected entity/status metadata and baseline actor attribution; audit failure aborts entire insert and returns an error. Check whether null actor is permitted rather than assuming it. |
| P4 | Call `sai_submit_application` with valid/invalid synthetic data; inspect downstream authorization and audit context before and after. | Same intended results and actor attribution as baseline; confirm transaction-local claims do not give a subsequent unrelated operation unintended authority. |
| A1 | Super admin and branch-A admin/receptionist insert, update, reassign to active branch staff and transition open/closed statuses. | Existing scope, row counts, `updated_at` and `closed_at` transitions and audit events match MAIN baseline, including updates to unchanged historical inactive sessions. |
| A2 | Attempt inactive/missing session, change to inactive session, inactive or cross-branch assignee, cross-branch admin/receptionist operation. | Denied with the expected constraint/authorization error or zero-row RLS result; no partial mutation or audit event. Compare ordering when both assignee and session are invalid. |
| A3 | Assigned teacher and unassigned teacher, inactive member and unrelated authenticated users select/update/insert. | Existing assigned-teacher read behavior remains; no unauthorized read or write, respecting whether the API returns denial or zero rows. |
| D1 | Call directory as super admin, active branch-A admin/receptionist. | Returns exactly active sessions' IDs/names in documented order; no inactive sessions or extra columns; preserves existing `academic_sessions` policies. |
| D2 | Directory call for null/nonexistent/branch-B by branch-A staff; teacher, inactive member and ordinary authenticated user; anon RPC call. | Unauthorized calls are denied, not returned as success or leaked data; anon has no effective EXECUTE through PUBLIC/inherited grants. |
| S1 | Attempt direct anon/authenticated enquiry INSERT/UPDATE with arbitrary `sai.public_web_enquiry=on` where connection/role permits; try setting it through exposed callable routines and pooled sessions. | No unauthorized row/assignee mutation or privilege escalation. If the current baseline permits it, classify as a blocker; the directory patch does not fix it. |
| S2 | Exercise public RPC, then in the same transaction/session attempt unrelated unauthorized DML; test failed RPC paths and reused pooled connections. | No flag or JWT-claim privilege survives in a way that authorizes later actions; RLS, grant and definer boundaries hold. Any failing baseline is a security blocker. |
| S3 | Snapshot ACLs/owners/trigger definitions before and after the patch, including PUBLIC, anon, authenticated and inherited roles. | Existing admissions trigger/public RPC/audit bodies and effective rights unchanged; directory EXECUTE limited to intended role; no unauthorized public schema CREATE. |
| H1 | Rehearse history and automation on separate MAIN-like 001–004 and STAGING-like 001–007 disposable databases. Induce failure at 005, 006, 007 and correction. | No committed window with broken public submissions; no skipped/untruthful history, no accidental deployment to other environment, and failure leaves a documented recoverable state. This is not established by the current proposal. |

Use the existing admissions SQL suite for complementary staff, session,
validation and audit-atomicity coverage after adapting the disposable fixture
to the MAIN-like production differences. Run it in the same session with its
required marker. Do not use the CLI local runner here: it expects a local
Supabase stack and may use Docker, which is prohibited for this phase.

### Tests executable locally without a database

- `node --test web\\tests\\admissions.test.cjs` exercises mocked client role,
  payload, pagination and error-handling behavior. **Executed in this phase:
  7 passed, 0 failed.** It does not evaluate SQL, Postgres grants, triggers,
  RLS, public RPC or deployment.
- Static review of the proposed SQL and comparison with migration 005 can be
  performed locally without connecting to a database. **Executed in this
  phase:** a text-level check confirmed that the proposed directory function
  matches the 005 body, contains the expected revoke/grant statements and
  does not redefine the preparation, audit or public-submission functions.
  This was not a SQL parser and cannot prove the patch executes or is safe.

**Not run:** all database/API cases P1–P4, A1–A3, D1–D2, S1–S3, H1;
the existing SQL suite; restore, migration, security advisors and integration
tests. Patch SQL syntax, permissions and runtime behavior are **UNVERIFIED**.

## Dependencies and next steps

1. Obtain fresh, read-only catalog evidence through an authorized separate
   process: MAIN/STAGING exact function bodies, signatures, RLS, policies,
   owner/ACL, public API exposure, role grants and trigger settings. Verify
   actual `auth.uid()` context and behavior of both website APIs.
2. Resolve and test the public GUC/claims trust boundaries. Confirm the
   business-approved audit attribution and preserve or intentionally change
   public validation, staff permissions and session lifecycle semantics.
3. Establish backup restore verification and the migration-aware forward
   ordering/history strategy above; prove it with failure injection and
   separate production-like and staging-like disposable environments.
4. Turn this reviewed proposal into a properly generated forward migration
   or supported deployment artifact only after those prerequisites are met.
   Run all SQL/API regressions and advisors on a disposable environment.
5. Keep MAIN deployment blocked until those results, schema drift and the
   separate attendance/finance readiness concerns are resolved.

References: [readiness report](MAIN_PRODUCTION_DEPLOYMENT_READINESS.md),
[PostgreSQL function replacement semantics](https://www.postgresql.org/docs/17/sql-createfunction.html),
[PostgreSQL custom settings](https://www.postgresql.org/docs/17/runtime-config-custom.html),
and [Supabase GitHub branching](https://supabase.com/docs/guides/deployment/branching/github-integration).
