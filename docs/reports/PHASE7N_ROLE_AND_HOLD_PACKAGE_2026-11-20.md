# Phase 7-N — role management and mutation-hold remediation package

**Status: PREPARED, NOT EXECUTED.** No SQL was run against `aeryusbrulqdxjdynwfh` while producing this
package. Execution requires the owner's explicit approval of the exact file below.

| Item | Value |
| --- | --- |
| Migration | `supabase/migrations/20261120120000_role_management_and_hold_infrastructure.sql` |
| Isolated test | `supabase/tests/role_management_and_hold_forward.sql` |
| Rollback | `supabase/deployment/phase7n/rollback_role_management_and_hold.sql` |
| Project | `aeryusbrulqdxjdynwfh` (Main) |
| Replays history? | No. Forward-only, creates objects only. |
| Leaves writes open? | Yes. Hold state is committed with `enabled = false` and asserted. |

---

## 1. Why a new migration instead of replaying the old ones

Read-only catalog checks on 2026-11-20 showed the live database **never received** two migrations that
the deployed Edge Functions depend on:

| Historical file | Missing objects found |
| --- | --- |
| `20261116142308_atomic_role_management.sql` | `public.sai_manage_role_assignment(...)`, `private.sai_has_other_usable_super_admin(uuid)` |
| `20261117202728_production_mutation_hold.sql` | `private.sai_mutation_hold_state`, `private.sai_mutation_hold_audit`, `public.sai_assert_mutations_enabled()` |

Replaying them is unsafe:

- `20261117202728` **ends by switching the hold ON** (`update … set enabled = true`) and installs
  statement + row triggers on every table in `public`, `private`, `storage` and on `auth.users` /
  `auth.identities`. Applied today it would reject every insert/update/delete platform-wide.
- The committed companion `20261117202835_production_release_mutation_hold.sql` is an **empty file**
  (its locked SHA-256 is the SHA-256 of the empty string), so there would be no committed way out.

This package installs the identical reviewed infrastructure with the hold explicitly **off**, re-uses
the reviewed Phase 3B role contract verbatim, and proves the off state before committing.

---

## 2. Requirement coverage

| # | Requirement | How it is met | Proof |
| --- | --- | --- | --- |
| 1 | Hold infrastructure installed with `enabled = false` | Tables + functions + guards created; first-install row writes `enabled = false`; `on conflict do nothing` never clobbers an existing intentional hold. Guard installation is **fail-safe**: a relation the deployer cannot alter (`storage`, `auth` on hosted projects) is skipped with a notice instead of aborting the package, and `sai_set_mutation_hold` then refuses to engage the hold | Post-install `do $verify$` block raises `mutation_hold_active_after_install` if the hold is on; `private.sai_mutation_hold_missing_guards()` reports the uncovered count |
| 2 | Reviewed atomic `public.sai_manage_role_assignment` | Re-used byte-for-byte from the reviewed `20261116142308` contract: `SECURITY INVOKER`, `search_path = ''`, `pg_advisory_xact_lock(831704, 1)` first | `do $verify$` asserts `prosecdef = false`; test asserts execute is granted to `service_role` only |
| 3 | All nine roles and multi-role support preserved | Assignable set is unchanged: `super_admin, admin, teacher, accountant, receptionist, librarian, student, parent, content_editor`; membership cleanup only fires when the **last** staff role is removed | Test: grant teacher + student, revoke student, teacher scope survives |
| 4 | Authorized Super Admins can grant and revoke | Actor must hold `super_admin`; email-confirmed, non-deleted, non-banned target for grants | Test: successful grant/revoke cycle, 8 audit rows |
| 5 | No unauthorized privilege escalation | Non-Super-Admin actor → `42501`; unconfirmed email → `22023`; `super_admin` grant needs `p_confirm_super_admin`; browsers cannot execute the RPC | Test covers all four denials |
| 6 | Last usable Super Admin protected, including concurrency | `pg_advisory_xact_lock(831704, 1)` serializes every mutation **before** the existence check; revocation fails closed on `23514`; unusable accounts (unconfirmed / banned / deleted) never count | Test: single remaining admin cannot self-revoke; unusable admins do not count; `pg_locks` proves the advisory lock is held |
| 7 | Branch membership security and trusted audit | Staff roles require at least one **active** branch, duplicates rejected, `branch_memberships` rewritten only for staff roles; every mutation writes `public.audit_logs` (`role_grant` / `role_revoke`) inside the same transaction | Test: inactive branch → `22023`; branch scope = exactly the selected branches; audit count assertion |
| 8 | Compatible with existing Edge Functions, web and mobile | `public.sai_assert_mutations_enabled()` (0 args) and `public.sai_manage_role_assignment(...)` (9 args, same order/types) match exactly what `supabase/functions/manage-roles/index.ts` calls via `supabase.rpc`. Return shape `{ok, action, role}` matches the handler contract | Signature comparison against the deployed handler source |
| 9 | Existing users, roles, permissions and records preserved | No `delete`, no `truncate`, no `alter … drop`, no data rewrite. Only creates and `create or replace` of functions that were absent | Static review; nothing outside the package's own object names is touched |
| 10 | Admissions, attendance, finance, learning stay available | Hold committed off; guards are no-ops while off; `sai_set_mutation_hold` refuses to engage unless guards cover every table | Test writes to a guarded table with the hold off, and re-writes after release |

