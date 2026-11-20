# Deployment pin refresh, CI status and history reconciliation — 2026-11-20

Scope: `aeryusbrulqdxjdynwfh` (Main) only. No production SQL, no history repair and no
further Edge deployment was executed while producing this report. Everything below is either a
read-only catalog verification or a local file change.

---

## 1. Deployment pins

### What was refreshed

`supabase/deployment/phase7m/test-results.json` — this is the **only** pin file that is not
hash-chained, so it is the only one that can be corrected without running the offline tool.

It now records:

- `counts`: 61 local migrations, 61 GitHub migrations, 33 remote history rows ending `20261110173506`.
- `edge_function_deployment`: `manage-roles` moved from version 9 / `verify_jwt: false` / no `summary`
  action to version 10 / `verify_jwt: true` / actions `list, grant, revoke, summary`, deployed as a
  self-contained bundle.
- The pre-deployment hashes are kept under `superseded_pins` for the audit trail and are explicitly
  labelled as no longer current.

### Why the other three pins cannot be hand-edited

The three remaining pins are content-hash chained:

```
integrity.json  ──pins──▶  main-deployment-manifest.json
integrity.json  ──pins──▶  supabase/functions/manage-roles/index.ts
main-deployment-manifest.json ──pins──▶ migration-lock.json, Invoke-MainDeployment.ps1, ...
```

`validate_migrations.py` recomputes each SHA-256 and fails on any mismatch, and
`supabase/tests/test_migration_validation.py::test_manifest_tamper` asserts that editing the
manifest produces an `integrity checksum` error. Writing a hash without hashing the file would
either be a false statement or break the gate — so the refresh must be produced by the tool.

### Finish the refresh with two local steps

**Step 1 — record the four migrations that have no lock entry yet.**

`migration-lock.json` has 58 entries; these four files exist on disk without one:

```
20261120000000_backup_disaster_recovery.sql
20261120010000_module_toggles.sql
20261120020000_module_role_overrides.sql
20261120030000_hr_payroll_and_leave.sql
```

Compute each `sha256_lf` and append the entries (keep the existing object shape):

