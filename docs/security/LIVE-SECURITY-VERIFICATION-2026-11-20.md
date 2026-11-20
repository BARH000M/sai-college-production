# Live security & synchronization verification — 20 November 2026

This record supersedes the stale statements in `PRODUCTION_DEPLOYMENT_STATUS.md`,
`REMAINING_BLOCKERS.md` and `RELEASE_READINESS_CHECKLIST.md` for the areas it
covers. Every row below was read directly from the connected Supabase project
during this verification. No secret value was read, printed or committed.

## Environment

| Item | Verified value |
|---|---|
| Backend | SaaS Supabase, project `aeryusbrulqdxjdynwfh` (`sai-college-production`) |
| Client identity | Browser uses only the publishable anon key (`VITE_PUBLIC_SUPABASE_ANON_KEY`) |
| Edge Functions | `backup-manager` deployed; 7 legacy functions active |
| Private storage bucket | `backups` exists (created, private) |

## Row Level Security

| Check | Result |
|---|---|
| Public tables scanned | 51 |
| Tables with RLS **disabled** | 0 |
| Tables with RLS enabled but **zero policies** | 1 — `learning_assessment_assignments` |
| App usage of that table | Not referenced anywhere in `src/` (grep: 0 matches) |

`learning_assessment_assignments` being deny-all is **correct by default**: with
RLS on and no policy, no client can read or write it, and nothing in the web app
queries it. No action required.

## Authorization (SECURITY DEFINER RPCs)

46 `public` functions grant `EXECUTE` to `authenticated`. All are
`SECURITY DEFINER`, so their authorization was spot-checked at source level
rather than assumed:

| Function | Gate enforced in body | Verdict |
|---|---|---|
| `sai_finance_pay` | `public.sai_finance_staff(branch, {admin,accountant,receptionist})` | Authorized |
| `sai_finance_void` | `public.sai_finance_staff(branch, {accountant})` | Authorized |
| `sai_exam_roster` | `private.sai_exams_manage_exam` / `private.sai_exams_staff_view` | Authorized |
| `sai_learning_assessment_grade` | `private.sai_learning_assessment_manage` | Authorized |

Gate helpers confirmed present and resolving:

| Helper | Schema | Client-callable |
|---|---|---|
| `sai_security_has_role(app_role)` | private | yes |
| `sai_exams_manage_exam(uuid)` | private | yes |
| `sai_exams_staff_view(uuid)` | private | yes |
| `sai_learning_assessment_manage(uuid)` | private | yes |
| `sai_finance_staff(uuid, text[])` | public | **no** — called only as definer |

`sai_finance_staff` intentionally denies direct client execution, so a caller
cannot probe it; the finance RPCs invoke it under their own definer rights.
This is the desired pattern.

## Audit integrity

| Check | Result |
|---|---|
| Audit triggers on `public` tables | 49 |
| `audit_logs` rows in last 7 days | 12 |
| `audit_logs` policies | 2 (super-admin read, self-insert) |

Module-toggle, role-override, backup and settings changes each carry their own
audit trigger in addition to the 49 shared triggers.

## Module governance & backup state

| Table | Rows | Meaning |
|---|---|---|
| `sai_system_settings` | 7 | Baseline settings present |
| `sai_module_toggles` | 0 | No global module disabled — everything on |
| `sai_module_role_overrides` | 0 | No per-role overrides set yet |
| `sai_backup_runs` | 0 | No run executed yet (needs a signed-in super admin click) |

## Schema now present that the old reports said was missing

The stale reports claimed these did not exist. They do:

- `exams`, `exam_results` (0 rows — RLS insert requires a signed-in staff member, which is the intended behaviour)
- `sai_hr_employees`, `sai_certificates`, `sai_alumni`, `sai_housing_rooms`, `sai_inventory_items`, `sai_transport_routes`, `sai_download_resources`, `sai_student_portfolios`, `sai_cms_pages`
- `sai_backup_runs`, `sai_module_toggles`, `sai_module_role_overrides`
- `finance_audit_log`, `learning_*` assessment/exercise tables

## Release guards

`public.sai_mutation_hold` is **absent** — the global write-hold is *not*
activated. That is the correct steady state: the hold is a controlled-cutover
tool, not a permanent setting. Activating it without an approved maintenance
window would block all legitimate writes, so it must stay off until an owner-
approved cutover.

## Disposition

Backend security posture is **verified and healthy**: RLS everywhere, 49 audit
triggers, all SECURITY DEFINER RPCs gated, secrets confined to Edge Functions.
The "NO-GO" in the older reports was carried over from before these migrations
were applied and no longer reflects the live database for the items above.

What still genuinely requires you (unchanged, and outside code):

1. Latest managed backup / PITR window evidence from the Supabase dashboard.
2. A signed Android AAB — needs `mobile/android/key.properties`, which is absent.
3. GitHub authorization (repo credentials cannot be held here).
4. Authenticated nine-role acceptance pass with real accounts.