# Web CI navigation regression — correction report (2026-11-20)

Baseline: portal version 87. Project: `aeryusbrulqdxjdynwfh` (SaaS Supabase).

## What broke

`web/tests/navigation.test.cjs` still asserted that `downloads`, `inventory`,
`transport`, `portfolio`, `housing`, `certificates`, `frontCms` and `alumni` must be
unavailable. Version 87 activated those modules (see commit 6 of
`docs/RELEASE-COMMIT-SEQUENCE.md`), so the assertion described a baseline that no
longer exists. The code was correct; the test was stale.

## Verification performed before changing any expectation

Read-only inspection of the live database (`pg_class` / `pg_policy`) and of the code:

| Module | Table | RLS | Policies | Screen |
| --- | --- | --- | --- | --- |
| downloads | `sai_download_resources` | on | read/insert/update/delete (branch + published read for student/parent) | `UnifiedModulePage` |
| inventory | `sai_inventory_items` | on | read/insert/update | `UnifiedModulePage` |
| transport | `sai_transport_routes` | on | read/insert/update/delete | `UnifiedModulePage` |
| portfolio | `sai_student_portfolios` | on | read/insert/update + student/branch guard trigger | `UnifiedModulePage` |
| housing | `sai_housing_rooms` | on | read/insert/update | `UnifiedModulePage` |
| certificates | `sai_certificates` | on | read/insert/update + student/branch guard trigger | `UnifiedModulePage` |
| frontCms | `sai_cms_pages` | on | read/insert/update/delete + anon published read | `UnifiedModulePage` |
| alumni | `sai_alumni` | on | read/insert/update + student/branch guard trigger | `UnifiedModulePage` |

Source of truth: `supabase/migrations/20261110173339_sai_unified_modules_web_mobile_secure.sql`
(tables, grants, RLS policies, stamp/audit/student-guard triggers) plus the live
catalogue confirming each table exists with RLS enabled and the expected policies.

Navigation role mapping matches the RLS roles of each table, so no module exposes a
role that the database would refuse to serve.

Modules that are still unverified (`quizzes`, `authoring`, `media`, `approvals`,
`reception`, and the lab screens) remain outside `availableModuleIds` and stay in
`pendingModules`. They are still hidden and still covered by a test.

## Defect found in the toggle logic (fixed)

`isModuleEnabledFor()` returned `true` when a per-role override said "enabled", even
if the module was disabled globally. A super administrator switching a module off
globally could therefore be bypassed by a leftover role override. Corrected
precedence:

1. Always-on module → visible.
2. Global OFF → hidden for every role, overrides ignored.
3. Global ON → explicit per-role `off` hides it for that role only; `inherit`/`on`
   keeps it; multi-role accounts get the union.

The settings panel now disables role buttons for a globally disabled module and
explains why, so the UI cannot imply an override that will not apply.

## Toggle-loading failure behaviour (reviewed)

`applyModuleToggleSnapshot()` distinguishes "read failed" (`null`) from "no rows"
(`[]`):

- First load of a session fails → nothing is hidden (fail open) so the portal stays
  reachable. Navigation is a UI hint; RLS remains the security boundary.
- After a successful load, a later failure keeps the last applied state, so a
  transient error cannot re-expose a module an administrator disabled.
- Only the override read failing is non-fatal: the global state applies and every
  role inherits it.
- Unknown role values in override rows are ignored.

## Files changed

- `src/portal/lib/navigation.ts` — global-OFF precedence, `ModuleToggleSnapshot`,
  `applyModuleToggleSnapshot`, documented failure contract.
- `src/portal/lib/moduleToggles.ts` — uses the snapshot loader; no longer clears
  state on error.
- `src/portal/pages/settings/ModuleTogglesPanel.tsx` — override copy, effective role
  count, per-role buttons disabled while the module is globally off.
- `web/tests/navigation.test.cjs` — stale expectation replaced with per-module
  verified availability, plus the still-pending set.
- `web/tests/module-toggles.test.cjs` — new regression suite: nine role mappings,
  global OFF precedence, per-role narrowing/inherit, multi-role union, unmapped role
  denial, always-on immunity, load-failure preservation, first-load fail-open,
  unknown-role rejection.

## Not done from this workspace

`git push` and running the Node test suite / CI jobs require the repository machine.
Nothing was written to production tables, no migration was applied, no RLS policy was
weakened and no security test was removed.

```powershell
git add -A
git commit -m "fix(web): correct v87 navigation availability and module toggle precedence"
git push origin main
```

Then re-run the two CI jobs; the web suite should report the navigation and toggle
tests green.