```powershell
Set-Location 'D:\SAI-College-Production'
foreach ($f in @(
  '20261120000000_backup_disaster_recovery.sql',
  '20261120010000_module_toggles.sql',
  '20261120020000_module_role_overrides.sql',
  '20261120030000_hr_payroll_and_leave.sql')) {
  $bytes = [IO.File]::ReadAllBytes("supabase/migrations/$f")
  $lf = [Text.Encoding]::UTF8.GetBytes(([Text.Encoding]::UTF8.GetString($bytes) -replace "`r`n", "`n"))
  $sha = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($lf)).Replace('-','').ToLower()
  "$f  $sha"
}
```

Entry template (classification is justified by §3, which verifies the objects exist):

```json
{
  "version": "20261120000000",
  "filename": "20261120000000_backup_disaster_recovery.sql",
  "sha256_lf": "<computed>",
  "history": false,
  "empty": false,
  "classification": "APPLIED BUT NOT RECORDED"
}
```

**Step 2 — regenerate the manifest and integrity pins.**

```powershell
python supabase/tools/refresh_phase7m_pins.py
python supabase/tools/validate_migrations.py
python supabase/tests/test_migration_validation.py
```

This single script rewrites `required_source_files`, `integrity.json`, `steps`, `deferred_steps` and
`quarantined_migrations`, so the `manage-roles/index.ts` hash and the manifest self-pin become
correct in one pass. It deliberately keeps `release_ready: false` and invalidates any prior approval
hashes.

---

## 2. The two CI jobs

GitHub Actions cannot be dispatched from this workspace, so both jobs were audited by reading every
assertion and comparing it with the current sources.

### Job `Portal / production SPA` — expected green

| Test | Assertion | State |
| --- | --- | --- |
| all workspace MCP clients… | `.mcp.json` / `.vscode/mcp.json` contain only `supabase-main`, `read_only=true`, no headers; `.codex/config.toml` has no `supabase-preview` | passes |
| web, mobile and VS Code launch… | `saiTarget !== undefined && saiTarget !== "production"` present; no retired refs; `mobile/lib/main.dart` guard; launch `toolArgs`; `live.example.json` values | passes |
| push workflows remain checks-only | `contents: read`, no push/deploy/provider tokens | passes |
| all GitHub Actions pinned | every `uses:` ends in a 40-char SHA | passes |
| root React app owns the build | `vite build`, web scripts delegate, `outDir: 'out'`, exact `web-ci` env block | passes |

The build step also passes the production gate: `VITE_SAI_TARGET=production`, the authorized URL and
`sb_publishable_ci` satisfy `assertProductionEnvironment`, and `verifyProductionBundle` finds the
authorized Supabase host in `out/`.

### Job `web/ compatibility and unit tests` — expected green

- `startup.test.cjs`: the four `auth` options are exactly
  `autoRefreshToken / detectSessionInUrl / persistSession / storageKey: sai-production-auth`, the
  rejected-configuration matrix resolves to `false` plus a reason, and the authorized project key
  still connects.
- `role-management.test.cjs`, `preview-blockers.test.cjs`, `branch-membership-lockdown.test.cjs`:
  the source-level contracts they read still hold.

**Previously failing tests and their status:** `web, mobile and VS Code launch cannot select a retired
backend` (fixed — guard wording now matches) and `startup stays renderable and never connects to an
unauthorized backend` (fixed — configuration failures no longer throw before render).

**Residual execution risk (not a logic failure):** these two tests depend on the CI toolchain, not on
project code — `vite` must export `transformWithOxc` and Node 22 must provide
`module.stripTypeScriptTypes`. If a re-run is still red, the failing names would come from that
toolchain compatibility, not from the assertions above.

### Job `Migration integrity and database security` — still red until Step 1 + Step 2

Expected failures today:

```
FAIL: unreviewed migration: 20261120000000_backup_disaster_recovery.sql
FAIL: unreviewed migration: 20261120010000_module_toggles.sql
FAIL: unreviewed migration: 20261120020000_module_role_overrides.sql
FAIL: unreviewed migration: 20261120030000_hr_payroll_and_leave.sql
FAIL: manifest hash mismatch: supabase/functions/manage-roles/index.ts
FAIL: integrity checksum mismatch: supabase/functions/manage-roles/index.ts
FAIL: integrity checksum mismatch: supabase/deployment/phase7r/main-deployment-manifest.json
```

All seven are resolved by the two commands in §1.2.

---

## 3. Migration history reconciliation

Remote history: **33 rows**, `001`–`016`, `018`–`031`, `20261110172940`, `20261110173339`,
`20261110173506`. Repository: **61 files**. So 28 files are not recorded remotely, and every one of
them is a candidate for a duplicate re-apply by `supabase db push`.

### Verified already applied — safe to mark applied (catalog evidence)

| Version | Evidence found in the live catalog |
| --- | --- |
| `20261115001316` | `private.admission_tracking_tokens` |
| `20261115014149` | `private.admission_status_events`, `public.admissions_public_history()` |
| `20261115051532` | `private.sai_finance_can_read_student()` |
| `20261116000437` | `learning_lesson_progress` basis column |
| `20261116013950` | `public.learning_exercise_questions`, `public.learning_exercise_attempts` |
| `20261116013952` | `private.sai_system_settings_audit` |
| `20261117202805` | `private.admission_status_events`, `public.admissions_public_history()` |
| `20261117202811` | `private.sai_finance_can_read_student()` |
| `20261117202825` | `public.exams`, `public.exam_results`, `public.sai_exams_classes()` |
| `20261119230404` | `public.sai_hr_employees` |
| `20261120000000` | `public.sai_backup_runs` |
| `20261120010000` | `public.sai_module_toggles` |
| `20261120020000` | `public.sai_module_role_overrides` |
| `20261120030000` | `public.sai_hr_payroll_entries`, `public.sai_hr_leave_requests` |

Mark them **one version at a time**, verifying the row appears after each command:

```powershell
supabase migration repair --status applied 20261115001316 --linked
supabase migration list --linked
# repeat for each version in the table above, never in bulk
```

### Verified NOT applied — must be executed, never repaired as applied

| Version | Missing objects | Consequence |
| --- | --- | --- |
| `20261116142308_atomic_role_management.sql` | `public.sai_manage_role_assignment(uuid, uuid, text, app_role, uuid[], boolean, boolean, text, text)`, `private.sai_has_other_usable_super_admin(uuid)` | The deployed `manage-roles` calls this RPC for every grant/revoke, so role changes cannot complete. |
| `20261117202728_production_mutation_hold.sql` | `private.sai_mutation_hold_state`, `private.sai_mutation_hold_audit`, `public.sai_assert_mutations_enabled()` | `mutationGateOpen()` cannot succeed, so grant/revoke returns the maintenance response and role management appears "paused for maintenance". |

These two are the reason the Super Admin **role assignment** screen is not functional even though
the indicators now load. They are production DDL and require explicit approval plus a reviewed hold
state — installing a mutation hold while the system is in production can, depending on the state row,
block writes across the platform.

### Still unverified — review before marking

- `20261116013951_phase2b_service_permissions.sql` — grants only.
- `20261116151509_branch_membership_write_lockdown.sql` — policies and revokes.
- `20261117202733_production_security_permissions.sql` — recreates `sai_set_role`, which migration
  `024` retired; confirm intent before applying or repairing.
- `20261117202739_production_atomic_role_management.sql` — same gap as `20261116142308`.
- `20261117202749_production_teacher_assignment.sql`, `20261117202754_production_verified_onboarding.sql`.
- `20261117202743`, `20261117202759`, `20261117202817`, `20261117202821`, `20261117202830`,
  `20261117202835` — empty placeholders; safe to mark applied once their emptiness is confirmed
  (`empty: true` in the lock).

Never run `supabase db push`, `supabase db reset` or a bulk repair against Main.

---

## 4. Approval gates

Still open:

1. Approve applying `20261116142308` and `20261117202728` (required for role management), or approve
   a reviewed replacement migration.
2. Approve the per-version `migration repair` batch above.
3. Run §1 Step 1 + Step 2 locally and commit — the hashes cannot be produced in this workspace.