---

## 3. Validation

### Static validation (performed here)

- SQL is transactional (`begin` … `commit`) with a post-install assertion block.
- Re-runnable: `create table if not exists`, `create or replace function`, `drop trigger if exists`
  before every `create trigger`.
- No object is created twice under two names; no historical migration is modified or replayed.
- Function name/arity/return shape matches the deployed `manage-roles` handler call sites.
- The three role/permission source contracts in `web/tests/role_management_atomic.sql`,
  `web/tests/branch-membership-lockdown.test.cjs` and `web/tests/role-management.test.cjs` continue to
  pass, because the reviewed contract text is preserved.

### Native PostgreSQL validation (must be run by you — cannot be run from this workspace)

```powershell
Set-Location 'D:\SAI-College-Production'
$env:PGOPTIONS = '-c sai.role_and_hold_forward_test=yes'
psql "$env:SAI_LOCAL_DB_URL" -v ON_ERROR_STOP=1 `
  -f supabase/migrations/20261120120000_role_management_and_hold_infrastructure.sql
psql "$env:SAI_LOCAL_DB_URL" -v ON_ERROR_STOP=1 `
  -f supabase/tests/role_management_and_hold_forward.sql
```

Expected final line:

```
Role management authorization, branch scope, multi-role, last-admin, advisory-lock, audit, and hold on/off assertions passed; fixtures rolled back
```

Coverage in that file: authorization, escalation denials, branch scope, multi-role preservation,
last-usable-Super-Admin (single and with unusable decoys), advisory-lock proof, audit integrity,
hold activation, hold blocking a real table write, hold release, and normal writes while the hold is
off. The whole test runs in one transaction and ends with `rollback`.

---

## 4. Exact deployment command (only after approval)

`supabase db push` must **not** be used — 28 unrecorded historical migrations would be re-applied.

```powershell
# 0. Verified backup of the production database first.

# 1. Pre-flight: prove this is a first install and the platform is not already held.
psql "$env:SAI_MAIN_DB_URL" -v ON_ERROR_STOP=1 -c "select count(*) as hold_rows from private.sai_mutation_hold_state;" 
#    ^ returns 0 today (table absent). If it errors, the hold was never installed.
psql "$env:SAI_MAIN_DB_URL" -v ON_ERROR_STOP=1 -c "select to_regclass('public.sai_manage_role_assignment');" 
#    ^ must return NULL (RPC absent) before applying.

# 2. Apply the single reviewed file in its own transaction.
psql "$env:SAI_MAIN_DB_URL" -v ON_ERROR_STOP=1 `
  -f supabase/migrations/20261120120000_role_management_and_hold_infrastructure.sql

