# Public RPC audit — enumeration oracles and exposed write surface

Date: 2026-11-09
Scope: every function in `public` reachable through PostgREST (`/rest/v1/rpc/*`)
by `authenticated` or `anon`, plus the policies that depend on them.

---

## 1. What was actually closed this round

The 023 revoke covers eleven helpers, but the audit found the same drift pattern
in finance, where six policies were still resolving helpers **unqualified**:

| Policy | Helper it resolved to |
|---|---|
| `fee_assignments_read` | `sai_finance_can_read_student(student_id, branch_id)` |
| `fee_payments_read` | `sai_finance_can_read_student(a.student_id, a.branch_id)` |
| `fee_waivers_read` | `sai_finance_can_read_student(a.student_id, a.branch_id)` |
| `fee_refunds_read` | `sai_finance_staff(branch_id, ARRAY['accountant'])` |
| `finance_audit_read` | `sai_finance_staff(branch_id, ARRAY['accountant'])` |
| `fee_groups_read` | `sai_finance_staff(branch_id, ARRAY['admin','accountant','receptionist'])` |

`public.sai_finance_staff` was invoker-mode and called `public.sai_security_*`,
so one fee row check could pass through three nested calls, and the answer
depended on the invoker's RLS rather than the real entitlement.

Applied in `026_consolidate_finance_helpers.sql`:

- `private.sai_finance_has_role`, `private.sai_finance_staff`,
  `private.sai_finance_can_read_student` created — one implementation each,
  `SECURITY DEFINER`, `search_path = pg_catalog, public, private`.
- All six policies re-pointed to `private.*`.
- The three public functions reduced to one-line delegators.

Verified after the change:

| Check | Result |
|---|---|
| Policies depending on a public `sai_*` helper (via `pg_depend`) | **0** |
| Private helpers calling a public helper | **0** |
| Private helper implementations | 17 |
| Public wrappers that stopped delegating | **0** |
| `pg_policies` text scan at default `search_path` | **0** unqualified |

Cumulative: **16 policies** now bind to `private.*` (10 from 022, 6 from 026).

### A trap worth recording

`pg_policies.qual` is deparsed **relative to the reader's `search_path`**. Inside
a function that pins `private` into its path, `private.sai_security_has_role(...)`
is printed as `sai_security_has_role(...)` — which looks like a regression and is
not one. Any hand-written text check on `pg_policies` will therefore produce
false positives or false negatives depending on who runs it. Both the gate
function and the test file use the dependency graph (`pg_depend` →
`pg_policy` / `pg_proc`) instead, which is exact.

---

## 2. Remaining exposure, ranked

### 2.1 Unauthenticated applicant enumeration — highest severity, still open

`sai_public_admission_status(p_reference text)` and
`sai_public_admission_history(p_reference text)` are `anon`-executable and look
up by `application_no`. That number is:

```
'SAI-APP-' || nextval('admissions_application_no_seq')   -- SAI-APP-1036 … SAI-APP-1041 today
```

So the key space is a dense integer run. Walking `SAI-APP-1000` → `SAI-APP-1100`
returns, for each hit, the applicant's **full name**, preferred program, level,
current status, branch and session — with no authentication at all.

This is a different class from the wrapper oracle: that one needed a signed-in
account and answered true/false; this one is anonymous and returns names.

Not changed here, because any real fix changes public UX (the status page today
asks for the reference number only). Options, in order of preference:

1. **Second factor** — require the phone or email used on the application in
   addition to the reference. Closes enumeration completely; adds one field to
   `src/pages/application-status/page.tsx`.
2. **Non-guessable reference** — replace the sequence with a random suffix
   (`SAI-APP-1041-7KQ2`) going forward. Stops future enumeration, leaves the six
   existing records guessable until they are reissued or masked.
3. **Presentation-only mitigation** — return a masked name (`A***l`) until the
   visitor proves the second factor. Weakest, but no new field.

### 2.2 Boolean entitlement oracles (authenticated)

| Function | Reachable by | Leaks | Status |
|---|---|---|---|
| 11 `sai_security_*` / `sai_learning_*` wrappers | `authenticated` | "may I read record X" for any UUID | revoke in **023** (blocked, dashboard) |
| `sai_finance_can_read_student(uuid, uuid)` | `authenticated` | same, for a student's fees | revoke in **028** (blocked, dashboard) |

Booleans only, never rows. Safe to revoke because every internal caller is
`SECURITY DEFINER` owned by `postgres`, and no client calls them (zero matches in
`src/` and `mobile/lib/`).

### 2.3 Second role-management implementation (authenticated)

`public.sai_set_role(p_user_id uuid, p_role app_role, p_enabled boolean)` still
exists — `SECURITY DEFINER`, EXECUTE to `authenticated`, guards on `super_admin`,
writes `profiles` / `user_roles` / `branch_memberships` plus a `role.grant` audit
row. It diverges from the `manage-roles` edge function (audit action names,
entity type, no campus cleanup on revoke, ignores `is_active` when picking
branches). Drop is prepared in **024** and blocked by the platform guardrail.

### 2.4 Anonymous write surface

`sai_public_admission_submit(...)` is `anon`-executable by design (public
application form). There is no rate limit or captcha at the database layer, so it
is a spam vector rather than an oracle. Application numbers are only consumed
when a row is created, so it can also run the sequence forward. Worth fronting
with the form/agent protection rather than changing the function.

### 2.5 Reviewed and cleared

| Function | Why it is fine |
|---|---|
| `sai_finance_has_role`, `sai_finance_staff` | returns facts about the **caller only**, not about an arbitrary entity |
| `sai_admissions_stale_new_count(p_branch)` | raises 42501 unless super_admin, or admin/receptionist of that branch |
| `sai_admission_status_email_context(p_enquiry_id)` | raises 42501 unless super_admin, or admin/receptionist of the enquiry's branch |
| `sai_admission_history`, `sai_admission_history_export`, `sai_admission_roster_export`, `sai_admissions_sessions`, `sai_admissions_staff`, `sai_attendance_roster`, `sai_directory`, `sai_staff_directory`, all `sai_finance_*` readers | role guard in the body plus branch scoping |
| `sai_library_issue`, `sai_library_return` | **invoker** mode (not `SECURITY DEFINER`), so RLS on `library_items` / `library_loans` is enforced — verified `prosecdef = false` |
| `sai_finance_balance(uuid)` | no EXECUTE grant to `authenticated` or `anon` at all |

---

## 3. The build gate

`private.sai_assert_security_invariants(p_enforce_execute boolean default false)`
raises `42501` when:

1. an RLS policy depends on a public `sai_*` helper;
2. a private `sai_*` helper calls a public `sai_*` helper;
3. a public wrapper stopped delegating to `private.*`;
4. *(opt-in, `p_enforce_execute => true`)* a wrapper still grants EXECUTE to
   `authenticated`.

Migration `027` calls it, so `supabase db push` fails on a dirty tree. Standalone
runs: `node supabase/tests/run-security-invariants.cjs` (exits non-zero).
Currently green, with only the advisory "pending 023/028" warning.

Flip the fourth assertion on once 023 and 028 have been run, so the oracle cannot
be reopened silently.

---

## 4. Tooling note

`GRANT`, `REVOKE` and `DROP FUNCTION` are refused from the agent SQL path as
privilege escalation. Everything in this report that required one of those is
committed as a dashboard-ready file: 021 (grants), 023 (wrapper revoke),
024 (drop `sai_set_role`), 028 (finance revoke). Everything else — helper
creation, policy re-pointing, the guard function — is applied and verified live.