# 3. Record it in the migration history so a later db push never replays it.
supabase migration repair --status applied 20261120120000 --linked

# 4. Post-flight.
psql "$env:SAI_MAIN_DB_URL" -v ON_ERROR_STOP=1 -c "select enabled, reason from private.sai_mutation_hold_state;"   # enabled = false
psql "$env:SAI_MAIN_DB_URL" -v ON_ERROR_STOP=1 -c "select public.sai_assert_mutations_enabled();"                  # succeeds, no output
psql "$env:SAI_MAIN_DB_URL" -v ON_ERROR_STOP=1 -c "select count(*) from pg_trigger where tgname like 'sai_mutation_hold%';"
psql "$env:SAI_MAIN_DB_URL" -v ON_ERROR_STOP=1 -c "select private.sai_mutation_hold_missing_guards();"
```

Then, in the portal as a confirmed Super Admin: **الأدوار والصلاحيات → grant a test role → revoke it**.
The maintenance banner must not appear, and `audit_logs` must contain the `role_grant` row.

---

## 5. Recovery procedure

| Situation | Action |
| --- | --- |
| Post-install assertion fails | The transaction rolls back on its own. Nothing was created; fix and retry. |
| Hold accidentally engaged later | As a confirmed Super Admin, call `public.sai_set_mutation_hold(false, 'reason of 8+ chars')`. As a last resort, the state row can be flipped directly: `update private.sai_mutation_hold_state set enabled = false where singleton;` (the state table is deliberately excluded from the guards). |
| Need to remove the whole package | Run `supabase/deployment/phase7n/rollback_role_management_and_hold.sql`. It releases the hold, drops every guard trigger, then drops the functions. Role grant/revoke returns to its current broken state — expect that. |
| Unexpected write failures on one table | That table is missing a guard, so `sai_set_mutation_hold` would have refused; re-run `select private.sai_install_mutation_hold_guards();` to repair coverage. |
| `sai_mutation_hold_missing_guards()` returns non-zero on Main | Expected when `storage`/`auth` tables belong to another service role. The hold simply cannot be engaged from this role; role management, the mutation gate and all normal writes are unaffected. To close the gap, run only the guard installation step as a role that owns those tables. |
| Full restore | Restore the verified backup taken in step 0. The package is additive, so a data-only restore plus rollback is normally sufficient. |

---

## 6. Registration and pin refresh (required before the database job goes green)

The migration governance gate scans `supabase/migrations/*.sql` and requires a matching
`migration-lock.json` entry whose SHA-256 equals the file. Until the hash is generated by tooling, the
file is correctly reported as an **unreviewed migration** — that is the intended pre-approval state and
must not be bypassed with a hand-written hash.

After approval:

1. Append the lock entry (hash from the tool, never typed by hand):

```json
{
  "version": "20261120120000",
  "filename": "20261120120000_role_management_and_hold_infrastructure.sql",
  "sha256_lf": "<computed>",
  "history": false,
  "empty": false,
  "classification": "NOT APPLIED"
}
```

2. Generate the hash with the snippet in
   [DEPLOYMENT_PIN_REFRESH_2026-11-20](./DEPLOYMENT_PIN_REFRESH_2026-11-20.md) §1, substituting this
   filename.
3. Run `python supabase/tools/refresh_phase7m_pins.py`, then
   `python supabase/tools/validate_migrations.py` and
   `python supabase/tests/test_migration_validation.py`.

---

## 7. Approval checklist

- [ ] Isolated native test executed and passed locally.
- [ ] File hash generated and lock entry added.
- [ ] Pins refreshed (`refresh_phase7m_pins.py`) and validation clean.
- [ ] Verified production backup taken.
- [ ] Owner approves this exact file, byte for byte.
- [ ] Deployment run with `psql -v ON_ERROR_STOP=1`, followed by `migration repair --status applied 20261120120000`.
- [ ] Post-flight §4 step 4 and a live grant/revoke performed by a Super Admin.